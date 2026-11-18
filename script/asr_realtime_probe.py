#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""realtime 探针:paraformer-realtime-v2 的字级时间戳到底是不是声学对齐出来的。

为什么要单独一个脚本:文件转写那个异步端点不收 realtime 模型(只收 paraformer-v1/v2/mtl),
realtime 只能走 WebSocket 流式口,得装 dashscope SDK:

  python3 -m venv /tmp/dsrt/venv
  /tmp/dsrt/venv/bin/pip install --only-binary=:all: -i https://mirrors.aliyun.com/pypi/simple/ dashscope
  # 不加 --only-binary=:all: 会去源码编译 cryptography,在这台机器上必失败

而 realtime 的构造参数里有个 `timestamp_alignment_enabled` —— 这个开关的存在本身就说明
默认那份时间戳不是对齐来的。所以一次跑两遍做 A/B:开 / 关,各自算 asr_probe.sentence_fits 的 R²。
R²≈1 就是匀速铺轴;R² 明显掉下来、去线性残差变成几十毫秒,才是真对齐。

音频要 16k 单声道裸 pcm(format='pcm' 时才不跟 wav 头较劲):

  ffmpeg -y -i narration.mp3 -f s16le -acodec pcm_s16le -ac 1 -ar 16000 narration-16k.pcm

  /tmp/dsrt/venv/bin/python -I script/asr_realtime_probe.py \
    --pcm player/public/books/61355/narration-16k.pcm --save /tmp/rt-on.json  --align 1
  /tmp/dsrt/venv/bin/python -I script/asr_realtime_probe.py \
    --pcm player/public/books/61355/narration-16k.pcm --save /tmp/rt-off.json --align 0

输出刻意做成和文件转写一样的 {"transcripts":[{"sentences":[…]}]},
所以 asr_probe.py 的 --from-result / sentence_fits / 指标都能直接复用,不必再抄一份。
"""

import argparse
import os
import sys
import time
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))  # -I 下 script/ 不在 sys.path 里
import asr_probe  # noqa: E402  复用 sentence_fits / load_env_file / 报告

from dashscope.audio.asr import Recognition, RecognitionCallback  # noqa: E402


class Collector(RecognitionCallback):
    """按 sentence_id 收最终句;中间结果也在更新同一个 id,取最后一个带 words 的版本。"""

    def __init__(self, verbose=False):
        self.by_id = {}
        self.verbose = verbose
        self.errors = []

    def on_open(self):
        if self.verbose:
            print("[rt] WebSocket 已连接", flush=True)

    def on_event(self, result):
        try:
            sent = result.get_sentence()
        except Exception:  # noqa: BLE001
            sent = (result.output or {}).get("sentence") if getattr(result, "output", None) else None
        if not isinstance(sent, dict) or sent.get("sentence_id") is None:
            return
        sid = sent["sentence_id"]
        if sent.get("words"):
            self.by_id[sid] = sent
        elif sid not in self.by_id:
            self.by_id[sid] = sent

    def on_complete(self):
        if self.verbose:
            print("[rt] 服务端 complete", flush=True)

    def on_error(self, result):
        self.errors.append(str(result))

    def on_close(self):
        if self.verbose:
            print("[rt] 连接关闭", flush=True)

    def payload(self):
        sentences = [self.by_id[k] for k in sorted(self.by_id)]
        return {"transcripts": [{"sentences": sentences}]}


def run(pcm, model, align, chunk_ms, sleep_ms, sr, verbose):
    cb = Collector(verbose=verbose)
    rec = Recognition(
        model=model,
        format="pcm",
        sample_rate=sr,
        callback=cb,
        disfluency_removal_enabled=False,
        timestamp_alignment_enabled=align,
    )
    rec.start()
    data = Path(pcm).read_bytes()
    frame = max(int(sr * 2 * chunk_ms / 1000), 2)
    n = 0
    t0 = time.time()
    for i in range(0, len(data), frame):
        rec.send_audio_frame(data[i:i + frame])
        n += 1
        if sleep_ms:
            time.sleep(sleep_ms / 1000.0)
    rec.stop()
    el = time.time() - t0
    print(f"[rt] 发了 {n} 帧 / {len(data)/1e6:.1f} MB / 耗时 {el:.0f}s "
          f"(约 {len(data)/(sr*2)/max(el,1):.1f}× 实时)  request_id={rec.get_last_request_id()}")
    if cb.errors:
        print("[rt] 服务端错误: " + " | ".join(cb.errors[:3]), file=sys.stderr)
    return cb.payload()


def main():
    ap = argparse.ArgumentParser(description="paraformer realtime 字级时间戳探针")
    ap.add_argument("--pcm", required=True, help="16k 单声道裸 pcm(s16le)")
    ap.add_argument("--model", default="paraformer-realtime-v2")
    ap.add_argument("--align", default="1", help="timestamp_alignment_enabled 1/0")
    ap.add_argument("--sample-rate", type=int, default=16000)
    ap.add_argument("--chunk-ms", type=int, default=100, help="每帧音频长度")
    ap.add_argument("--sleep-ms", type=int, default=10, help="帧间隔;0=尽快发(服务端可能丢)")
    ap.add_argument("--save", required=True, help="结果 JSON 落地路径")
    ap.add_argument("--verbose", action="store_true")
    ap.add_argument("--env-file", default=".env")
    args = ap.parse_args()

    if args.env_file and os.path.exists(args.env_file):
        asr_probe.load_env_file(args.env_file)
    import dashscope
    dashscope.api_key = os.environ.get("DASHSCOPE_API_KEY") or asr_probe.env("DASHSCOPE_API_KEY")

    align = str(args.align).lower() in ("1", "true", "yes", "on")
    print(f"[rt] model={args.model} timestamp_alignment_enabled={align}")
    payload = run(args.pcm, args.model, align, args.chunk_ms, args.sleep_ms,
                  args.sample_rate, args.verbose)

    Path(args.save).write_text(__import__("json").dumps(payload, ensure_ascii=False), encoding="utf-8")
    sents = payload["transcripts"][0]["sentences"]
    nchars = sum(len(s.get("words") or []) for s in sents)
    print(f"[rt] 句子 {len(sents)} 条 · words 条目 {nchars} · 已存 {args.save}")
    if sents:
        last = sents[-1].get("end_time")
        print(f"[rt] 最后一句 end_time={last} ms(和音频总长 264098 比一下,短太多就是服务端截流了)")
    asr_probe.print_uniformity(payload)


if __name__ == "__main__":
    main()
