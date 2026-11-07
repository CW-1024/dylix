#!/usr/bin/env python3
"""Exercise production verifier without adding signatures to the fixture afterward."""
from pathlib import Path
import subprocess, tempfile
ROOT=Path(__file__).resolve().parents[1]
def run(*args): subprocess.run([str(a) for a in args],check=True)
with tempfile.TemporaryDirectory(prefix='dylix-signature-') as tmp:
    d=Path(tmp); source=d/'Fixture.c';source.write_text('int fixture(void){return 42;}\n')
    run('xcrun','clang','-isysroot','/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk','-fobjc-arc','-framework','Foundation',ROOT/'tests/DylibSignatureTests.m','-o',d/'Tests')
    for signed in [True,False]:
        output=d/('signed.dylib' if signed else 'unsigned.dylib')
        run('xcrun','--sdk','iphoneos','clang','-arch','arm64','-miphoneos-version-min=15.0','-dynamiclib',source,'-Wl,-adhoc_codesign' if signed else '-Wl,-no_adhoc_codesign','-o',output)
    run('codesign','--verify','--strict',d/'signed.dylib')
    run(d/'Tests',d/'signed.dylib',d/'unsigned.dylib')
