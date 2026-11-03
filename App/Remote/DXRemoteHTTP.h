#import <Foundation/Foundation.h>
#import <Security/Security.h>
NS_ASSUME_NONNULL_BEGIN
NSDictionary *DXRemoteResponse(NSInteger status,NSDictionary *json);
NSDictionary * _Nullable DXRemoteParseRequest(NSData *bytes,BOOL *complete,NSInteger *failure);
@interface DXRemoteHTTP : NSObject
@property(nonatomic,readonly) dispatch_queue_t queue;
@property(nonatomic,copy) NSDictionary *(^handler)(NSDictionary *request);
@property(nonatomic,copy,nullable) void (^asyncHandler)(NSDictionary *request,void(^complete)(NSDictionary *response));
@property(nonatomic,copy,nullable) void (^stateChanged)(NSString *state);
@property(nonatomic,readonly) NSString *origin;
// The caller owns the identity; Network.framework retains it in TLS options.
@property(nonatomic,nullable) SecIdentityRef tlsIdentity;
- (instancetype)initWithQueue:(dispatch_queue_t)queue;
- (BOOL)startAddress:(NSString *)address port:(NSUInteger)port error:(NSError **)error;
- (void)stop;
@end
NS_ASSUME_NONNULL_END
