#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
static inline CGFloat TFAIDockedKeyboardInset(CGRect bounds,CGRect keyboard,CGFloat safeBottom){CGRect overlap=CGRectIntersection(bounds,keyboard);BOOL docked=!CGRectIsNull(overlap)&&CGRectGetMaxY(keyboard)>=CGRectGetMaxY(bounds)-1&&overlap.size.width>=bounds.size.width*.75;return docked?MAX(0,CGRectGetMaxY(bounds)-CGRectGetMinY(keyboard)-safeBottom):0;}
