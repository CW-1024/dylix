#import "../App/AI/Providers/TFAIProviderBalance.h"
#import "../App/AI/Providers/TFAIProtocol.h"
static int checks=0;
static void Check(BOOL pass,NSString *name){checks++;if(!pass){fprintf(stderr,"FAIL %s\n",name.UTF8String);exit(1);}}
@implementation TFAIConnections
+ (NSString *)secret:(NSString *)identifier{return @"fixture-secret-only";}
@end
NSString *TFAIUserAgent(NSDictionary *c,NSError **error){return c[@"userAgent"]?:@"Dylix-fixture";}
NSURL *TFAIEndpoint(NSDictionary *c,BOOL models,NSError **error){NSURL *u=[NSURL URLWithString:[c[@"baseURL"] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]];return [u.scheme isEqual:@"https"]||([u.scheme isEqual:@"http"]&&[c[@"allowHTTP"] boolValue])?u:nil;}
static NSDictionary *Connection(NSString *base){return @{@"id":@"fixture",@"baseURL":base,@"balanceAdapter":@"sub2api",@"allowHTTP":@YES};}
static NSDictionary *Fetch(TFAIProviderBalance *s,NSDictionary *c,BOOL force){__block NSDictionary *r=nil;[s fetch:c refresh:force completion:^(NSDictionary *value){r=value;}];NSDate *until=[NSDate dateWithTimeIntervalSinceNow:10];while(!r&&until.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];Check(r!=nil,@"query completed");return r;}
int main(int argc,const char **argv){@autoreleasepool{
 NSDictionary *j=TFAIBalanceDecode([@"{\"data\":{\"limit_remaining\":0.1234567890123456789012345678}}" dataUsingEncoding:NSUTF8StringEncoding]);Check([TFAIBalanceParse(@"openrouter",j)[@"amounts"][0][@"value"] isEqual:@"0.1234567890123456789012345678"],@"decimal lexemes retain precision");
 Check([TFAIBalanceParse(@"openrouter",j)[@"kind"] isEqual:@"credit_limit"],@"key credit distinct from wallet");
 Check([TFAIBalanceParse(@"deepseek",@{@"is_available":@YES,@"balance_infos":@[@{@"currency":@"CNY",@"total_balance":@"0"},@{@"currency":@"USD",@"total_balance":@"-0.25"}]})[@"amounts"] count]==2,@"zero negative and multiple currencies retained");
 Check(!TFAIBalanceParse(@"deepseek",@{@"is_available":@NO,@"balance_infos":@[]}),@"provider unavailable");
 Check([TFAIBalanceParse(@"siliconflow",@{@"status":@YES,@"code":@20000,@"data":@{@"totalBalance":@"5.123"}})[@"amounts"][0][@"value"] isEqual:@"5.123"],@"SiliconFlow adapter");
 Check([TFAIBalanceParse(@"moonshot",@{@"status":@YES,@"code":@0,@"data":@{@"available_balance":@"2.01"}})[@"amounts"][0][@"currency"] isEqual:@"CNY"],@"Moonshot adapter");
 Check([TFAIBalanceParse(@"openrouterCredits",@{@"data":@{@"total_credits":@"0.3",@"total_usage":@"0.1"}})[@"amounts"][0][@"value"] isEqual:@"0.2"],@"decimal subtraction exact");
 Check([TFAIBalanceParse(@"openrouter",@{@"data":@{@"limit_remaining":NSNull.null}})[@"needsCredits"] boolValue],@"unlimited key requests wallet endpoint");
 NSDictionary *wallet=@{@"isValid":@YES,@"mode":@"unrestricted",@"balance":@"0",@"remaining":@"20",@"unit":@"USD"};Check([TFAIBalanceParse(@"sub2api",wallet)[@"amounts"][0][@"value"] isEqual:@"0"],@"zero wallet never replaced by fallback");
 for(NSDictionary *change in @[@{@"quota":@0},@{@"mode":@"subscription"},@{@"balance":@"invalid"},@{@"balance":@YES},@{@"unit":@"a\nb"}]){NSMutableDictionary *bad=[wallet mutableCopy];[bad addEntriesFromDictionary:change];Check(!TFAIBalanceParse(@"sub2api",bad),@"ambiguous or invalid relay data refused");}
 Check([TFAIBalanceAdapter(@{@"baseURL":@"https://custom.invalid/v1"}) isEqual:@"sub2api"],@"compatible custom origins automatically try wallet adapter");
 for(NSString *base in @[@"https://api.siliconflow.cn",@"https://api.siliconflow.cn/v1",@" https://api.siliconflow.cn/v1/ ",@"https://api.siliconflow.cn/v1/chat/completions",@"https://api.siliconflow.cn/v1/responses"]){NSDictionary *c=@{@"baseURL":base};Check([TFAIBalanceAdapter(c) isEqual:@"siliconflow"],@"SiliconFlow root v1 and full model endpoints recognized");Check([TFAIBalanceURL(c,@"siliconflow").absoluteString isEqual:@"https://api.siliconflow.cn/v1/user/info"],@"SiliconFlow always uses documented official wallet URL");}
 Check(!TFAIBalanceAdapter(@{@"baseURL":@"https://api.siliconflow.cn/custom/v1"}),@"unknown official path not mistaken for relay");
 for(NSString *host in @[@"api.openai.com",@"api.anthropic.com",@"api.x.ai",@"api.siliconflow.com",@"api.moonshot.ai",@"generativelanguage.googleapis.com",@"dashscope.aliyuncs.com"]){Check(!TFAIBalanceAdapter(@{@"baseURL":[@"https://" stringByAppendingString:host]}),@"unsupported official API not probed as wallet");}
 Check(!TFAIBalanceAdapter(@{@"baseURL":@"https://custom.invalid/v1",@"balanceAdapter":@"off"}),@"explicit off prevents automatic request");
 Check(!TFAIBalanceAdapter(@{@"baseURL":@"http://custom.invalid/v1"}),@"automatic HTTP detection still requires stored opt-in");
 Check(!TFAIBalanceAdapter(@{@"baseURL":@"https://custom.invalid/v1?token=secret"}),@"automatic URL refuses query credentials even with loose test validator");
 for(NSString *suffix in @[@"/v1",@"/v1/",@"/v1/chat/completions",@"/v1/responses",@"/v1/messages",@"/v1/models"]){Check([TFAIBalanceURL(@{@"baseURL":[@"https://relay.invalid/prefix" stringByAppendingString:suffix]},@"sub2api").absoluteString isEqual:@"https://relay.invalid/prefix/v1/usage"],@"automatic wallet strips inference suffix and preserves prefix");}
 Check([TFAIBalanceParse(@"siliconflow",@{@"code":@20000,@"data":@{@"totalBalance":@"0"}})[@"amounts"][0][@"value"] isEqual:@"0"],@"documented success code accepts omitted optional status and zero balance");
 Check(!TFAIBalanceParse(@"siliconflow",@{@"status":@NO,@"code":@20000,@"data":@{@"totalBalance":@"10"}}),@"explicit provider error status never becomes balance");
 Check(!TFAIBalanceParse(@"siliconflow",@{@"code":@30014,@"data":@{@"totalBalance":@"10"}}),@"error code cannot masquerade as wallet");
 NSDictionary *failure=TFAIBalanceFailure(@"siliconflow",[NSURL URLWithString:@"https://api.siliconflow.cn/v1/user/info"],410,nil,[@"{\"code\":30014,\"message\":\"fixture-secret-only\"}" dataUsingEncoding:NSUTF8StringEncoding]);
 Check([failure[@"httpStatus"] isEqual:@410]&&[failure[@"apiCode"] isEqual:@"30014"]&&[failure[@"endpoint"] hasSuffix:@"/v1/user/info"],@"HTTP410 retains exact official endpoint and bounded numeric API code");
 Check(![[failure description] containsString:@"fixture-secret-only"]&&![failure[@"unsupported"] boolValue],@"official failure not mislabeled unsupported and never echoes response secrets");
 failure=TFAIBalanceFailure(@"sub2api",[NSURL URLWithString:@"https://relay.invalid/v1/usage"],410,nil,nil);Check([failure[@"unsupported"] boolValue],@"HTTP410 relay endpoint means wallet unsupported not zero balance");
 failure=TFAIBalanceFailure(@"siliconflow",[NSURL URLWithString:@"https://example.invalid/v1/user/info?token=fixture-secret-only"],401,nil,[@"{\"code\":\"fixture-secret-only\"}" dataUsingEncoding:NSUTF8StringEncoding]);Check(![[failure description] containsString:@"fixture-secret-only"]&&!failure[@"apiCode"],@"diagnostic strips query and arbitrary error-code strings");
 Check(!TFAIBalanceAdapter(@{@"baseURL":@"https://api.deepseek.com",@"authMethod":@"oauth"}),@"no OAuth token sent to API-key balance endpoint");
 Check(!TFAIBalanceAdapter(Connection(@"http://api.deepseek.com/v1")),@"official wallet requires TLS");
 Check(!TFAIBalanceAdapter(Connection(@"https://api.deepseek.com.evil.invalid/v1"))||[TFAIBalanceAdapter(Connection(@"https://api.deepseek.com.evil.invalid/v1")) isEqual:@"sub2api"],@"hostname suffix not official");
 Check([TFAIBalanceURL(Connection(@"https://relay.invalid/prefix/v1"),@"sub2api").absoluteString isEqual:@"https://relay.invalid/prefix/v1/usage"],@"relay remains same origin and prefix");
 Check(!TFAIBalanceURL(Connection(@"https://relay.invalid/v1"),@"deepseek"),@"cannot select unrelated credential destination");
 Check(!TFAIBalanceDecode([@"[1,2,3]" dataUsingEncoding:NSUTF8StringEncoding]),@"array response rejected");
 for(id bad in @[NSNull.null,@{},@[],@"broken"]){Check(!TFAIBalanceParse(@"deepseek",@{@"is_available":bad,@"balance_infos":@[]}),@"malformed provider availability does not crash");Check(!TFAIBalanceParse(@"siliconflow",@{@"status":@YES,@"code":bad}),@"malformed provider code does not crash");}Check(!TFAIBalanceDecode(NSData.data),@"empty response rejected");
 NSString *base=[NSString stringWithUTF8String:argv[1]];TFAIProviderBalance *s=[TFAIProviderBalance new];NSDictionary *c=Connection([base stringByAppendingString:@"/ok/v1"]);NSDictionary *r=Fetch(s,c,NO);Check([r[@"amounts"][0][@"value"] isEqual:@"12.34"],@"real URLSession success");NSDictionary *r2=Fetch(s,c,NO);Check([r2[@"updatedAt"] isEqual:r[@"updatedAt"]],@"successful balance cached");r=Fetch(s,c,YES);Check([r[@"stale"] boolValue]&&r[@"amounts"]&&r[@"error"],@"refresh failure retains known balance with stale marker");
 r=Fetch(s,Connection([base stringByAppendingString:@"/redirect/v1"]),YES);Check(r[@"error"]&&!r[@"amounts"],@"redirect denied");r=Fetch(s,Connection([base stringByAppendingString:@"/large/v1"]),YES);Check(r[@"error"]&&!r[@"amounts"],@"oversized response bounded");
 NSMutableDictionary *automatic=[Connection([base stringByAppendingString:@"/auto/v1/responses"]) mutableCopy];[automatic removeObjectForKey:@"balanceAdapter"];
 r=Fetch(s,automatic,NO);Check([r[@"amounts"][0][@"value"] isEqual:@"12.34"]&&[r[@"endpoint"] hasSuffix:@"/auto/v1/usage"],@"real automatic discovery needs no manual adapter and handles responses URL");
 for(NSString *name in @[@"gone",@"missing",@"subscription"]){r=Fetch(s,Connection([base stringByAppendingFormat:@"/%@/v1",name]),YES);Check([r[@"unsupported"] boolValue]&&!r[@"amounts"]&&r[@"endpoint"],@"unsupported wallet recognized and no fabricated balance");}
 NSDictionary *recover=Connection([base stringByAppendingString:@"/recover/v1"]);r=Fetch(s,recover,YES);Check([r[@"unsupported"] boolValue],@"unsupported response cached accurately");r=Fetch(s,recover,YES);Check(r[@"amounts"]&&!r[@"unsupported"]&&!r[@"error"]&&!r[@"stale"],@"successful refresh clears old unsupported and diagnostic error state");
 __block int completed=0;NSDictionary *single=Connection([base stringByAppendingString:@"/single/v1"]);for(int i=0;i<4;i++)[s fetch:single refresh:YES completion:^(NSDictionary *v){Check(v[@"amounts"]!=nil,@"concurrent caller receives balance");completed++;}];NSDate *until=[NSDate dateWithTimeIntervalSinceNow:10];while(completed<4&&until.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];Check(completed==4,@"single flight completes all callers");
 printf("Balance: %d checks passed\n",checks);return 0;
}}
