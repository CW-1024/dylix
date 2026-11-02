// Uses the bundled Mach-O linker. No external strip executable is required on iOS.
static BOOL TMCProcessReleaseSymbols(NSArray *link,NSString *relative,NSString *scheme,NSString *build,FILE *input,FILE *log,NSMutableDictionary *indexes,NSMutableArray *records,NSError **error){
 NSString *path=[build stringByAppendingPathComponent:relative];NSData *full=[NSData dataWithContentsOfFile:path options:0 error:error];if(!full)return NO;
 NSString *debugRelative=[NSString stringWithFormat:@"DebugSymbols/%@-%@",scheme,relative.lastPathComponent];NSString *debugPath=[build stringByAppendingPathComponent:debugRelative];
 if(![NSFileManager.defaultManager createDirectoryAtPath:debugPath.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:error]||![full writeToFile:debugPath options:NSDataWritingAtomic error:error])return NO;
 NSString *temporary=[path stringByAppendingString:@".release-tmp"];
 NSMutableArray *releaseLink=[link mutableCopy];NSUInteger output=[releaseLink indexOfObject:@"-o"];
 if(output==NSNotFound||output+1>=releaseLink.count)return NO;
 releaseLink[output+1]=temporary;[releaseLink addObjectsFromArray:@[@"-S"]];
 TMCLog(log,"发布符号裁剪：保留完整副本 %s\n$ %s\n",debugRelative.UTF8String,[releaseLink componentsJoinedByString:@" "].UTF8String);
 int status=runTool(releaseLink,input,log);
 NSData *small=status?nil:[NSData dataWithContentsOfFile:temporary options:0 error:error];
 NSMutableDictionary *index=small?[TFReleaseSymbolIndex(full,small,error) mutableCopy]:nil;
 [NSFileManager.defaultManager removeItemAtPath:temporary error:nil];
 if(!index){if(error&&!*error)*error=[NSError errorWithDomain:@"Dylix.Symbols" code:status?:1 userInfo:@{NSLocalizedDescriptionKey:@"发布符号裁剪失败，完整调试副本已保留；本次停止导出和打包。"}];return NO;}
 if(small.length>full.length){if(error)*error=[NSError errorWithDomain:@"Dylix.Symbols" code:1 userInfo:@{NSLocalizedDescriptionKey:@"裁剪副本异常增大，已停止打包并保留完整副本。"}];return NO;}
 if(![small writeToFile:path options:NSDataWritingAtomic error:error])return NO;
 index[@"debugFile"]=debugRelative;indexes[relative]=index;
 [records addObject:@{@"file":relative,@"scheme":scheme,@"debugFile":debugRelative,@"beforeBytes":@(full.length),@"afterBytes":@(small.length),@"savedBytes":@(full.length-small.length),@"uuid":index[@"uuid"],@"debugUUID":index[@"debugUUID"],@"sha256":index[@"sha256"],@"debugSHA256":index[@"debugSHA256"],@"runtimeSectionsVerified":@YES}];
 TMCLog(log,"发布符号裁剪完成：%lu → %lu 字节；代码、数据、异常展开段验证一致\n",(unsigned long)full.length,(unsigned long)small.length);return YES;
}
