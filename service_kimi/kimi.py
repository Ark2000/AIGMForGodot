"""用法: python kimi.py <session_dir>
读取 session_dir/messages.json、tools.json，将 API 响应写入 session_dir/output.json（原子替换）。
并发时每个任务使用独立 session 目录即可。"""

import json
import sys
from pathlib import Path

import httpx
from openai import OpenAI

endpoint = {
    "api_key": "sk-quzV3bnKVN4OG4CCNnu8aaK4llfWEsv9bhVVwoW7x0DdW2B4",
    "base_url": "https://api.moonshot.cn/v1",
}


def _load(p: Path):
    with open(p, encoding="utf-8") as f:
        return json.load(f)


def _write_atomic(path: Path, obj) -> None:
    tmp = path.parent / (path.name + ".tmp")
    tmp.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(path)


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: python kimi.py <session_dir>", file=sys.stderr)
        return 2
    root = Path(sys.argv[1]).resolve()
    out = root / "output.json"
    try:
        params = {
            "model": "kimi-k2.5",
            "messages": _load(root / "messages.json"),
            "tools": _load(root / "tools.json"),
            "max_tokens": 32768,
            "stream": False,
        }
        http = httpx.Client(trust_env=False)
        client = OpenAI(**endpoint, http_client=http)
        r = client.chat.completions.create(**params)
        _write_atomic(out, r.model_dump())
        return 0
    except Exception as e:
        try:
            _write_atomic(out, {"error": str(e)})
        except OSError:
            pass
        print(e, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
