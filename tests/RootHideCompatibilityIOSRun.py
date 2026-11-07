#!/usr/bin/env python3
"""Exercise all package schemes and standalone outputs with the actual embedded compiler."""
import io, json, os, plistlib, struct, subprocess, tarfile, tempfile, time, hashlib, shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'evidence/1.0.9-build203-signing'
DEVICE=os.environ.get('DYLIX_SIM_DEVICE','booted')
APP='com.xuegao.theosmobilecompiler'
def sim(*args):
    return subprocess.check_output(['xcrun','simctl',*map(str,args)],text=True).strip()
def macho(data):
    magic,cpu,subtype,kind,ncmd,size,flags,reserved=struct.unpack_from('<8I',data)
    assert magic==0xfeedfacf and cpu==0x100000c and kind==6
    at=32; deps=[]; rpaths=[]; identifier=None; signature=None
    for _ in range(ncmd):
        cmd,length=struct.unpack_from('<II',data,at); assert length>=8 and at+length<=32+size
        if cmd in [0xd,0xc,0x80000018,0x8000001f,0x80000023,0x8000001c]:
            start=struct.unpack_from('<I',data,at+8)[0]
            name=data[at+start:at+length].split(b'\0',1)[0].decode()
            if cmd==0xd: identifier=name
            elif cmd==0x8000001c:rpaths.append(name)
            else:deps.append(name)
        if cmd==0x1d:signature=struct.unpack_from('<II',data,at+8)
        at+=length
    assert at==32+size
    return dict(cpu='arm64e' if subtype&0xffffff==2 else 'arm64',identifier=identifier,dependencies=deps,rpaths=rpaths,signature=signature)
def unpack(path):
    raw=path.read_bytes(); assert raw[:8]==b'!<arch>\n';at=8;members={}
    while at<len(raw):
        h=raw[at:at+60];size=int(h[48:58]);members[h[:16].decode().strip().rstrip('/')]=raw[at+60:at+60+size];at+=60+size+size%2
    assert list(members)==['debian-binary','control.tar.gz','data.tar.gz']
    control=tarfile.open(fileobj=io.BytesIO(members['control.tar.gz'])).extractfile('./control').read().decode()
    with tarfile.open(fileobj=io.BytesIO(members['data.tar.gz'])) as tf:
        entry=next(m for m in tf.getmembers() if m.name.endswith('.dylib') and m.isfile())
        image=tf.extractfile(entry).read()
    return control,image
