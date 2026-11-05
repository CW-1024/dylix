from pathlib import Path
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
import subprocess,tempfile,threading,json,time
root=Path(__file__).resolve().parents[1]
counts={}; lock=threading.Lock()
class Handler(BaseHTTPRequestHandler):
 def log_message(self,*args):pass
 def do_GET(self):
  with lock:counts[self.path]=counts.get(self.path,0)+1;count=counts[self.path]
  assert self.headers.get('Authorization')=='Bearer fixture-secret-only'
  if self.path.startswith('/redirect/'):
   self.send_response(302);self.send_header('Location','/must-not-follow');self.end_headers();return
  if self.path.startswith('/ok/') and count>1:self.send_response(503);self.end_headers();return
  if self.path.startswith('/gone/') or (self.path.startswith('/recover/') and count==1):self.send_response(410);self.end_headers();return
  if self.path.startswith('/missing/'):self.send_response(404);self.end_headers();return
  if self.path.startswith('/single/'):time.sleep(.1)
  body=(b'x'*70000 if self.path.startswith('/large/') else json.dumps(dict(isValid=True,mode='subscription' if self.path.startswith('/subscription/') else 'unrestricted',balance='12.34',unit='USD')).encode())
  self.send_response(200);self.send_header('Content-Length',str(len(body)));self.end_headers()
  try:self.wfile.write(body)
  except BrokenPipeError:pass
server=ThreadingHTTPServer(('127.0.0.1',0),Handler);threading.Thread(target=server.serve_forever,daemon=True).start()
try:
 with tempfile.TemporaryDirectory(prefix='dylix-balance-') as d:
  p=Path(d);(p/'UIKit').mkdir();(p/'UIKit/UIKit.h').write_text('#import <Foundation/Foundation.h>\n@class UIViewController;\n')
  binary=p/'tests'
  subprocess.run(['xcrun','clang','-isysroot','/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk','-I'+str(p),'-fobjc-arc','-fblocks','-Wno-incompatible-pointer-types','-Wno-incomplete-implementation',str(root/'tests/BalanceTests.m'),str(root/'App/AI/Providers/TFAIProviderBalance.m'),'-framework','Foundation','-framework','Security','-o',str(binary)],check=True)
  subprocess.run([str(binary),f'http://127.0.0.1:{server.server_port}'],check=True,timeout=60)
 assert counts.get('/ok/v1/usage')==2,counts
 assert counts.get('/single/v1/usage')==1,counts
 assert counts.get('/auto/v1/usage')==1 and not counts.get('/auto/v1/responses/v1/usage'),counts
 assert not counts.get('/must-not-follow'),counts
 print('Balance network: cache, single-flight and redirect assertions passed')
finally:server.shutdown()
