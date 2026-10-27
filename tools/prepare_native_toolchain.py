"""Fetch a pinned official Zig compiler into the project, verifying its checksum."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import subprocess
import time
import urllib.request
import zipfile

from run_checks import ROOT

VERSION = '0.15.2'
FOLDER = ROOT / 'artifacts' / 'native-toolchain'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mirror', help='Base URL listed by ziglang.org/download/community-mirrors.txt')
    parser.add_argument('--probe', action='store_true', help='Measure a small range from official-listed mirrors without executing it')
    parser.add_argument('--workers', type=int, default=1, help='Parallel verified byte ranges (1 to 16)')
    args = parser.parse_args()
    FOLDER.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen('https://ziglang.org/download/index.json', timeout=45) as response:
        package = json.load(response)[VERSION]['x86_64-windows']
    url = package['tarball']
    if not url.startswith('https://ziglang.org/download/' + VERSION + '/'):
        raise RuntimeError('Unexpected official toolchain URL')
    archive = FOLDER / url.rsplit('/', 1)[-1]
    if args.mirror or args.probe:
        with urllib.request.urlopen('https://ziglang.org/download/community-mirrors.txt', timeout=30) as response:
            mirrors = response.read().decode('utf-8').splitlines()
        mirrors = [entry.rstrip('/') for entry in mirrors if entry.startswith('https://')]
        if args.probe:
            def probe(base):
                started = time.monotonic()
                try:
                    req = urllib.request.Request(base + '/' + archive.name, headers={'Range': 'bytes=0-65535'})
                    with urllib.request.urlopen(req, timeout=8) as result:
                        data = result.read(65536)
                        return {'mirror': base, 'seconds': round(time.monotonic() - started, 3),
                                'bytes': len(data), 'status': result.status,
                                'content_range': result.headers.get('Content-Range')}
                except Exception as error:
                    return {'mirror': base, 'error': str(error)}
            with ThreadPoolExecutor(max_workers=6) as pool:
                for result in pool.map(probe, mirrors):
                    print(json.dumps(result), flush=True)
            return
        if args.mirror.rstrip('/') not in mirrors:
            raise RuntimeError('Mirror is not in the official community list')
        url = args.mirror.rstrip('/') + '/' + archive.name
    (FOLDER / 'official-package.json').write_text(json.dumps(package, indent=2), encoding='utf-8')
    expected = package['shasum']
    if not 1 <= args.workers <= 16:
        raise ValueError('workers must be between 1 and 16')
    if args.workers > 1 and (not archive.is_file() or hashlib.sha256(archive.read_bytes()).hexdigest() != expected):
        total = int(package['size'])
        step = 2 * 1024 * 1024
        parts = FOLDER / 'range-parts'
        parts.mkdir(exist_ok=True)
        def fetch_part(index):
            low = index * step
            high = min(total, low + step) - 1
            part = parts / f'{index:04d}.bin'
            if part.is_file() and part.stat().st_size == high - low + 1:
                return part
            for attempt in range(3):
                try:
                    req = urllib.request.Request(url, headers={'Range': f'bytes={low}-{high}'})
                    with urllib.request.urlopen(req, timeout=20) as response:
                        if response.status != 206 or response.headers.get('Content-Range') != f'bytes {low}-{high}/{total}':
                            raise RuntimeError('Mirror did not honor exact requested byte range')
                        data = response.read(high - low + 2)
                    if len(data) != high - low + 1:
                        raise RuntimeError('Incomplete byte range')
                    part.write_bytes(data)
                    print(json.dumps({'range_completed': index, 'bytes': len(data)}), flush=True)
                    return part
                except Exception:
                    if attempt == 2:
                        raise
            raise RuntimeError('Unreachable range retry')
        with ThreadPoolExecutor(max_workers=args.workers) as pool:
            downloaded = list(pool.map(fetch_part, range((total + step - 1) // step)))
        temporary = archive.with_suffix('.zip.assembled')
        digest = hashlib.sha256()
        with temporary.open('wb') as output:
            for part in downloaded:
                data = part.read_bytes()
                output.write(data)
                digest.update(data)
        if digest.hexdigest() != expected or temporary.stat().st_size != total:
            raise RuntimeError('Official compiler checksum/size mismatch; no extraction or execution')
        temporary.replace(archive)
    if not archive.is_file() or hashlib.sha256(archive.read_bytes()).hexdigest() != expected:
        temporary = archive.with_suffix('.zip.partial')
        digest = hashlib.sha256()
        size = temporary.stat().st_size if temporary.is_file() else 0
        if size:
            digest.update(temporary.read_bytes())
        request = urllib.request.Request(url, headers={'Range': f'bytes={size}-'} if size else {})
        started = time.monotonic()
        with urllib.request.urlopen(request, timeout=20) as response:
            if response.status == 206:
                if not response.headers.get('Content-Range', '').startswith(f'bytes {size}-'):
                    raise RuntimeError('Unexpected resume Content-Range; partial archive preserved')
            else:
                size = 0; digest = hashlib.sha256()
            with temporary.open('ab' if size else 'wb') as output:
                notice = size // (1024 * 1024)
                while chunk := response.read1(64 * 1024):
                    output.write(chunk); output.flush(); digest.update(chunk); size += len(chunk)
                    if time.monotonic() - started > 600:
                        raise TimeoutError('Download exceeded ten minutes; verified final checksum remains required on resume')
                    if size // (1024 * 1024) != notice:
                        notice = size // (1024 * 1024)
                        print(json.dumps({'downloaded_bytes': size}), flush=True)
        if digest.hexdigest() != expected or size != int(package['size']):
            raise RuntimeError('Official compiler checksum/size mismatch; no extraction or execution')
        temporary.replace(archive)
    target = FOLDER / archive.stem
    executable = target / 'zig.exe'
    if not executable.is_file():
        base = FOLDER.resolve()
        with zipfile.ZipFile(archive) as bundle:
            for member in bundle.infolist():
                path = (base / member.filename).resolve()
                if not path.is_relative_to(base):
                    raise RuntimeError('Archive member outside toolchain directory')
            bundle.extractall(base)
    process = subprocess.run([str(executable), 'version'], capture_output=True, text=True, check=True)
    if process.stdout.strip() != VERSION:
        raise RuntimeError('Unexpected compiler version')
    print(json.dumps({'version': VERSION, 'executable': str(executable), 'sha256': expected,
                      'scope': 'Project-local compiler only; no system installation or PATH change'}), flush=True)


if __name__ == '__main__':
    main()
