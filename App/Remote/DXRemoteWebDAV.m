#import "DXRemoteWebDAV.h"
#import "DXRemoteHTTP.h"
#import "../AI/Permissions/TFAIPolicy.h"
#import "../GitPreferences.h"
#import "../ProjectSafety.h"
static NSString *XML(NSString *s){return [[[[[s?:@"" stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"] stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"] stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"] stringByReplacingOccurrencesOfString:@"\"" withString:@"&quot;"] stringByReplacingOccurrencesOfString:@"'" withString:@"&apos;"];}
static NSDictionary *Response(NSInteger status,NSString *text,NSDictionary *headers){return @{@"status":@(status),@"type":@"application/xml; charset=utf-8",@"body":[text?:@"" dataUsingEncoding:NSUTF8StringEncoding],@"headers":headers?:@{}};}
@interface DXRemoteWebDAV ()
@property NSMutableDictionary *locks;
@end
@implementation DXRemoteWebDAV
- (instancetype)init{if((self=[super init]))_locks=[NSMutableDictionary new];return self;}
- (NSString *)path:(NSString *)request root:(NSString *)root error:(NSError **)error{
 if([request containsString:@"?"]||[request containsString:@"#"])return nil;NSString *decoded=request.stringByRemovingPercentEncoding;if(!decoded||![decoded hasPrefix:@"/"]||[decoded containsString:@"//"])return nil;
 while(decoded.length>1&&[decoded hasSuffix:@"/"])decoded=[decoded substringToIndex:decoded.length-1];return [decoded isEqual:@"/"]?root:TFAISafePath(root,[decoded substringFromIndex:1],YES,error);
}
- (NSString *)href:(NSString *)path root:(NSString *)root directory:(BOOL)directory{
 NSString *relative=[path isEqual:root]?@"":[path substringFromIndex:root.length+1];NSMutableArray *parts=[NSMutableArray new];NSCharacterSet *allowed=[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"];for(NSString *part in [relative componentsSeparatedByString:@"/"])[parts addObject:[part stringByAddingPercentEncodingWithAllowedCharacters:allowed]];return [NSString stringWithFormat:@"/%@%@",[parts componentsJoinedByString:@"/"],directory&&relative.length?@"/":@""];
}
- (NSDictionary *)respond:(NSDictionary *)request root:(NSString *)root readOnly:(BOOL)readOnly origin:(NSString *)origin{
 @synchronized(self){
 NSString *method=request[@"method"];NSDictionary *headers=request[@"headers"];NSFileManager *fm=NSFileManager.defaultManager;NSError *error=nil;
 for(NSString *p in self.locks.allKeys)if([self.locks[p][@"expires"] doubleValue]<NSDate.date.timeIntervalSince1970)[self.locks removeObjectForKey:p];
 if([method isEqual:@"OPTIONS"])return Response(200,@"",@{@"DAV":@"1, 2",@"MS-Author-Via":@"DAV",@"Allow":@"OPTIONS, PROPFIND, GET, HEAD, PUT, MKCOL, MOVE, COPY, DELETE, LOCK, UNLOCK"});
 NSString *path=[self path:request[@"path"] root:root error:&error];if(!path)return Response(403,@"",nil);
 NSDictionary *a=[fm attributesOfItemAtPath:path error:nil];BOOL directory=[a[NSFileType] isEqual:NSFileTypeDirectory];if(a&&!directory&&![a[NSFileType] isEqual:NSFileTypeRegular])return Response(403,@"",nil);
 if([method isEqual:@"PROPFIND"]){
  if(!a)return Response(404,@"",nil);NSString *depth=headers[@"depth"]?:@"infinity";if(![@[@"0",@"1"] containsObject:depth])return Response(403,@"<?xml version=\"1.0\"?><D:error xmlns:D=\"DAV:\"><D:propfind-finite-depth/></D:error>",nil);
  NSMutableArray *paths=[NSMutableArray arrayWithObject:path];if(directory&&[depth isEqual:@"1"]){NSArray *names=[fm contentsOfDirectoryAtPath:path error:nil];if(names.count>2000)return Response(507,@"",nil);for(NSString *name in names){NSString *full=[path stringByAppendingPathComponent:name],*relative=[full substringFromIndex:root.length+1];if(TFAISafePath(root,relative,YES,nil))[paths addObject:full];}}
  NSMutableString *xml=[NSMutableString stringWithString:@"<?xml version=\"1.0\" encoding=\"utf-8\"?><D:multistatus xmlns:D=\"DAV:\">"];
  NSDateFormatter *date=[NSDateFormatter new];date.locale=[[NSLocale alloc]initWithLocaleIdentifier:@"en_US_POSIX"];date.timeZone=[NSTimeZone timeZoneForSecondsFromGMT:0];date.dateFormat=@"EEE, dd MMM yyyy HH:mm:ss 'GMT'";
  for(NSString *full in paths){NSDictionary *attrs=[fm attributesOfItemAtPath:full error:nil];BOOL dir=[attrs[NSFileType] isEqual:NSFileTypeDirectory];if(!dir&&![attrs[NSFileType] isEqual:NSFileTypeRegular])continue;
   NSString *etag=dir?@"directory":[NSString stringWithFormat:@"%@-%@",attrs[NSFileSize],@([attrs[NSFileModificationDate] timeIntervalSince1970])];
   [xml appendFormat:@"<D:response><D:href>%@</D:href><D:propstat><D:prop><D:displayname>%@</D:displayname><D:resourcetype>%@</D:resourcetype><D:getcontentlength>%@</D:getcontentlength><D:getlastmodified>%@</D:getlastmodified><D:getetag>&quot;%@&quot;</D:getetag><D:supportedlock><D:lockentry><D:lockscope><D:exclusive/></D:lockscope><D:locktype><D:write/></D:locktype></D:lockentry></D:supportedlock></D:prop><D:status>HTTP/1.1 200 OK</D:status></D:propstat></D:response>",XML([self href:full root:root directory:dir]),XML(full.lastPathComponent),dir?@"<D:collection/>":@"",attrs[NSFileSize]?:@0,[date stringFromDate:attrs[NSFileModificationDate]?:NSDate.date],XML(etag)];
  }[xml appendString:@"</D:multistatus>"];return Response(207,xml,nil);
 }
 if([@[@"GET",@"HEAD"] containsObject:method]){if(!a||directory)return Response(404,@"",nil);if([a[NSFileSize] unsignedLongLongValue]>32*1024*1024)return Response(413,@"",nil);NSData *data=[NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];NSString *text=data.length<1024*1024?[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]:nil;if(TFAIContainsSecret(text))return Response(403,@"",nil);NSString *etag=[NSString stringWithFormat:@"\"%@-%@\"",a[NSFileSize],@([a[NSFileModificationDate] timeIntervalSince1970])];return @{@"status":@200,@"type":@"application/octet-stream",@"body":data?:NSData.data,@"headers":@{@"ETag":etag}};}
 if(readOnly)return Response(403,@"",nil);if([TMCGitLease isBuilding:root])return Response(423,@"",nil);
 TMCGitLease *lease __attribute__((objc_precise_lifetime))=[TMCGitLease tryWrite];if(!lease)return Response(423,@"",nil);
 NSString *lockToken=self.locks[path][@"token"];if(lockToken&&![headers[@"if"] containsString:lockToken]&&![headers[@"lock-token"] containsString:lockToken])return Response(423,@"",nil);
 if([method isEqual:@"LOCK"]){
  NSString *token=lockToken?:[@"opaquelocktoken:" stringByAppendingString:NSUUID.UUID.UUIDString];if([headers[@"depth"] isEqual:@"infinity"])return Response(403,@"",nil);
  self.locks[path]=@{@"token":token,@"expires":@(NSDate.date.timeIntervalSince1970+600)};
  NSString *xml=[NSString stringWithFormat:@"<?xml version=\"1.0\"?><D:prop xmlns:D=\"DAV:\"><D:lockdiscovery><D:activelock><D:locktype><D:write/></D:locktype><D:lockscope><D:exclusive/></D:lockscope><D:depth>0</D:depth><D:timeout>Second-600</D:timeout><D:locktoken><D:href>%@</D:href></D:locktoken><D:lockroot><D:href>%@</D:href></D:lockroot></D:activelock></D:lockdiscovery></D:prop>",XML(token),XML(request[@"path"])];return Response(a?200:201,xml,@{@"Lock-Token":[NSString stringWithFormat:@"<%@>",token],@"Timeout":@"Second-600"});
 }
 if([method isEqual:@"UNLOCK"]){if(!lockToken)return Response(409,@"",nil);[self.locks removeObjectForKey:path];return Response(204,@"",nil);}
 if([path isEqual:root])return Response(403,@"",nil);
 NSString *etag=a?[NSString stringWithFormat:@"\"%@-%@\"",a[NSFileSize],@([a[NSFileModificationDate] timeIntervalSince1970])]:nil;
 if(headers[@"if-match"]&&![headers[@"if-match"] isEqual:etag]&&![headers[@"if-match"] isEqual:@"*"])return Response(412,@"",nil);
 if([headers[@"if-none-match"] isEqual:@"*"]&&a)return Response(412,@"",nil);
 if([method isEqual:@"MKCOL"]){if(a)return Response(405,@"",nil);BOOL ok=[fm createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:&error];return Response(ok?201:409,@"",nil);}
 if([method isEqual:@"PUT"]){
  if(directory)return Response(405,@"",nil);NSData *body=request[@"body"];NSString *text=body.length<=1024*1024?[[NSString alloc]initWithData:body encoding:NSUTF8StringEncoding]:nil;if(TFAIContainsSecret(text))return Response(403,@"",nil);
  NSData *before=a?[NSData dataWithContentsOfFile:path options:0 error:&error]:nil;if(error)return Response(409,@"",nil);
  if(before){NSString *backups=[root stringByAppendingPathComponent:@".studio-remote-backups"];[fm createDirectoryAtPath:backups withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&error];if(!error)[before writeToFile:[backups stringByAppendingPathComponent:NSUUID.UUID.UUIDString] options:NSDataWritingAtomic error:&error];}
  BOOL ok=NO;if(!error){if(before&&text)ok=TMCWriteDocument(path,before,text,&error);else if(before){NSFileCoordinator *coordinator=[[NSFileCoordinator alloc]initWithFilePresenter:nil];[coordinator coordinateWritingItemAtURL:[NSURL fileURLWithPath:path] options:0 error:&error byAccessor:^(NSURL *url){if([[NSData dataWithContentsOfURL:url] isEqual:before])[body writeToURL:url options:NSDataWritingAtomic error:nil];}];ok=[[NSData dataWithContentsOfFile:path] isEqual:body];}else ok=[body writeToFile:path options:NSDataWritingWithoutOverwriting error:&error];}return Response(ok?(a?204:201):409,@"",nil);
 }
 if([method isEqual:@"DELETE"]){if(!a)return Response(404,@"",nil);if(directory&&[[fm contentsOfDirectoryAtPath:path error:nil] count])return Response(409,@"",nil);NSString *backups=[root stringByAppendingPathComponent:@".studio-remote-backups"];[fm createDirectoryAtPath:backups withIntermediateDirectories:YES attributes:nil error:&error];BOOL ok=!error&&[fm moveItemAtPath:path toPath:[backups stringByAppendingPathComponent:NSUUID.UUID.UUIDString] error:&error];[self.locks removeObjectForKey:path];return Response(ok?204:409,@"",nil);}
 if([@[@"MOVE",@"COPY"] containsObject:method]){
  if(!a)return Response(404,@"",nil);NSURLComponents *destination=[NSURLComponents componentsWithString:headers[@"destination"]];NSString *targetPath=destination.percentEncodedPath;if(destination.host.length){NSString *targetOrigin=[NSString stringWithFormat:@"%@://%@%@",destination.scheme,destination.host,destination.port?[@":" stringByAppendingString:destination.port.stringValue]:@""];if(![targetOrigin isEqual:origin])return Response(502,@"",nil);}
  NSString *to=targetPath?[self path:targetPath root:root error:&error]:nil;if(!to||[to isEqual:root]||[to hasPrefix:[path stringByAppendingString:@"/"]])return Response(403,@"",nil);if(directory&&[[fm contentsOfDirectoryAtPath:path error:nil] count])return Response(409,@"",nil);if([fm fileExistsAtPath:to])return Response(412,@"",nil);if(self.locks[to])return Response(423,@"",nil);
  BOOL ok=[method isEqual:@"MOVE"]?[fm moveItemAtPath:path toPath:to error:&error]:[fm copyItemAtPath:path toPath:to error:&error];return Response(ok?201:409,@"",nil);
 }return Response(405,@"",nil);
 }
}
@end
