#import <Foundation/Foundation.h>
NSDictionary *TFBinaryIndex(NSData *data);
NSDictionary *TFBuildProvenance(NSString *root, NSArray *sources, NSDictionary *config, NSString *build);
NSArray *TFRuntimeRisks(NSString *root);
NSString *TFCrashAnalysis(NSData *data, NSString *documents);
NSString *TFResolvedOptimization(NSDictionary *config);

BOOL TFShouldStripSymbols(NSDictionary *config);
NSDictionary *TFReleaseSymbolIndex(NSData *debug, NSData *release, NSError **error);
