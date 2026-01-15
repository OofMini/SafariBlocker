TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = MobileSafari

# Modern rootless standard
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SafariBlocker

SafariBlocker_FILES = Tweak.xm $(wildcard Bagel/*.m)
SafariBlocker_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += SafariBlocker
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 MobileSafari"
