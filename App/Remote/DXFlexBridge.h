#import <Foundation/Foundation.h>

// Short-lived runtime report scoped to a paired Remote device and AI session.
@interface DXFlexBridge : NSObject
+ (instancetype)shared;
- (NSDictionary *)publish:(NSDictionary *)input device:(NSString *)device error:(NSError **)error;
- (void)bindSession:(NSString *)session device:(NSString *)device;
- (BOOL)hasContextForSession:(NSString *)session;
- (NSDictionary *)contextForSession:(NSString *)session;
- (BOOL)hasLiveAgentForSession:(NSString *)session;
- (NSDictionary *)nextForDevice:(NSString *)device;
- (BOOL)reply:(NSDictionary *)input device:(NSString *)device error:(NSError **)error;
- (void)enqueueForSession:(NSString *)session operation:(NSString *)operation arguments:(NSDictionary *)arguments completion:(void (^)(NSDictionary *result, NSError *error))completion;
- (void)revokeDevice:(NSString *)device;
@end
