#!/usr/bin/env python3
"""
使用 faster-whisper 进行音字强制对齐
输出字级别的精准时间戳，用于绘本字幕同步
"""

import sys
import json
import argparse
from faster_whisper import WhisperModel


def transcribe_audio(audio_path, model_size="base", language="zh"):
    """
    使用 faster-whisper 转录音频并返回字级别时间戳

    Args:
        audio_path: 音频文件路径
        model_size: 模型大小 (tiny, base, small, medium, large-v3)
        language: 语言代码

    Returns:
        包含字级别时间戳的列表
    """
    # 加载模型
    # 使用 cpu 模式，如果需要更快可以用 cuda
    model = WhisperModel(model_size, device="cpu", compute_type="int8")

    # 转录音频，启用 word timestamps
    segments, info = model.transcribe(
        audio_path,
        language=language,
        word_timestamps=True,
        vad_filter=True,  # 启用语音活动检测
        vad_parameters=dict(min_silence_duration_ms=500)
    )

    # 收集所有字级别时间戳
    words = []
    for segment in segments:
        if segment.words:
            for word in segment.words:
                words.append({
                    "text": word.word.strip(),
                    "start_ms": round(word.start * 1000),
                    "end_ms": round(word.end * 1000)
                })

    return words


def main():
    parser = argparse.ArgumentParser(description="音字强制对齐工具")
    parser.add_argument("audio_path", help="音频文件路径")
    parser.add_argument("--model", default="base",
                        choices=["tiny", "base", "small", "medium", "large-v3"],
                        help="模型大小 (default: base)")
    parser.add_argument("--output", "-o", help="输出 JSON 文件路径")

    args = parser.parse_args()

    print(f"处理音频: {args.audio_path}", file=sys.stderr)
    print(f"使用模型: {args.model}", file=sys.stderr)

    # 转录音频
    words = transcribe_audio(args.audio_path, model_size=args.model)

    result = {
        "word_count": len(words),
        "words": words
    }

    # 输出结果
    output_json = json.dumps(result, ensure_ascii=False, indent=2)

    if args.output:
        with open(args.output, 'w', encoding='utf-8') as f:
            f.write(output_json)
        print(f"结果已保存到: {args.output}", file=sys.stderr)
    else:
        print(output_json)

    print(f"共识别 {len(words)} 个字", file=sys.stderr)


if __name__ == "__main__":
    main()
