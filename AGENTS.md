# AGENTS.md

Guidance for agents implementing this repo. Nothing is implemented yet: the
job is to build FluidSynth for Android and publish it as a release, following
the pattern established by
[llama.cpp-vendored-android](https://github.com/jamesbiederbeck/llama.cpp-vendored-android)
(the "reference repo"). Items marked **VERIFY** are expectations about
FluidSynth that must be checked against the pinned upstream ref before relying on them.

## Goal

Publish `fluidsynth-<version>-android-aarch64-devkit.tar.gz`: a plain
`cmake --install` tree of headers and shared libraries. The consumer is a
Make/NDK-built Android app (no Gradle, no androidx) that links the C API
through a small JNI shim. An AAR is **not** a goal. Add one only if asked.

## Patterns inferred from the reference repo

### 1. Do not vendor upstream source
- The repo holds only build glue. At build time, clone upstream at a pinned
  ref (`git clone --depth 1 --branch <ref>`) into `build/upstream`.
- Never commit upstream sources, build output, or `.cxx/`. `.gitignore`
  `build/`.

### 2. `version.json` is the single source of truth
```json
{ "upstream_repo": "https://github.com/FluidSynth/fluidsynth",
  "upstream_ref": "<upstream tag>",
  "version": "<release tag for this repo>" }
```
- `upstream_ref` is what gets built; `version` is the tag this repo releases
  under. They may differ (e.g. a rebuild with changed flags bumps `version`
  only).
- Read it with `jq` in CI and `python3 -c json` in local scripts. No extra
  tooling.

### 3. One script shared by local and CI builds
- `scripts/prepare.sh [output_dir]` (default `build/upstream`): `set -euo pipefail`,
  resolve `REPO_ROOT` from `BASH_SOURCE`, read `version.json`, echo the
  inputs, `rm -rf` the output dir, shallow-clone upstream.
- If an overlay is ever needed (patches, extra CMake files), keep it in a
  top-level directory and copy it in from this script. Prefer **no overlay**
  if FluidSynth's own CMake suffices. The reference repo overlays only
  because Gradle must live inside the upstream tree.
- CI must call the same script, so "works locally" means "works in CI".

### 4. Single ABI, pinned toolchain
- `arm64-v8a` only; `-DANDROID_PLATFORM=android-24` (the consuming apps use minSdk 24).
- Pin the NDK version in one workflow `env:` var and install it explicitly with
  `sdkmanager --install "ndk;<version>"`. Use
  `$ANDROID_HOME/ndk/<version>/build/cmake/android.toolchain.cmake`.
- Build: `cmake -B build/devkit -S build/upstream ...`, `cmake --build ... --parallel`,
  then `cmake --install build/devkit --prefix build/devkit-pkg/fluidsynth`.
- Use `-DBUILD_SHARED_LIBS=ON` and turn off everything that is not the
  library (examples, tests, CLI, docs, audio drivers Android lacks), the
  way the reference passes `-D..._BUILD_EXAMPLES=OFF` etc.

### 5. Release workflow shape (`.github/workflows/release.yml`)
Copy the reference's structure:
- Triggers: `push` to **`main`** with `paths: ['version.json']`, plus
  `workflow_dispatch`. (The reference initially watched `master` by mistake and
  needed a fix commit. Check the default branch name.)
- `concurrency: { group: ${{ github.workflow }}, cancel-in-progress: false }`
- `permissions: contents: write`
- `runs-on: ubuntu-22.04`
- Third-party actions **pinned by full commit SHA with a `# vN` comment**:
  `actions/checkout`, `actions/setup-java` (needed by the SDK manager),
  `android-actions/setup-android`. Look up current SHAs; do not copy the reference's.
- Steps, in order: clone, read `version.json`, **fail if the tag already
  exists** (`git ls-remote --exit-code --tags origin refs/tags/$TAG`, with a
  message telling the maintainer to bump `version`), install Java/SDK/pinned
  NDK, run `prepare.sh`, build the devkit, collect artifacts, then
  `git tag` + `git push origin` + `gh release create` with `GH_TOKEN: ${{ github.token }}`.
- Artifact naming: `fluidsynth-${VERSION}-android-aarch64-devkit.tar.gz`,
  created with `tar czf ... -C build/devkit-pkg fluidsynth`.
- Release notes: one line naming upstream ref, what is attached and the ABI.
- Release = bump `version` in `version.json` and push to `main`. Do not add
  other release paths.

### 6. README conventions
Document: what it builds, how to build locally (`./scripts/prepare.sh` then the
cmake commands), the tarball's tree, how to release, and a Layout list of each
top-level file and its role.

## FluidSynth-specific concerns (not in the reference)

The reference builds one self-contained project. FluidSynth has dependencies,
which is the main new work.

- **Dependency cross-compilation. VERIFY** which of these the pinned ref
  requires: GLib (historically required; check whether the ref still needs it),
  libsndfile (for SF3/Ogg Vorbis SoundFonts and file output), plus its own
  transitive libraries (libogg/libvorbis/flac/opus etc.). Build each from a
  pinned tag or release tarball, **sha256-verified**, into the same install
  prefix before FluidSynth, via `scripts/` helpers or CMake `ExternalProject`.
  Record every pin in `version.json` or a `deps.json` alongside it, not inline
  in YAML.
- **Disable what Android lacks or the consumer does not want. VERIFY option
  names against upstream `CMakeLists.txt`**: ALSA, PulseAudio, JACK, SDL, DBus,
  readline, PortAudio, and similar. The consumer renders PCM itself and feeds
  AAudio, so the minimum is the synth core with no audio driver. Whether to
  enable FluidSynth's own Oboe/OpenSL ES driver is an open decision; default to
  off and say why in the README.
- **Licensing.** FluidSynth is LGPL-2.1. Ship **shared libraries only** (never
  static), include upstream's LICENSE/COPYING and the licenses of each bundled
  dependency inside the tarball, and keep the README noting that the
  consumer must keep the libs replaceable. SoundFonts have their own licenses;
  do not bundle one here.
- **Tarball layout.** Mirror the reference:
  ```
  fluidsynth/
  ├── include/      (fluidsynth.h and fluidsynth/*.h)
  ├── lib/          (libfluidsynth.so + dependency .so files)
  └── licenses/
  ```
  List *every* `.so` the consumer must copy into `lib/arm64-v8a/` of its APK,
  including transitive dependencies, in the README. Check the install tree
  for `pkg-config`/cmake config files that carry host paths and drop or fix them.
- **Smoke test in CI.** After building, check with `readelf -d` that the
  libs have no unresolved `NEEDED` entries outside the Android system set
  (`libc`, `libm`, `libdl`, `liblog`, `libandroid`), so a missing bundled
  dependency fails the release instead of the app at runtime.
- **16 KB page size.** Build with `-Wl,-z,max-page-size=16384` (or a
  new enough NDK default) so the libs load on 16 KB-page devices. **VERIFY** for the pinned NDK.

## Rules for agents working here

- Do not implement beyond what the task asks. Keep the repo glue-only.
- Do not hand-edit generated or downloaded artifacts; change `version.json`
  or scripts.
- Pin and checksum every external input (actions by SHA, NDK by version,
  dependencies by sha256).
- Prefer a cold local run of `scripts/prepare.sh` and the cmake commands
  over editing the workflow blind, then mirror the working commands into CI.
- If a decision is a real tradeoff (enabling the Oboe driver, adding an AAR,
  an extra ABI), ask the maintainer rather than choosing silently.
