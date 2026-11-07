from pathlib import Path
import subprocess, tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="dylix-preflight-") as directory:
    binary = Path(directory) / "tests"
    sources = ["tests/ToolPreflightTests.m", "App/AI/Registry/TFAIToolRegistry.m",
               "App/AI/Core/TFAIContextProjection.m", "App/AI/Providers/TFAIRegistry.m", "App/AI/UI/TFAIActivity.m"]
    subprocess.run(["xcrun", "clang", "-isysroot", "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk",
                    "-fobjc-arc", "-fblocks", *[str(root / file) for file in sources],
                    "-framework", "Foundation", "-o", str(binary)], check=True)
    subprocess.run([str(binary)], check=True, timeout=60)
