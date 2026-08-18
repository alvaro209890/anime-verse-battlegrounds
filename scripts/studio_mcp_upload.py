"""Cliente MCP NDJSON para o StudioMCP.exe (nao usa Content-Length)."""

from __future__ import annotations

import json
import subprocess
import sys
import threading
import time

EXE = r"C:\Users\Usuario\AppData\Local\Roblox\Versions\version-d679641ad17741aa\StudioMCP.exe"
FILES = [
    "http://127.0.0.1:8765/avb_slate_cracked_floor_normal.png",
    "http://127.0.0.1:8765/avb_slate_cracked_floor_roughness.png",
    "http://127.0.0.1:8765/avb_slate_cracked_floor_metalness.png",
    "http://127.0.0.1:8765/avb_runed_stone_wall_normal.png",
    "http://127.0.0.1:8765/avb_runed_stone_wall_roughness.png",
    "http://127.0.0.1:8765/avb_runed_stone_wall_metalness.png",
    "http://127.0.0.1:8765/avb_crystal_emissive_strip_normal.png",
    "http://127.0.0.1:8765/avb_crystal_emissive_strip_roughness.png",
    "http://127.0.0.1:8765/avb_crystal_emissive_strip_metalness.png",
]


def send(proc: subprocess.Popen, obj: dict) -> None:
    line = json.dumps(obj, separators=(",", ":")) + "\n"
    assert proc.stdin is not None
    proc.stdin.write(line.encode("utf-8"))
    proc.stdin.flush()


def read_json(proc: subprocess.Popen, timeout: float) -> dict | None:
    assert proc.stdout is not None
    deadline = time.time() + timeout
    buf = b""
    while time.time() < deadline:
        ch = proc.stdout.read(1)
        if not ch:
            time.sleep(0.01)
            continue
        buf += ch
        if ch == b"\n":
            line = buf.decode("utf-8", errors="replace").strip()
            if not line:
                buf = b""
                continue
            return json.loads(line)
    return None


def main() -> int:
    proc = subprocess.Popen(
        [EXE, "-v"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    def drain() -> None:
        assert proc.stderr is not None
        for raw in proc.stderr:
            sys.stderr.write(raw.decode("utf-8", errors="replace"))

    threading.Thread(target=drain, daemon=True).start()
    send(
        proc,
        {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "avb-upload", "version": "1"},
            },
        },
    )
    init = read_json(proc, 20)
    print("INIT", json.dumps(init, ensure_ascii=False)[:1500] if init else None)
    if not init or "error" in init:
        proc.kill()
        return 3
    send(proc, {"jsonrpc": "2.0", "method": "notifications/initialized"})
    send(proc, {"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}})
    listed = read_json(proc, 20)
    names = []
    if listed and "result" in listed:
        names = [t.get("name") for t in listed["result"].get("tools", [])]
    print("TOOL_NAMES", names)
    send(
        proc,
        {
            "jsonrpc": "2.0",
            "id": 3,
            "method": "tools/call",
            "params": {"name": "list_roblox_studios", "arguments": {}},
        },
    )
    studios = read_json(proc, 25)
    print("STUDIOS", json.dumps(studios, ensure_ascii=False)[:2000] if studios else None)
    studio_id = None
    if studios and "result" in studios:
        content = studios["result"].get("content") or []
        text = ""
        for item in content:
            if item.get("type") == "text":
                text += item.get("text") or ""
        try:
            parsed = json.loads(text)
            if isinstance(parsed, list) and parsed:
                studio_id = parsed[0].get("id") or parsed[0].get("studio_id")
            elif isinstance(parsed, dict):
                studio_id = parsed.get("id") or parsed.get("studio_id")
                if not studio_id:
                    arr = parsed.get("studios") or parsed.get("instances") or []
                    if arr:
                        studio_id = arr[0].get("id")
        except json.JSONDecodeError:
            print("STUDIO_TEXT", text[:1500])
    print("STUDIO_ID", studio_id)
    if not studio_id:
        proc.kill()
        return 4
    send(
        proc,
        {
            "jsonrpc": "2.0",
            "id": 4,
            "method": "tools/call",
            "params": {
                "name": "upload_image",
                "arguments": {"imagePaths": FILES, "studio_id": studio_id},
            },
        },
    )
    uploaded = read_json(proc, 180)
    print("UPLOAD", json.dumps(uploaded, ensure_ascii=False)[:4000] if uploaded else None)
    proc.kill()
    return 0 if uploaded else 5


if __name__ == "__main__":
    raise SystemExit(main())
