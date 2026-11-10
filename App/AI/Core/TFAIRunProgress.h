#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
static NSString *RunProgressJSON(id object){NSData *d=[NSJSONSerialization dataWithJSONObject:object options:NSJSONWritingSortedKeys error:nil];return d?[[NSString alloc]initWithData:d encoding:NSUTF8StringEncoding]:@"{}";}
static NSString *RunProgressDigest(id object){NSData *d=[RunProgressJSON(object) dataUsingEncoding:NSUTF8StringEncoding];unsigned char hash[CC_SHA256_DIGEST_LENGTH];CC_SHA256(d.bytes,(CC_LONG)d.length,hash);NSMutableString *s=[NSMutableString new];for(NSUInteger i=0;i<sizeof(hash);i++)[s appendFormat:@"%02x",hash[i]];return s;}
static id RunProgressStable(id value){
 if([value isKindOfClass:NSDictionary.class]){NSMutableDictionary *out=[NSMutableDictionary new];for(NSString *k in value)if(![@[@"duration",@"timestamp",@"export_id",@"request_id",@"elapsed",@"queriedAt"] containsObject:k])out[k]=RunProgressStable(value[k]);return out;}
 if([value isKindOfClass:NSArray.class]){NSMutableArray *out=[NSMutableArray new];for(id v in value)[out addObject:RunProgressStable(v)];return out;}return value;
}
static BOOL RunProgressPolling(NSDictionary *call,NSDictionary *value){NSString *n=call[@"name"];return [n hasPrefix:@"sandbox_process_"]||[n hasPrefix:@"flex_"]||[n isEqual:@"subtask_task"]||[n isEqual:@"read_app_state"];}
static BOOL RunProgressMilestone(NSDictionary *call,NSDictionary *value){return value[@"export_id"]||value[@"artifact_id"]||value[@"build_id"]||value[@"jobID"]||[value[@"applied"] boolValue]||[call[@"name"] isEqual:@"build_project"];}
static NSDictionary *RunProgressFacts(NSDictionary *value){NSMutableDictionary *out=[NSMutableDictionary new];for(NSString *k in @[@"export_id",@"artifact_id",@"build_id",@"jobID",@"name",@"bytes",@"success",@"applied",@"copied",@"state",@"sha256"])if(value[k]&&[RunProgressJSON(@{k:value[k]}) length]<512)out[k]=value[k];return out;}
