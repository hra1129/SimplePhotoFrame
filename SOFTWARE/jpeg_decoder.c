#include "jpeg_decoder.h"

#include <stdio.h>
#include <string.h>

#include "ff.h"
#include "tjpgd.h"

typedef struct {
    FIL file;
} jpeg_input_file_t;

typedef struct {
    jpeg_input_file_t input;
    jpeg_decoder_output_callback_t callback;
    void *user_data;
} jpeg_decoder_context_t;

static size_t jpeg_input_func(JDEC *jd, uint8_t *buf, size_t bytes_to_read);

static bool jpeg_prepare_from_file(
    const char *path,
    JDEC *out_jd,
    jpeg_decoder_context_t *ctx,
    uint8_t *work,
    size_t work_size) {
    FRESULT fr;
    JRESULT jr;

    fr = f_open(&ctx->input.file, path, FA_READ);
    if (fr != FR_OK) {
        printf("JPEG open failed: %s (fr=%d)\n", path, fr);
        return false;
    }

    memset(out_jd, 0, sizeof(*out_jd));
    jr = jd_prepare(out_jd, jpeg_input_func, work, work_size, ctx);
    if (jr != JDR_OK) {
        printf("JPEG prepare failed: %s (jr=%d)\n", path, jr);
        (void)f_close(&ctx->input.file);
        return false;
    }

    return true;
}

static size_t jpeg_input_func(JDEC *jd, uint8_t *buf, size_t bytes_to_read) {
    jpeg_decoder_context_t *ctx = (jpeg_decoder_context_t *)jd->device;
    UINT bytes_processed = 0;

    if (buf != NULL) {
        if (f_read(&ctx->input.file, buf, (UINT)bytes_to_read, &bytes_processed) != FR_OK) {
            return 0;
        }
        return (size_t)bytes_processed;
    }

    if (f_lseek(&ctx->input.file, f_tell(&ctx->input.file) + bytes_to_read) != FR_OK) {
        return 0;
    }
    return bytes_to_read;
}

static int jpeg_output_func(JDEC *jd, void *bitmap, JRECT *rect) {
    jpeg_decoder_context_t *ctx = (jpeg_decoder_context_t *)jd->device;

    if (ctx->callback == NULL) {
        return 1;
    }

    if (ctx->callback(rect->left, rect->top, rect->right, rect->bottom, (const uint16_t *)bitmap, ctx->user_data)) {
        return 1;
    }

    return 0;
}

bool jpeg_probe_file(
    const char *path,
    uint16_t *out_width,
    uint16_t *out_height) {
    JDEC jd;
    jpeg_decoder_context_t ctx;
    uint8_t work[TJPGD_WORKSPACE_SIZE];

    if (path == NULL) {
        return false;
    }

    memset(&ctx, 0, sizeof(ctx));
    ctx.callback = NULL;
    ctx.user_data = NULL;

    if (!jpeg_prepare_from_file(path, &jd, &ctx, work, sizeof(work))) {
        return false;
    }

    if (out_width != NULL) {
        *out_width = jd.width;
    }
    if (out_height != NULL) {
        *out_height = jd.height;
    }

    (void)f_close(&ctx.input.file);
    return true;
}

bool jpeg_decode_file(
    const char *path,
    uint8_t scale,
    jpeg_decoder_output_callback_t output_callback,
    void *user_data,
    uint16_t *out_width,
    uint16_t *out_height) {
    JRESULT jr;
    JDEC jd;
    jpeg_decoder_context_t ctx;
    uint8_t work[TJPGD_WORKSPACE_SIZE];

    if (path == NULL) {
        return false;
    }
    if (scale > 3) {
        return false;
    }

    memset(&ctx, 0, sizeof(ctx));
    ctx.callback = output_callback;
    ctx.user_data = user_data;

    if (!jpeg_prepare_from_file(path, &jd, &ctx, work, sizeof(work))) {
        return false;
    }

    if (out_width != NULL) {
        *out_width = jd.width;
    }
    if (out_height != NULL) {
        *out_height = jd.height;
    }

    jr = jd_decomp(&jd, jpeg_output_func, scale);
    (void)f_close(&ctx.input.file);

    if (jr != JDR_OK) {
        printf("JPEG decode failed: %s (jr=%d)\n", path, jr);
        return false;
    }

    return true;
}
