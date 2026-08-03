cmake_minimum_required(VERSION 3.13...3.27)

# initialize the SDK based on PICO_SDK_PATH
# note: this must happen before project()
include(pico_sdk_import.cmake)

project(simple_photo_frame)

# initialize the Raspberry Pi Pico SDK
pico_sdk_init()

# -----------------------------------------------------------------------------
add_executable(simple_photo_frame
	simple_photo_frame.c
	sdcard.c
	fpga_io.c
	vram_accessor.c
	display_controller.c
	button.c
	${PICO_SDK_PATH}/lib/tinyusb/lib/fatfs/source/ff.c
	${PICO_SDK_PATH}/lib/tinyusb/lib/fatfs/source/ffunicode.c
)

target_include_directories(simple_photo_frame PRIVATE
	${PICO_SDK_PATH}/lib/tinyusb/lib/fatfs/source
)

# Add pico_stdlib library which aggregates commonly used features
target_link_libraries(simple_photo_frame pico_stdlib hardware_spi pico_cyw43_arch_none)

# enable usb output, disable uart output
pico_enable_stdio_usb(simple_photo_frame 1)
pico_enable_stdio_uart(simple_photo_frame 0)

# create map/bin/hex/uf2 file in addition to ELF.
pico_add_extra_outputs(simple_photo_frame)
