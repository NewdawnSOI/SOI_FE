#include "soi_media_native.h"

#define STB_IMAGE_IMPLEMENTATION
#include "../third_party/stb/stb_image.h"

#define STB_IMAGE_RESIZE_IMPLEMENTATION
#include "../third_party/stb/stb_image_resize2.h"

#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "../third_party/stb/stb_image_write.h"

#include "../third_party/libwebp/src/webp/decode.h"
#include "../third_party/libwebp/src/webp/encode.h"
#include "../third_party/libwebp/src/webp/types.h"

typedef enum SoiPixelOwnership {
  SOI_PIXEL_OWNERSHIP_NONE = 0,
  SOI_PIXEL_OWNERSHIP_STBI = 1,
  SOI_PIXEL_OWNERSHIP_WEBP = 2,
  SOI_PIXEL_OWNERSHIP_MALLOC = 3,
} SoiPixelOwnership;

typedef struct SoiPixelBuffer {
  uint8_t *pixels;
  int32_t width;
  int32_t height;
  SoiPixelOwnership ownership;
} SoiPixelBuffer;

static uint32_t read_be32(const unsigned char *bytes) {
  return ((uint32_t)bytes[0] << 24U) |
         ((uint32_t)bytes[1] << 16U) |
         ((uint32_t)bytes[2] << 8U) |
         (uint32_t)bytes[3];
}

static double min_double(double a, double b) {
  return a < b ? a : b;
}

/// PNG 헤더만 읽어 빠른 이미지 probe 경로에서 폭과 높이를 구합니다.
static int32_t probe_png(FILE *file, int32_t *width, int32_t *height) {
  unsigned char header[24];
  if (fseek(file, 0, SEEK_SET) != 0) {
    return 0;
  }
  if (fread(header, 1, sizeof(header), file) != sizeof(header)) {
    return 0;
  }
  if (memcmp(header, "\211PNG\r\n\032\n", 8) != 0) {
    return 0;
  }
  *width = (int32_t)read_be32(header + 16);
  *height = (int32_t)read_be32(header + 20);
  return *width > 0 && *height > 0;
}

/// JPEG 세그먼트를 따라가며 SOF 프레임에서 실제 폭과 높이를 찾습니다.
static int32_t probe_jpeg(FILE *file, int32_t *width, int32_t *height) {
  unsigned char marker[2];
  if (fseek(file, 0, SEEK_SET) != 0) {
    return 0;
  }
  if (fread(marker, 1, 2, file) != 2 || marker[0] != 0xFF || marker[1] != 0xD8) {
    return 0;
  }

  while (fread(marker, 1, 2, file) == 2) {
    while (marker[0] != 0xFF) {
      marker[0] = marker[1];
      if (fread(&marker[1], 1, 1, file) != 1) {
        return 0;
      }
    }

    const unsigned char type = marker[1];
    if (type == 0xD9 || type == 0xDA) {
      return 0;
    }

    unsigned char size_bytes[2];
    if (fread(size_bytes, 1, 2, file) != 2) {
      return 0;
    }
    int32_t segment_size = (int32_t)(((uint32_t)size_bytes[0] << 8U) | size_bytes[1]);
    if (segment_size < 2) {
      return 0;
    }

    if ((type >= 0xC0 && type <= 0xC3) ||
        (type >= 0xC5 && type <= 0xC7) ||
        (type >= 0xC9 && type <= 0xCB) ||
        (type >= 0xCD && type <= 0xCF)) {
      unsigned char frame[5];
      if (fread(frame, 1, sizeof(frame), file) != sizeof(frame)) {
        return 0;
      }
      *height = (int32_t)(((uint32_t)frame[1] << 8U) | frame[2]);
      *width = (int32_t)(((uint32_t)frame[3] << 8U) | frame[4]);
      return *width > 0 && *height > 0;
    }

    if (fseek(file, segment_size - 2, SEEK_CUR) != 0) {
      return 0;
    }
  }

  return 0;
}

