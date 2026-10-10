import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CLOCK = ROOT / "game/ReplicatedStorage/0049_ForestClock.luau"
SPEC = ROOT / "tests/luau/forest_clock_spec.luau"
LUAU = os.environ.get("LUAU") or shutil.which("luau")


@unittest.skipUnless(LUAU, "Luau CLI not found; put `luau` on PATH or set LUAU to run the HUD text tests")
class HudTextTests(unittest.TestCase):
    """Runs the shared HUD text helpers in a bare Luau VM. It does not render any UI."""

    def test_spec(self):
        script = "local C = (function()\n" + CLOCK.read_text() + "\nend)()\n" + SPEC.read_text()
        with tempfile.TemporaryDirectory() as folder:
            harness = Path(folder) / "harness.luau"
            harness.write_text(script)
            done = subprocess.run([LUAU, str(harness)], capture_output=True, text=True, cwd=folder)
        self.assertEqual(0, done.returncode, done.stdout + done.stderr)
        self.assertIn("all ForestClock tests passed", done.stdout)


if __name__ == "__main__":
    unittest.main()
