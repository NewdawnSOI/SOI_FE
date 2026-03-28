// ignore_for_file: non_constant_identifier_names

import 'dart:ffi' as ffi;

@ffi.Native<
  ffi.IntPtr Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Int32>,
    ffi.Pointer<ffi.Int32>,
  )
>()
external int soi_probe_image(
  ffi.Pointer<ffi.Char> path,
  ffi.Pointer<ffi.Int32> width,
  ffi.Pointer<ffi.Int32> height,
);

@ffi.Native<
  ffi.IntPtr Function(
    ffi.Pointer<ffi.Char>,
    ffi.Pointer<ffi.Char>,
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
    ffi.Int32,
  )
>()
external int soi_compress_image(
  ffi.Pointer<ffi.Char> inputPath,
  ffi.Pointer<ffi.Char> outputPath,
  int quality,
  int maxWidth,
  int maxHeight,
  int outputFormat,
);

@ffi.Native<
  ffi.Int32 Function(
    ffi.Pointer<ffi.Double>,
    ffi.Int32,
    ffi.Int32,
    ffi.Pointer<ffi.Double>,
  )
>()
external int soi_sample_waveform(
  ffi.Pointer<ffi.Double> input,
  int inputLength,
  int targetLength,
  ffi.Pointer<ffi.Double> output,
);
