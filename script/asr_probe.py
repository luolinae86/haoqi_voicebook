#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ASR 逐字时间戳探针:量「云上 ASR」比我们现在的 whisper+手工校准 charTimes 到底准不准。

用法(零第三方依赖,python3 直接跑):

  # 1) 不联网,先用仿真数据把指标跑通(验证这套度量本身可信)
  python3 -I script/asr_probe.py --book <book.json> --simulate

  # 2) 已经有识别结果 JSON 了,只跑指标(不花调用费)
  python3 -I script/asr_probe.py --book <book.json> --from-result result-61355.json

  # 3) 真跑一次:上传音频到本项目 OSS → 签名 URL → DashScope paraformer → 拉结果 → 比偏差
  #    凭证从 --env-file 取(默认 .env;里面密码带括号,`source .env` 在 zsh 会报错,
  #    所以别用 source)。DASHSCOPE_API_KEY 已加进 .env 和 .kamal/secrets 两处
  python3 -I script/asr_probe.py --env-file .env \
    --book ~/Downloads/绘本播放/player/public/data/61355/book.json \
    --audio ~/Downloads/绘本播放/player/public/books/61355/narration.mp3 \
    --oss-prefix tmp/asr-probe --save /tmp/asr-61355.json --dump /tmp/asr-61355.csv --cleanup

  重复算指标不必再花一次调用费:--from-result /tmp/asr-61355.json

2026-11-07 用 61355《女娲补天》实测到的结论(别再当新发现):
  paraformer-v2 回的是「字级 words」,但那些时刻是句内匀速铺出来的:
  句内 begin_time 对字序号线性拟合 R²=1.0000、去线性残差中位 0.2 ms,
  723 个相邻字缝隙里 713 个为 0(句中不带气口)。
  ⇒ 逐字精度 ≈ 前端「匀速猜」的兜底,换它不提升高亮。
  真信号只有句边界(begin/end + 句间 120~900 ms 留白)和识别文本本身。
  它还会把朗读的书名并进正文(书名后 ~1.3 s 停顿被抹掉),导致整页提前 ~1.4 s。
  跑之前先看「粒度自检」那一段,别只看中位偏差 —— 中位偏差里混着基线自己的错。

基准 baseline = book.json 里的 charTimes(已经人工校准入过的时刻)。
只比对汉字;标点在原流水线里继承前一个字的时间,不参与对齐。

