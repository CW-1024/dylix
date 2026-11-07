"""SDK selection contract: never silently ship an older-SDK device release."""
from pathlib import Path
import importlib.util,json,tempfile
root=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('build_sdk',root/'scripts/build_sdk.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
with tempfile.TemporaryDirectory() as tmp:
    base=Path(tmp)
    def sdk(name,version,platform):
        p=base/name;p.mkdir();(p/'SDKSettings.json').write_text(json.dumps({'Version':version,'SupportedTargets':{platform:{}}}));return p
    old=sdk('old','18.2','iphoneos');new=sdk('new','26.0','iphoneos');sim=sdk('sim','18.2','iphonesimulator')
    assert module.select_sdk('iphoneos',old,new)[0]==new.resolve();print('PASS older Xcode defaults to bundled SDK 26')
    assert module.select_sdk('iphoneos',new,base/'missing')[0]==new.resolve();print('PASS installed SDK 26 is accepted')
    assert module.select_sdk('iphonesimulator',sim,new)[0]==sim.resolve();print('PASS simulator uses its compatible installed SDK')
    assert module.select_sdk('iphoneos',old,new,old)[0]==old.resolve();print('PASS explicit compatibility SDK override remains possible')
    for platform,installed,bundled,explicit in [('iphoneos',old,base/'missing',None),('iphoneos',old,old,None),('iphonesimulator',sim,new,new)]:
        try:module.select_sdk(platform,installed,bundled,explicit)
        except ValueError:pass
        else:raise AssertionError('must reject missing, outdated, or mismatched SDK')
    print('PASS missing SDK, outdated fallback, and platform mismatch fail closed')
print('PASS 7 SDK selection checks')
