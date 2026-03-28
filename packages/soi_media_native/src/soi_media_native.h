#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if _WIN32
#include <windows.h>
#else
#include <pthread.h>
#include <unistd.h>
#endif

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

FFI_PLUGIN_EXPORT intptr_t soi_probe_image(
    const char *path,
    int32_t *out_width,
    int32_t *out_height);

FFI_PLUGIN_EXPORT intptr_t soi_compress_image(
    const char *input_path,
    const char *output_path,
    int32_t quality,
    int32_t max_width,
    int32_t max_height,
    int32_t output_format);

FFI_PLUGIN_EXPORT int32_t soi_sample_waveform(
    const double *input,
    int32_t input_length,
    int32_t target_length,
    double *output);
