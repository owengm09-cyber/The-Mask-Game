"""Lossless source-only workflow for a native Studio XML snapshot (Python 3.10+)."""
import argparse
import gzip
import hashlib
import json
import re
from pathlib import Path
from xml.parsers import expat
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "studio/base.rbxlx.gz"
MANIFEST = ROOT / "studio/scripts.json"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def inspect(data):
    parser = expat.ParserCreate()
    stack, records, hierarchy = [], [], []
    prop = None
    chunks = []
    source_start = None

    def start(tag, attrs):
        nonlocal prop, chunks, source_start
        if tag == "Item":
            parent = stack[-1] if stack else None
            node = {"class": attrs["class"], "referent": attrs.get("referent"), "parent": parent, "name": "", "properties": {}}
            stack.append(node)
            hierarchy.append(node)
        elif stack and "name" in attrs:
            prop = attrs["name"]
            chunks = []
            if prop == "Source":
                source_start = parser.CurrentByteIndex

    def chars(value):
        if prop in ("Name", "Source", "Disabled", "RunContext", "LinkedSource"):
            chunks.append(value)

    def end(tag):
        nonlocal prop, source_start
        if tag == "Item":
            node = stack.pop()
            if node["class"] in ("Script", "LocalScript", "ModuleScript"):
                records.append(node)
        elif prop and stack:
            value = "".join(chunks)
            if prop == "Name":
                stack[-1]["name"] = value
            elif prop == "Source":
                opening_end = data.find(b">", source_start) + 1
                end_index = opening_end if data[source_start:opening_end].rstrip().endswith(b"/>") else data.find(b">", parser.CurrentByteIndex) + 1
                stack[-1].update(source=value, span=(source_start, end_index))
            elif prop in ("Disabled", "RunContext", "LinkedSource"):
                stack[-1]["properties"][prop] = value
            prop = None

    parser.StartElementHandler = start
    parser.EndElementHandler = end
    parser.CharacterDataHandler = chars
    parser.Parse(data, True)

    def path(node):
        parts = []
        while node:
            parts.append(node["name"])
            node = node["parent"]
        return list(reversed(parts))

    return records, [{"referent": n["referent"], "class": n["class"], "path": path(n)} for n in hierarchy], path


def export(input_path):
    if MANIFEST.exists():
        raise SystemExit("Export already exists; use a fresh checkout to avoid overwriting edits.")
    data = Path(input_path).read_bytes()
    records, hierarchy, path = inspect(data)
    BASE.parent.mkdir(parents=True, exist_ok=True)
    BASE.write_bytes(gzip.compress(data, compresslevel=9, mtime=0))
    entries = []
    for i, record in enumerate(records, 1):
        if "source" not in record:
            raise ValueError(f"Missing source: {path(record)}")
        names = path(record)
        safe = re.sub(r"[^A-Za-z0-9_.-]", "_", record["name"])[:80] or "unnamed"
        suffix = {"Script": ".server.luau", "LocalScript": ".client.luau", "ModuleScript": ".luau"}[record["class"]]
        file = f"game/{names[0]}/{i:04d}_{safe}{suffix}"
        payload = record["source"].encode("utf-8")
        target = ROOT / file
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(payload)
        entries.append({"file": file, "path": names, "referent": record["referent"], "class": record["class"], "properties": record["properties"], "sha256": digest(payload)})
    MANIFEST.write_text(json.dumps({"base_sha256": digest(data), "scripts": entries}, indent=2), encoding="utf-8")
    (BASE.parent / "hierarchy.json").write_text(json.dumps(hierarchy, separators=(",", ":")), encoding="utf-8")
    print(f"Exported {len(entries)} scripts; {len(hierarchy)} instances; compressed base {BASE.stat().st_size:,} bytes")


def build(output=None):
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    data = gzip.decompress(BASE.read_bytes())
    if digest(data) != manifest["base_sha256"]:
        raise ValueError("Base snapshot hash mismatch")
    records, _, path = inspect(data)
    by_ref = {r["referent"]: r for r in records}
    if len(records) != len(manifest["scripts"]):
        raise ValueError("Script count mismatch")
    if len(by_ref) != len(records) or {e["referent"] for e in manifest["scripts"]} != set(by_ref):
        raise ValueError("Duplicate or missing script identity")
    expected = {e["file"] for e in manifest["scripts"]}
    actual = {p.relative_to(ROOT).as_posix() for p in (ROOT / "game").rglob("*.luau")}
    if expected != actual:
        raise ValueError("Source files added, removed or renamed; this workflow only supports existing scripts")
    edits = []
    for entry in manifest["scripts"]:
        record = by_ref[entry["referent"]]
        if path(record) != entry["path"] or record["class"] != entry["class"]:
            raise ValueError("Script identity mismatch")
        if digest(record["source"].encode("utf-8")) != entry["sha256"]:
            raise ValueError("Original source hash mismatch")
        source_file = (ROOT / entry["file"]).resolve()
        if not source_file.is_relative_to(ROOT):
            raise ValueError("Source path outside repository")
        current = source_file.read_bytes().decode("utf-8")
        if current != record["source"]:
            replacement = ('<ProtectedString name="Source">' + escape(current) + '</ProtectedString>').encode("utf-8")
            edits.append((*record["span"], replacement))
    pieces, cursor = [], 0
    for start, end, replacement in sorted(edits):
        pieces.extend((data[cursor:start], replacement))
        cursor = end
    pieces.append(data[cursor:])
    result = b"".join(pieces)
    checked, _, _ = inspect(result)
    final = {r["referent"]: r["source"] for r in checked}
    for entry in manifest["scripts"]:
        if final[entry["referent"]] != (ROOT / entry["file"]).read_bytes().decode("utf-8"):
            raise ValueError("Built source roundtrip failed")
    if output:
        target = Path(output).resolve()
        if target.exists():
            raise ValueError("Output exists; choose a new filename")
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(result)
    print(f"Validated {len(records)} scripts; {len(edits)} changed. All bytes outside changed Source elements preserved.")


if __name__ == "__main__":
    cli = argparse.ArgumentParser(description=__doc__)
    commands = cli.add_subparsers(dest="command", required=True)
    commands.add_parser("export").add_argument("input")
    commands.add_parser("validate")
    commands.add_parser("build").add_argument("output")
    args = cli.parse_args()
    if args.command == "export":
        export(args.input)
    else:
        build(args.output if args.command == "build" else None)
