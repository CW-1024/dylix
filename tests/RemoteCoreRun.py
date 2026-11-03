#!/usr/bin/env python3
import pathlib,subprocess,tempfile,shutil
openssl='/opt/homebrew/opt/openssl@3/bin/openssl' if pathlib.Path('/opt/homebrew/opt/openssl@3/bin/openssl').exists() else shutil.which('openssl')
root=pathlib.Path(__file__).resolve().parents[1]
sdk=pathlib.Path('/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk')
if not sdk.exists():sdk=pathlib.Path(subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip())
with tempfile.TemporaryDirectory(prefix='dylix-remote-core-') as folder:
 output=pathlib.Path(folder)/'test'
 subprocess.run(['xcrun','clang','-isysroot',str(sdk),'-fobjc-arc','-Wno-incompatible-pointer-types','-framework','Foundation','-framework','Network','-framework','Security',str(root/'tests/RemoteCoreTests.m'),str(root/'App/Remote/DXRemoteHTTP.m'),str(root/'App/Remote/DXRemoteAccess.m'),str(root/'App/Remote/DXRemoteTLS.m'),'-o',str(output)],check=True)
 cert=pathlib.Path(folder)/'cert.der'
 subprocess.run([str(output),str(cert)],check=True,timeout=30)
 pem=pathlib.Path(folder)/'cert.pem'
 subprocess.run([openssl,'x509','-inform','DER','-in',str(cert),'-out',str(pem)],check=True)
 subprocess.run([openssl,'verify','-CAfile',str(pem),'-purpose','sslserver','-verify_ip','127.0.0.1',str(pem)],check=True)
 invalid=subprocess.run([openssl,'verify','-CAfile',str(pem),'-verify_ip','127.0.0.2',str(pem)],capture_output=True)
 assert invalid.returncode!=0,'wrong IP must be rejected'
 print('PASS OpenSSL certificate signature, server purpose, correct SAN and wrong-SAN rejection')
