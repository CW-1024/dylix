#!/usr/bin/env python3
"""Build three real package variants with the installed simulator app and inspect archives."""
import io, json, os, plistlib, shutil, subprocess, tarfile, tempfile, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'evidence/1.0.8-build192-deb-compatibility/simulator'
APP = 'com.xuegao.theosmobilecompiler'
DEVICE = os.environ.get('DYLIX_SIM_DEVICE', 'booted')
def sim(*args):
    return subprocess.check_output(['xcrun','simctl',*map(str,args)], text=True).strip()

sim('install',DEVICE,ROOT/'build/simulator/TheosMobileCompiler.app')
doc = Path(sim('get_app_container',DEVICE,APP,'data'))/'Documents'
OUT.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix='dylix-issue2-ios-') as temp:
    project=Path(temp)
    (project/'Fixture.c').write_text('int package_fixture(void) { return 42; }\n')
    (project/'MobileCompiler.json').write_text(json.dumps({'name':'Deb compatibility','productName':'Fixture','sources':['Fixture.c'],'package':True,'exportDylib':True,'packageSchemes':['rootless','rootful','roothide']}))
    (project/'control').write_text('Package: local.dylix.issue2\nName: Fixture\nVersion: 1.0.0\nArchitecture: iphoneos-arm64\nMaintainer: Test\nDescription: Disposable compatibility fixture\n')
    (project/'Fixture.plist').write_bytes(plistlib.dumps({'Filter':{'Bundles':['com.example.fixture']}}))
    resource=project/'layout/Library/Application Support/Fixture.bundle/test.txt'
    resource.parent.mkdir(parents=True); resource.write_text('resource fixture\n')
    before=set(doc.glob('Build-*'))
    sim('launch','--terminate-running-process',DEVICE,APP,'--self-test-project','--test-project-path',project)
    deadline=time.monotonic()+120; build=None
    while time.monotonic()<deadline:
        found=[p for p in set(doc.glob('Build-*'))-before if (p/'report.json').exists()]
        if found: build=found[0]; break
        time.sleep(.3)
    assert build, 'Embedded compiler timed out'
    report=json.loads((build/'report.json').read_text())
    assert report['success'], report
    assert len(report['packages'])==3,report
    for f in build.iterdir():
        if f.is_file() and f.suffix in ['.json','.log','.deb','.dylib']: shutil.copy2(f,OUT/f.name)
    results=[]
    for package in report['packages']:
        path=build/package['name']; raw=path.read_bytes(); members={}; at=8
        assert raw[:8]==b'!<arch>\n'
        while at<len(raw):
            h=raw[at:at+60]; size=int(h[48:58]); members[h[:16].decode().strip().rstrip('/')]=raw[at+60:at+60+size]; at+=60+size+size%2
        assert list(members)==['debian-binary','control.tar.gz','data.tar.gz']
        with tarfile.open(fileobj=io.BytesIO(members['data.tar.gz']),mode='r:gz') as tf:
            entries=tf.getmembers(); names={e.name:e for e in entries}
            prefix='./var/jb/' if package['scheme']=='rootless' else './'
            bundle=prefix+'Library/Application Support/Fixture.bundle'
            assert names[bundle].isdir()
            assert tf.extractfile(bundle+'/test.txt').read()==b'resource fixture\n'
            dylib=next(e for e in entries if e.name.endswith('.dylib'))
            assert tf.extractfile(dylib).read()[:4]==b'\xcf\xfa\xed\xfe'
            assert prefix+'Library/MobileSubstrate/DynamicLibraries' in names
        if shutil.which('dpkg-deb'):
            checked=subprocess.run(['dpkg-deb','--contents',str(path)],capture_output=True,text=True)
            assert checked.returncode==0,checked.stderr
            (OUT/(package['scheme']+'-dpkg-contents.txt')).write_text(checked.stdout)
        results.append({'scheme':package['scheme'],'file':package['name'],'gzip':True,'explicitDirectories':True,'bundleResource':True,'embeddedBuild':True})
        print('PASS embedded iOS compiler:',package['scheme'])
    (OUT/'compatibility-results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2))
print('PASS all three package variants from simulator compiler')
