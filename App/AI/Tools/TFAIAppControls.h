#import <Foundation/Foundation.h>
NSArray<NSDictionary *> *TFAIAppControlSchemas(BOOL readOnly);
NSDictionary *TFAIAppState(void);
BOOL TFAIValidateAppSettings(NSDictionary *changes,NSError **error);
NSDictionary *TFAIApplyAppSettings(NSDictionary *changes,NSError **error);
