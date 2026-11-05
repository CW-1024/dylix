from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
sdk='/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk'
with tempfile.TemporaryDirectory(prefix='dylix-registry164-') as d:
 p=Path(d);exe=p/'tests'
 files=['tests/ToolRegistryTests.m','App/AI/Registry/TFAIToolRegistry.m','App/AI/Registry/TFAIToolIsolation.m']
 subprocess.run(['xcrun','clang','-isysroot',sdk,'-fobjc-arc','-fblocks',*[str(root/f) for f in files],'-framework','Foundation','-o',str(exe)],check=True)
 subprocess.run([str(exe),str(p/'fixtures')],check=True)
