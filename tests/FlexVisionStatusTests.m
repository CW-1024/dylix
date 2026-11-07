// Production AIRuntime with fixture transport. ImageIO decodes a real local JPEG;
// no paid/model request and no claim of an injected-device end-to-end test.
#define TFAI_VISION_IMAGEIO 1
#define main ExistingBudgetMain
#import "AIRuntimeBudgetTests.m"
#undef main
static NSData *JPEG(void) {
 unsigned char pixels[4*8*8];memset(pixels,200,sizeof(pixels));CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
 CGContextRef context=CGBitmapContextCreate(pixels,8,8,8,32,space,kCGImageAlphaNoneSkipLast);CGColorSpaceRelease(space);
 CGImageRef image=CGBitmapContextCreateImage(context);CGContextRelease(context);NSMutableData *data=[NSMutableData new];
 CGImageDestinationRef dest=CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data,CFSTR("public.jpeg"),1,NULL);CGImageDestinationAddImage(dest,image,NULL);Check(CGImageDestinationFinalize(dest),@"real fixture JPEG generated");CFRelease(dest);CGImageRelease(image);return data;
}
int main(){@autoreleasepool{
 NSData *jpeg=JPEG();NSString *encoded=[jpeg base64EncodedStringWithOptions:0];
 for(NSString *scenario in @[@"success",@"error",@"stop",@"blocked",@"invalid"]){
  requests=0;NSMutableArray *events=[NSMutableArray new];FixtureTransport=^(NSArray *m,NSArray *t,TFAIEvent e){};
  PatchFeedbackRuntime *runtime=[PatchFeedbackRuntime new];runtime.root=@"/tmp/fixture";runtime.projectID=@"fixture";
  runtime.event=^(NSDictionary *e){[events addObject:e];};[runtime activateSession:@"vision-status-fixture"];
  [runtime send:@[@{@"role":@"user",@"content":@"Inspect"}] session:@"vision-status-fixture"];
  NSMutableDictionary *connection=[runtime.connection mutableCopy];connection[@"capabilities"]=@{@"image":@"supported"};runtime.connection=connection;
  NSDictionary *call=@{@"id":@"capture-test",@"name":@"flex_sensitive_read",@"arguments":@{@"operation":@"capture_screen"}};
  [runtime recordCall:call result:@{@"mime":@"image/jpeg",@"imageBase64":[scenario isEqual:@"invalid"]?@"aGVsbG8=":encoded,@"width":@8,@"height":@8} error:nil index:0];
  if([scenario isEqual:@"invalid"]){Check(!runtime.pendingFlexImage&&!runtime.pendingFlexCaptureID,@"invalid JPEG never becomes a pending visual input");[runtime stop];continue;}
  Check([events.lastObject[@"stage"] isEqual:@"captured"]&&[runtime.pendingFlexImage[@"data"] isEqual:encoded],@"valid JPEG is acquired before upload is claimed");
  NSString *saved=[[NSString alloc]initWithData:[NSJSONSerialization dataWithJSONObject:runtime.messages options:0 error:nil] encoding:NSUTF8StringEncoding];Check(![saved containsString:encoded],@"capture payload is absent from persisted tool history");
  __block BOOL sawImage=NO;
  FixtureTransport=^(NSArray *messages,NSArray *tools,TFAIEvent event){sawImage=[messages.lastObject[@"images"][0][@"data"] isEqual:encoded];
   if([scenario isEqual:@"success"]){event(@{@"type":@"request_body_sent"});event(@{@"type":@"request_body_sent"});event(@{@"type":@"text",@"text":@"fixture reply"});event(@{@"type":@"done"});}
   else if([scenario isEqual:@"error"])event(@{@"type":@"error",@"message":@"fixture failure before upload"});
  };
  if([scenario isEqual:@"blocked"])[runtime.messages addObject:@{@"role":@"user",@"content":[@"x" stringByPaddingToLength:1024*1024 withString:@"x" startingAtIndex:0]}];
  [runtime nextRound];if([scenario isEqual:@"stop"])[runtime stop];
  NSUInteger sent=0;NSString *finalStage=nil;for(NSDictionary *e in events)if([e[@"type"] isEqual:@"flex_capture_status"]){finalStage=e[@"stage"];if([finalStage isEqual:@"sent"])sent++;Check(!e[@"imageBase64"]&&!e[@"data"],@"status events contain metadata only");}
  if([scenario isEqual:@"success"])Check(sawImage&&sent==1&&[finalStage isEqual:@"sent"],@"next request receives JPEG; only confirmed body upload marks sent once");
  else Check(sent==0&&[finalStage isEqual:[scenario isEqual:@"stop"]?@"cancelled":@"failed"],@"failure, cancellation and blocked context never claim upload");
  if([scenario isEqual:@"blocked"])Check(!sawImage&&requests==1,@"context guard blocks screenshot request before transport");
  Check(!runtime.pendingFlexImage&&!runtime.pendingFlexCaptureID&&!runtime.currentFlexCaptureID,@"terminal outcome clears transient screenshot state");
 }
 FixtureTransport=nil;NSLog(@"PASS FLEX vision status runtime checks");
}return 0;}
