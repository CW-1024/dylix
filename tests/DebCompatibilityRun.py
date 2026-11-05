#!/usr/bin/env python3
"""Issue #2: actual package writer, dpkg and compressed-member/parent-directory checks."""
from pathlib import Path
import argparse, gzip, hashlib, io, json, plistlib, shutil, struct, subprocess, tempfile, tarfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path)
args = parser.parse_args()

def audit(path, scheme, image):
    raw = path.read_bytes()
    assert raw[:8] == b'!<arch>\n'
    members = {}; at = 8
    while at < len(raw):
        header = raw[at:at+60]; assert header[58:60] == b'`\n'
        size = int(header[48:58]); name = header[:16].decode().strip().rstrip('/')
        assert name not in members
        members[name] = raw[at+60:at+60+size]
        assert len(members[name]) == size
        at += 60 + size + size % 2
    assert at == len(raw)
    # This is the gzip branch TrollFools actually accepts, not raw data.tar.
    assert list(members) == ['debian-binary', 'control.tar.gz', 'data.tar.gz'], list(members)
    assert members['debian-binary'] == b'2.0\n'
    archives = {}
    for name in ['control', 'data']:
        compressed = members[name + '.tar.gz']; assert compressed[:2] == b'\x1f\x8b'
        data = gzip.decompress(compressed); assert data[-1024:] == bytes(1024)
        archives[name] = tarfile.open(fileobj=io.BytesIO(data), mode='r:')
    control, payload = archives['control'], archives['data']
    fields = control.extractfile('./control').read().decode()
    arch = {'rootful': 'iphoneos-arm', 'rootless': 'iphoneos-arm64', 'roothide': 'iphoneos-arm64e'}[scheme]
    assert 'Architecture: ' + arch + '\n' in fields
    assert control.getmember('./postinst').mode == 0o755
    entries = {e.name: e for e in payload.getmembers()}; assert len(entries) == len(payload.getmembers())
    prefix = './var/jb/' if scheme == 'rootless' else './'
    lib = prefix + 'Library/MobileSubstrate/DynamicLibraries/Fixture.dylib'
    assert payload.extractfile(lib).read() == image
    assert payload.getmember(lib).mode == 0o755
    filt = plistlib.loads(payload.extractfile(lib[:-6] + '.plist').read())
    assert filt['Filter']['Bundles'] == ['com.example.fixture']
    bundle = prefix + 'Library/Application Support/Fixture.bundle'
    assert entries[bundle].isdir(), 'bundle needs its own directory record for TrollFools'
    assert payload.extractfile(bundle + '/extra.txt').read() == b'resource\n'
    assert payload.extractfile(bundle + '/中文.txt').read().decode() == '中文资源\n'
    assert payload.extractfile(bundle + '/' + 'p' * 95 + '/long.txt').read() == b'long path\n'
    for e in entries.values():
        assert e.uid == 0 and e.gid == 0
        if e.name == '.': continue
        parent = str(Path(e.name).parent)
        key = '.' if parent == '.' else './' + parent
        assert key in entries and entries[key].isdir(), ('missing directory', e.name, key)
    assert entries['.'].isdir()
    return {'scheme': scheme, 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest(), 'entries': len(entries), 'compression': 'gzip', 'architecture': arch}

with tempfile.TemporaryDirectory(prefix='dylix-deb-issue2-') as tmp:
    work = Path(tmp); project = work/'project'; project.mkdir()
    out = args.output.resolve() if args.output else work/'output'; out.mkdir(parents=True, exist_ok=True)
    # A real arm64 dylib, without external framework dependencies.
    (project/'Fixture.c').write_text('int fixture(void) { return 42; }\n')
    subprocess.run(['xcrun', 'clang', '-target', 'arm64-apple-ios15.0', '-c', str(project/'Fixture.c'), '-o', str(work/'fixture.o')], check=True)
    subprocess.run(['xcrun', 'ld', '-dylib', '-arch', 'arm64', '-platform_version', 'ios', '15.0', '18.0', '-install_name', '@rpath/Fixture.dylib', str(work/'fixture.o'), '-o', str(project/'Fixture.dylib')], check=True)
    bundle = project/'layout/Library/Application Support/Fixture.bundle'; bundle.mkdir(parents=True)
    (bundle/'中文.txt').write_text('中文资源\n')
    longdir = bundle/('p'*95); longdir.mkdir(); (longdir/'long.txt').write_text('long path\n')
    scripts = project/'layout/DEBIAN'; scripts.mkdir(); (scripts/'postinst').write_text('#!/bin/sh\nexit 0\n')
    (project/'extra.txt').write_bytes(b'resource\n')
    (project/'outside-link').symlink_to('/etc/hosts')
    sdk = '/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk'
    if not Path(sdk).exists(): sdk = subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'], text=True).strip()
    subprocess.run(['xcrun','clang','-isysroot',sdk,'-fobjc-arc',str(ROOT/'tests/DebCompatibilityTests.m'),str(ROOT/'App/DebPackage.m'),'-framework','Foundation','-larchive','-o',str(work/'test')], check=True)
    subprocess.run([str(work/'test'),str(project),str(out)], check=True)
    results = []
    for scheme in ['rootful','rootless','roothide']:
        path = out/(scheme+'.deb'); result = audit(path,scheme,(project/'Fixture.dylib').read_bytes())
        if shutil.which('dpkg-deb'):
            for flag in ['--info','--contents']:
                check = subprocess.run(['dpkg-deb',flag,str(path)], capture_output=True, text=True)
                assert check.returncode == 0, check.stderr
                (out/(scheme+flag+'.txt')).write_text(check.stdout)
            dest = work/(scheme+'-extract')
            subprocess.run(['dpkg-deb','--extract',str(path),str(dest)],check=True)
            installed = dest/('var/jb' if scheme=='rootless' else '')/'Library/MobileSubstrate/DynamicLibraries/Fixture.dylib'
            assert installed.read_bytes() == (project/'Fixture.dylib').read_bytes()
            result['dpkgVerified'] = True
        results.append(result); print('PASS',scheme,result['entries'],'archive entries')
    (out/'results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2))
    print('PASS issue #2 package compatibility regression')
