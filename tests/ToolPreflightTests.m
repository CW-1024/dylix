#import <Foundation/Foundation.h>
#import "../App/AI/Registry/TFAIToolRegistry.h"
#import "../App/AI/Core/TFAIContextProjection.h"
#import "../App/AI/UI/TFAIActivity.h"
static NSUInteger checks;
static void Check(BOOL ok,NSString *name){checks++;if(!ok){NSLog(@"FAIL %@",name);exit(1);}}
static NSDictionary *Call(NSString *name,NSDictionary *args){return @{@"name":name,@"arguments":args};}
int main(){@autoreleasepool{
 NSDictionary *context=@{@"hasSession":@YES,@"hasProject":@YES,@"attachmentIDs":@[@"grant-secret-one"]};
 NSArray *schemas=@[TFAIContextProjection.schema];NSError *error=nil;
 Check(![TFAIToolRegistry preflight:Call(@"read_context",@{@"ref":@"message:0",@"limit":@8192}) schemas:schemas context:context error:&error],@"oversized read is rejected");
 Check([error.userInfo[@"TFAIToolRecovery"][@"reason"] isEqual:@"invalid_arguments"],@"oversized page is not reported as lost authorization");
 Check([error.userInfo[@"TFAIToolRecovery"][@"parameter"] isEqual:@"arguments.limit"]&&[error.localizedDescription containsString:@"4096"],@"exact failing field and bound are reported");
 Check([error.userInfo[@"TFAIToolRecovery"][@"requiresUserAuthorization"] isEqual:@NO]&&[error.localizedDescription containsString:@"无需重新授权"],@"ordinary schema errors do not ask for authorization");
 NSString *detail=TFAIActivityDetail(@{@"name":@"read_context",@"status":@"failed",@"result":@{@"error":error.localizedDescription,@"recovery":error.userInfo[@"TFAIToolRecovery"]}});
 Check([detail containsString:@"4096"]&&![detail containsString:@"requiresUserAuthorization"]&&![detail containsString:@"nextAction"],@"activity shows readable diagnostic while model receives structured recovery");
 for(NSDictionary *args in @[@{@"ref":@"message:0",@"limit":@0},@{@"ref":@"message:0",@"limit":@YES},@{@"ref":@"message:0",@"limit":@1.5},@{@"ref":@"message:0",@"offset":@(-1)},@{@"ref":@"message:0",@"unexpected":@"secret-value"},@{},@{@"ref":@""}]){
  error=nil;Check(![TFAIToolRegistry preflight:Call(@"read_context",args) schemas:schemas context:context error:&error],@"invalid pagination and shape stay rejected");
  Check([error.userInfo[@"TFAIToolRecovery"][@"reason"] isEqual:@"invalid_arguments"],@"shape failures have recoverable classification");
  Check(![error.localizedDescription containsString:@"secret-value"]&&![[error.userInfo description] containsString:@"secret-value"],@"diagnostics omit supplied argument values");
 }
 for(NSDictionary *args in @[@{@"ref":@"message:0"},@{@"ref":@"message:0",@"offset":@0,@"limit":@4096},@{@"ref":@"message:0",@"limit":@1}])Check([TFAIToolRegistry preflight:Call(@"read_context",args) schemas:schemas context:context error:nil],@"valid default and boundary pages pass");
 error=nil;Check(![TFAIToolRegistry preflight:Call(@"not_sent",@{}) schemas:schemas context:context error:&error]&&[error.userInfo[@"TFAIToolRecovery"][@"reason"] isEqual:@"tool_not_advertised"],@"unadvertised tool remains blocked separately");
 error=nil;Check(![TFAIToolRegistry preflight:Call(@"read_context",@{@"ref":@"message:0"}) schemas:schemas context:@{@"hasSession":@NO} error:&error]&&[error.userInfo[@"TFAIToolRecovery"][@"reason"] isEqual:@"tool_unavailable"],@"lost session stays unavailable");
 NSDictionary *attachment=@{@"name":@"read_attachment",@"parameters":@{@"type":@"object",@"properties":@{@"id":@{@"type":@"string"}},@"required":@[@"id"],@"additionalProperties":@NO}};
 NSArray *sent=[TFAIToolRegistry schemas:@[attachment] context:context];
 Check([TFAIToolRegistry preflight:Call(@"read_attachment",@{@"id":@"grant-secret-one"}) schemas:sent context:context error:nil],@"existing grant passes");
 error=nil;Check(![TFAIToolRegistry preflight:Call(@"read_attachment",@{@"id":@"grant-secret-two"}) schemas:sent context:context error:&error],@"unadvertised grant stays blocked");
 Check(![[error.userInfo description] containsString:@"grant-secret-one"]&&![[error.userInfo description] containsString:@"grant-secret-two"],@"grant identifiers are absent from diagnostics");
 NSDictionary *changed=@{@"hasSession":@YES,@"attachmentIDs":@[@"grant-secret-two"]};
 error=nil;Check(![TFAIToolRegistry preflight:Call(@"read_attachment",@{@"id":@"grant-secret-one"}) schemas:sent context:changed error:&error]&&[error.userInfo[@"TFAIToolRecovery"][@"reason"] isEqual:@"authorization_changed"],@"revoked advertised grant stays rejected");
 Check(![TFAIToolRegistry preflight:Call(@"read_attachment",@{@"id":@"grant-secret-two"}) schemas:sent context:changed error:nil],@"new grant cannot replace an advertised grant mid-turn");
 NSDictionary *patch=@{@"name":@"propose_patch",@"parameters":@{@"type":@"object",@"properties":@{@"edits":@{@"type":@"array",@"minItems":@1,@"items":@{@"type":@"object",@"properties":@{@"before":@{@"type":@"string"}},@"required":@[@"before"],@"additionalProperties":@NO}}},@"required":@[@"edits"],@"additionalProperties":@NO}};
 error=nil;Check(![TFAIToolRegistry preflight:Call(@"propose_patch",@{@"edits":@[@{}]}) schemas:@[patch] context:context error:&error]&&[error.userInfo[@"TFAIToolRecovery"][@"parameter"] isEqual:@"arguments.edits[0].before"],@"nested patch errors identify the exact missing field");
 Check([TFAIActivityTitle(@{@"name":@"read_context",@"status":@"failed"}) containsString:@"回读会话原文"],@"readback UI preserves actual failing tool identity");
 NSLog(@"PASS %lu tool preflight diagnostics checks",(unsigned long)checks);
 }return 0;}
