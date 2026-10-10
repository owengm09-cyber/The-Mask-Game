import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CORE = ROOT / "game/ServerScriptService/0058_ReadyQueueCore.luau"
SPEC = ROOT / "tests/luau/ready_queue_core_spec.luau"
LUAU = os.environ.get("LUAU") or shutil.which("luau")


@unittest.skipUnless(LUAU, "Luau CLI not found; put `luau` on PATH or set LUAU to run the ReadyQueueCore tests")
class ReadyQueueCoreTests(unittest.TestCase):
    """Runs the pure arrival-queue planner in a bare Luau VM. It does not exercise Roblox services."""

    def test_spec(self):
        script = "local Q = (function()\n" + CORE.read_text() + "\nend)()\n" + SPEC.read_text()
        with tempfile.TemporaryDirectory() as folder:
            harness = Path(folder) / "harness.luau"
            harness.write_text(script)
            done = subprocess.run([LUAU, str(harness)], capture_output=True, text=True, cwd=folder)
        self.assertEqual(0, done.returncode, done.stdout + done.stderr)
        self.assertIn("all ReadyQueueCore tests passed", done.stdout)


if __name__ == "__main__":
    unittest.main()
