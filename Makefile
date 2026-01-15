TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = MobileSafari

# Modern rootless standard (Dopamine, Palera1n)
THEOS_PACKAGE_SCHEME = rootless

ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SafariBlocker

# Wildcard includes all Bagel subfiles automatically
SafariBlocker_FILES = Tweak.xm $(wildcard Bagel/*.m)
SafariBlocker_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += SafariBlocker
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 MobileSafari"