sim('install',DEVICE,ROOT/'build/simulator/TheosMobileCompiler.app')
doc=Path(sim('get_app_container',DEVICE,APP,'data'))/'Documents'
OUT.mkdir(parents=True,exist_ok=True)
results=[]
for label,schemes,policy in [('multi-release',['rootless','rootful','roothide'],'auto'),('multi-debug',['rootless','rootful','roothide'],'keep'),('native-library-alias',['roothide'],'auto'),('standalone-release',['rootless'],'auto'),('standalone-debug',['rootless'],'keep')]:
    with tempfile.TemporaryDirectory(prefix='dylix193-') as temp:
        project=Path(temp)
        # Resolves a real Substrate symbol. Nothing is hooked or executed by this test.
        (project/'Fixture.c').write_text('extern void MSHookFunction(void*,void*,void**);\nvoid link_fixture(void) { MSHookFunction((void*)0,(void*)0,(void**)0); }\n')
        (project/'MobileCompiler.json').write_text(json.dumps(dict(name='RootHide linkage',productName='Fixture',sources=['Fixture.c'],package=not label.startswith('standalone'),exportDylib=True,packageSchemes=schemes,frameworks=[] if label=='native-library-alias' else ['CydiaSubstrate'],libraries=['substrate'] if label=='native-library-alias' else [],symbolPolicy=policy,optimization='release-speed')))
        (project/'control').write_text('Package: local.dylix.nativefixture\nName: NativeFixture\nVersion: 1.0.0\nArchitecture: iphoneos-arm64\nMaintainer: Test\nDescription: Isolated native RootHide linkage test\nDepends: mobilesubstrate, firmware (>= 15.0)\n')
        (project/'Fixture.plist').write_bytes(plistlib.dumps({'Filter':{'Bundles':['com.example.fixture']}}))
        before=set(doc.glob('Build-*'))
        sim('launch','--terminate-running-process',DEVICE,APP,'--self-test-project','--test-project-path',project)
        deadline=time.monotonic()+120;build=None
        while time.monotonic()<deadline:
            found=[p for p in set(doc.glob('Build-*'))-before if (p/'report.json').exists()]
            if found:build=found[0];break
            time.sleep(.3)
        assert build,'Embedded build timed out'
        report=json.loads((build/'report.json').read_text())
        dest=OUT/label;dest.mkdir(exist_ok=True)
        for f in build.iterdir():
            if f.is_file() and f.suffix in ['.json','.log','.deb','.dylib']:shutil.copy2(f,dest/f.name)
        assert report['success'],report.get('packageError',report)
        assert report['stripSymbols']==(policy=='auto'),report
        expected=0 if label.startswith('standalone') else len(schemes)
        assert len(report['packages'])==expected
        assert report['signatureVerified']
        for relative in report['namedArtifacts']:
            if relative.endswith('.dylib'):
                check=subprocess.run(['codesign','--verify','--strict',str(build/relative)],capture_output=True,text=True)
                assert check.returncode==0,check.stderr
        for debug in (build/'DebugSymbols').glob('*'):
            check=subprocess.run(['codesign','--verify','--strict',str(debug)],capture_output=True,text=True)
            assert check.returncode==0,check.stderr
        if not expected:
            results.append(dict(label=label,scheme='rootless',standalone=True,codeSignatureVerified=True))
            print('PASS',label,'standalone and debug copy signatures',flush=True)
        for package in report['packages']:
            path=dest/package['name'];control,image=unpack(path); info=macho(image)
            assert info['cpu']=='arm64' # Debian arm64e is not the Mach-O CPU ABI.
            assert 'Depends: mobilesubstrate, firmware (>= 15.0)' in control
            assert report['signatureVerified'] and info['signature'],info
            off,size=info['signature'];assert off+size<=len(image)
            signed=dest/(package['scheme']+'-signed.dylib');signed.write_bytes(image)
            check=subprocess.run(['codesign','--verify','--strict',str(signed)],capture_output=True,text=True)
            assert check.returncode==0,check.stderr
            info['codeSignatureVerified']=True
            if package['scheme']=='roothide':
                assert 'Architecture: iphoneos-arm64e\n' in control
                assert info['identifier']=='@loader_path/.jbroot/Library/MobileSubstrate/DynamicLibraries/Fixture.dylib',info
                assert '@loader_path/.jbroot/usr/lib/libsubstrate.dylib' in info['dependencies'],info
                assert all('/var/jb' not in p for p in info['dependencies']+info['rpaths'])
            else:
                assert '@rpath/CydiaSubstrate.framework/CydiaSubstrate' in info['dependencies'],info
                assert not any('/.jbroot/' in p for p in info['dependencies']),info
            if shutil.which('dpkg-deb'):
                check=subprocess.run(['dpkg-deb','--field',str(path)],capture_output=True,text=True)
                assert check.returncode==0 and 'Package: local.dylix.nativefixture' in check.stdout,check.stderr
                # Sileo reads dpkg-deb --field, then passes the package to APT/dpkg.
                (dest/(package['scheme']+'-sileo-fields.txt')).write_text(check.stdout)
            info.update(label=label,scheme=package['scheme'],file=package['name'],sha256=hashlib.sha256(path.read_bytes()).hexdigest())
            results.append(info);print('PASS',label,package['scheme'],info['dependencies'],flush=True)
(OUT/'results.json').write_text(json.dumps(results,indent=2))
print('PASS all-scheme actual embedded compiler/linkage/signature regression')
