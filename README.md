# fluidsynth-vendored-android

Reproducible **Android arm64-v8a / API 24+ native FluidSynth devkit** for Conductor and other NDK/Make applications. No Gradle, AAR, AndroidX, or vendored upstream sources. No SoundFonts are included.

Follows the clone/build/release approach of [llama.cpp-vendored-android](https://github.com/jamesbiederbeck/llama.cpp-vendored-android), but produces a C-library devkit rather than an AAR or demo APK.

## Build configuration

- FluidSynth v2.6.3, pinned by tag and Git commit in version.json.
- GCEM header-only dependency, pinned via the upstream Git submodule commit.
- NDK 29.0.13113456 in CI; Android arm64-v8a, minSdk 24.
- osal=cpp11 eliminates GLib. Shared libfluidsynth.so uses NDK libc++_shared.so.
- SF2 support, MIDI, float PCM, core DSP and threading remain enabled. External audio drivers, SF3/libsndfile, DLS, optional Signalsmith effects, networking, and OpenMP are disabled.
- Versionless Android SONAME and 16 KB ELF page alignment.
- Conductor owns the audio output backend; FluidSynth renders PCM into buffers.

## Local build

Requires Git, Python 3, CMake >=3.13, Ninja and the Android NDK.

```sh
export ANDROID_NDK_HOME="$HOME/Android/Sdk/ndk/29.0.13113456"
./scripts/prepare.sh
./scripts/build.sh
```

The resulting archive at the repository root is `fluidsynth-v2.6.3-android1-android-aarch64-devkit.tar.gz` and contains:

```text
fluidsynth/
  include/fluidsynth.h
  include/fluidsynth/*.h
  lib/libfluidsynth.so
  lib/libc++_shared.so
  licenses/FluidSynth-LGPL-2.1.txt
  licenses/GCEM-Apache-2.0.txt
  licenses/Android-NDK-NOTICE.txt (when supplied by the NDK)
```

After building, scripts/verify_elf.py checks ELF64/AArch64, SONAME, all DT_NEEDED dependencies, 16 KB PT_LOAD alignment, and float PCM C API export.

## Conductor integration

Extract under `third_party/fluidsynth/` and add `-Ithird_party/fluidsynth/include` to your compiler flags and `-Lthird_party/fluidsynth/lib -lfluidsynth` to the native JNI bridge link command. Package **both** `libfluidsynth.so` and `libc++_shared.so` into the APK `lib/arm64-v8a/` directory; never package two differing versions of libc++_shared.so. Link other C++ components against the same NDK runtime.

Include `<fluidsynth.h>` and use new_fluid_settings/new_fluid_synth, fluid_synth_sfload, fluid_synth_noteon/noteoff, and fluid_synth_write_float for PCM. Conductor supplies its own SF2 file under app-private storage. Avoid file loading and unbounded control operations on the real-time audio callback.

## Release process

Bump `version` in `version.json` and push to **main** to build, verify, tag, and publish the archive via GitHub Releases. A manual workflow_dispatch is also supported. Pull requests only build/test. Changing a script without bumping version does not publish a new release.

## Licensing

FluidSynth is LGPL-2.1-or-later and GCEM is Apache-2.0. The devkit ships replaceable shared libraries and upstream license text; downstream distributors must follow LGPL notice/source/replacement requirements. SoundFont licenses are independent.

## Layout

- `version.json`: upstream/GCEM commit pins and release version.
- `scripts/prepare.sh`: verified shallow checkout of upstream and GCEM.
- `scripts/build.sh`: shared local/CI cross-compile and packaging.
- `scripts/verify_elf.py`: ELF architecture/dependency/page-size checks.
- `.github/workflows/release.yml`: build and release automation.
- `AGENTS.md`: implementation conventions.
