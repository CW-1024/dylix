#import <Foundation/Foundation.h>
NSString *TFAIBuildInputFingerprint(NSString *root,NSDictionary *config);
BOOL TFAIBuildRestoreObject(NSString *fingerprint,NSArray *arguments,NSString *root,NSString *build,NSString *object,NSString *cache);
void TFAIBuildSaveObject(NSString *fingerprint,NSArray *arguments,NSString *root,NSString *build,NSString *object,NSString *cache);
