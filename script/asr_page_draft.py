#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""翻页初稿:用 paraformer-realtime 的真实气口,自动定 page / 短句 的边界时刻。

分工先划清(61355《女娲补天》实测,结论也写在 asr_probe.py 顶部):
  逐字高亮 = charTimes,来自 whisper 对齐 + smooth.py + 人工微调,ASR 换不掉
             —— realtime 句内仍是匀速铺轴,粒度只有 ~2 字;
  翻页边界 = 一条时间线上 pageCount-1 个切点,只问"哪里停顿",
             这恰好是 realtime 比现有文件转写强的唯一一处(它有真气口,
             还会把书名单独切成一句,文件转写会把书名并进正文导致整页提前)。
所以本脚本只产边界,一个字都不碰 charTimes。

前端的读法(src/composables/usePlayback.js):
  pageIndexAt(t) 从头找第一个 t < page.end 的页 —— 翻页只看 page.end;
  goToPage() 则 seek 到 page.start。实测 book.json:page[i+1].start == page[i].end、
  页首行 start == page.start、页末行 end == page.end,11 页无缝铺满 0→264.024。
  ⇒ 要生成的其实只有一列单调递增的切点,页窗口和行窗口都从它派生。

人工惯例(10 个页切点全量测过,别自己发明一套):
  切点一律落在「上页末字 onset → 下页首字 onset」之间,缝隙中位 1.39 s,
  在缝隙内的位置比例 中位 0.64(min 0.42 / max 1.00)
  ⇒ 默认 --frac 0.64:切在停顿走完约 2/3 处,新页在该页首字前约 0.5 s 出现。

短句窗口顺手做严:现有人工数据里有行 start 比本行首字还晚 1.43 s、
行 end 比本行末字早 1.93 s 的 —— align.py 正是拿行窗口筛锚点,窗口歪了字就落不进去。
这里让行也首尾相接,每个行窗口必然含住自己的字。
但行切点的**数值**不取自识别:实测行窗口彼此重叠、根本不是人工惯例,而 ASR 给的
行切点对现值飘 ±0.5 s(最大 2.6 s),远不如这本书自己的 charTimes ——
所以默认 页边界←识别气口、行边界←本书 charTimes(--line-source 可切)。

  python3 -I script/asr_page_draft.py \
    --result /tmp/rt/align-1.json \
    --book "player/public/data/61355/book.json" \
    --emit /tmp/rt/book.draft.json

