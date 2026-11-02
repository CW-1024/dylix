#!/usr/bin/env python3
"""Build REipa's in-process static library. Requires Rust and Apple target std."""
import argparse, os, pathlib, shutil, subprocess
root=pathlib.Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--platform',choices=['device','simulator','macos'],default='device');a=p.parse_args()
env=os.environ.copy()
cargo=shutil.which('cargo') or str(pathlib.Path(env.get('CARGO_HOME','~/.cargo')).expanduser()/'bin/cargo')
target={'device':'aarch64-apple-ios','simulator':'x86_64-apple-ios','macos':'aarch64-apple-darwin'}[a.platform]
out=root/'build'/('classdump-'+a.platform);out.mkdir(parents=True,exist_ok=True)
output=out/'libtweakforge_classdump.a'
rust_inputs=[path for path in (root/'Vendor/REipa').rglob('*') if path.is_file() and 'target' not in path.parts and (path.suffix=='.rs' or path.name in ('Cargo.toml','Cargo.lock','build.rs'))]
if output.exists() and rust_inputs and output.stat().st_mtime>=max(path.stat().st_mtime for path in rust_inputs):
 print(output);raise SystemExit(0)
env['PATH']=str(pathlib.Path(cargo).parent)+os.pathsep+env.get('PATH','');env['IPHONEOS_DEPLOYMENT_TARGET']='15.0'
subprocess.run([cargo,'+stable','build','--manifest-path',str(root/'Vendor/REipa/Cargo.toml'),'--package','tweakforge-classdump','--locked','--release','--target',target],env=env,check=True)
shutil.copy2(root/'Vendor/REipa/target'/target/'release/libtweakforge_classdump.a',out/'libtweakforge_classdump.a')
print(out/'libtweakforge_classdump.a')
