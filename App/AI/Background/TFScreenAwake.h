#import <Foundation/Foundation.h>
// Main-thread, idempotent reason ownership shared by build, AI and Remote.
FOUNDATION_EXPORT void TFScreenAwakeSet(NSString *reason, BOOL active);
