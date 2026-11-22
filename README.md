# fluidsynth-vendored-android

**Status: planned, not implemented.** This repo will build
[FluidSynth](https://github.com/FluidSynth/fluidsynth) for Android
(arm64-v8a only) from an upstream ref pinned in `version.json`, and publish a
plain headers + shared-libs devkit tarball as a GitHub release asset, so
Make/NDK-built apps can link a SoundFont synthesizer without Gradle.

It follows the same shape as
[llama.cpp-vendored-android](https://github.com/jamesbiederbeck/llama.cpp-vendored-android).
See [`AGENTS.md`](AGENTS.md) for the conventions to follow when implementing it.
