#import "../AIContracts.h"
NSArray *TFAIActionSchemas(BOOL readOnly);
BOOL TFAIActionValidate(NSDictionary *args,BOOL *write,NSError **error);
void TFAIActionExecute(NSDictionary *args,NSString *root,NSString *project,NSString *session,TFAIResult completion);
NSDictionary *TFAIActionCatalog(BOOL readOnly);
