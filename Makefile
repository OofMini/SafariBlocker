TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = MobileSafari

# Modern rootless standard
THEOS_PACKAGE_SCHEME = rootless

ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SafariBlocker

SafariBlocker_FILES = Tweak.xm $(wildcard Bagel/*.m)
# Added -Wno-deprecated-declarations to suppress strict errors
SafariBlocker_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-error

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += SafariBlocker
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 MobileSafari"
