#import "TFAIProviderBalance.h"
#import "TFAIProtocol.h"
#import <CommonCrypto/CommonDigest.h>
static NSDictionary *BDict(id v){return [v isKindOfClass:NSDictionary.class]?v:@{};}
NSString *TFAIBalanceAdapter(NSDictionary *c){
 if([c[@"balanceAdapter"] isEqual:@"off"]||[c[@"authMethod"] isEqual:@"oauth"])return nil;
 NSURL *u=TFAIEndpoint(c,NO,NULL);if(!u)return nil;NSString *host=u.host.lowercaseString;
 NSDictionary *official=@{@"api.deepseek.com":@"deepseek",@"api.siliconflow.cn":@"siliconflow",@"api.moonshot.cn":@"moonshot",@"openrouter.ai":@"openrouter"};
 if(official[host])return ([u.scheme isEqual:@"https"]&&(!u.port||u.port.integerValue==443))?official[host]:nil;
 NSSet *excluded=[NSSet setWithArray:@[@"api.openai.com",@"api.anthropic.com",@"generativelanguage.googleapis.com",@"api.x.ai",@"api.moonshot.ai",@"api.siliconflow.com",@"dashscope.aliyuncs.com"]];
 return [c[@"balanceAdapter"] isEqual:@"sub2api"]&&![excluded containsObject:host]?@"sub2api":nil;
}
NSURL *TFAIBalanceURL(NSDictionary *c,NSString *adapter){
 NSString *actual=TFAIBalanceAdapter(c);if(!actual||(![actual isEqual:adapter]&&!([actual isEqual:@"openrouter"]&&[adapter isEqual:@"openrouterCredits"])))return nil;
 NSDictionary *urls=@{@"deepseek":@"https://api.deepseek.com/user/balance",@"siliconflow":@"https://api.siliconflow.cn/v1/user/info",@"moonshot":@"https://api.moonshot.cn/v1/users/me/balance",@"openrouter":@"https://openrouter.ai/api/v1/key",@"openrouterCredits":@"https://openrouter.ai/api/v1/credits"};
 if(urls[adapter])return [NSURL URLWithString:urls[adapter]];
 if(![adapter isEqual:@"sub2api"])return nil;
 NSURLComponents *u=[NSURLComponents componentsWithString:c[@"baseURL"]];u.query=nil;u.fragment=nil;NSString *path=u.path;while([path hasSuffix:@"/"])path=[path substringToIndex:path.length-1];u.path=[path stringByAppendingString:[path hasSuffix:@"/v1"]?@"/usage":@"/v1/usage"];return u.URL;
}
NSDictionary *TFAIBalanceDecode(NSData *data){
 // Validate JSON first, then quote its numeric lexemes before decoding. This
 // preserves monetary decimals without a binary floating-point round trip.
 if(!data.length||data.length>65536||![NSJSONSerialization JSONObjectWithData:data options:0 error:nil])return nil;
 NSString *s=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];if(!s)return nil;NSMutableString *out=[NSMutableString new];BOOL quoted=NO,escaped=NO;
 for(NSUInteger i=0;i<s.length;i++){unichar ch=[s characterAtIndex:i];if(quoted){[out appendFormat:@"%C",ch];if(escaped)escaped=NO;else if(ch=='\\')escaped=YES;else if(ch=='"')quoted=NO;continue;}if(ch=='"'){quoted=YES;[out appendString:@"\""];continue;}if(ch=='-'||(ch>='0'&&ch<='9')){NSUInteger start=i;while(i+1<s.length&&[[NSCharacterSet characterSetWithCharactersInString:@"0123456789.eE+-"] characterIsMember:[s characterAtIndex:i+1]])i++;[out appendFormat:@"\"%@\"",[s substringWithRange:NSMakeRange(start,i-start+1)]];}else[out appendFormat:@"%C",ch];}
 id json=[NSJSONSerialization JSONObjectWithData:[out dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];return [json isKindOfClass:NSDictionary.class]?json:nil;
}
static NSDecimalNumber *BDecimal(id value){
 if(![value isKindOfClass:NSString.class]&&![value isKindOfClass:NSNumber.class])return nil;if([value isKindOfClass:NSNumber.class]&&CFGetTypeID((__bridge CFTypeRef)value)==CFBooleanGetTypeID())return nil;
 NSString *s=[value description];if(s.length>96||![s rangeOfString:@"^-?(0|[1-9][0-9]*)(\\.[0-9]+)?([eE][+-]?[0-9]{1,2})?$" options:NSRegularExpressionSearch].length)return nil;
 NSUInteger digits=0;for(NSUInteger i=0;i<s.length;i++)if([s characterAtIndex:i]>='0'&&[s characterAtIndex:i]<='9')digits++;if(digits>38)return nil;
 NSDecimalNumber *n=[NSDecimalNumber decimalNumberWithString:s locale:@{@"NSLocaleDecimalSeparator":@"."}];return [n isEqual:NSDecimalNumber.notANumber]?nil:n;
}
static NSDictionary *BAmount(NSString *currency,id value){NSDecimalNumber *n=BDecimal(value);return n?@{@"currency":currency?:@"",@"value":n.stringValue}:nil;}
static BOOL BCode(id value,NSString *expected){return ([value isKindOfClass:NSString.class]&&[value isEqual:expected])||([value isKindOfClass:NSNumber.class]&&CFGetTypeID((__bridge CFTypeRef)value)!=CFBooleanGetTypeID()&&[[value stringValue] isEqual:expected]);}
NSDictionary *TFAIBalanceParse(NSString *adapter,NSDictionary *j){
 j=BDict(j);
 NSMutableArray *amounts=[NSMutableArray new];NSString *kind=@"balance";
 if([adapter isEqual:@"deepseek"]){if(![j[@"is_available"] isEqual:@YES]||![j[@"balance_infos"] isKindOfClass:NSArray.class])return nil;for(id raw in j[@"balance_infos"]){NSDictionary *row=BDict(raw);if(![@[@"CNY",@"USD"] containsObject:row[@"currency"]])continue;NSDictionary *v=BAmount(row[@"currency"],row[@"total_balance"]);if(!v)return nil;[amounts addObject:v];}}
 else if([adapter isEqual:@"siliconflow"]||[adapter isEqual:@"moonshot"]){if(![j[@"status"] isEqual:@YES]||!BCode(j[@"code"],[adapter isEqual:@"siliconflow"]?@"20000":@"0"))return nil;NSDictionary *v=BAmount(@"CNY",BDict(j[@"data"])[[adapter isEqual:@"siliconflow"]?@"totalBalance":@"available_balance"]);if(v)[amounts addObject:v];}
 else if([adapter isEqual:@"openrouter"]){NSDictionary *d=BDict(j[@"data"]);if(!d.count)return nil;if(d[@"limit_remaining"]==NSNull.null)return @{@"needsCredits":@YES};NSDictionary *v=BAmount(@"USD",d[@"limit_remaining"]);if(v)[amounts addObject:v];kind=@"credit_limit";}
 else if([adapter isEqual:@"openrouterCredits"]){NSDictionary *d=BDict(j[@"data"]);NSDecimalNumber *credits=BDecimal(d[@"total_credits"]),*used=BDecimal(d[@"total_usage"]);if(credits&&used){NSDecimal a=credits.decimalValue,b=used.decimalValue,difference;if(NSDecimalSubtract(&difference,&a,&b,NSRoundPlain)!=NSCalculationNoError)return nil;[amounts addObject:@{@"currency":@"USD",@"value":[NSDecimalNumber decimalNumberWithDecimal:difference].stringValue}];}}
 else if([adapter isEqual:@"sub2api"]){if((j[@"error"]&&j[@"error"]!=NSNull.null)||![j[@"isValid"] isEqual:@YES]||![j[@"mode"] isEqual:@"unrestricted"])return nil;for(NSString *k in @[@"quota",@"subscription",@"subscriptions"])if(j[k]&&j[k]!=NSNull.null)return nil;id limits=j[@"rate_limits"];if(limits&&limits!=NSNull.null&&(![limits isKindOfClass:NSArray.class]||[limits count]))return nil;id unit=j[@"unit"];if(unit==NSNull.null||!unit)unit=@"";if(![unit isKindOfClass:NSString.class]||[unit length]>32||[unit rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound)return nil;id balance=j[@"balance"];if(!balance||balance==NSNull.null)balance=j[@"remaining"];NSDictionary *v=BAmount(unit,balance);if(v)[amounts addObject:v];}
 return amounts.count?@{@"amounts":amounts,@"kind":kind}:nil;
}
@interface TFBalanceHTTP : NSObject <NSURLSessionDataDelegate>
@property NSURLSession *session;
@property NSMutableData *data;
@property(copy) void(^completion)(NSData *,NSInteger,NSError *);
@property BOOL finished;
@end
@implementation TFBalanceHTTP
- (void)finish:(NSError *)error status:(NSInteger)status{if(self.finished)return;self.finished=YES;void(^done)(NSData *,NSInteger,NSError *)=self.completion;self.completion=nil;if(done)done(error?nil:[self.data copy],status,error);[self.session invalidateAndCancel];self.session=nil;}
- (void)URLSession:(NSURLSession *)s task:(NSURLSessionTask *)t willPerformHTTPRedirection:(NSHTTPURLResponse *)r newRequest:(NSURLRequest *)req completionHandler:(void (^)(NSURLRequest *))handler{handler(nil);}
- (void)URLSession:(NSURLSession *)s dataTask:(NSURLSessionDataTask *)t didReceiveResponse:(NSURLResponse *)r completionHandler:(void (^)(NSURLSessionResponseDisposition))handler{handler(r.expectedContentLength>65536?NSURLSessionResponseCancel:NSURLSessionResponseAllow);}
- (void)URLSession:(NSURLSession *)s dataTask:(NSURLSessionDataTask *)t didReceiveData:(NSData *)data{if(self.data.length+data.length>65536){[self finish:[NSError errorWithDomain:@"Dylix.Balance" code:1 userInfo:nil] status:0];return;}[self.data appendData:data];}
- (void)URLSession:(NSURLSession *)s task:(NSURLSessionTask *)t didCompleteWithError:(NSError *)e{[self finish:e status:[(NSHTTPURLResponse *)t.response statusCode]];}
@end
@interface TFAIProviderBalance ()
@property NSMutableDictionary *cache,*pending;
@end
@implementation TFAIProviderBalance
+ (instancetype)shared{static TFAIProviderBalance *s;static dispatch_once_t once;dispatch_once(&once,^{s=[self new];s.cache=[NSMutableDictionary new];s.pending=[NSMutableDictionary new];});return s;}
- (instancetype)init{if((self=[super init])){_cache=[NSMutableDictionary new];_pending=[NSMutableDictionary new];}return self;}
- (void)request:(NSDictionary *)c adapter:(NSString *)adapter secret:(NSString *)secret completion:(void (^)(NSDictionary *,NSString *))completion{
 NSURL *url=TFAIBalanceURL(c,adapter);if(!url){completion(nil,@"当前连接不支持余额查询");return;}
 NSMutableURLRequest *r=[NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15];[r setValue:[@"Bearer " stringByAppendingString:secret] forHTTPHeaderField:@"Authorization"];[r setValue:@"application/json" forHTTPHeaderField:@"Accept"];NSString *ua=TFAIUserAgent(c,NULL);if(ua.length)[r setValue:ua forHTTPHeaderField:@"User-Agent"];
 TFBalanceHTTP *http=[TFBalanceHTTP new];http.data=[NSMutableData new];NSURLSessionConfiguration *config=NSURLSessionConfiguration.ephemeralSessionConfiguration;config.HTTPCookieStorage=nil;config.HTTPShouldSetCookies=NO;config.URLCache=nil;config.timeoutIntervalForResource=20;
 http.completion=^(NSData *data,NSInteger status,NSError *error){dispatch_async(dispatch_get_main_queue(),^{if(error||status<200||status>=300){completion(nil,error?@"网络查询失败，请稍后重试":[NSString stringWithFormat:@"查询失败（HTTP %ld），请核对服务商接口和密钥权限",(long)status]);return;}NSDictionary *result=TFAIBalanceParse(adapter,TFAIBalanceDecode(data));if([result[@"needsCredits"] boolValue]){[self request:c adapter:@"openrouterCredits" secret:secret completion:completion];return;}completion(result,result?nil:@"接口未返回可识别的余额数据");});};
 http.session=[NSURLSession sessionWithConfiguration:config delegate:http delegateQueue:nil];[[http.session dataTaskWithRequest:r] resume];
}
- (void)fetch:(NSDictionary *)connection refresh:(BOOL)refresh completion:(void (^)(NSDictionary *))completion{
 NSDictionary *c=[connection copy];dispatch_async(dispatch_get_main_queue(),^{NSString *adapter=TFAIBalanceAdapter(c);if(!adapter){completion(@{@"unsupported":@YES,@"error":@"未提供官方余额接口；中转站可在连接设置中手动启用 Sub2API 适配。"});return;}NSString *secret=[TFAIConnections secret:c[@"id"]];if(!secret.length){completion(@{@"error":@"请先保存 API 密钥"});return;}
 NSData *scope=[NSJSONSerialization dataWithJSONObject:@[c[@"id"]?:@"",c[@"baseURL"]?:@"",c[@"userAgent"]?:@"",adapter,secret] options:0 error:nil];unsigned char digest[CC_SHA256_DIGEST_LENGTH];CC_SHA256(scope.bytes,(CC_LONG)scope.length,digest);NSMutableString *key=[NSMutableString new];for(NSUInteger i=0;i<sizeof(digest);i++)[key appendFormat:@"%02x",digest[i]];
 NSDictionary *old=self.cache[key];NSTimeInterval age=NSDate.date.timeIntervalSince1970-[old[@"checkedAt"] doubleValue];if(!refresh&&old&&age<(old[@"error"]?60:300)){completion(old);return;}NSMutableArray *listeners=self.pending[key];if(listeners){[listeners addObject:[completion copy]];return;}self.pending[key]=[NSMutableArray arrayWithObject:[completion copy]];
 [self request:c adapter:adapter secret:secret completion:^(NSDictionary *value,NSString *error){NSMutableDictionary *result=[value?:old?:@{} mutableCopy];result[@"checkedAt"]=@(NSDate.date.timeIntervalSince1970);result[@"source"]=adapter;if(value){result[@"updatedAt"]=result[@"checkedAt"];[result removeObjectForKey:@"error"];[result removeObjectForKey:@"stale"];}else{result[@"error"]=error?:@"查询失败";result[@"stale"]=@YES;}self.cache[key]=result;NSArray *callbacks=[self.pending[key] copy];[self.pending removeObjectForKey:key];for(void(^callback)(NSDictionary *) in callbacks)callback([result copy]);}];
 });
}
@end
