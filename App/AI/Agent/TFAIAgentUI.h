#import <UIKit/UIKit.h>
UIViewController *TFAIAgentSettingsController(NSString *root,NSString *sessionID);
UIViewController *TFAIAgentSettingsControllerWithBrowserAction(NSString *root,NSString *sessionID,void (^onAsk)(NSString *url));