指标口径见文末 print_report 的注释。偏差为负 = ASR 比人工时刻早。
"""

import argparse
import base64
import difflib
import hashlib
import hmac
import json
import os
import random
import re
import statistics
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from email.utils import formatdate

HAN = re.compile(u"[一-鿿]")
ASR_SUBMIT_URL = "https://dashscope.aliyuncs.com/api/v1/services/audio/asr/transcription"
ASR_TASK_URL = "https://dashscope.aliyuncs.com/api/v1/tasks/%s"


# ---------------------------------------------------------------- baseline ---

def load_baseline(path):
    """book.json → 每个汉字 token 一条记录,按全书顺序编号。"""
    book = json.load(open(path, encoding="utf-8"))
    rows = []
    for pi, page in enumerate(book["pages"], 1):
        for li, line in enumerate(page.get("lines", []), 1):
            offset = sum(len(l.get("tokens", [])) for l in page["lines"][:li - 1])
            for ti, tok in enumerate(line.get("tokens", [])):
                ch = tok.get("ch", "")
                if not HAN.search(ch):
                    continue
                idx = offset + ti
                rows.append({
                    "ch": ch,
                    "page": pi,
                    "line": li,
                    "page_start": float(page.get("start", 0.0)),
                    "page_end": float(page.get("end", 0.0)),
                    "expect": float(page["charTimes"][idx]) if idx < len(page["charTimes"]) else None,
                })
    return rows, book


# ------------------------------------------------------------- asr → words ---

def extract_asr_items(payload):
    """识别结果 JSON → [(汉字, begin_sec, end_sec)],按时间顺序。

    优先取 words(字级);只回落到 sentences 时 marked 为 0(等于没有逐字时间)。
    """
    items, level = [], None
    transcripts = payload.get("transcripts") or []
    sentences = []
    for tr in transcripts:
        sentences.extend(tr.get("sentences") or [])
    if not sentences:
        sentences = payload.get("sentences") or []

    for s in sentences:
        words = s.get("words") or []
        if words:
            level = "words"
            for w in words:
                chars = [c for c in str(w.get("text", "")) if HAN.search(c)]
                if not chars:
                    continue
                b, e = num(w.get("begin_time")), num(w.get("end_time"))
                if b is None:
                    continue
                # 一个词可能含多个汉字(文件转写基本 1 字/词,realtime 多为 2 字/词)。
                # 同词的每个字都取 begin 会把它们压在同一时刻,必须按 [begin,end] 均分 ——
                # 与 player/scripts/align/align.py 处理 whisper word 的做法一致。
                span = ((e - b) / len(chars)) if e is not None else 0.0
                for k, ch in enumerate(chars):
                    items.append((ch, b + span * k, e))
        elif level is None and s.get("text"):
            level = "sentences"
            b, e = num(s.get("begin_time")), num(s.get("end_time"))
            chars = [c for c in str(s["text"]) if HAN.search(c)]
            if not chars or b is None:
                continue
            span = (e - b) if e is not None else 0
            for k, ch in enumerate(chars):
                items.append((ch, b + span * k / max(len(chars), 1), None))
    return items, level


def num(v):
    """毫秒 → 秒;None 原样返回。"""
    return None if v is None else float(v) / 1000.0


# ------------------------------------------------------------ uniformity ----

def sentence_fits(payload):
    """每句:begin_time 对「句内第几个字」线性拟合 → (R², 去线性残差中位 ms, 步长 ms)。

    R²≈1 且残差≈0 ⇒ 这些"字级时刻"是 句时长/字数 等差铺出来的,不是声学对齐。
    这是判断能不能拿它做逐字高亮的唯一可靠依据,比中位偏差重要。
    """
    sentences = []
    for tr in payload.get("transcripts") or []:
        sentences.extend(tr.get("sentences") or [])

    fits = []
    for s in sentences:
        words = s.get("words") or []
        if len(words) < 6:
            continue
        xs = list(range(len(words)))
        ys = [float(w["begin_time"]) for w in words]
        mx, my = statistics.fmean(xs), statistics.fmean(ys)
        den = sum((x - mx) ** 2 for x in xs)
        ss_tot = sum((y - my) ** 2 for y in ys)
        if not den or not ss_tot:
            continue
        slope = sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / den
        icept = my - slope * mx
        err = [y - (slope * x + icept) for x, y in zip(xs, ys)]
        fits.append((1 - sum(e * e for e in err) / ss_tot,
                     statistics.median([abs(e) for e in err]), slope))
    return fits


def print_uniformity(payload):
    fits = sentence_fits(payload)
    print("\n" + "-" * 68)
    print("粒度自检 · 这些字级时刻到底是「对齐」还是「匀速铺」")
    print("-" * 68)
    if not fits:
        print("句子太少,判不出来。")
        return
    r2s = [f[0] for f in fits]
    res = [f[1] for f in fits]
    print(f"可比句数      : {len(fits)}")
    print(f"R² 中位/最低  : {statistics.median(r2s):.4f} / {min(r2s):.4f}")
    print(f"去线性残差中位: {statistics.median(res):.1f} ms")
    if statistics.median(r2s) > 0.999 and statistics.median(res) < 25:
        print("判定          : 句内匀速铺轴(≠ 逐字对齐)。逐字高亮换它没有收益,")
        print("                只有句边界和识别文本可用。")
    else:
        print("判定          : 句内有真实起伏,可能是声学对齐,逐字精度值得再看。")


# ------------------------------------------------------------------ align ----

def align(asr_items, baseline):
    """把 ASR 出的汉字序列对齐到原文汉字序列(全书一次,单调天然成立)。

    matched: 原文下标 → ASR begin(秒)
    其余为「需要插值」——即 ASR 没给到这个字,前端只能按行窗口匀速估。
    """
    a = [r["ch"] for r in baseline]
    b = [ch for ch, _s, _e in asr_items]
    sm = difflib.SequenceMatcher(a=a, b=b, autojunk=False)
    matched = {}
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag != "equal":
            continue
        for k in range(i2 - i1):
            matched[i1 + k] = asr_items[j1 + k][1]
    return matched


def align_linewise(asr_items, book, tol=0.3):
    """复刻 player/scripts/align/align.py 的口径:先按人工短句窗口切识别字,
    窗口内 difflib,对不上的在窗口内匀速兜底,窗口外的锚点一律不要。

    这才是"能不能换 ASR 引擎"该看的口径 —— 全书一条 difflib 会把边界误差一路
    累积下去(实测能把 page 2 之后整页带偏 1.4 s),生产流水线不允许它漂出句子。

    返回每字一条 {page,line,ch,expect,got,hit};hit=False 表示这个字没进窗口、
    只能匀速猜 —— 换引擎时真正会退化的就是这个比例,不是时间戳精度。
    """
    rows = []
    for pi, page in enumerate(book["pages"], 1):
        char_times = page.get("charTimes") or []
        for li, line in enumerate(page.get("lines", []), 1):
            tokens = line.get("tokens", [])
            base = sum(len(l.get("tokens", [])) for l in page["lines"][:li - 1])
            real = [ti for ti, t in enumerate(tokens) if HAN.search(t.get("ch", ""))]
            if not real:
                continue
            ls, le = float(line.get("start", 0.0)), float(line.get("end", 0.0))
            win = [(ch, s) for ch, s, _e in asr_items if ls - tol <= s <= le + tol]
            known = "".join(tokens[ti]["ch"] for ti in real)
            rec = "".join(ch for ch, _ in win)
            got = {}
            for a, b, size in difflib.SequenceMatcher(None, known, rec, autojunk=False).get_matching_blocks():
                for k in range(size):
                    got[real[a + k]] = win[b + k][1]
            span = (le - ls) / len(real)
            for j, ti in enumerate(real):
                t = got.get(ti)
                idx = base + ti
                rows.append({
                    "page": pi, "line": li, "ch": tokens[ti]["ch"],
                    "expect": float(char_times[idx]) if idx < len(char_times) else None,
                    "got": t if t is not None else ls + j * span,
                    "hit": t is not None,
                })
    return rows


def print_linewin(rows, label, listen=10):
    cmp_rows = [r for r in rows if r["expect"] is not None]
    if not cmp_rows:
        print("没有可比的 expect(基准里没有 charTimes?)")
        return
    d = sorted(abs((r["got"] - r["expect"]) * 1000.0) for r in cmp_rows)
    n = len(d)
    miss = sum(1 for r in cmp_rows if not r["hit"])
    print(f"\n{'-' * 68}\n生产口径(短句窗口)· {label}")
    print(f"{'-' * 68}")
    print(f"字数 {n} · 需匀速兜底 {miss} ({miss / n * 100:.1f}%)  ← 换引擎先看这个")
    print(f"偏差 中位 {statistics.median(d):.0f} ms · p90 {d[int(n * .9)]:.0f} · "
          f"p95 {d[int(n * .95)]:.0f} · max {d[-1]:.0f} ms")
    for th in (100, 150, 300, 500):
        c = sum(1 for v in d if v > th)
        print(f"  超 {th} ms: {c} 字 ({c / n * 100:.1f}%)")

    worst = sorted(cmp_rows, key=lambda r: abs(r["got"] - r["expect"]), reverse=True)[:listen]
    print(f"\n分歧最大的 {len(worst)} 处 —— 基线也是机器算的,谁对只能去听:")
    print(f"  {'页':>3} {'行':>3} {'字':>3} {'基准':>9} {'ASR':>9} {'差':>8} 来源")
    for r in worst:
        src = "对齐" if r["hit"] else "匀速兜底"
        print(f"  {r['page']:>3} {r['line']:>3} {r['ch']:>3} "
              f"{r['expect']:>8.3f}s {r['got']:>8.3f}s "
              f"{(r['got'] - r['expect']) * 1000:>+7.0f}ms {src}")



# ---------------------------------------------------------------- metrics ----

def metrics(matched, baseline, level):
    deltas = []
    per_page = {}
    for i, r in enumerate(baseline):
        got = matched.get(i)
        p = per_page.setdefault(r["page"], {"n": 0, "hit": 0, "first_delta": None})
        p["n"] += 1
        if got is None or r["expect"] is None:
            continue
        p["hit"] += 1
        d = (got - r["expect"]) * 1000.0
        deltas.append(abs(d))
        if p["first_delta"] is None:
            p["first_delta"] = d
            p["first_raw"] = d
    total = len(baseline)
    hit = len(deltas)
    out = {
        "level": level,
        "total_han": total,
        "matched": hit,
        "match_rate": hit / total if total else 0.0,
        "interpolated": total - hit,
        "median_ms": statistics.median(deltas) if deltas else None,
        "mean_ms": statistics.fmean(deltas) if deltas else None,
        "p90_ms": pct(deltas, 0.90),
        "p95_ms": pct(deltas, 0.95),
        "max_ms": max(deltas) if deltas else None,
        "over_150ms": sum(1 for d in deltas if d > 150),
        "over_300ms": sum(1 for d in deltas if d > 300),
        "over_500ms": sum(1 for d in deltas if d > 500),
        "per_page": per_page,
    }
    return out


def pct(xs, q):
    if not xs:
        return None
    ys = sorted(xs)
    return ys[min(int(len(ys) * q), len(ys) - 1)]


def print_report(m, rows, top=12):
    lvl = {"words": "字级 words", "sentences": "句级 sentences(退化成匀速,不可用)"}.get(m["level"], "无")
    print("\n" + "=" * 68)
    print("ASR 逐字时间戳 · 与已校准 charTimes 的偏差")
    print("=" * 68)
    print(f"返回粒度        : {lvl}")
    print(f"全书汉字        : {m['total_han']}")
    print(f"对齐命中        : {m['matched']}  ({m['match_rate'] * 100:.1f}%)")
    print(f"需插值(没命中)  : {m['interpolated']}  ← 决定前端有多少字是「匀速猜」的")
    if m["median_ms"] is None:
        print("没有可比对的命中,指标无法计算。")
        return
    print(f"偏差 中位/均值  : {m['median_ms']:.0f} ms / {m['mean_ms']:.0f} ms")
    print(f"偏差 p90 / p95  : {m['p90_ms']:.0f} ms / {m['p95_ms']:.0f} ms")
    print(f"偏差 最大       : {m['max_ms']:.0f} ms")
    print(f"超 ±150/300/500 : {m['over_150ms']} / {m['over_300ms']} / {m['over_500ms']} 字")

    print("\n按页(页首偏差 = 自动翻页的时刻对不对,正=晚于人工):")
    print(f"  {'页':>3} {'字数':>5} {'命中':>5} {'命中率':>7} {'页首偏差':>9}")
    for page in sorted(m["per_page"]):
        p = m["per_page"][page]
        rate = p["hit"] / p["n"] * 100 if p["n"] else 0
        fd = f"{p['first_raw']:+.0f}ms" if p.get("first_raw") is not None else "  n/a"
        print(f"  {page:>3} {p['n']:>5} {p['hit']:>5} {rate:>6.1f}% {fd:>9}")

    worst = sorted(rows, key=lambda r: abs(r["delta_ms"]), reverse=True)[:top]
    print(f"\n偏差最大的 {len(worst)} 个字(拿这几个去听,判断谁是对的):")
    print(f"  {'页':>3} {'行':>3} {'字':>3} {'人工':>9} {'ASR':>9} {'偏差':>9}")
    for r in worst:
        print(f"  {r['page']:>3} {r['line']:>3} {r['ch']:>3} "
              f"{r['expect']:>8.3f}s {r['got']:>8.3f}s {r['delta_ms']:>+8.0f}ms")
    print("")


# --------------------------------------------------------------- simulate ----

def simulate(baseline, seed=20260, sigma=0.06, dropout=0.05):
    """造一份「像 ASR 的」结果,用来验证指标本身(不联网)。"""
    rnd = random.Random(seed)
    items = []
    for r in baseline:
        if r["expect"] is None or rnd.random() < dropout:
            continue
        items.append((r["ch"], r["expect"] + rnd.gauss(0, sigma), None))
    items.sort(key=lambda x: x[1])
    return items, "words"


# -------------------------------------------------------------- dashscope ----

def http_json(url, body=None, headers=None, method=None, timeout=60):
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(url, data=data, method=method or ("POST" if data else "GET"))
    for k, v in (headers or {}).items():
        req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as res:
            raw = res.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        # 阿里云把真正的原因写在响应体里,状态码本身没用
        detail = exc.read().decode("utf-8", "replace")
        raise SystemExit(f"HTTP {exc.code} ← {url}\n{detail[:900]}") from None
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        raise SystemExit(f"返回不是 JSON({url}): {raw[:400]}")


def oss_sign_get(bucket, endpoint, key, ak, sk, ttl=3600):
    """和 voicebook 的 AliyunOssService#generate_signed_url 同口径(OSS V1 query 签名)。"""
    exp = int(time.time()) + ttl
    resource = f"/{bucket}/{key}"
    sig = base64.b64encode(
        hmac.new(sk.encode(), f"GET\n\n\n{exp}\n{resource}".encode(), hashlib.sha1).digest()
    ).decode()
    q = urllib.parse.urlencode({"Expires": exp, "OSSAccessKeyId": ak, "Signature": sig})
    return f"https://{bucket}.{endpoint}/{key}?{q}"


