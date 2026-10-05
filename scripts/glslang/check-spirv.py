"""Check that the smoke test emitted a SPIR-V 1.0 library exporting the requested helper."""

import struct
import sys
from pathlib import Path

blob = Path(sys.argv[1]).read_bytes()
assert len(blob) >= 20 and len(blob) % 4 == 0, "Malformed SPIR-V size"
words = struct.unpack(f"<{len(blob) // 4}I", blob)
assert words[:2] == (0x07230203, 0x00010000), "Expected SPIR-V 1.0"
assert words[4] == 0, "Invalid reserved word"
instructions = []
pos = 5
while pos < len(words):
    count, opcode = words[pos] >> 16, words[pos] & 0xFFFF
    assert count > 0 and pos + count <= len(words), "Malformed instruction"
    instructions.append((opcode, words[pos + 1 : pos + count]))
    pos += count
assert not any(op == 15 for op, _ in instructions), "Library must not have an OpEntryPoint"
assert any(op == 17 and args == (5,) for op, args in instructions), "Missing Linkage capability"
assert any(op == 71 and args[1:] == (11, 26) for op, args in instructions), "Missing WorkgroupId builtin"
exports = []
for op, args in instructions:
    if op == 71 and len(args) >= 4 and args[1] == 41 and args[-1] == 0:
        name_bytes = struct.pack(f"<{len(args) - 3}I", *args[2:-1])
        exports.append(name_bytes.split(b"\0", 1)[0].decode())
assert "get_work_group_id" in exports, f"Missing helper export: {exports}"
print(f"PASS: {len(blob)} bytes, SPIR-V 1.0, Linkage, WorkgroupId, no entry point, exports={exports}")
