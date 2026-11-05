// Simulator-only integration harness. Excluded from every device build.
#import <UIKit/UIKit.h>
#import <Security/Security.h>
#import <objc/runtime.h>
#import "../App/AI/Providers/TFAIOAuth.h"
#import "../App/AI/Agent/TFAIMCP.h"
#import "../App/AI/Agent/TFAIBuildQueue.h"
#import "../App/AI/Agent/TFAIReadOnlyBrowser.h"
#import "../App/AI/Agent/TFAIAgentUI.h"
#import "../App/AI/Agent/TFAIAgentContext.h"
#import "../App/AI/Tools/TFAIWebTools.h"
@interface TFAIOAuth (FixtureRequest)
- (void)request:(NSString *)url fields:(NSDictionary *)fields json:(BOOL)json completion:(TFAIResult)completion;
@end
@interface DXOAuthFixture : TFAIOAuth
@property NSUInteger refreshCount;
@property(copy) TFAIResult pending;
@end
@implementation DXOAuthFixture
- (void)request:(NSString *)url fields:(NSDictionary *)fields json:(BOOL)json completion:(TFAIResult)completion{if([fields[@"grant_type"] isEqual:@"refresh_token"]){self.refreshCount++;self.pending=completion;}else completion(@{},nil);}
@end
static NSMutableArray *Checks;
static void Check(BOOL ok,NSString *name){[Checks addObject:@{@"name":name,@"pass":@(ok)}];NSLog(@"AGENT163 %@ %@",ok?@"PASS":@"FAIL",name);}
static NSDictionary *TokenQuery(NSString *identifier){return @{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,(__bridge id)kSecAttrService:@"com.xuegao.dylix.ai.oauth.v1",(__bridge id)kSecAttrAccount:identifier};}
static void Seed(NSString *identifier){NSMutableDictionary *q=[TokenQuery(identifier) mutableCopy];SecItemDelete((__bridge CFDictionaryRef)q);q[(__bridge id)kSecValueData]=[NSJSONSerialization dataWithJSONObject:@{@"accessToken":@"fixture-old",@"refreshToken":@"fixture-refresh",@"clientID":@"fixture.apps.googleusercontent.com",@"expiresAt":@1,@"kind":@"google"} options:0 error:nil];q[(__bridge id)kSecAttrAccessible]=(__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;Check(SecItemAdd((__bridge CFDictionaryRef)q,NULL)==errSecSuccess,@"fixture credential stored only in simulator Keychain");}
static IMP OriginalURL;
static BOOL FixtureURL(id cls,SEL cmd,NSURL *url,NSError **error){if([url.host isEqual:@"127.0.0.1"]&&url.port.intValue==18463)return YES;return ((BOOL(*)(id,SEL,NSURL *,NSError **))OriginalURL)(cls,cmd,url,error);}
@interface DXAgentRegression : UIViewController
@property UITextView *output;
@property DXOAuthFixture *auth;
@property TFAIMCP *mcp;
@property TFAIReadOnlyBrowser *browser;
@property NSString *serverID;
@end
@implementation DXAgentRegression
- (void)uiSmoke{NSError *error=nil;NSString *original=[TFAIAgentContext memory:nil error:&error];Check(original!=nil&&!error,@"general memory opens without a project");NSString *sample=[@"agent-fixture-" stringByAppendingString:NSUUID.UUID.UUIDString];Check([TFAIAgentContext saveMemory:sample root:nil expected:[TFAIAgentContext fingerprint:original] error:&error],@"general memory saves locally");Check([[TFAIAgentContext memory:nil error:nil] isEqual:sample],@"general memory can be read back");[TFAIAgentContext saveMemory:original root:nil expected:[TFAIAgentContext fingerprint:sample] error:nil];UITableViewController *settings=(UITableViewController *)TFAIAgentSettingsController(nil,@"fixture");[settings view];UITableViewCell *memory=[settings tableView:settings.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:1]];Check(memory.userInteractionEnabled,@"general memory cell is enabled");UIViewController *browser=TFAIReadOnlyBrowserControllerWithAsk(@"fixture",nil);[browser view];Check([browser.view.subviews containsObject:[TFAIReadOnlyBrowser browserForSession:@"fixture"].webView],@"browser page displays the live WKWebView");}
- (void)viewDidLoad{[super viewDidLoad];self.title=@"Agent163 integration";self.view.backgroundColor=UIColor.systemBackgroundColor;self.output=[[UITextView alloc]initWithFrame:self.view.bounds];self.output.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;self.output.editable=NO;self.output.text=@"Running simulator integration fixtures…";[self.view addSubview:self.output];self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc]initWithTitle:@"Agent UI" style:UIBarButtonItemStylePlain target:self action:@selector(openAgent)];Checks=[NSMutableArray new];[self uiSmoke];dispatch_after(dispatch_time(DISPATCH_TIME_NOW,200*NSEC_PER_MSEC),dispatch_get_main_queue(),^{[self oauth];});}
- (void)openAgent{[self.navigationController pushViewController:TFAIAgentSettingsController(nil,@"fixture-session") animated:YES];}
- (void)oauth{self.auth=[DXOAuthFixture new];NSString *identifier=[@"agent163-fixture-" stringByAppendingString:NSUUID.UUID.UUIDString];Seed(identifier);NSDictionary *c=@{@"id":identifier,@"protocol":@"gemini",@"baseURL":@"https://generativelanguage.googleapis.com/v1beta",@"authMethod":@"oauth",@"oauthClientID":@"fixture.apps.googleusercontent.com"};__block NSUInteger callbacks=0;for(NSUInteger i=0;i<20;i++)[self.auth credential:c completion:^(NSString *token,NSError *error){if([token isEqual:@"fixture-new"]&&!error)callbacks++;}];Check(self.auth.refreshCount==1,@"20 concurrent expired requests share one refresh");self.auth.pending(@{@"access_token":@"fixture-new",@"expires_in":@3600},nil);Check(callbacks==20,@"single refresh resumes all waiting requests");[self.auth credential:c completion:^(NSString *token,NSError *error){Check([token isEqual:@"fixture-new"]&&!error,@"fresh token retrieved after refresh");}];Check(self.auth.refreshCount==1,@"fresh token causes no second HTTP refresh");NSMutableDictionary *changed=[c mutableCopy];changed[@"protocol"]=@"openrouter";changed[@"baseURL"]=@"https://openrouter.ai/api/v1";[self.auth credential:changed completion:^(NSString *token,NSError *error){Check(!token&&error,@"token from another provider never leaves its issuer connection");}];NSMutableDictionary *bad=[c mutableCopy];bad[@"baseURL"]=@"https://generativelanguage.googleapis.com:9443/v1beta";[self.auth credential:bad completion:^(NSString *token,NSError *error){Check(!token&&error,@"OAuth credential rejected for changed origin port");}];[self.auth logout:c completion:^(NSDictionary *r,NSError *e){Check([r[@"cleared"] boolValue]&&[r[@"revoked"] boolValue]&&![self.auth hasCredential:identifier],@"logout deletes Keychain credential and invokes revoke");}];Seed(identifier);__block BOOL cancelled=NO;[self.auth credential:c completion:^(NSString *token,NSError *error){cancelled=!token&&error!=nil;}];TFAIResult late=self.auth.pending;[self.auth logout:c completion:^(NSDictionary *r,NSError *e){}];late(@{@"access_token":@"late-fixture",@"expires_in":@3600},nil);Check(cancelled&&![self.auth hasCredential:identifier],@"logout during refresh never resurrects token");[self mcpTest];}
- (void)mcpTest{self.mcp=[TFAIMCP new];NSString *json=@"{\"mcpServers\":{\"agent163-fixture\":{\"url\":\"http://127.0.0.1:18463/mcp\",\"headers\":{\"Authorization\":\"Bearer fixture-only\"}}}}";NSError *failure=nil;BOOL imported=[self.mcp importJSON:json error:&failure];Check(imported,@"HTTP MCP import stores header in simulator Keychain");for(NSDictionary *r in self.mcp.servers)if([r[@"name"] isEqual:@"agent163-fixture"])self.serverID=r[@"id"];if(!self.serverID){[self browserTest];return;}Check([self.mcp schemas:@"fixture"].count==0,@"MCP import starts disabled with zero tool schemas");[self.mcp discover:self.serverID completion:^(NSDictionary *r,NSError *e){Check(!e&&[r[@"tools"] count]==2,@"real HTTP initialize + notification + tools/list");Check(![self.mcp setAllowed:YES tool:@"write_file" server:self.serverID error:nil],@"mislabelled MCP write tool remains blocked");Check([self.mcp setAllowed:YES tool:@"search_docs" server:self.serverID error:nil],@"explicit read tool approval persists");[self.mcp setEnabled:YES server:self.serverID session:@"fixture"];NSArray *tools=[self.mcp schemas:@"fixture"];Check(tools.count==1,@"per-session MCP enables only approved read query");if(!tools.count){[self.browser cancel];[self browserTest];return;}[self.mcp call:tools[0][@"name"] arguments:@{@"query":@"fixture"} session:@"fixture" completion:^(NSDictionary *v,NSError *error){Check(!error&&[v[@"content"][0][@"text"] isEqual:@"MCP fixture result"],@"real HTTP tools/call completes SSE without waiting for server close");[self.mcp call:tools[0][@"name"] arguments:@{@"query":@"DELETE FROM notes"} session:@"fixture" completion:^(NSDictionary *v,NSError *error){Check(!v&&error,@"MCP mutation arguments rejected before network");}];Check([self.mcp importJSON:json error:nil]&&[self.mcp schemas:@"fixture"].count==0,@"MCP reimport invalidates tools and session approval");[self.mcp remove:self.serverID];[self browserTest];}];}];}
- (void)browserTest{
 Method m=class_getClassMethod(TFAIWebTools.class,@selector(validURL:error:));OriginalURL=method_setImplementation(m,(IMP)FixtureURL);
 self.browser=[TFAIReadOnlyBrowser new];
 Check([TFAIReadOnlyBrowser browserForSession:@"fixture-a"]==[TFAIReadOnlyBrowser browserForSession:@"fixture-a"]&&[TFAIReadOnlyBrowser browserForSession:@"fixture-a"]!=[TFAIReadOnlyBrowser browserForSession:@"fixture-b"],@"browser state stays inside one AI session");
 Check(!self.browser.webView.configuration.websiteDataStore.isPersistent,@"JS browser uses nonpersistent website store");
 [self.browser read:@"http://127.0.0.1:18463/page" completion:^(NSDictionary *result,NSError *error){
  Check(!error&&[result[@"text"] containsString:@"Rendered fixture text"]&&[result[@"links"] count]==1,@"WKWebView extracts JS-generated text and links");
  [self.browser read:nil completion:^(NSDictionary *current,NSError *currentError){
   Check(!currentError&&[current[@"text"] containsString:@"Rendered fixture text"],@"AI can read the current browser page without a new URL");
   [self browserFollowUp];
  }];
 }];
}
- (void)browserFollowUp{
 [self.browser perform:@{@"action":@"scroll",@"direction":@"down",@"amount":@1} completion:^(NSDictionary *scrolled,NSError *scrollError){
  Check(!scrollError&&[scrolled[@"text"] containsString:@"Rendered fixture text"],@"AI can scroll and reread the live page");
  [self.browser perform:@{@"action":@"follow_link",@"link_index":@0} completion:^(NSDictionary *linked,NSError *linkError){
   Check(!linkError&&[linked[@"url"] hasSuffix:@"/next"],@"AI follows an indexed link in the visible browser");
   [self.browser perform:@{@"action":@"back"} completion:^(NSDictionary *previous,NSError *backError){
    Check(!backError&&[previous[@"url"] hasSuffix:@"/page"],@"AI can return through browser history");
    [self.browser.webView evaluateJavaScript:@"document.querySelector('input').disabled" completionHandler:^(id value,NSError *error){
     Check([value boolValue],@"rendered form input is disabled");
     method_setImplementation(class_getClassMethod(TFAIWebTools.class,@selector(validURL:error:)),OriginalURL);
     [self queueTest];
    }];
   }];
  }];
 }];
}
- (void)queueTest{TFAIBuildQueue *q=[TFAIBuildQueue new];NSMutableArray *started=[NSMutableArray new];__block TFAIResult finishFirst=nil;__block BOOL cancelled=NO;NSString *one=[q enqueue:@"/fixture/one" name:@"fixture one" executor:^(void(^p)(NSString *,double),TFAIResult done){[started addObject:@1];finishFirst=done;p(@"Fixture compiler boundary",.5);} cancel:^{cancelled=YES;} completion:^(NSDictionary *r,NSError *e){Check(e.code==NSURLErrorCancelled,@"running cancellation overrides successful executor result");}];NSString *two=[q enqueue:@"/fixture/two" name:@"fixture two" executor:^(void(^p)(NSString *,double),TFAIResult done){[started addObject:@2];done(@{@"success":@YES},nil);} cancel:nil completion:nil];[q enqueue:@"/fixture/three" name:@"fixture three" executor:^(void(^p)(NSString *,double),TFAIResult done){[started addObject:@3];done(@{@"success":@YES},nil);} cancel:nil completion:^(NSDictionary *r,NSError *e){Check([started isEqual:@[@1,@3]],@"queue executes serially and skips cancelled pending job");Check([[q.tasks valueForKey:@"state"] containsObject:@"completed"],@"successful queue job persists completed state");[self finish];}];TFAIBuildExecutor neverRun=^(void(^p)(NSString *,double),TFAIResult done){Check(NO,@"cancelled conversation-scope fixture must not execute");done(@{@"success":@NO},nil);};NSString *scopeA=[q enqueue:@"/fixture/shared" session:@"conversation-a" name:@"scoped fixture" executor:neverRun cancel:nil completion:nil],*scopeB=[q enqueue:@"/fixture/shared" session:@"conversation-b" name:@"scoped fixture" executor:neverRun cancel:nil completion:nil];NSString *duplicateA=[q enqueue:@"/fixture/shared" session:@"conversation-a" name:@"scoped fixture" executor:neverRun cancel:nil completion:nil];Check(![scopeA isEqual:scopeB]&&[scopeA isEqual:duplicateA],@"queue coalesces only matching project and conversation scope");[q cancel:scopeA];[q cancel:scopeB];[q cancel:two];dispatch_after(dispatch_time(DISPATCH_TIME_NOW,100*NSEC_PER_MSEC),dispatch_get_main_queue(),^{Check([started isEqual:@[@1]],@"only first executor runs before completion");[q cancel:one];Check(cancelled,@"running job receives cooperative cancel request");if(finishFirst)finishFirst(@{@"success":@YES},nil);else{Check(NO,@"first queue executor started");[self finish];}});}
- (void)finish{NSUInteger failures=0;for(NSDictionary *r in Checks)if(![r[@"pass"] boolValue])failures++;NSDictionary *report=@{@"checks":Checks,@"failures":@(failures),@"fixtureOnly":@YES};NSData *data=[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil];NSString *path=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"agent163-tests.json"];[data writeToFile:path atomically:YES];self.output.text=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];self.title=failures?@"Agent tests failed":@"Agent tests passed";}
@end
UIViewController *TFAIAgent163Regression(void){return [DXAgentRegression new];}
