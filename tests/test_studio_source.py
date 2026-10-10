import gzip
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from tools import studio_source as tool

FIXTURE = b'''<roblox version="4"><Item class="Workspace" referent="W"><Properties><string name="Name">Workspace</string><BinaryString name="UnrecognizedTerrainProperty">AAEC</BinaryString></Properties><Item class="Script" referent="A"><Properties><string name="Name">Same</string><bool name="Disabled">true</bool><ProtectedString name="Source"><![CDATA[print("original")]]></ProtectedString></Properties></Item><Item class="Script" referent="B"><Properties><string name="Name">Same</string><ProtectedString name="Source"/></Properties></Item></Item></roblox>'''


class SourceWorkflowTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.patcher = patch.multiple(tool, ROOT=self.root, BASE=self.root / "studio/base.rbxlx.gz", MANIFEST=self.root / "studio/scripts.json")
        self.patcher.start()
        self.input = self.root / "input.rbxlx"
        self.input.write_bytes(FIXTURE)
        tool.export(self.input)
        self.manifest = json.loads(tool.MANIFEST.read_text())

    def tearDown(self):
        self.patcher.stop()
        self.temp.cleanup()

    def test_unchanged_build_is_byte_identical(self):
        output = self.root / "result.rbxlx"
        tool.build(output)
        self.assertEqual(FIXTURE, output.read_bytes())

    def test_duplicate_names_empty_source_and_special_characters(self):
        entries = self.manifest["scripts"]
        self.assertNotEqual(entries[0]["file"], entries[1]["file"])
        source = '-- Unicode: café\nprint("<& ]]> ")\n'
        (self.root / entries[1]["file"]).write_bytes(source.encode())
        output = self.root / "changed.rbxlx"
        tool.build(output)
        expected = FIXTURE.replace(b'<ProtectedString name="Source"/>', ('<ProtectedString name="Source">' + tool.escape(source) + '</ProtectedString>').encode())
        self.assertEqual(expected, output.read_bytes())

    def test_refuses_existing_output(self):
        with self.assertRaisesRegex(ValueError, "Output exists"):
            tool.build(self.input)
        self.assertEqual(FIXTURE, self.input.read_bytes())

    def test_refuses_base_tampering(self):
        tool.BASE.write_bytes(gzip.compress(FIXTURE + b" "))
        with self.assertRaisesRegex(ValueError, "hash mismatch"):
            tool.build()

    def test_refuses_unmapped_new_source(self):
        (self.root / "game/new.luau").write_text("return 1")
        with self.assertRaisesRegex(ValueError, "added, removed or renamed"):
            tool.build()


if __name__ == "__main__":
    unittest.main()
