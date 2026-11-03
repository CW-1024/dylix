#import <Foundation/Foundation.h>
@interface DXRemoteWebDAV : NSObject
// Caller authenticates and resolves a native-authorized project UUID first.
- (NSDictionary *)respond:(NSDictionary *)request root:(NSString *)root readOnly:(BOOL)readOnly origin:(NSString *)origin;
@end
