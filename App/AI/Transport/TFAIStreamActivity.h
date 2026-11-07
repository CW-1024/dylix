#import <Foundation/Foundation.h>

// Metadata only. Times use systemUptime, so a changed wall clock cannot expire
// a session or masquerade as newly received model output. This never retries.
@interface TFAIStreamActivity : NSObject
- (instancetype)initAt:(NSTimeInterval)now;
- (void)packetAt:(NSTimeInterval)now bytes:(NSUInteger)bytes;
- (void)contentAt:(NSTimeInterval)now phase:(NSString *)phase;
- (NSDictionary *)statusAt:(NSTimeInterval)now;
@end
