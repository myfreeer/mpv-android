APP_ABI :=arm64-v8a
ifneq ($(PREFIX32),)
APP_ABI += armeabi-v7a
endif
ifneq ($(PREFIX_X64),)
APP_ABI += x86_64
endif

APP_PLATFORM := android-21
APP_STL := c++_shared
