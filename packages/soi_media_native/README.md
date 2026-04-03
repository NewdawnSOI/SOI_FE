# soi_media_native

Native image and waveform helpers used by SOI media flows.

## Features

- Probe PNG, JPEG, and WebP dimensions without decoding the full image
- Compress images through a bundled native pipeline using `stb` and `libwebp`
- Sample long waveform arrays in native code for upload-friendly payloads
- Encode and decode waveform payloads in JSON or CSV-compatible formats

## Public API

`SoiMediaNativeClient` exposes three main capabilities:

- `probeImage(path)` returns `SoiImageProbeResult?`
- `compressImage(...)` writes a compressed file and returns `File?`
- `sampleWaveform(...)`, `encodeWaveform(...)`, `decodeWaveform(...)`

`compressImage` keeps the historical parameter names `minWidth` and `minHeight`
for compatibility with the app layer, but the native pipeline treats them as
the maximum output bounds while preserving aspect ratio.

## Development

Install dependencies and run package checks from the package root:

```bash
dart pub get
dart analyze
flutter test
```

## Native build details

The package uses a Dart build hook at [hook/build.dart](hook/build.dart) to
compile:

- `src/soi_media_native.c`
- the required `libwebp` encoder/decoder sources
- `stb` headers for probing, decoding, resizing, and file output helpers

Bindings are generated from [src/soi_media_native.h](src/soi_media_native.h):

```bash
dart run ffigen --config ffigen.yaml
```

`compressImage` runs the native call on a helper isolate so large image work
does not block the UI isolate.
