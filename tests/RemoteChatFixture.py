"""Isolated OpenAI-compatible loopback provider for the actual iOS runtime.
No paid provider; responses are explicitly marked regression fixtures.
"""
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
import json,time,threading
requests=[]
class Provider(BaseHTTPRequestHandler):
 def log_message(self,*args):pass
 def do_POST(self):
  request=json.loads(self.rfile.read(int(self.headers['Content-Length'])))
  requests.append(request)
  self.send_response(200);self.send_header('Content-Type','text/event-stream');self.end_headers()
  def send(delta,finish=None):
   self.wfile.write(('data: '+json.dumps({'choices':[{'index':0,'delta':delta,'finish_reason':finish}]},ensure_ascii=False)+'\n\n').encode());self.wfile.flush()
  try:
   send({'role':'assistant','reasoning_content':'这是本地回归服务返回的处理摘要，用于验证流式 UI。'})
   content='## 本地回归回复\n\n已收到模型 **'+request.get('model','')+'**，思考档位 **'+request.get('reasoning_effort','默认')+'**。\n\n- 模型由手机运行时调用\n- 浏览器保留已完成段落\n\n```objective-c\nNSString *name = @"Dylix";\nNSLog(@"%@", name);\n```\n\n| 项目 | 状态 |\n| --- | --- |\n| 本地服务 | 已验证 |\n\n'
   if any('长回复' in str(m.get('content','')) for m in request.get('messages',[])):
    content+='\n\n'.join('第 %d 段回归文本，用于验证用户阅读历史内容时的位置保持。'%i for i in range(35))
   for i in range(0,len(content),28):send({'content':content[i:i+28]});time.sleep(.12)
   send({},'stop');self.wfile.write(b'data: [DONE]\n\n');self.wfile.flush()
  except (BrokenPipeError,ConnectionResetError):pass

def start():
 server=ThreadingHTTPServer(('127.0.0.1',18991),Provider);threading.Thread(target=server.serve_forever,daemon=True).start();return server
if __name__=='__main__':start();threading.Event().wait()