不联网、不需要 API key —— 吃 asr_realtime_probe.py 存下来的结果就行。
"""

import argparse
import difflib
import json
import statistics
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))  # -I 下 script/ 不在 sys.path 里
import asr_probe  # noqa: E402  复用 num / HAN / 环境读取

HAN = asr_probe.HAN


def _s(v, nd=2):
    """表格里 None(没有锚点)要能打出来,别整张表崩掉。"""
    return "—" if v is None else f"{v:.{nd}f}"


def sentences(payload):
    out = []
    for tr in payload.get("transcripts") or []:
        out.extend(tr.get("sentences") or [])
    if not out:
        out = payload.get("sentences") or []
    return sorted(out, key=lambda s: (s.get("begin_time") if s.get("begin_time") is not None else 0))


def asr_onsets(payload):
    """→ [(汉字, onset秒, 词号, 句号)],按时间序。词内多字按 [begin,end] 均分取 onset。

    不直接用 asr_probe.extract_asr_items:它第三个字段是整个词的 end,跨页的那个词会把
    「下页首字所属词的结束」当成「上页末字的结束」,缝隙就被吃掉了。这里要的是 onset
    (和 charTimes 同一个参照点,人工惯例也是按 onset 量的),外加词号 ——
    好判断两页首尾是不是落在同一个词里(那就是没停顿)。
    """
    rows = []
    wid = 0
    for si, s in enumerate(sentences(payload)):
        sb = asr_probe.num(s.get("begin_time"))
        se = asr_probe.num(s.get("end_time"))
        words = s.get("words") or []
        if words:
            for w in words:
                wid += 1
                chars = [c for c in str(w.get("text", "")) if HAN.search(c)]
                b = asr_probe.num(w.get("begin_time"))
                e = asr_probe.num(w.get("end_time"))
                if b is None or not chars:
                    continue
                step = ((e - b) / len(chars)) if (e is not None and len(chars) > 1) else 0.0
                for k, c in enumerate(chars):
                    rows.append((c, b + step * k, wid, si))
        elif s.get("text") and sb is not None:
            # 没有 words 的兜底(纯句级):整句匀速铺,缝隙不可信,后面会标出来
            wid += 1
            chars = [c for c in str(s["text"]) if HAN.search(c)]
            step = ((se - sb) / len(chars)) if (se is not None and chars) else 0.0
            for k, c in enumerate(chars):
                rows.append((c, sb + step * k, wid, si))
    rows.sort(key=lambda r: r[1])
    return rows


def book_char_onsets(book):
    """→ {汉字位置: 该书 charTimes 里的秒数};整本没有 charTimes 则返回 None。

    汉字位置和 book_units 是同一个索引空间(只数汉字、跳标点),而 charTimes 数的是
    token,所以这里得自己走一遍 token 下标。

    为什么行切点要用它:现书的行窗口根本不是"惯例",而是 align.py 的残留 ——
    行与行最多重叠 1.4 s、行 start 可以比上一行末字晚 1~5 s,只是每条窗口够宽
    把自己那几个字含住了(实测 725 字只有 10 个落在窗外)。所以拿"初稿 vs 现行窗口"
    算 |差| 没有判据意义。行切点真正的强证据本来就在这本书里:charTimes
    (whisper 对齐 + smooth.py + 人工微调),比 realtime 句内匀速铺轴准得多。
    ⇒ 分工:页边界问 ASR 的气口(全篇停顿只有它有),行边界问自己的 charTimes。
    """
    out, h = {}, 0
    for pg in book["pages"]:
        ct = pg.get("charTimes") or []
        base = 0
        for line in pg.get("lines", []):
            for i, t in enumerate(line.get("tokens", [])):
                if HAN.search(t.get("ch", "")):
                    if base + i < len(ct):
                        out[h] = float(ct[base + i])
                    h += 1
            base += len(line.get("tokens", []))
    return out or None


def book_units(book):
    """→ 行单元表(全书阅读顺序),每个带自己的汉字区间 [lo,hi) 和页号/行号。

    索引空间只有一个:全书汉字展平后的位置(跳标点,因为 ASR 不回标点)。
    charTimes 是按 token 排的,那是另一个空间 —— 本脚本不做逐字,只在自检里
    换算一次(见 window_miss)。
    """
    units, flat, g = [], [], 0
    for pi, pg in enumerate(book["pages"]):
        for li, line in enumerate(pg.get("lines", [])):
            lo = g
            for t in line.get("tokens", []):
                if HAN.search(t.get("ch", "")):
                    flat.append(t["ch"])
                    g += 1
            units.append({"page": pi, "line": li, "lo": lo, "hi": g,
                          "text": "".join(flat[lo:g])})
    return units, "".join(flat)


def map_to_asr(book_str, rows):
    """全书汉字串 vs 识别汉字串 difflib → {书中位置: 识别位置}。

    只用来认字,不用来推时间:每个切点的时间取自它自己那对首末字的 onset,
    所以这里不会像"全书一条 difflib 量精度"那样把误差一路累积下去。
    """
    asr_str = "".join(r[0] for r in rows)
    pos = {}
    sm = difflib.SequenceMatcher(None, book_str, asr_str, autojunk=False)
    for a, b, size in sm.get_matching_blocks():
        for k in range(size):
            pos[a + k] = b + k
    return pos


def anchor(pos, rows, lo, hi, reach, want_last=True):
    """在 [lo,hi) 里找一个有识别锚点的字,返回 (onset, 词号, 句号, 偏离边缘几个字)。

    want_last=True 取本单元最靠后的锚点(算停顿的左端),反之取最靠前的(右端)。
    两端各让 reach 个字:识别漏字/错字时不至于整段没锚点,但会如实报出退让距离。
    """
    rng = range(hi - 1, lo - 1, -1) if want_last else range(lo, hi)
    for step, i in enumerate(rng):
        if step >= reach:
            break
        ap = pos.get(i)
        if ap is not None:
            _ch, t, wid, si = rows[ap]
            return t, wid, si, step
    return None, None, None, None


def cut_pairs(units, pos, rows, char_on, frac, line_frac, min_gap, reach, line_source):
    """相邻两个行单元之间定一个切点。缝隙不可信的一律如实标记,不偷偷改数。

    信号来源按边界类型分:
      页切点 → ASR 的字 onset。判据是 evidence:两个锚点跨了识别的**句子**才算真有停顿;
                跨词不算 —— realtime 句内是匀速铺轴的,同句两个词之间那个"缝"是算出来的,
                不是听出来的。实测 10 个页切点全部跨句(所以页边界准),
                行切点只有 29/83 跨句。
      行切点 → 优先本书 charTimes(--line-source char,默认),ASR 只作没有 charTimes 时的后备。
    """
    cuts = []
    for u, v in zip(units, units[1:]):
        page_seam = u["page"] != v["page"]
        flags = []
        if page_seam or not char_on or line_source != "char":
            a, wa, sa, ka = anchor(pos, rows, u["lo"], u["hi"], reach, want_last=True)
            b, wb, sb, kb = anchor(pos, rows, v["lo"], v["hi"], reach, want_last=False)
            src, f, ev = "asr", frac, bool(sa is not None and sb is not None and sa != sb)
            reach_cost = (ka or 0) + (kb or 0)
            if not page_seam and src == "asr" and not ev:
                flags.append("同句内(匀速猜)")
            if wa is not None and wa == wb:
                flags.append("同词(其实没停顿)")
        else:
            a = char_on.get(u["hi"] - 1)
            b = char_on.get(v["lo"])
            src, f, ev, reach_cost = "char", line_frac, None, 0
        if a is None or b is None:
            cut, gap = None, None
            flags.append("无锚点")
        else:
            gap = b - a
            if gap <= 0:
                cut, flags = a + 0.15, flags + ["倒挂"]
            elif gap < min_gap:
                cut, flags = a + max(gap * f, 0.05), flags + ["停顿短"]
            else:
                cut = a + f * gap
        cuts.append({"after_line": u, "before_line": v, "page_seam": page_seam,
                     "a": a, "b": b, "gap": gap, "cut": cut, "flags": flags,
                     "reach": reach_cost, "evidence": ev, "source": src})
    return cuts


def make_monotone(cuts, units, total):
    """切点必须严格递增才能翻页。没锚点的按前后可靠点线性插值,并把调整如实记下。"""
    n = len(cuts)
    if n == 0:
        return
    for i, c in enumerate(cuts):
        if c["cut"] is not None:
            continue
        lo = next((j for j in range(i - 1, -1, -1) if cuts[j]["cut"] is not None), None)
        hi = next((j for j in range(i + 1, n) if cuts[j]["cut"] is not None), None)
        t0 = cuts[lo]["cut"] if lo is not None else 0.0
        t1 = cuts[hi]["cut"] if hi is not None else total
        span = (hi if hi is not None else n) - (lo if lo is not None else -1)
        c["cut"] = t0 + (t1 - t0) * ((i - (lo if lo is not None else -1)) / max(span, 1))
        c["flags"].append("插值")
    eps = 0.05
    for i in range(1, n):
        if cuts[i]["cut"] <= cuts[i - 1]["cut"] + eps:
            cuts[i]["cut"] = cuts[i - 1]["cut"] + eps
            cuts[i]["flags"].append("被推后(保单调)")
    for i in range(n - 2, -1, -1):
        if cuts[i]["cut"] >= cuts[i + 1]["cut"] - eps:
            cuts[i]["cut"] = max(cuts[i + 1]["cut"] - eps, 0.0)
            cuts[i]["flags"].append("被提前(保单调)")


def windows_from_cuts(book, units, cuts, total):
    """切点 → page.start/end 与 line.start/end。

    cuts[i] 就是第 i 条线与第 i+1 条线之间(units 按页/行阅读顺序建),所以
    行 i = [cuts[i-1], cuts[i]]、末行 end = 总时长;页窗口再从本页首行 start /
    末行 end 取 —— 页与页、页与行因此天然首尾相接,不用另外对齐。
    """
    out = json.loads(json.dumps(book))  # 深拷贝,原书只读
    line_no = 0
    for pi, pg in enumerate(out["pages"]):
        for li, line in enumerate(pg.get("lines", [])):
            line["start"] = round(cuts[line_no - 1]["cut"], 3) if line_no > 0 else 0.0
            line["end"] = (round(cuts[line_no]["cut"], 3)
                           if line_no < len(cuts) else round(total, 3))
            line_no += 1
        if pg.get("lines"):
            pg["start"] = pg["lines"][0]["start"]
            pg["end"] = pg["lines"][-1]["end"]
    out["pages"][-1]["end"] = round(total, 3)
    return out


def char_times(pg):
    return pg.get("charTimes") or []


def token_line_offsets(pg):
    return [sum(len(l.get("tokens", [])) for l in pg["lines"][:i]) for i in range(len(pg["lines"]))]


def window_miss(pg, tol):
    """本页有多少字的时间落在自己的行窗口外(±tol)—— 这就是 align.py 要匀速兜底的比例。"""
    ct, miss, tot = char_times(pg), 0, 0
    offs = token_line_offsets(pg)
    for li, line in enumerate(pg.get("lines", [])):
        toks = line.get("tokens", [])
        base = offs[li]
        for i, t in enumerate(toks):
            if not HAN.search(t.get("ch", "")):
                continue
            idx = base + i
            if idx >= len(ct):
                continue
            tot += 1
            if not (line["start"] - tol <= ct[idx] <= line["end"] + tol):
                miss += 1
    return miss, tot


def attach_delta(cuts, book):
    """每个切点对上现书的值(页切点比下一页 start,行切点比下一行 start)。"""
    for c in cuts:
        u = c["after_line"]
        c["cur"] = float(book["pages"][u["page"] + 1]["start"] if c["page_seam"]
                         else book["pages"][u["page"]]["lines"][u["line"] + 1]["start"])
        c["delta"] = c["cut"] - c["cur"]


def evidence_summary(cuts):
    """分层报 |差| —— 哪类切点能信、哪类只是噪声,全在这张表里。"""
    print("\n=== 分层:每类切点对现书的偏离 ===")
    groups = [
        ("页切点·跨识别句(有停顿证据)", lambda c: c["page_seam"] and c["evidence"]),
        ("页切点·同句内(匀速猜)", lambda c: c["page_seam"] and not c["evidence"]),
        ("行切点·取自本书 charTimes", lambda c: not c["page_seam"] and c["source"] == "char"),
        ("行切点·取自 ASR(后备)", lambda c: not c["page_seam"] and c["source"] != "char"),
    ]
    for tag, sel in groups:
        xs = [abs(c["delta"]) for c in cuts if sel(c)]
        if not xs:
            continue
        print(f"{tag:28} {len(xs):>3} 个 · |差| 中位 {statistics.median(xs):.2f} s"
              f" · 最大 {max(xs):.2f} s · agree±0.3 {sum(1 for x in xs if x <= .3)}/{len(xs)}")
    print("注:行切点那一栏的对照值不是'人工惯例' —— 现书行窗口是 align.py 残留、彼此重叠,"
          "\n    所以行切点看下面的结构自检,不看这张偏离表。")


def main():
    ap = argparse.ArgumentParser(description="realtime 气口 → 页/短句边界初稿")
    ap.add_argument("--result", required=True, help="asr_realtime_probe.py 存的 JSON")
    ap.add_argument("--book", required=True, help="book.json(要 pages[].lines[].tokens[].ch)")
    ap.add_argument("--frac", type=float, default=0.64,
                    help="页切点在「上末字→下首字」缝隙内的位置,人工中位 0.64")
    ap.add_argument("--line-frac", type=float, default=0.5,
                    help="行切点(取本书 charTimes 时)的缝隙内位置;charTimes 已是 onset,"
                         "两侧都是字的起点,取中间最保守")
    ap.add_argument("--line-source", choices=["char", "asr"], default="char",
                    help="行切点的信号源;char=本书 charTimes(默认,强),"
                         "asr=用识别气口(只有没有 charTimes 时才该用)")
    ap.add_argument("--min-gap", type=float, default=0.25, help="小于这个缝隙不算停顿")
    ap.add_argument("--reach", type=int, default=6, help="找锚点最多往单元内退几个字")
    ap.add_argument("--tol", type=float, default=0.3, help="行窗口容差(与 align.py 一致)")
    ap.add_argument("--emit", help="把初稿写这份(拷原书、只改 start/end)")
    ap.add_argument("--show-lines", action="store_true", help="连行切点一起列")
    args = ap.parse_args()

    payload = json.loads(Path(args.result).read_text(encoding="utf-8"))
    book = json.loads(Path(args.book).read_text(encoding="utf-8"))
    total = float(book.get("totalDuration") or 0.0)
    rows = asr_onsets(payload)
    units, bstr = book_units(book)
    char_on = book_char_onsets(book)
    pos = map_to_asr(bstr, rows)
    hit = len(pos)
    print(f"识别 onset {len(rows)} 字 · 书 {len(bstr)} 字 · difflib 认上 {hit} "
          f"({hit / max(len(bstr), 1) * 100:.1f}%) · 行单元 {len(units)}")
    if not char_on and args.line_source == "char":
        print("这本书没有 charTimes,行切点只能退回识别气口(会明显更飘)")

    cuts = cut_pairs(units, pos, rows, char_on, args.frac, args.line_frac,
                     args.min_gap, args.reach, args.line_source)
    make_monotone(cuts, units, total)
    attach_delta(cuts, book)

    print("\n=== 页边界:现值 vs 初稿 ===(证据列 句=跨识别句,即真有停顿)")
    print(f"{'切点':>7} {'现值':>7} {'初稿':>7} {'差':>7} {'上末字':>7} {'下首字':>7} "
          f"{'缝隙':>5} {'退让':>4} {'证据':>4}  备注")
    for c in cuts:
        if not c["page_seam"]:
            continue
        pi = c["after_line"]["page"]
        print(f"p{pi+1}|p{pi+2:<4} {c['cur']:>7.2f} {c['cut']:>7.2f} {c['delta']:>+7.2f} "
              f"{_s(c['a']):>7} {_s(c['b']):>7} {_s(c['gap']):>5} {c['reach']:>4} "
              f"{'句' if c['evidence'] else '—':>4}  "
              + (" ".join(c["flags"]) if c["flags"] else "")
              + f"   「{c['after_line']['text'][-4:]}」→「{c['before_line']['text'][:4]}」")

    if args.show_lines:
        print("\n=== 行切点 ===(来源 字=本书 charTimes / asr=识别气口)")
        print(f"{'页':>3}{'行':>3} {'现值':>7} {'初稿':>7} {'差':>7} {'缝隙':>5} {'来源':>4}  备注")
        for c in cuts:
            if c["page_seam"]:
                continue
            u = c["after_line"]
            print(f"{u['page']+1:>3}{u['line']+1:>3} {c['cur']:>7.2f} {c['cut']:>7.2f} "
                  f"{c['delta']:>+7.2f} {_s(c['gap']):>5} "
                  f"{'字' if c['source'] == 'char' else 'asr':>4}  "
                  + (" ".join(c["flags"]) if c["flags"] else ""))

    evidence_summary(cuts)

    draft = windows_from_cuts(book, units, cuts, total)

    print("\n=== 自检 ===")
    bad = []
    prev = -1.0
    for pg in draft["pages"]:
        if not (pg["start"] < pg["end"]):
            bad.append(f"页 {pg['start']}≥{pg['end']}")
        if pg["start"] < prev:
            bad.append("页窗口逆序")
        prev = pg["start"]
        for line in pg["lines"]:
            if not (line["start"] < line["end"]):
                bad.append(f"行 {pg.get('start')}:{line['start']}≥{line['end']}")
    for a, b in zip(draft["pages"], draft["pages"][1:]):
        if abs(a["end"] - b["start"]) > 1e-3:
            bad.append(f"页不接 {a['end']}≠{b['start']}")
    if abs(draft["pages"][-1]["end"] - total) > 1e-3:
        bad.append(f"末页 end {draft['pages'][-1]['end']} ≠ totalDuration {total}")
    print("结构      : " + ("全部通过(单调、页行首尾相接、末页对齐总时长)" if not bad
                        else "有问题 → " + "; ".join(bad[:5])))

    m0 = t0 = m1 = t1 = 0
    for old, new in zip(book["pages"], draft["pages"]):
        a, n = window_miss(old, args.tol)
        b, m = window_miss(new, args.tol)
        m0, t0 = m0 + a, t0 + n
        m1, t1 = m1 + b, t1 + m
    print(f"窗口外字数: 现书 {m0}/{t0} ({m0/max(t0,1)*100:.1f}%) → 初稿 {m1}/{t1} "
          f"({m1/max(t1,1)*100:.1f}%)")
    if args.line_source == "char":
        print("           这一项在 --line-source char 下是构造性成立(行窗口由 charTimes 自己划的),"
              "\n           真正可能压线的只剩页边界那 10 处 —— 别把 0.0% 当成证据")
    print("           口径注意:这是「新窗口 vs 已定稿 charTimes」的相容度,"
          "和先前那个 13.9%(「ASR 时刻 vs 现窗口」)参照不同,别混为一谈")
    if m1 > m0:
        print("           初稿更差:切点压到了字的时间上,人工微调过的 charTimes 落在窗口外了 —— 听一下再说")

    if args.emit:
        Path(args.emit).write_text(json.dumps(draft, ensure_ascii=False), encoding="utf-8")
        print(f"\n已写 {args.emit}(拷自原书,只改 page/line 的 start/end,charTimes 原样)")


if __name__ == "__main__":
    main()
