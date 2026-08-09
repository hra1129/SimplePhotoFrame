#ifndef JPEG_DECODER_H
#define JPEG_DECODER_H

#include <stdbool.h>
#include <stdint.h>

typedef bool (*jpeg_decoder_output_callback_t)(
    uint16_t left,
    uint16_t top,
    uint16_t right,
    uint16_t bottom,
    const uint16_t *rgb565_pixels,
    void *user_data);

bool jpeg_probe_file(
    const char *path,
    uint16_t *out_width,
    uint16_t *out_height);

bool jpeg_decode_file(
    const char *path,
    uint8_t scale,
    jpeg_decoder_output_callback_t output_callback,
    void *user_data,
    uint16_t *out_width,
    uint16_t *out_height);

#endif
