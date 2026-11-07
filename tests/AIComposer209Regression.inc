// Native chat layout checks. Local fixture only; no credentials or model requests.
@interface UIViewController (TFAIComposer209Calls)
- (void)updateInputHeight;
- (void)textViewDidChange:(UITextView *)textView;
@end
UIViewController *TFAIComposer209Regression(void){
 NSString *scope=[@"composer209-" stringByAppendingString:NSUUID.UUID.UUIDString];NSMutableDictionary *session=[TFAISessions create:scope title:@"输入框布局验证"];
 TFAIV2FakeRuntime *runtime=[TFAIV2FakeRuntime new];UIViewController *chat=TFAIChatFixtureController(@"",scope,runtime,^(NSString *p,NSUInteger l){});TFAIConfigureChat(chat,session,YES,nil);
 __block void(^poll)(void);NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:15];
 poll=^{if(!chat.isViewLoaded||[[chat valueForKey:@"loading"] boolValue]){if(deadline.timeIntervalSinceNow>0){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,100*NSEC_PER_MSEC),dispatch_get_main_queue(),poll);return;}}
  if([NSProcessInfo.processInfo.arguments containsObject:@"--composer209-dark"]){chat.navigationController.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;chat.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;}
  NSMutableArray *checks=[NSMutableArray new];void(^check)(BOOL,NSString *)=^(BOOL ok,NSString *name){[checks addObject:@{@"pass":@(ok),@"name":name}];};
  UITextView *input=[chat valueForKey:@"input"];NSLayoutConstraint *height=[chat valueForKey:@"inputHeightConstraint"];UIView *composer=[chat valueForKey:@"composer"];UITableView *table=[chat valueForKey:@"table"];
  void(^layout)(void)=^{[chat.view setNeedsLayout];[chat.view layoutIfNeeded];[chat updateInputHeight];[chat.view layoutIfNeeded];};
  void(^set)(NSString *)=^(NSString *text){input.text=text;[chat textViewDidChange:input];layout();};
  set(@"");CGFloat empty=height.constant;check(empty>=48&&!input.scrollEnabled,@"empty composer keeps compact minimum and no internal scrolling");
  NSString *six=@"第一行：检查输入框自动增高\n第二行：支持中文与换行\n第三行：编辑内容完整可见\n第四行：保留当前光标\n第五行：无需反复滚动\n第六行：继续查看会话";set(six);CGFloat sixHeight=height.constant;
  check(sixHeight>empty+input.font.lineHeight*3,@"six-line draft grows beyond the previous fixed two-line field");check(!input.scrollEnabled,@"short multiline draft grows before enabling scrolling");
  NSString *wrapped=[@"中文自动换行测试，输入内容应该逐行增高。" stringByPaddingToLength:140 withString:@"中文自动换行测试，输入内容应该逐行增高。" startingAtIndex:0];set(wrapped);check(height.constant>empty+input.font.lineHeight,@"soft-wrapped CJK text is measured at actual container width");
  NSString *longText=[@"较长的测试内容与符号 [] {}\n" stringByPaddingToLength:3000 withString:@"较长的测试内容与符号 [] {}\n" startingAtIndex:0];set(longText);NSRange selection=NSMakeRange(17,3);input.selectedRange=selection;[chat updateInputHeight];
  check(input.scrollEnabled&&height.constant<=ceil(input.font.lineHeight*8+20)+.5,@"long paste reaches bounded eight-line height then scrolls internally");check(NSEqualRanges(input.selectedRange,selection)&&[input.text isEqual:longText],@"measurement preserves content and selection");
  set(@"短消息");check(fabs(height.constant-empty)<1&&!input.scrollEnabled,@"deleting long content shrinks input and disables internal scrolling");
  CGRect original=chat.view.bounds;chat.view.bounds=CGRectMake(0,0,320,568);set(six);check(composer.bounds.size.width<=320&&height.constant>=empty&&table.bounds.size.height>96,@"small portrait retains usable message area");
  chat.view.bounds=CGRectMake(0,0,700,360);set(longText);check(height.constant>=empty&&height.constant<190,@"landscape limits composer height to available screen");chat.view.bounds=original;set(six);
  UIFont *font=input.font;input.font=[UIFont systemFontOfSize:28];[chat updateInputHeight];layout();check(height.constant>=ceil(input.font.lineHeight+20)&&[input.text isEqual:six],@"larger text remains legible without replacing the draft");input.font=font;
  UINavigationBarAppearance *transparent=TMCTransparentChatBarAppearance();check(transparent.backgroundEffect==nil&&(!transparent.backgroundColor||CGColorGetAlpha(transparent.backgroundColor.CGColor)<.001)&&(!transparent.shadowColor||CGColorGetAlpha(transparent.shadowColor.CGColor)<.001),@"chat-specific transparent navigation appearance has no color blur or shadow plate");
  if(@available(iOS 26.0,*)){check(chat.navigationItem.standardAppearance.backgroundEffect==nil,@"iOS26 uses transparent chat navigation item");check(CGRectGetMaxY(table.frame)>CGRectGetMinY(composer.frame)&&[[chat valueForKey:@"composerOverlapInset"] doubleValue]>0,@"iOS26 scrolls content behind glass and reserves last-message clearance");}
  else{check(chat.navigationItem.standardAppearance==nil,@"older iOS keeps existing navigation appearance");UIVisualEffectView *glass=[chat valueForKey:@"composerGlass"];check([glass.effect isKindOfClass:UIBlurEffect.class]||UIAccessibilityIsReduceTransparencyEnabled(),@"older iOS retains existing material fallback");check(CGRectGetMaxY(table.frame)<=CGRectGetMinY(composer.frame),@"older iOS retains nonoverlapping composer layout");}
  set(@"");[input becomeFirstResponder];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,700*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
   [input.undoManager removeAllActions];[input.undoManager beginUndoGrouping];[input insertText:six];[input.undoManager endUndoGrouping];layout();check([input.text isEqual:six]&&height.constant>empty,@"native insertText paste path grows input while editing");check(composer.frame.origin.y>=chat.view.safeAreaInsets.top,@"editing composer remains inside visible screen");
   if(input.undoManager.canUndo){[input.undoManager undo];[chat textViewDidChange:input];layout();check(input.text.length==0&&height.constant<=empty+1,@"native undo restores empty draft and compact height");}else check(NO,@"native text insertion registers Undo");
   set(six);input.selectedRange=NSMakeRange(input.text.length,0);layout();BOOL pass=YES;for(NSDictionary *c in checks)pass&=[c[@"pass"] boolValue];JSONWrite(@{@"passed":@(pass),@"checks":checks,@"os":UIDevice.currentDevice.systemVersion,@"emptyHeight":@(empty),@"sixLineHeight":@(sixHeight),@"keyboardHeight":@(height.constant),@"keyboardVisible":@(((NSLayoutConstraint *)[chat valueForKey:@"composerBottomConstraint"]).constant < -100),@"transparentBackground":transparent.backgroundColor.description?:@"nil",@"transparentShadow":transparent.shadowColor.description?:@"nil",@"inputFrame":NSStringFromCGRect(input.frame),@"composerFrame":NSStringFromCGRect(composer.frame)},[Docs() stringByAppendingPathComponent:@"ai-composer209.json"],nil);
   [TFAISessions remove:session[@"id"] project:scope];
  });poll=nil;
 };dispatch_async(dispatch_get_main_queue(),poll);return [[TMCNavigationController alloc]initWithRootViewController:chat];
}
