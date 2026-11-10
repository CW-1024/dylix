#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
/// Host-side offline maintenance. Must only apply pending operations before iSH boots.
@interface TFAIISHEnvironment : NSObject
+ (NSString *)basePath;
+ (NSDictionary *)inventoryAtBase:(NSString *)base;
+ (BOOL)schedule:(NSString *)operation sessionKey:(NSString *)key snapshot:(nullable NSString *)snapshot base:(NSString *)base error:(NSError **)error;
+ (BOOL)applyPendingAtBase:(NSString *)base error:(NSError **)error;
+ (BOOL)deleteSnapshot:(NSString *)identifier base:(NSString *)base error:(NSError **)error;
+ (BOOL)cancelPendingAtBase:(NSString *)base error:(NSError **)error;
@end
NS_ASSUME_NONNULL_END
