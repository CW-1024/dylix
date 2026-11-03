"""Real UIApplication idle timer checks through simulator-only command harness."""
import json,pathlib,subprocess,time
root=pathlib.Path(subprocess.check_output(['xcrun','simctl','get_app_container','booted','com.xuegao.theosmobilecompiler','data'],text=True).strip())/'Documents'
def state():return json.loads((root/'RemoteTestState.json').read_text())
def command(action,**kw):
 p=root/'RemoteTestCommand.json';tmp=p.with_suffix('.tmp');tmp.write_text(json.dumps(dict(action=action,**kw)));tmp.replace(p)
 for _ in range(100):
  if not p.exists():time.sleep(.3);return
  time.sleep(.05)
 raise AssertionError('command timed out')
checks=0
def check(value,name):
 global checks
 assert value,name
 checks+=1;print('PASS',name,flush=True)
command('start');time.sleep(.3);check(state()['screenAwake'],'LAN listening keeps foreground screen awake')
command('awake',reason='ai',active=True);command('stop');check(state()['screenAwake'],'stopping LAN preserves active AI reason')
command('awake',reason='build',active=True);command('awake',reason='ai',active=False);check(state()['screenAwake'],'ending AI preserves active build reason')
command('awake',reason='build',active=False);check(not state()['screenAwake'],'last reason restores system idle timer')
command('awake',reason='ai',active=True);command('awake',reason='ai',active=True);command('awake',reason='ai',active=False);check(not state()['screenAwake'],'repeated state publication is idempotent')
command('start');subprocess.run(['xcrun','simctl','openurl','booted','https://example.com'],check=True,stdout=subprocess.DEVNULL);time.sleep(.6);check(not state()['screenAwake'],'leaving foreground releases idle suppression')
subprocess.run(['xcrun','simctl','launch','booted','com.xuegao.theosmobilecompiler'],check=True,stdout=subprocess.DEVNULL);time.sleep(.8);check(state()['screenAwake'],'foreground restores active LAN reason')
print('TOTAL',checks,'real simulator awake checks passed')
