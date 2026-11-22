#!/usr/bin/env python3
"""Verify Android ABI, SONAME, dynamic dependencies and 16 KB ELF alignment."""
from pathlib import Path
import re
import subprocess
import sys

lib_dir, ndk = map(Path, sys.argv[1:3])
readelf = ndk / "toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-readelf"
if not readelf.is_file():
    sys.exit(f"Missing NDK llvm-readelf: {readelf}")

def inspect(path, arg):
    return subprocess.check_output([str(readelf), arg, str(path)], text=True)

shipped = {p.name for p in lib_dir.glob("*.so") if p.is_file()}
expected = {"libfluidsynth.so", "libc++_shared.so"}
if shipped != expected:
    sys.exit(f"Unexpected library set: {shipped}; expected {expected}")
system = {"libc.so", "libm.so", "libdl.so", "liblog.so", "libandroid.so", "libz.so"}

for name in sorted(shipped):
    path = lib_dir / name
    header = inspect(path, "-h")
    if "AArch64" not in header or "ELF64" not in header:
        sys.exit(f"{name}: expected ELF64/AArch64")
    dynamic = inspect(path, "-d")
    soname = re.search(r"\(SONAME\).*?\[([^\]]+)\]", dynamic)
    if not soname or soname.group(1) != name:
        sys.exit(f"{name}: incorrect or missing SONAME: {soname}")
    if re.search(r"\((?:RPATH|RUNPATH|TEXTREL)\)", dynamic):
        sys.exit(f"{name}: forbidden RPATH/RUNPATH/TEXTREL")
    needed = re.findall(r"\(NEEDED\).*?\[([^\]]+)\]", dynamic)
    if not needed:
        sys.exit(f"{name}: could not parse DT_NEEDED")
    unexpected = set(needed) - shipped - system
    if unexpected:
        sys.exit(f"{name}: unresolved DT_NEEDED: {sorted(unexpected)}")
    program = inspect(path, "-l")
    load_lines = [line for line in program.splitlines()
                  if line.lstrip().startswith("LOAD ")]
    if not load_lines:
        sys.exit(f"{name}: no PT_LOAD segments")
    aligns = [int(line.split()[-1], 0) for line in load_lines]
    if any(a < 16384 for a in aligns):
        sys.exit(f"{name}: PT_LOAD alignment less than 16 KB: {aligns}")
    print(f"PASS {name}: NEEDED={needed}, PT_LOAD align={aligns}")

symbols = inspect(lib_dir / "libfluidsynth.so", "--dyn-syms")
if "fluid_synth_write_float" not in symbols:
    sys.exit("Missing fluid_synth_write_float C API export")
print("PASS: exported float PCM API")
