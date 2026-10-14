"""Fetch only the Windows x64 entries of the official Godot template ZIP."""
import binascii
import hashlib
import json
from pathlib import Path
import struct
import urllib.request
import zlib

URL = "https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/Godot_v4.6.3-stable_export_templates.tpz"
ARCHIVE_SIZE = 1255918323
OUT = Path(__file__).resolve().parents[1] / "artifacts" / "windows-build" / "templates"
OUT.mkdir(parents=True, exist_ok=True)
download_url = URL


def read_range(start, end):
    global download_url
    request = urllib.request.Request(download_url, headers={
        "Range": f"bytes={start}-{end}", "User-Agent": "Godot-Windows-review-build"
    })
    with urllib.request.urlopen(request, timeout=60) as response:
        if response.status != 206 or response.headers.get("Content-Range") != f"bytes {start}-{end}/{ARCHIVE_SIZE}":
            raise RuntimeError(f"Server did not honor byte range: {response.status} {response.headers.get('Content-Range')}")
        download_url = response.url
        data = response.read(end - start + 2)
    if len(data) != end - start + 1:
        raise RuntimeError("Incomplete range")
    return data


tail = read_range(ARCHIVE_SIZE - 65557, ARCHIVE_SIZE - 1)
eocd = tail.rfind(b"PK\x05\x06")
if eocd < 0:
    raise RuntimeError("ZIP central directory not found")
_, disk, central_disk, disk_count, total_count, central_size, central_start, comment_size = struct.unpack_from("<4s4H2IH", tail, eocd)
if disk or central_disk or disk_count != total_count:
    raise RuntimeError("Unsupported multipart ZIP")
central = read_range(central_start, central_start + central_size - 1)
offset = 0
selected = []
for _ in range(total_count):
    header = struct.unpack_from("<4s6H3I5H2I", central, offset)
    if header[0] != b"PK\x01\x02":
        raise RuntimeError("Invalid central entry")
    flags, method, crc, compressed_size, size = header[3], header[4], header[7], header[8], header[9]
    name_size, extra_size, note_size, local_start = header[10], header[11], header[12], header[16]
    name = central[offset + 46: offset + 46 + name_size].decode("utf-8")
    offset += 46 + name_size + extra_size + note_size
    if name not in ["templates/windows_release_x86_64.exe", "templates/windows_debug_x86_64.exe"]:
        continue
    if flags & 1 or method not in [0, 8]:
        raise RuntimeError("Unsupported compressed template")
    print(f"Downloading {name}: {compressed_size:,} bytes", flush=True)
    local = read_range(local_start, local_start + 29)
    local_header = struct.unpack("<4s5H3I2H", local)
    if local_header[0] != b"PK\x03\x04":
        raise RuntimeError("Invalid local entry")
    start = local_start + 30 + local_header[-2] + local_header[-1]
    compressed = read_range(start, start + compressed_size - 1)
    data = zlib.decompress(compressed, -15) if method == 8 else compressed
    if len(data) != size or binascii.crc32(data) != crc:
        raise RuntimeError("Template ZIP integrity check failed")
    path = OUT / Path(name).name
    path.write_bytes(data)
    record = {"file": path.name, "size": size, "crc32": f"{crc:08x}", "sha256": hashlib.sha256(data).hexdigest()}
    selected.append(record)
    print(json.dumps(record), flush=True)
if len(selected) != 2:
    raise RuntimeError("Both Windows x64 templates were not found")
(OUT / "provenance.json").write_text(json.dumps({"source": URL, "version": "4.6.3.stable", "archive_sha256": "3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8", "templates": selected}, indent=2), encoding="utf-8")
