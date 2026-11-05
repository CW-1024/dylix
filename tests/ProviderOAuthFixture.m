#import "../App/AI/Providers/TFAIOAuth.h"
@implementation TFAIOAuth
+ (instancetype)shared{static id s;static dispatch_once_t once;dispatch_once(&once,^{s=[self new];});return s;}
- (void)credential:(NSDictionary *)c completion:(void(^)(NSString *,NSError *))done{done(nil,[NSError errorWithDomain:@"Fixture" code:1 userInfo:nil]);}
- (void)logout:(NSDictionary *)c completion:(TFAIResult)done{done(@{},nil);}
@end
