#import <Foundation/Foundation.h>
// Only generated Build-UUID directories recorded by this project's cache manifest.
NSArray *TFAIProjectBuilds(NSString *root, NSString *documents);
NSDictionary *TFAICleanProjectBuilds(NSString *root, NSString *documents, NSArray *identifiers, NSError **error);
// Internal host context only. Never supplied by model tool arguments.
NSString *TFAISessionCheckpointDirectory(NSString *caches, NSString *root, NSString *sessionID);
NSDictionary *TFAICleanSessionBuildCache(NSString *root, NSString *documents, NSString *sessionID, NSString *caches, NSError **error);
