#import <Foundation/Foundation.h>
NSDictionary *TFAIToolContext(NSString *root,NSString *session,NSDictionary *references,BOOL bridge,BOOL approval,BOOL readOnly);
NSDictionary *TFAIToolValidReferences(NSDictionary *references);
NSDictionary *TFAIToolRemoteStatus(void);
