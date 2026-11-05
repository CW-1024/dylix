#import <Foundation/Foundation.h>
NSArray<NSDictionary *> *TFAIProviderRegistry(void);
NSDictionary *TFAIProvider(NSString *identifier);
NSString *TFAIWireProtocol(NSString *identifier);
NSArray<NSDictionary *> *TFAIFamilyReasoningOptions(NSDictionary *connection);
NSDictionary *TFAIObservedCapabilities(NSDictionary *connection);
NSString *TFAIConnectionCaption(NSDictionary *connection);