def oss_put(bucket, endpoint, key, path, ak, sk, content_type="audio/mpeg"):
    body = open(path, "rb").read()
    date = formatdate(usegmt=True)
    resource = f"/{bucket}/{key}"
    sig = base64.b64encode(
        hmac.new(sk.encode(), f"PUT\n\n{content_type}\n{date}\n{resource}".encode(), hashlib.sha1).digest()
    ).decode()
    req = urllib.request.Request(f"https://{bucket}.{endpoint}/{key}", data=body, method="PUT")
    req.add_header("Date", date)
    req.add_header("Content-Type", content_type)
    req.add_header("Authorization", f"OSS {ak}:{sig}")
    with urllib.request.urlopen(req, timeout=300) as res:
        if res.status >= 300:
            raise SystemExit(f"OSS PUT 失败 {res.status}")
    return f"https://{bucket}.{endpoint}/{key}"


def oss_delete(bucket, endpoint, key, ak, sk):
    """删掉探针传上去的临时对象(生产 bucket 不留垃圾)。"""
    date = formatdate(usegmt=True)
    resource = f"/{bucket}/{key}"
    sig = base64.b64encode(
        hmac.new(sk.encode(), f"DELETE\n\n\n{date}\n{resource}".encode(), hashlib.sha1).digest()
    ).decode()
    req = urllib.request.Request(f"https://{bucket}.{endpoint}/{key}", method="DELETE")
    req.add_header("Date", date)
    req.add_header("Authorization", f"OSS {ak}:{sig}")
    try:
        urllib.request.urlopen(req, timeout=60)
        return True
    except Exception as exc:  # noqa: BLE001 清理失败不该盖掉主结果
        print(f"  清理失败({exc}),对象 oss://{bucket}/{key} 请手动删", file=sys.stderr)
        return False


