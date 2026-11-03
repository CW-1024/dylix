#import "TFScreenAwake.h"
#import <UIKit/UIKit.h>
@interface TFScreenAwake : NSObject
@property NSMutableSet *reasons;
- (void)apply;
@end
@implementation TFScreenAwake
- (instancetype)init { if((self=[super init])){_reasons=[NSMutableSet new];for(NSString *name in @[UIApplicationDidBecomeActiveNotification,UIApplicationWillResignActiveNotification])[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(changed:) name:name object:nil];}return self; }
- (void)changed:(NSNotification *)notification { if([notification.name isEqual:UIApplicationWillResignActiveNotification])UIApplication.sharedApplication.idleTimerDisabled=NO;else [self apply]; }
- (void)apply { UIApplication.sharedApplication.idleTimerDisabled=self.reasons.count>0&&UIApplication.sharedApplication.applicationState==UIApplicationStateActive; }
@end
void TFScreenAwakeSet(NSString *reason, BOOL active){
 if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{TFScreenAwakeSet(reason,active);});return;}
 static TFScreenAwake *owner;static dispatch_once_t once;dispatch_once(&once,^{owner=[TFScreenAwake new];});
 if(active)[owner.reasons addObject:reason];else[owner.reasons removeObject:reason];[owner apply];
}
