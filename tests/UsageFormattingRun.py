from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='dylix-token-format-') as tmp:
    exe=Path(tmp)/'tests'
    subprocess.run(['xcrun','clang','-isysroot','/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk','-fobjc-arc',str(root/'tests/UsageFormattingTests.m'),'-framework','Foundation','-o',str(exe)],check=True)
    subprocess.run([str(exe)],check=True)