def run_asr(url, key, model, extra_params, polls=120):
    params = {"channel_id": [0], "language_hints": ["zh"], "disfluency_removal_enabled": False}
    params.update(extra_params or {})
    body = {"model": model, "input": {"file_urls": [url]}, "parameters": params}
    headers = {
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
        "X-DashScope-Async": "enable",
    }
    print(f"提交识别 model={model} …")
    res = http_json(ASR_SUBMIT_URL, body, headers)
    task_id = (res.get("output") or {}).get("task_id")
    if not task_id:
        raise SystemExit("没拿到 task_id: " + json.dumps(res, ensure_ascii=False)[:500])
    print(f"task_id={task_id} 轮询中 …")
    out = None
    for i in range(polls):
        time.sleep(2)
        out = (http_json(ASR_TASK_URL % task_id, headers=headers).get("output")) or {}
        st = out.get("task_status")
        if st in ("SUCCEEDED", "FAILED"):
            break
        if i % 5 == 0:
            print(f"  …{st} ({i * 2}s)")
    if out.get("task_status") != "SUCCEEDED":
        raise SystemExit("任务没成功: " + json.dumps(out, ensure_ascii=False)[:500])
    results = out.get("results") or []
    if not results or not results[0].get("transcription_url"):
        raise SystemExit("没有 transcription_url: " + json.dumps(out, ensure_ascii=False)[:500])
    tu = results[0]["transcription_url"]
    print("下载逐字结果 …")
    return http_json(tu)


