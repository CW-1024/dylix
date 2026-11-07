#import <UIKit/UIKit.h>
UIVisualEffect *TMCGlassEffect(BOOL interactive);
UIButtonConfiguration *TMCButtonConfiguration(BOOL prominent);
// Configure the chat item only; shared navigation bar styling stays untouched.
UINavigationBarAppearance *TMCTransparentChatBarAppearance(void);
@interface TMCNavigationController : UINavigationController
@end
