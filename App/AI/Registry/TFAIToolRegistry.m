#import "TFAIToolRegistry.h"
#import <math.h>

static BOOL Reject(NSError **error,NSString *text){if(error)*error=[NSError errorWithDomain:@"Dylix.ToolRegistry" code:1 userInfo:@{NSLocalizedDescriptionKey:text}];return NO;}
static NSDictionary *Declarations(void){
 static NSDictionary *declarations;static dispatch_once_t once;dispatch_once(&once,^{
  NSMutableDictionary *all=[NSMutableDictionary new];
  void(^add)(NSArray *,NSString *,NSString *,NSString *,NSString *,BOOL,NSString *,NSString *)=^(NSArray *names,NSString *effect,NSString *scope,NSString *tier,NSString *approval,BOOL foreground,NSString *module,NSString *availability){
   for(NSString *name in names)all[name]=@{@"name":name,@"description":[NSString stringWithFormat:@"%@ (%@; %@)",name,effect,scope],@"effect":effect,@"scope":scope,@"tier":tier,@"permissionTier":tier,@"approvalPolicy":approval,@"requiresUserApproval":@(![approval isEqual:@"none"]),@"requiresForeground":@(foreground),@"module":module,@"availability":availability};
  };
  add(@[@"read_development_guide",@"read_app_state"],@"read",@"app_public_state",@"A",@"none",NO,@"core",@"always");
  add(@[@"set_app_settings"],@"write",@"declared_app_preferences",@"A",@"existing",YES,@"core",@"always");
  add(@[@"app_action"],@"mixed",@"declared_app_actions",@"A",@"existing",NO,@"core",@"actions");
  add(@[@"list_projects"],@"read",@"local_project_index",@"A",@"none",NO,@"core",@"bridge");
  add(@[@"create_project",@"clone_project",@"select_project"],@"write",@"confirmed_workspace",@"A",@"existing",YES,@"core",@"bridge");
  add(@[@"list_files",@"read_file",@"search_text",@"list_symbols",@"read_project_config",@"git_status",@"git_diff",@"git_history"],@"read",@"current_project",@"A",@"none",NO,@"core",@"project");
  add(@[@"propose_patch",@"propose_config_change",@"propose_build_settings"],@"read",@"current_project_proposal",@"A",@"none",NO,@"core",@"project");
  add(@[@"apply_approved_patch",@"create_directory",@"create_file",@"request_delete",@"prepare_project",@"git_stage",@"git_save_version",@"git_download_updates",@"git_upload",@"download_file",@"extract_archive"],@"write",@"current_project",@"A",@"existing",NO,@"core",@"project");
  add(@[@"list_builds",@"read_diagnostics",@"list_artifacts"],@"read",@"current_project_builds",@"A",@"none",NO,@"core",@"projectBridge");
  add(@[@"clean_builds",@"cancel_build"],@"write",@"current_project_builds",@"A",@"existing",NO,@"core",@"projectBridge");
  add(@[@"build_project"],@"write",@"current_project_build",@"A",@"existing",NO,@"core",@"compiler");
  add(@[@"binary_inspect"],@"read",@"selected_staged_binary",@"A",@"none",NO,@"core",@"binary");
  add(@[@"classdump_export"],@"read",@"selected_staged_ipa_derived_output",@"A",@"none",NO,@"core",@"ipa");
  add(@[@"classdump_headers"],@"read",@"selected_local_headers",@"A",@"none",NO,@"core",@"headers");
  add(@[@"web_read",@"web_search",@"github_query"],@"read",@"public_web",@"A",@"none",NO,@"core",@"web");
  add(@[@"agent_skill_read"],@"read",@"project_or_bundled_skill_text",@"A",@"none",NO,@"skills",@"skills");
  add(@[@"web_browse"],@"read",@"ephemeral_public_web",@"A",@"none",YES,@"browser",@"browser");
  add(@[@"agent_memory_read"],@"read",@"project_or_local_MEMORY.md",@"A",@"none",NO,@"memory",@"always");
  add(@[@"agent_build_tasks"],@"read",@"current_project_tasks",@"A",@"none",NO,@"build_queue",@"projectBridge");
  add(@[@"read_attachment"],@"read",@"selected_attachment_or_live_directory_grant",@"B",@"none",NO,@"core",@"attachment");
  add(@[@"remote_workspace_status"],@"read",@"explicitly_enabled_remote_service",@"B",@"none",NO,@"remote",@"remote");
  add(@[@"flex_current_context"],@"read",@"paired_FLEX_selected_object",@"B",@"none",NO,@"core",@"flexContext");
  add(@[@"flex_live_read"],@"read",@"paired_FLEX_live_runtime",@"B",@"none",NO,@"core",@"flexLive");
  add(@[@"flex_sensitive_read"],@"read",@"paired_FLEX_sensitive_content",@"B",@"every_call",NO,@"core",@"flexLive");
  add(@[@"flex_control"],@"write",@"paired_FLEX_bounded_controls",@"B",@"every_call",NO,@"core",@"flexLive");
  add(@[@"target_app_metadata"],@"read",@"one_native_enrolled_app_Info.plist",@"C",@"every_call",YES,@"isolation",@"targetApp");
  add(@[@"own_plugin_logs"],@"read",@"one_native_enrolled_own_plugin_log",@"C",@"every_call",YES,@"isolation",@"pluginLog");
  declarations=all.copy;
 });return declarations;
}
static BOOL ActionAvailable(NSString *name,NSDictionary *context){
 if([name hasPrefix:@"git_"]&&![context[@"hasProject"] boolValue])return NO;
 if(([name hasPrefix:@"open_"]||[name isEqual:@"choose_attachment"])&&![context[@"foreground"] boolValue])return NO;
 if([@[@"session_info",@"session_rename",@"session_pin",@"list_session_files",@"read_session_file",@"open_model_controls",@"open_permissions",@"choose_attachment"] containsObject:name]&&![context[@"hasSession"] boolValue])return NO;
 return YES;
}
static BOOL Available(NSDictionary *entry,NSDictionary *c){
 if(!entry||![TFAIToolRegistry enabled:entry[@"module"]])return NO;
 // Browser confirmation does not satisfy the isolated tier's phone-native consent.
 if([entry[@"tier"] isEqual:@"C"]&&[c[@"remoteExecution"] boolValue])return NO;
 if([entry[@"requiresForeground"] boolValue]&&![c[@"foreground"] boolValue])return NO;
 NSString *check=entry[@"availability"];
 if([check isEqual:@"always"]||[check isEqual:@"actions"])return YES;
 if([check isEqual:@"bridge"])return [c[@"hasBridge"] boolValue];
 if([check isEqual:@"project"])return [c[@"hasProject"] boolValue];
 if([check isEqual:@"projectBridge"])return [c[@"hasProject"] boolValue]&&[c[@"hasBridge"] boolValue];
 if([check isEqual:@"compiler"])return [c[@"hasProject"] boolValue]&&[c[@"hasBridge"] boolValue]&&[c[@"compilerAvailable"] boolValue];
 if([check isEqual:@"binary"])return [c[@"binaryIDs"] count]>0;
 if([check isEqual:@"ipa"])return [c[@"ipaIDs"] count]>0;
 if([check isEqual:@"headers"])return [c[@"headerIDs"] count]>0;
 if([check isEqual:@"attachment"])return [c[@"attachmentIDs"] count]>0;
 if([check isEqual:@"web"])return [c[@"webEnabled"] boolValue];
 if([check isEqual:@"browser"])return [c[@"webEnabled"] boolValue]&&[c[@"browserAvailable"] boolValue];
 if([check isEqual:@"skills"])return [c[@"skillIDs"] count]>0;
 if([check isEqual:@"remote"])return [c[@"remoteAvailable"] boolValue];
 if([check isEqual:@"flexContext"])return [c[@"flexContextAvailable"] boolValue];
 if([check isEqual:@"flexLive"])return [c[@"flexLiveAvailable"] boolValue]&&([entry[@"effect"] isEqual:@"read"]||![c[@"readOnly"] boolValue]);
 if([entry[@"tier"] isEqual:@"C"]){if(![c[@"isolationEnabled"] boolValue]||[c[@"readOnly"] boolValue]||![c[@"hasApproval"] boolValue])return NO;return [c[[check isEqual:@"targetApp"]?@"targetAppIDs":@"pluginLogIDs"] count]>0;}
 return [check isEqual:@"mcp"]&&[c[@"mcpNames"] containsObject:entry[@"name"]];
}
static BOOL Validate(id value,NSDictionary *s,NSUInteger depth){
 if(![s isKindOfClass:NSDictionary.class]||depth>16)return depth<=16;
 NSString *type=[s[@"type"] isKindOfClass:NSString.class]?s[@"type"]:nil;
 if(s[@"enum"]&&[s[@"enum"] isKindOfClass:NSArray.class]&&![s[@"enum"] containsObject:value])return NO;
 BOOL number=[value isKindOfClass:NSNumber.class],boolean=number&&CFGetTypeID((__bridge CFTypeRef)value)==CFBooleanGetTypeID();
 if([type isEqual:@"string"]){if(![value isKindOfClass:NSString.class])return NO;if(s[@"minLength"]&&[value length]<[s[@"minLength"] unsignedIntegerValue])return NO;if(s[@"maxLength"]&&[value length]>[s[@"maxLength"] unsignedIntegerValue])return NO;}
 else if([type isEqual:@"boolean"]){if(!boolean)return NO;}
 else if([type isEqual:@"number"]||[type isEqual:@"integer"]){if(!number||boolean||!isfinite([value doubleValue])||([type isEqual:@"integer"]&&floor([value doubleValue])!=[value doubleValue]))return NO;if(s[@"minimum"]&&[value doubleValue]<[s[@"minimum"] doubleValue])return NO;if(s[@"maximum"]&&[value doubleValue]>[s[@"maximum"] doubleValue])return NO;}
 else if([type isEqual:@"array"]){if(![value isKindOfClass:NSArray.class])return NO;if(s[@"minItems"]&&[value count]<[s[@"minItems"] unsignedIntegerValue])return NO;if(s[@"maxItems"]&&[value count]>[s[@"maxItems"] unsignedIntegerValue])return NO;for(id item in value)if(!Validate(item,s[@"items"],depth+1))return NO;}
 else if([type isEqual:@"object"]){if(![value isKindOfClass:NSDictionary.class])return NO;if(s[@"minProperties"]&&[value count]<[s[@"minProperties"] unsignedIntegerValue])return NO;NSDictionary *props=[s[@"properties"] isKindOfClass:NSDictionary.class]?s[@"properties"]:@{};for(id key in s[@"required"])if(!value[key]||value[key]==NSNull.null)return NO;for(id key in value){if(![key isKindOfClass:NSString.class])return NO;if(!props[key]&&[s[@"additionalProperties"] isEqual:@NO])return NO;if(!Validate(value[key],props[key]?:([s[@"additionalProperties"] isKindOfClass:NSDictionary.class]?s[@"additionalProperties"]:nil),depth+1))return NO;}}
 return YES;
}
@implementation TFAIToolRegistry
+ (NSArray *)modules{return @[@"skills",@"mcp",@"browser",@"memory",@"build_queue",@"remote",@"isolation"];}
+ (BOOL)enabled:(NSString *)module{if([module isEqual:@"core"])return YES;if(![self.modules containsObject:module])return NO;id value=[NSUserDefaults.standardUserDefaults objectForKey:[@"Dylix.Tools.v1." stringByAppendingString:module]];return value?[value boolValue]:![@[@"isolation",@"remote"] containsObject:module];}
+ (void)setEnabled:(BOOL)enabled module:(NSString *)module{if(![self.modules containsObject:module])return;[NSUserDefaults.standardUserDefaults setBool:enabled forKey:[@"Dylix.Tools.v1." stringByAppendingString:module]];[NSNotificationCenter.defaultCenter postNotificationName:@"DylixToolRegistryChanged" object:module];}
+ (NSDictionary *)descriptor:(NSString *)name{return Declarations()[name];}
+ (NSArray *)entries:(NSArray *)schemas context:(NSDictionary *)context{
 NSMutableArray *out=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];
 for(id raw in schemas){if(![raw isKindOfClass:NSDictionary.class]||![raw[@"name"] isKindOfClass:NSString.class])continue;NSString *name=raw[@"name"];if([seen containsObject:name])continue;[seen addObject:name];NSMutableDictionary *entry=[Declarations()[name] mutableCopy];
  if(!entry&&[name hasPrefix:@"mcp_"]&&[context[@"mcpNames"] containsObject:name])entry=[@{@"name":name,@"effect":@"read",@"scope":@"user_allowed_HTTP_MCP_query",@"tier":@"A",@"permissionTier":@"A",@"approvalPolicy":@"none",@"requiresUserApproval":@NO,@"requiresForeground":@NO,@"module":@"mcp",@"availability":@"mcp"} mutableCopy];
  if(!Available(entry,context))continue;
  NSMutableDictionary *wire=[raw mutableCopy],*parameters=[raw[@"parameters"] mutableCopy];NSMutableDictionary *props=[parameters[@"properties"] mutableCopy];
  NSDictionary *ids=@{@"read_attachment":@[@"id",@"attachmentIDs"],@"binary_inspect":@[@"binary_id",@"binaryIDs"],@"classdump_export":@[@"input_id",@"ipaIDs"],@"classdump_headers":@[@"job_id",@"headerIDs"],@"agent_skill_read":@[@"id",@"skillIDs"],@"target_app_metadata":@[@"target_id",@"targetAppIDs"],@"own_plugin_logs":@[@"target_id",@"pluginLogIDs"]};
  if(ids[name]){NSArray *pair=ids[name];NSMutableDictionary *field=[props[pair[0]] mutableCopy]?:[NSMutableDictionary new];field[@"enum"]=context[pair[1]]?:@[];props[pair[0]]=field;}
  if([name isEqual:@"app_action"]){NSMutableDictionary *action=[props[@"action"] mutableCopy];NSMutableArray *names=[NSMutableArray new];for(NSString *value in action[@"enum"])if(ActionAvailable(value,context))[names addObject:value];if(!names.count)continue;action[@"enum"]=names;props[@"action"]=action;}
  if(props){parameters[@"properties"]=props;wire[@"parameters"]=parameters;}entry[@"description"]=[wire[@"description"] isKindOfClass:NSString.class]?wire[@"description"]:@"";entry[@"schema"]=wire.copy;[out addObject:entry.copy];
 }return out.copy;
}
+ (NSArray *)schemas:(NSArray *)schemas context:(NSDictionary *)context{NSMutableArray *out=[NSMutableArray new];for(NSDictionary *entry in [self entries:schemas context:context])[out addObject:entry[@"schema"]];return out.copy;}
+ (NSDictionary *)actionCatalog:(NSDictionary *)catalog context:(NSDictionary *)context{NSMutableDictionary *result=[catalog mutableCopy],*actions=[NSMutableDictionary new];for(NSString *name in catalog[@"actions"])if(ActionAvailable(name,context)){NSMutableDictionary *entry=[catalog[@"actions"][name] mutableCopy];entry[@"tier"]=@"A";entry[@"scope"]=[name hasPrefix:@"git_"]?@"current_project":@"declared_app_action";entry[@"requiresUserApproval"]=entry[@"mutates"]?:@NO;entry[@"requiresForeground"]=@([name hasPrefix:@"open_"]||[name isEqual:@"choose_attachment"]);actions[name]=entry;}result[@"actions"]=actions;return result;}
+ (BOOL)preflight:(NSDictionary *)call schemas:(NSArray *)schemas context:(NSDictionary *)context error:(NSError **)error{if(![call isKindOfClass:NSDictionary.class]||![call[@"name"] isKindOfClass:NSString.class]||![call[@"arguments"] isKindOfClass:NSDictionary.class])return Reject(error,@"工具名称或参数格式有误。");BOOL sent=NO;for(NSDictionary *schema in schemas)if([schema[@"name"] isEqual:call[@"name"]]){sent=Validate(call[@"arguments"],schema[@"parameters"],0);break;}if(!sent)return Reject(error,@"调用不属于本轮已下发的工具和授权ID。");for(NSDictionary *schema in [self schemas:schemas context:context])if([schema[@"name"] isEqual:call[@"name"]])return Validate(call[@"arguments"],schema[@"parameters"],0)?YES:Reject(error,@"参数与当前工具声明不一致，请核对类型、范围和已授权ID。");return Reject(error,@"当前设备、开关或授权范围未提供此工具，操作已停止。");}
@end
