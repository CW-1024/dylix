#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
// Pure adapters are exposed for fixture tests. No provider credentials in results.
NSString * _Nullable TFAIBalanceAdapter(NSDictionary *connection);
NSURL * _Nullable TFAIBalanceURL(NSDictionary *connection, NSString *adapter);
NSDictionary * _Nullable TFAIBalanceDecode(NSData *data);
NSDictionary * _Nullable TFAIBalanceParse(NSString *adapter, NSDictionary *payload);
@interface TFAIProviderBalance : NSObject
+ (instancetype)shared;
- (void)fetch:(NSDictionary *)connection refresh:(BOOL)refresh completion:(void (^)(NSDictionary *result))completion;
@end
NS_ASSUME_NONNULL_END