# ------------------------------------------------------------------- main ----

def main():
    ap = argparse.ArgumentParser(description="ASR 逐字时间戳质量探针")
    ap.add_argument("--book", required=True, help="已校准的 book.json(基准)")
    ap.add_argument("--audio", help="原始旁白 mp3(要真跑时上传 OSS 用)")
    ap.add_argument("--url", help="音频已经可访问的 URL(给了就不上传)")
    ap.add_argument("--from-result", help="已下载的识别结果 JSON,只算指标")
    ap.add_argument("--simulate", action="store_true", help="用仿真结果跑通指标,不联网")
    ap.add_argument("--model", default="paraformer-v2")
    ap.add_argument("--param", action="append", default=[], metavar="K=V",
                    help="追加到 parameters 里的实验开关,可重复;V 为 JSON")
    ap.add_argument("--oss-prefix", default="asr-probe", help="OSS 上传前缀")
    ap.add_argument("--save", help="把原始识别结果存到这个文件,便于反复算指标")
    ap.add_argument("--dump", help="把逐字比对明细写成 CSV")
    ap.add_argument("--cleanup", action="store_true", help="跑完删掉传上去的临时 OSS 对象")
    ap.add_argument("--env-file", default=".env",
                    help="从这里取凭证(值带括号时 shell source 不了);设为 '' 则只用环境变量")
    ap.add_argument("--linewin", action="store_true",
                    help="按生产口径比(复刻 align.py 的短句窗口),这才是能不能换引擎的依据")
    ap.add_argument("--against", action="append", default=[], metavar="BOOK_JSON",
                    help="比对的 charTimes 来源,可重复(如 beforeSmooth.bak = whisper 原值);"
                         "不给就用 --book 自己")
    ap.add_argument("--label", default="", help="输出里给这份识别结果起的名字")
    args = ap.parse_args()
    if args.env_file and os.path.exists(args.env_file):
        load_env_file(args.env_file)

    baseline, _book = load_baseline(args.book)
    print(f"基准 {args.book}: {len(baseline)} 个汉字")
    uploaded = None
    payload = None

    extra = {}
    for kv in args.param:
        k, _, v = kv.partition("=")
        extra[k] = json.loads(v) if v[:1] in "[{\"0123456789tfn" else v

    if args.simulate:
        items, level = simulate(baseline)
        print("模式:仿真(指标自检)")
    elif args.from_result:
        payload = json.load(open(args.from_result, encoding="utf-8"))
        items, level = extract_asr_items(payload)
        print(f"模式:离线结果 {args.from_result}")
    else:
        url = args.url
        if not url:
            if not args.audio:
                raise SystemExit("要真跑得给 --audio 或 --url;或者先 --simulate")
            ak, sk = env("ALIYUN_ACCESS_KEY_ID"), env("ALIYUN_ACCESS_KEY_SECRET")
            bucket, endpoint = env("OSS_BUCKET_NAME"), env("OSS_ENDPOINT").replace("https://", "").replace("http://", "")
            key = f"{args.oss_prefix}/{os.path.basename(args.audio)}"
            print(f"上传 {args.audio} → oss://{bucket}/{key} …")
            oss_put(bucket, endpoint, key, args.audio, ak, sk)
            uploaded = (bucket, endpoint, key, ak, sk)
            url = oss_sign_get(bucket, endpoint, key, ak, sk, ttl=7200)
            print("已生成签名 URL(有效期 2h)")
        try:
            payload = run_asr(url, env("DASHSCOPE_API_KEY"), args.model, extra)
        finally:
            if args.cleanup and uploaded:
                if oss_delete(*uploaded):
                    print("临时 OSS 对象已删除")
        if args.save:
            json.dump(payload, open(args.save, "w", encoding="utf-8"), ensure_ascii=False)
            print(f"原始结果已存 {args.save}")
        items, level = extract_asr_items(payload)

    print(f"ASR 出字 {len(items)} 个 · 粒度 {level or '无'}")
    if payload:
        print_uniformity(payload)

    if args.linewin:
        name = args.label or os.path.basename(args.from_result or args.save or "ASR")
        for path in (args.against or [args.book]):
            if os.path.abspath(path) == os.path.abspath(args.book):
                bk = _book
            else:
                bk = json.load(open(path, encoding="utf-8"))
            print_linewin(align_linewise(items, bk), f"{name}  vs  {os.path.basename(path)}")

    matched = align(items, baseline)

    rows = []
    for i, r in enumerate(baseline):
        got = matched.get(i)
        if got is not None and r["expect"] is not None:
            rows.append({"page": r["page"], "line": r["line"], "ch": r["ch"],
                         "expect": r["expect"], "got": got,
                         "delta_ms": (got - r["expect"]) * 1000.0})

    print_report(metrics(matched, baseline, level), rows)

    if args.dump:
        with open(args.dump, "w", encoding="utf-8") as f:
            f.write("page,line,ch,expect,got,delta_ms\n")
            for r in rows:
                f.write(f"{r['page']},{r['line']},{r['ch']},{r['expect']:.3f},{r['got']:.3f},{r['delta_ms']:.0f}\n")
        print(f"明细已写 {args.dump}({len(rows)} 行)")


def env(name):
    v = os.environ.get(name)
    if not v:
        raise SystemExit(f"环境变量 {name} 没设(可用 --env-file 从 .env/.kamal/secrets 取)")
    return v


def load_env_file(path):
    """按 NAME=VALUE 取值填进环境,已有的不覆盖。

    本项目 .env 的密码值里有括号,`source .env` 在 zsh 下会 parse error,
    所以不借 shell,直接在这里解析。
    """
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, _, v = line.partition("=")
            k, v = k.strip(), v.strip().strip('"').strip("'")
            if k and k not in os.environ:
                os.environ[k] = v


if __name__ == "__main__":
    main()
