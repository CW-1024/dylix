"""Run browser regression in a real insecure HTTP origin, relaying unchanged bodies
and native APIs to the loopback-only simulator. Only Host/same-origin Origin are
translated for the native listener's allowlist. This is a test fixture, not App code.
"""
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
import http.client,threading,subprocess,os
class Relay(BaseHTTPRequestHandler):
 def log_message(self,*args):pass
 def forward(self):
  body=self.rfile.read(int(self.headers.get('Content-Length',0)))
  headers={k:v for k,v in self.headers.items() if k.lower() not in ('host','connection')}
  if headers.get('Origin')=='http://dylix.test:'+str(self.server.server_port):headers['Origin']='http://127.0.0.1:18787'
  try:
   c=http.client.HTTPConnection('127.0.0.1',18787,timeout=120);c.request(self.command,self.path,body=body or None,headers=headers);r=c.getresponse();data=r.read();self.send_response(r.status)
   for k,v in r.getheaders():
    if k.lower() not in ('connection','transfer-encoding','content-length'):self.send_header(k,v)
   self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data);c.close()
  except (BrokenPipeError,ConnectionResetError):pass
 do_GET=do_POST=do_HEAD=forward
server=ThreadingHTTPServer(('127.0.0.1',0),Relay)
threading.Thread(target=server.serve_forever,daemon=True).start()
try:
 env=dict(os.environ,REMOTE_BROWSER_ORIGIN='http://dylix.test:'+str(server.server_port),REMOTE_EXPECT_INSECURE='1')
 subprocess.run(['python3',os.path.join(os.path.dirname(__file__),'RemoteBrowser.py')],env=env,check=True)
finally:server.shutdown();server.server_close()
