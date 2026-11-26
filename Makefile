# Czytnik M3U - aplikacja na iOS 6 (jailbreak), budowana w Theosie.
# SDKVER: wersja SDK iOS, z którą kompilujemy. Skrypt build.sh sam wybiera najstarsze dostępne.
SDKVER ?= 6.1

# armv7 działa na iPhone 3GS/4/4S/5 i iPod touch 4/5 (iOS 6.x)
export ARCHS = armv7
export TARGET = iphone:clang:$(SDKVER):6.0

# stary dpkg z iOS 6 nie czyta nowszej kompresji niż gzip
export THEOS_PLATFORM_DEB_COMPRESSION_TYPE = gzip

INSTALL_TARGET_PROCESSES = CzytnikM3U

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = CzytnikM3U

CzytnikM3U_FILES = main.m AppDelegate.m M3UList.m M3UStore.m M3UPlaylistsController.m M3UAddController.m M3UChannelsController.m M3UTheme.m M3ULogos.m M3UTiles.m M3USetupController.m M3URailController.m M3USettingsController.m M3ULocalization.m M3UEpg.m M3UDiag.m m3u.c m3u_libc.c
CzytnikM3U_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore MediaPlayer
CzytnikM3U_CFLAGS = -fobjc-arc -D_FORTIFY_SOURCE=0 -Wno-deprecated-declarations -Wno-unused-command-line-argument

include $(THEOS_MAKE_PATH)/application.mk

after-install::
	install.exec "uicache"
