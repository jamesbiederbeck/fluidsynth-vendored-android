#!/usr/bin/env bash
# Cross-compile Android/arm64 devkit; shared by CI and local builders.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NDK="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}"
[[ -n "$NDK" && -f "$NDK/build/cmake/android.toolchain.cmake" ]] || {
  echo "Set ANDROID_NDK_HOME to an installed Android NDK (CI uses r29)" >&2; exit 1;
}
SRC="$ROOT/build/upstream"
BUILD="$ROOT/build/devkit"
PKG_ROOT="$ROOT/build/devkit-pkg"
PREFIX="$PKG_ROOT/fluidsynth"
[[ -f "$SRC/CMakeLists.txt" ]] || { echo "Run ./scripts/prepare.sh first" >&2; exit 1; }
VERSION="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["version"])' "$ROOT/version.json")"
rm -rf -- "$BUILD" "$PKG_ROOT"
cmake -S "$SRC" -B "$BUILD" -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-24 \
  -DANDROID_STL=c++_shared -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_PLATFORM_NO_VERSIONED_SONAME=ON \
  -DCMAKE_SHARED_LINKER_FLAGS="-Wl,-z,max-page-size=16384" \
  -DBUILD_SHARED_LIBS=ON -Dosal=cpp11 \
  -Denable-alsa=OFF -Denable-aufile=OFF -Denable-dbus=OFF \
  -Denable-jack=OFF -Denable-ladspa=OFF -Denable-libsndfile=OFF \
  -Denable-midishare=OFF -Denable-opensles=OFF -Denable-oboe=OFF \
  -Denable-network=OFF -Denable-oss=OFF -Denable-dsound=OFF \
  -Denable-wasapi=OFF -Denable-waveout=OFF -Denable-winmidi=OFF \
  -Denable-sdl3=OFF -Denable-pulseaudio=OFF -Denable-pipewire=OFF \
  -Denable-readline=OFF -Denable-portaudio=OFF \
  -Denable-openmp=OFF -Denable-native-dls=OFF \
  -Denable-signalsmith=OFF -Denable-ipv6=OFF
cmake --build "$BUILD" --target libfluidsynth --parallel "$(nproc)"
# Install library and headers, not the unbuilt CLI/test targets.
cmake --install "$BUILD" --component fluidsynth_runtime
cmake --install "$BUILD" --component fluidsynth_development
rm -rf -- "$PREFIX/lib/pkgconfig" "$PREFIX/lib/cmake"
test -s "$PREFIX/lib/libfluidsynth.so"
test -s "$PREFIX/include/fluidsynth.h"
CXX="$(find "$NDK/toolchains/llvm/prebuilt" -path '*/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so' -print -quit)"
[[ -n "$CXX" && -f "$CXX" ]] || { echo "NDK libc++_shared.so not found" >&2; exit 1; }
cp "$CXX" "$PREFIX/lib/libc++_shared.so"
mkdir -p "$PREFIX/licenses"
cp "$SRC/LICENSE" "$PREFIX/licenses/FluidSynth-LGPL-2.1.txt"
cp "$SRC/gcem/LICENSE" "$PREFIX/licenses/GCEM-Apache-2.0.txt"
for notice in "$NDK/NOTICE" "$NDK/NOTICE.md" "$NDK/toolchains/llvm/prebuilt/linux-x86_64/NOTICE"; do
  if [[ -f "$notice" ]]; then cp "$notice" "$PREFIX/licenses/Android-NDK-NOTICE.txt"; break; fi
done
python3 "$ROOT/scripts/verify_elf.py" "$PREFIX/lib" "$NDK"
tar -czf "$ROOT/fluidsynth-${VERSION}-android-aarch64-devkit.tar.gz" -C "$PKG_ROOT" fluidsynth
echo "Built fluidsynth-${VERSION}-android-aarch64-devkit.tar.gz"