/// WEBP 컨테이너 헤더를 읽어 decode 없이 폭과 높이를 추출합니다.
static int32_t probe_webp(FILE *file, int32_t *width, int32_t *height) {
  unsigned char header[30];
  if (fseek(file, 0, SEEK_SET) != 0) {
    return 0;
  }
  if (fread(header, 1, sizeof(header), file) < 30) {
    return 0;
  }
  if (memcmp(header, "RIFF", 4) != 0 || memcmp(header + 8, "WEBP", 4) != 0) {
    return 0;
  }

  if (memcmp(header + 12, "VP8X", 4) == 0) {
    *width = 1 + (int32_t)(header[24] | (header[25] << 8U) | (header[26] << 16U));
    *height = 1 + (int32_t)(header[27] | (header[28] << 8U) | (header[29] << 16U));
    return *width > 0 && *height > 0;
  }

  if (memcmp(header + 12, "VP8 ", 4) == 0) {
    *width = (int32_t)(header[26] | ((header[27] & 0x3F) << 8U));
    *height = (int32_t)(header[28] | ((header[29] & 0x3F) << 8U));
    return *width > 0 && *height > 0;
  }

  if (memcmp(header + 12, "VP8L", 4) == 0) {
    const uint32_t bits =
        (uint32_t)header[21] |
        ((uint32_t)header[22] << 8U) |
        ((uint32_t)header[23] << 16U) |
        ((uint32_t)header[24] << 24U);
    *width = 1 + (int32_t)(bits & 0x3FFFU);
    *height = 1 + (int32_t)((bits >> 14U) & 0x3FFFU);
    return *width > 0 && *height > 0;
  }

  return 0;
}

/// 파일 바이트를 통째로 읽어 decode와 encode helper에서 재사용합니다.
static int32_t read_file_bytes(const char *path, uint8_t **out_bytes, size_t *out_size) {
  FILE *file = NULL;
  long file_size = 0;
  uint8_t *buffer = NULL;
  size_t read_size = 0;

  if (path == NULL || out_bytes == NULL || out_size == NULL) {
    return 0;
  }

  file = fopen(path, "rb");
  if (file == NULL) {
    return 0;
  }

  if (fseek(file, 0, SEEK_END) != 0) {
    fclose(file);
    return 0;
  }

  file_size = ftell(file);
  if (file_size <= 0) {
    fclose(file);
    return 0;
  }

  if (fseek(file, 0, SEEK_SET) != 0) {
    fclose(file);
    return 0;
  }

  buffer = (uint8_t *)malloc((size_t)file_size);
  if (buffer == NULL) {
    fclose(file);
    return 0;
  }

  read_size = fread(buffer, 1, (size_t)file_size, file);
  fclose(file);

  if (read_size != (size_t)file_size) {
    free(buffer);
    return 0;
  }

  *out_bytes = buffer;
  *out_size = read_size;
  return 1;
}

/// 메모리 버퍼를 출력 파일로 저장해 WEBP 인코더 결과를 디스크에 남깁니다.
static int32_t write_file_bytes(const char *path, const uint8_t *bytes, size_t size) {
  FILE *file = NULL;
  size_t written = 0;

  if (path == NULL || bytes == NULL || size == 0) {
    return 0;
  }

  file = fopen(path, "wb");
  if (file == NULL) {
    return 0;
  }

  written = fwrite(bytes, 1, size, file);
  fclose(file);
  return written == size;
}

/// 이미지 버퍼의 소유권 종류에 맞춰 decode와 resize 결과 메모리를 해제합니다.
static void release_pixel_buffer(SoiPixelBuffer *buffer) {
  if (buffer == NULL || buffer->pixels == NULL) {
    return;
  }

  switch (buffer->ownership) {
    case SOI_PIXEL_OWNERSHIP_STBI:
      stbi_image_free(buffer->pixels);
      break;
    case SOI_PIXEL_OWNERSHIP_WEBP:
      WebPFree(buffer->pixels);
      break;
    case SOI_PIXEL_OWNERSHIP_MALLOC:
      free(buffer->pixels);
      break;
    case SOI_PIXEL_OWNERSHIP_NONE:
    default:
      break;
  }

  buffer->pixels = NULL;
  buffer->width = 0;
  buffer->height = 0;
  buffer->ownership = SOI_PIXEL_OWNERSHIP_NONE;
}

static int32_t is_webp_buffer(const uint8_t *bytes, size_t size) {
  return bytes != NULL &&
         size >= 12 &&
         memcmp(bytes, "RIFF", 4) == 0 &&
         memcmp(bytes + 8, "WEBP", 4) == 0;
}

