from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
sdk=Path('/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk')
sdk=str(sdk) if sdk.exists() else subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
with tempfile.TemporaryDirectory(prefix='dylix-persona-') as folder:
 p=Path(folder);exe=p/'test'
 subprocess.run(['xcrun','clang','-isysroot',sdk,'-fobjc-arc','-fblocks',str(root/'tests/PersonaBuiltinsTests.m'),str(root/'App/AI/Persona/TFAIPersona.m'),'-framework','Foundation','-o',str(exe)],check=True)
 for phase in ['core','relaunch']:subprocess.run([str(exe),str(p/'state/personas.json'),str(root/'Resources/Personas/Builtins.json'),phase],check=True,timeout=20)
