import os
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='dylix-registry-runtime164-') as d:
 p=Path(d);(p/'UIKit').mkdir();(p/'UIKit/UIKit.h').write_text('#import <Foundation/Foundation.h>\n@class UIViewController;\nextern NSString *UIApplicationDidEnterBackgroundNotification;\n');(p/'WebKit').mkdir();(p/'WebKit/WebKit.h').write_text('#import <Foundation/Foundation.h>\n@class WKWebView;\n');exe=p/'tests'
 files=['tests/ToolRegistryRuntimeTests.m','App/AI/Registry/TFAIToolRegistry.m','App/AI/Persona/TFAIPersona.m','App/AI/Core/TFAIRecovery.m','App/AI/Usage/TFAIUsageStore.m','App/AI/Providers/TFAIRegistry.m','App/AI/Core/TFAIContextProjection.m','App/Remote/DXFlexBridge.m']
 subprocess.run(['xcrun','clang','-isysroot','/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk','-I'+str(p),'-fobjc-arc','-fblocks','-Wno-incomplete-implementation',*[str(root/f) for f in files],'-framework','Foundation','-o',str(exe)],check=True)
 subprocess.run([str(exe)],env={**os.environ,"DYLIX_USAGE_TEST_DIRECTORY":str(exe.parent/"usage")},check=True,timeout=30)
