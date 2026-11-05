#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
// Counters are provider-reported, cumulative within ONE HTTP model request.
NSDictionary *TFAINormalizeUsage(NSDictionary *usage, NSString *wireProtocol);
NSDictionary *TFAIUsageTotals(NSArray<NSDictionary *> *records);
@interface TFAIUsageStore : NSObject
+ (instancetype)shared;
- (instancetype)initWithDirectory:(NSURL *)directory;
- (void)begin:(NSString *)requestID project:(NSString *)project session:(NSString *)session connection:(NSDictionary *)connection wire:(NSString *)wire;
- (void)update:(NSString *)requestID usage:(NSDictionary *)usage;
- (void)finish:(NSString *)requestID status:(NSString *)status;
// Serialized after pending writes. Off the main thread; caller dispatches UI.
- (void)read:(void (^)(NSArray<NSDictionary *> *records, NSString * _Nullable error))completion;
@end
NS_ASSUME_NONNULL_END
