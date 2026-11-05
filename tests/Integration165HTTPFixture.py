"""Loopback only, no real credentials. Echo UA through real iOS HTTP requests."""
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
import json
class Handler(BaseHTTPRequestHandler):
 def log_message(self,*args):pass
 def do_GET(self):
  data=json.dumps({'data':[{'id':self.headers.get('User-Agent','missing')}]}).encode()
  self.send_response(200);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data)
 def do_POST(self):
  self.rfile.read(int(self.headers.get('Content-Length',0)))
  content=self.headers.get('User-Agent','missing')
  data=('data: '+json.dumps({'choices':[{'index':0,'delta':{'content':content},'finish_reason':None}]})+'\n\ndata: '+json.dumps({'choices':[{'index':0,'delta':{},'finish_reason':'stop'}]})+'\n\ndata: [DONE]\n\n').encode()
  self.send_response(200);self.send_header('Content-Type','text/event-stream');self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data)
if __name__=='__main__':ThreadingHTTPServer(('127.0.0.1',18995),Handler).serve_forever()