static int32_t clamp_quality(int32_t quality) {
  if (quality < 0) {
    return 0;
  }
  if (quality > 100) {
    return 100;
  }
  return quality;
}

/// flutter_image_compress와 비슷하게 비율을 유지한 채 bounds 안으로만 축소합니다.
static void resolve_target_dimensions(
    int32_t source_width,
    int32_t source_height,
    int32_t max_width,
    int32_t max_height,
    int32_t *target_width,
    int32_t *target_height) {
  double scale = 0.0;

  *target_width = source_width;
  *target_height = source_height;

  if (max_width > 0) {
    scale = (double)source_width / (double)max_width;
  }
  if (max_height > 0) {
    const double scale_height = (double)source_height / (double)max_height;
    scale = scale > 0.0 ? min_double(scale, scale_height) : scale_height;
  }

  if (scale < 1.0) {
    scale = 1.0;
  }

  *target_width = (int32_t)((double)source_width / scale);
  *target_height = (int32_t)((double)source_height / scale);

  if (*target_width < 1) {
    *target_width = 1;
  }
  if (*target_height < 1) {
    *target_height = 1;
  }
}

/// PNG/JPEG/STB 경로와 WEBP decode 경로를 통합해 RGBA 버퍼를 만듭니다.
static int32_t decode_image_rgba(
    const uint8_t *bytes,
    size_t size,
    SoiPixelBuffer *out_buffer) {
  if (bytes == NULL || size == 0 || out_buffer == NULL) {
    return 0;
  }

  memset(out_buffer, 0, sizeof(*out_buffer));

  if (is_webp_buffer(bytes, size)) {
    int width = 0;
    int height = 0;
    uint8_t *decoded = WebPDecodeRGBA(bytes, size, &width, &height);
    if (decoded == NULL || width <= 0 || height <= 0) {
      return 0;
    }

    out_buffer->pixels = decoded;
    out_buffer->width = (int32_t)width;
    out_buffer->height = (int32_t)height;
    out_buffer->ownership = SOI_PIXEL_OWNERSHIP_WEBP;
    return 1;
  }

  int width = 0;
  int height = 0;
  int channels = 0;
  stbi_uc *decoded = stbi_load_from_memory(bytes, (int)size, &width, &height, &channels, 4);
  if (decoded == NULL || width <= 0 || height <= 0) {
    return 0;
  }

  out_buffer->pixels = decoded;
  out_buffer->width = (int32_t)width;
  out_buffer->height = (int32_t)height;
  out_buffer->ownership = SOI_PIXEL_OWNERSHIP_STBI;
  return 1;
}

/// decode 결과를 지정된 목표 크기로 리사이즈해 새 RGBA 버퍼를 반환합니다.
static int32_t resize_image_rgba(
    const SoiPixelBuffer *source,
    int32_t target_width,
    int32_t target_height,
    SoiPixelBuffer *out_buffer) {
  uint8_t *resized = NULL;

  if (source == NULL ||
      source->pixels == NULL ||
      out_buffer == NULL ||
      target_width <= 0 ||
      target_height <= 0) {
    return 0;
  }

  memset(out_buffer, 0, sizeof(*out_buffer));

  resized = (uint8_t *)malloc((size_t)target_width * (size_t)target_height * 4U);
  if (resized == NULL) {
    return 0;
  }

  if (stbir_resize_uint8_linear(
          source->pixels,
          source->width,
          source->height,
          source->width * 4,
          resized,
          target_width,
          target_height,
          target_width * 4,
          STBIR_RGBA) == NULL) {
    free(resized);
    return 0;
  }

  out_buffer->pixels = resized;
  out_buffer->width = target_width;
  out_buffer->height = target_height;
  out_buffer->ownership = SOI_PIXEL_OWNERSHIP_MALLOC;
  return 1;
}

