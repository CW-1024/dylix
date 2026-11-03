#import <Foundation/Foundation.h>
#import "../AI/AIContracts.h"
// Shared Studio adapters. They call the same editor/workspace entry points as native AI.
void DXStudioWorkspace(NSMutableDictionary *owner,NSString *tool,NSDictionary *arguments,TFAIResult completion);
NSDictionary *DXStudioWorkspaceState(NSMutableDictionary *owner);
@interface DXRemoteWorkspace : NSObject
// Called only on the Remote serial queue; business callbacks re-enter that queue.
- (instancetype)initWithQueue:(dispatch_queue_t)queue;
- (NSDictionary *)submit:(NSDictionary *)request device:(NSString *)device;
- (NSDictionary *)job:(NSString *)identifier device:(NSString *)device;
- (NSDictionary *)confirm:(NSString *)identifier nonce:(NSString *)nonce accepted:(BOOL)accepted device:(NSString *)device;
- (NSDictionary *)cancel:(NSString *)identifier device:(NSString *)device;
- (NSDictionary *)download:(NSString *)identifier device:(NSString *)device;
- (void)revoke:(NSString *)device;
- (void)stop;
@end
