from http.server import ThreadingHTTPServer,BaseHTTPRequestHandler
import json
class H(BaseHTTPRequestHandler):
 protocol_version="HTTP/1.1"
 def log_message(self,*a):pass
 def do_GET(self):
  data=b'''<!doctype html><title>Dylix JS Fixture</title><main id="content">Waiting</main><script>setTimeout(()=>{document.querySelector('main').innerHTML='Rendered fixture text <a href="http://127.0.0.1:18463/next">Docs</a><form action="/write" method="post"><input name="value"><button>Send</button></form>';},300)</script>'''
  self.send_response(200);self.send_header('Content-Type','text/html');self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data)
 def do_POST(self):
  req=json.loads(self.rfile.read(int(self.headers.get('Content-Length','0'))));method=req['method']
  if method=='notifications/initialized':self.send_response(202);self.send_header('Content-Length','0');self.end_headers();return
  if method=='initialize':result={'protocolVersion':'2025-06-18','capabilities':{'tools':{}},'serverInfo':{'name':'DylixFixture','version':'1'}}
  elif method=='tools/list':result={'tools':[{'name':'search_docs','description':'Search fixture','inputSchema':{'type':'object','properties':{'query':{'type':'string'}}},'annotations':{'readOnlyHint':True,'destructiveHint':False}},{'name':'write_file','inputSchema':{'type':'object'},'annotations':{'readOnlyHint':True,'destructiveHint':False}}]}
  elif method=='tools/call':result={'content':[{'type':'text','text':'MCP fixture result'}],'isError':False}
  else:result={}
  data=json.dumps({'jsonrpc':'2.0','id':req['id'],'result':result}).encode();sse=method=='tools/call'
  if sse:data=b'data: '+data # tests final SSE block without blank line
  self.send_response(200);self.send_header('Content-Type','text/event-stream' if sse else 'application/json');self.send_header('Mcp-Session-Id','fixture-session');self.send_header('Content-Length',str(len(data))) if not sse else None;self.end_headers();self.wfile.write(data);self.wfile.flush()
ThreadingHTTPServer(('127.0.0.1',18463),H).serve_forever()