/// RGBA 버퍼를 WEBP, JPEG, PNG 파일로 저장해 Dart 호출부가 바로 File을 재사용하게 만듭니다.
static int32_t encode_image_rgba(
    const char *output_path,
    const SoiPixelBuffer *buffer,
    int32_t quality,
    int32_t output_format) {
  const int32_t clamped_quality = clamp_quality(quality);

  if (output_path == NULL || buffer == NULL || buffer->pixels == NULL) {
    return 0;
  }

  switch (output_format) {
    case 1:
      return stbi_write_jpg(
          output_path,
          buffer->width,
          buffer->height,
          4,
          buffer->pixels,
          clamped_quality);
    case 2:
      return stbi_write_png(
          output_path,
          buffer->width,
          buffer->height,
          4,
          buffer->pixels,
          buffer->width * 4);
    case 0:
    default: {
      uint8_t *encoded = NULL;
      const size_t encoded_size = WebPEncodeRGBA(
          buffer->pixels,
          buffer->width,
          buffer->height,
          buffer->width * 4,
          (float)clamped_quality,
          &encoded);

      if (encoded == NULL || encoded_size == 0) {
        return 0;
      }

      const int32_t ok = write_file_bytes(output_path, encoded, encoded_size);
      WebPFree(encoded);
      return ok;
    }
  }
}

/// 파일 헤더만 읽어 빠른 aspect ratio 계산용 폭과 높이를 반환합니다.
FFI_PLUGIN_EXPORT intptr_t soi_probe_image(
    const char *path,
    int32_t *out_width,
    int32_t *out_height) {
  if (path == NULL || out_width == NULL || out_height == NULL) {
    return 0;
  }

  FILE *file = fopen(path, "rb");
  if (file == NULL) {
    return 0;
  }

  int32_t width = 0;
  int32_t height = 0;
  int32_t ok =
      probe_png(file, &width, &height) ||
      probe_jpeg(file, &width, &height) ||
      probe_webp(file, &width, &height);

  fclose(file);

  if (!ok) {
    return 0;
  }

  *out_width = width;
  *out_height = height;
  return 1;
}

/// 이미지 압축은 decode, optional resize, encode를 한 C 파이프라인으로 처리합니다.
FFI_PLUGIN_EXPORT intptr_t soi_compress_image(
    const char *input_path,
    const char *output_path,
    int32_t quality,
    int32_t max_width,
    int32_t max_height,
    int32_t output_format) {
  uint8_t *input_bytes = NULL;
  size_t input_size = 0;
  SoiPixelBuffer decoded = {0};
  SoiPixelBuffer resized = {0};
  int32_t target_width = 0;
  int32_t target_height = 0;
  int32_t ok = 0;

  if (input_path == NULL || output_path == NULL) {
    return 0;
  }

  if (!read_file_bytes(input_path, &input_bytes, &input_size)) {
    return 0;
  }

  if (!decode_image_rgba(input_bytes, input_size, &decoded)) {
    free(input_bytes);
    return 0;
  }
  free(input_bytes);

  resolve_target_dimensions(
      decoded.width,
      decoded.height,
      max_width,
      max_height,
      &target_width,
      &target_height);

  if (target_width != decoded.width || target_height != decoded.height) {
    if (!resize_image_rgba(&decoded, target_width, target_height, &resized)) {
      release_pixel_buffer(&decoded);
      return 0;
    }
    release_pixel_buffer(&decoded);
    ok = encode_image_rgba(output_path, &resized, quality, output_format);
    release_pixel_buffer(&resized);
    return ok ? 1 : 0;
  }

  ok = encode_image_rgba(output_path, &decoded, quality, output_format);
  release_pixel_buffer(&decoded);
  return ok ? 1 : 0;
}

/// 긴 웨이브폼을 균등 간격으로 샘플링해 Dart 측 반복문 비용을 줄입니다.
FFI_PLUGIN_EXPORT int32_t soi_sample_waveform(
    const double *input,
    int32_t input_length,
    int32_t target_length,
    double *output) {
  if (input == NULL || output == NULL || input_length <= 0 || target_length <= 0) {
    return 0;
  }

  if (input_length <= target_length) {
    for (int32_t i = 0; i < input_length; ++i) {
      output[i] = input[i];
    }
    return input_length;
  }

  const double step = (double)input_length / (double)target_length;
  for (int32_t index = 0; index < target_length; ++index) {
    int32_t source_index = (int32_t)(index * step);
    if (source_index >= input_length) {
      source_index = input_length - 1;
    }
    output[index] = input[source_index];
  }
  return target_length;
}
