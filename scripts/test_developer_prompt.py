#!/usr/bin/env python3
import pathlib,tempfile,subprocess
root=pathlib.Path(__file__).resolve().parents[1]
sdk=pathlib.Path('/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk')
sdk=str(sdk) if sdk.exists() else subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
with tempfile.TemporaryDirectory(prefix='tf-prompt-tests-') as directory:
 exe=str(pathlib.Path(directory)/'prompt-tests')
 subprocess.run(['xcrun','clang','-isysroot',sdk,'-fobjc-arc','-fmodules','-framework','Foundation',str(root/'tests/DeveloperPromptTests.m'),'-o',exe],check=True)
 subprocess.run([exe],check=True)
