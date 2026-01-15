TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = MobileSafari

# Automatically support Rootless (Dopamine/Palera1n)
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SafariBlocker

# Source files
SafariBlocker_FILES = Tweak.xm $(wildcard Bagel/*.m)

# Compilation flags
SafariBlocker_CFLAGS = -fobjc-arc

# Libraries
# Note: Ensure libundirect is present in your build environment or 'libs' folder
SafariBlocker_LIBRARIES = undirect

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += SafariBlocker
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 MobileSafari"
