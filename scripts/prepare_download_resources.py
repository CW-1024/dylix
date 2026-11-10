"""Pin optional archives and optionally stage a static dylib.cn deployment tree."""
from pathlib import Path
import argparse
import hashlib
import json
import re
import shutil

ROOT = Path(__file__).resolve().parents[1]

def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for part in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(part)
    return h.hexdigest()

def prepare(stage=None):
    # Optional payloads are hosted separately; a clean source checkout uses the
    # pinned manifest without downloading hundreds of megabytes during a build.
    lock_path = ROOT / 'Resources/DownloadResources.json'
    locked = {row['id']: row for row in json.loads(lock_path.read_text())}
    rows = []
    for identifier, title, path in [
        ('developer-tools', '开发工具', ROOT / 'Resources/iSH/developer-tools.tar'),
        ('reverse-tools', '逆向分析工具', ROOT / 'Resources/iSH/reverse-tools.tar'),
        ('sdk26', 'iOS 26.0 SDK', ROOT / 'build/embedded-SDK26.zip'),
    ]:
        row = locked.get(identifier)
        if not row or not re.fullmatch(r'[0-9a-f]{64}', row.get('sha256', '')):
            raise ValueError(f'Missing or invalid resource lock: {identifier}')
        filename = f"{identifier}-{row['sha256'][:16]}{path.suffix}"
        if (row.get('file') != filename or row.get('title') != title
                or type(row.get('bytes')) is not int or row['bytes'] <= 0
                or row.get('url') != f'https://dylib.cn/downloads/dylix/v1/{filename}'):
            raise ValueError(f'Invalid resource metadata: {identifier}')
        if path.exists():
            if path.stat().st_size != row['bytes'] or digest(path) != row['sha256']:
                raise ValueError(f'Local archive differs from resource lock: {identifier}')
        elif stage:
            raise FileNotFoundError(f'Staging requires {path}; fetch {row["url"]} and verify SHA-256 {row["sha256"]}')
        rows.append(dict(row))
        if stage:
            target = Path(stage) / 'downloads/dylix/v1' / filename
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, target)
    if stage:
        notices = Path(stage) / 'downloads/dylix/notices'
        shutil.copytree(ROOT / 'Resources/ThirdPartyNotices', notices, dirs_exist_ok=True)
        shutil.copytree(ROOT / 'Resources/iSH/GuestTools', notices / 'GuestTools', dirs_exist_ok=True)
        shutil.copy2(ROOT / 'Resources/iSH/developer-tools.json', notices / 'developer-tools.json')
        shutil.copy2(ROOT / 'Resources/iSH/reverse-tools.json', notices / 'reverse-tools.json')
    return rows

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--stage', type=Path)
    parser.add_argument('--output', type=Path, default=ROOT / 'Resources/DownloadResources.json')
    args = parser.parse_args()
    args.output.write_text(json.dumps(prepare(args.stage), ensure_ascii=False, indent=2) + '\n')
    print(args.output)
