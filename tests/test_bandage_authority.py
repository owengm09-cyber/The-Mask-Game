import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "game/ServerStorage/0154_Script.server.luau"
SPEC = ROOT / "tests/luau/bandage_spec.luau"
LUAU = os.environ.get("LUAU") or shutil.which("luau")


@unittest.skipUnless(LUAU, "Luau CLI not found; put `luau` on PATH or set LUAU to run the Bandage tests")
class BandageAuthorityTests(unittest.TestCase):
    """Runs the shipped Bandage server script against fake Roblox objects. It does not test real replication."""

    def test_spec(self):
        script = "local function run(script, os, game, workspace)\n" + SCRIPT.read_text() + "\nend\n" + SPEC.read_text()
        with tempfile.TemporaryDirectory() as folder:
            harness = Path(folder) / "harness.luau"
            harness.write_text(script)
            done = subprocess.run([LUAU, str(harness)], capture_output=True, text=True, cwd=folder)
        self.assertEqual(0, done.returncode, done.stdout + done.stderr)
        self.assertIn("all bandage tests passed", done.stdout)


if __name__ == "__main__":
    unittest.main()
