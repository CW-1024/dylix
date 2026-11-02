#!/usr/bin/env python3
"""Run real bundled LLVM14 ARM64 exception regression in a booted simulator.

Requires an Apple Silicon Mac and scripts/build.py --simulator. The negative
control intentionally crashes isolated helper processes; the app is untouched.
"""
import json
import pathlib
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]


def run(*args):
    return subprocess.check_output(list(map(str, args)), stderr=subprocess.STDOUT, text=True)


def main():
    app = ROOT / 'build/simulator/TheosMobileCompiler.app'
    source = (ROOT / 'App/main.m').read_text()
    assert '@"-mframe-pointer=non-leaf"' in source
    assert '@"-funwind-tables=1"' in source
    sdk = run('xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path').strip()
    with tempfile.TemporaryDirectory(prefix='dylix-unwind-regression-') as temporary:
        work = pathlib.Path(temporary)
        bundle = work / 'Tool.app'
        bundle.mkdir()
        (bundle / 'Frameworks').symlink_to(app / 'Frameworks', target_is_directory=True)
        helper = work / 'Tool.m'
        helper.write_text('''#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <ios_system/ios_system.h>
#import <dlfcn.h>
#import <pthread.h>
''' + source[source.index('static void TMCLog'):source.index('static NSString *projectPath')] + '''
int main(int argc,char **argv) { @autoreleasepool {
 NSArray *commands=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[NSString stringWithUTF8String:argv[1]]] options:0 error:nil];
 for(NSArray *args in commands) { int status=runTool(args,stdin,stdout);if(status)return status; } return 0;
} }
''')
        run('xcrun', '--sdk', 'iphonesimulator', 'clang', '-arch', 'x86_64',
            '-mios-simulator-version-min=15.0', '-fobjc-arc', '-framework', 'Foundation',
            '-framework', 'UIKit', '-F', app / 'Frameworks', '-framework', 'ios_system',
            '-Wl,-rpath,@executable_path/Frameworks', helper, '-o', bundle / 'Tool')
        run('codesign', '-f', '-s', '-', bundle / 'Tool')
        probe = work / 'Probe.mm'
        probe.write_text('''__attribute__((objc_root_class)) @interface NSObject
- (id)valueForKey:(id)key;
@end
extern "C" __attribute__((noinline)) int objc_probe(id obj) {
 @try { [obj valueForKey:@"DylixMissingKey"]; return 0; }
 @catch(id exception) { return 42; }
}
static volatile int cleaned;
struct Cleanup { ~Cleanup() { cleaned=1; } };
extern "C" __attribute__((noinline)) int cpp_probe() {
 cleaned=0; try { Cleanup c; throw 7; }
 catch(int value) { return value==7 && cleaned ? 42 : -1; }
}
''')
        runner = work / 'Runner.m'
        runner.write_text('''#import <Foundation/Foundation.h>
#import <dlfcn.h>
int main(int argc,char **argv) { @autoreleasepool {
 void *handle=dlopen(argv[1],RTLD_NOW); if(!handle){fprintf(stderr,"%s",dlerror());return 2;}
 int result;
 if(argc>2){int(*probe)(void)=dlsym(handle,"cpp_probe");if(!probe)return 3;result=probe();}
 else {int(*probe)(id)=dlsym(handle,"objc_probe");if(!probe)return 3;result=probe([NSObject new]);}
 printf("CATCH_RESULT=%d\\n",result);return result==42?0:4;
} }
''')
        run('xcrun', '--sdk', 'iphonesimulator', 'clang', '-arch', 'arm64',
            '-mios-simulator-version-min=15.0', '-fobjc-arc', '-framework', 'Foundation',
            runner, '-o', work / 'Runner')
        run('codesign', '-f', '-s', '-', work / 'Runner')
        results = {}
        for variant, flags in [('before', []), ('after', ['-mframe-pointer=non-leaf', '-funwind-tables=1'])]:
            obj, dylib = work / (variant + '.o'), work / (variant + '.dylib')
            commands = [
                ['clang', '-cc1', '-triple', 'arm64-apple-ios15.0-simulator', '-emit-obj',
                 '-target-cpu', 'apple-a7', '-target-abi', 'darwinpcs', '-mrelocation-model',
                 'pic', '-pic-level', '2', '-fobjc-runtime=ios-15.0', '-fobjc-arc',
                 '-fobjc-exceptions', '-fcxx-exceptions', '-fexceptions', '-std=gnu++17',
                 '-O2'] + flags + ['-x', 'objective-c++', str(probe), '-o', str(obj)],
                ['ld64.lld', '-dylib', '-arch', 'arm64', '-platform_version', 'ios-simulator',
                 '15.0', '18.2', '-syslibroot', sdk, '-lSystem', '-lobjc', '-lc++',
                 '-framework', 'Foundation', str(obj), '-o', str(dylib)],
            ]
            command_file = work / 'commands.json'
            command_file.write_text(json.dumps(commands))
            run('xcrun', 'simctl', 'spawn', 'booted', bundle / 'Tool', command_file)
            run('codesign', '-f', '-s', '-', dylib)
            results[variant] = {}
            for mode in ['objc', 'cpp']:
                process = subprocess.run(['xcrun', 'simctl', 'spawn', 'booted', str(work / 'Runner'),
                                          str(dylib)] + (['cpp'] if mode == 'cpp' else []),
                                         capture_output=True, text=True, timeout=30)
                results[variant][mode] = {'exit': process.returncode, 'output': process.stdout + process.stderr}
                if variant == 'after':
                    assert process.returncode == 0 and 'CATCH_RESULT=42' in process.stdout, results
                else:
                    assert process.returncode in [134, 139], results
        print(json.dumps(results, indent=2))


if __name__ == '__main__':
    main()
