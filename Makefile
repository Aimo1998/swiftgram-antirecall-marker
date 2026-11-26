TARGET := iphone:clang:latest:15.0
ARCHS := arm64
INSTALL_TARGET_PROCESSES := Swiftgram
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SwiftgramAntiRecallMarker

SwiftgramAntiRecallMarker_FILES = Tweak.x
SwiftgramAntiRecallMarker_CFLAGS = -fobjc-arc
SwiftgramAntiRecallMarker_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk
