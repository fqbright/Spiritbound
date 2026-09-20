#!/usr/bin/env python3
"""Print where the bytes in an exported Godot .pck actually go.

Usage: python3 Godot/tools/pck_audit.py Godot/build/ios/Spiritbound.pck

Grouping is by extension and by directory, so a size question ("is it art or audio?") is
answered from the shipped artifact rather than from the source tree. The two differ: Godot
re-imports every asset and packs the *imported* form, so the bytes in the .pck are not the bytes
in `assets/`. Wrote this after a guess about the source tree produced a wrong conclusion --
see Docs/STORE_SUBMISSION.md section 1.1.
"""
import struct, sys, collections, os

path = sys.argv[1]
data = open(path, 'rb').read()
n = len(data)
assert data[:4] == b'GDPC', "not a Godot .pck"
ver = struct.unpack('<iii', data[4:16])
flags = struct.unpack('<I', data[16:20])[0]
print(f"pack format {ver[0]}.{ver[1]}.{ver[2]}  flags={flags:#x}  size={n:,}")

# In Godot 4.4+ the file directory is written as a footer: walk backwards from EOF. Each entry is
# u32 path_len | path bytes (NUL-terminated) | u64 offset | u64 size | 16 md5 | u32 flags.
end = n
entries = []
while True:
    start = None
    for p in range(end - 4, max(end - 400, 0), -1):
        ln = struct.unpack('<I', data[p:p + 4])[0]
        if ln == 0 or ln > 300:
            continue
        if p + 4 + ln != end - 36:
            continue
        chunk = data[p + 4:p + 4 + ln]
        if b'.' in chunk and all(c == 0 or 32 <= c < 127 for c in chunk):
            start = p
            break
    if start is None:
        break
    ln = struct.unpack('<I', data[start:start + 4])[0]
    # The path field is NUL-padded to a 4-byte boundary. Leaving the padding on turned one
    # extension into several in the table below (`ctex`, `ctex `, `ctex  ` ...), which reads as a
    # broken parser rather than as padding -- it did, and it cost a wrong conclusion about missing
    # files. Stripped here.
    name = data[start + 4:start + 4 + ln].decode().rstrip('\x00')
    off, size = struct.unpack('<QQ', data[start + 4 + ln:start + 4 + ln + 16])
    entries.append((name, off, size))
    end = start

entries.reverse()
print(f"directory starts at {end}, {len(entries)} entries")

tot = sum(s for _, _, s in entries)
print(f"sum of declared sizes: {tot:,} bytes ({tot / 1048576:.1f} MiB)")

by_ext = collections.Counter()
by_dir = collections.Counter()
for name, off, size in entries:
    ext = name.rsplit('.', 1)[-1] if '.' in name else '(none)'
    by_ext[ext] += size
    parts = name.split('/')
    key = '/'.join(parts[:3]) if len(parts) > 3 else '/'.join(parts[:-1])
    by_dir[key] += size

print("\n=== by extension ===")
for ext, s in by_ext.most_common():
    print(f"{ext:>12}  {s / 1048576:8.2f} MiB  {100 * s / tot:5.1f}%")

print("\n=== by directory (top 40) ===")
for d, s in by_dir.most_common(40):
    print(f"{d:>52}  {s / 1048576:8.2f} MiB  {100 * s / tot:5.1f}%")

print("\n=== 25 biggest files ===")
for name, off, size in sorted(entries, key=lambda e: -e[2])[:25]:
    print(f"{size / 1024:9.1f} KB  {name}")

print("\n=== top-level groups outside assets/ ===")
others = collections.Counter()
for name, off, size in entries:
    if not name.startswith('assets/'):
        top = name.split('/')[0] if '/' in name else '(root file)'
        others[top] += size
for d, s in others.most_common(30):
    print(f"{d:>40}  {s / 1048576:8.2f} MiB")
