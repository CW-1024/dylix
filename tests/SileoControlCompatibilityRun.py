#!/usr/bin/env python3
"""Test-only: run the upstream Sileo C parser against dpkg-deb --field output.
Usage: python3 tests/SileoControlCompatibilityRun.py /path/to/Sileo-roothide package.deb ...
Upstream is compiled in place; no upstream implementation is copied into Dylix.
"""
import json, subprocess, sys, tempfile
from pathlib import Path
source=Path(sys.argv[1])/'Sileo/Backend/Control File Parser'
assert (source/'ControlFileParserFast.c').is_file()
with tempfile.TemporaryDirectory(prefix='dylix-sileo-control-') as temp:
    temp=Path(temp)
    (temp/'main.m').write_text('''#import <Foundation/Foundation.h>
#import "ControlFileParserFast.h"
int main(int argc, char **argv) { @autoreleasepool {
    for (int i=1;i<argc;i++) {
        NSData *data=[NSData dataWithContentsOfFile:@(argv[i])];
        NSMutableDictionary *fields=[NSMutableDictionary new];
        parseControlFile(data.bytes,data.length,true,^(const char *key,const char *value){fields[@(key)]=@(value);},^(int tags){});
        if (![fields[@"package"] length] || ![fields[@"version"] length] || ![fields[@"architecture"] isEqual:@"iphoneos-arm64e"]) return 1;
        printf("PASS Sileo upstream control parser: %s (%s)\\n",[fields[@"package"] UTF8String],[fields[@"architecture"] UTF8String]);
    }
    return 0;
} }''')
    exe=temp/'check'
    subprocess.run(['xcrun','clang','-isysroot','/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk','-fblocks','-fobjc-arc',str(temp/'main.m'),'-I',str(source),'-x','objective-c',str(source/'ControlFileParserFast.c'),'-framework','Foundation','-o',str(exe)],check=True)
    files=[]
    for i,path in enumerate(sys.argv[2:]):
        result=subprocess.run(['dpkg-deb','--field',path],capture_output=True,check=True)
        p=temp/(str(i)+'.control');p.write_bytes(result.stdout);files.append(p)
    assert files,'Provide a DEB'
    subprocess.run([str(exe),*map(str,files)],check=True)
