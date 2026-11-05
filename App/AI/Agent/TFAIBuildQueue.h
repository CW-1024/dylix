#import "../AIContracts.h"
typedef void(^TFAIBuildExecutor)(void(^progress)(NSString *stage,double fraction),TFAIResult done);
@interface TFAIBuildQueue : NSObject
+ (instancetype)shared;
- (NSArray<NSDictionary *> *)tasks;
- (NSString *)enqueue:(NSString *)root name:(NSString *)name executor:(TFAIBuildExecutor)executor cancel:(dispatch_block_t)cancel completion:(TFAIResult)completion;
- (NSString *)enqueue:(NSString *)root session:(NSString *)sessionID name:(NSString *)name executor:(TFAIBuildExecutor)executor cancel:(dispatch_block_t)cancel completion:(TFAIResult)completion;
- (void)cancel:(NSString *)identifier;
@end
FOUNDATION_EXPORT UIViewController *TFAIBuildQueueController(void);
