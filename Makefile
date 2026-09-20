APP_NAME := Endelito
EXECUTABLE := Endelito
BUILD_DIR := build
APP_DIR := $(BUILD_DIR)/$(APP_NAME).app
CONTENTS_DIR := $(APP_DIR)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
RESOURCES_DIR := $(CONTENTS_DIR)/Resources
DIST_DIR := dist
PACKAGE_DIR := $(DIST_DIR)/$(APP_NAME)
VERSION_FILE := VERSION
RELEASE_VERSION ?= $(shell if test -f "$(VERSION_FILE)"; then tr -d '[:space:]' < "$(VERSION_FILE)"; else printf dev; fi)
ARCH := $(shell uname -m)
APPLICATIONS_DIR ?= /Applications
PREFIX ?= $(shell if command -v brew >/dev/null 2>&1; then brew --prefix; elif test -d /opt/homebrew/bin; then printf /opt/homebrew; else printf /usr/local; fi)
SOURCES_JSON := app/Resources/sources.json
CODESIGN_IDENTITY ?=

.PHONY: build build-app sign-release verify-release-signatures package-release notarize-release check-js test-bridge test-playback doctor run install uninstall smoke verify clean clean-app

build: build-app

build-app:
	mkdir -p "$(MACOS_DIR)" "$(RESOURCES_DIR)"
	cp app/Info.plist "$(CONTENTS_DIR)/Info.plist"
	plutil -replace CFBundleShortVersionString -string "$(RELEASE_VERSION)" "$(CONTENTS_DIR)/Info.plist"
	plutil -replace CFBundleVersion -string "$(RELEASE_VERSION)" "$(CONTENTS_DIR)/Info.plist"
	sed 's/__ENDELITO_VERSION__/$(RELEASE_VERSION)/g' app/Resources/EndelitoBridge.js > "$(RESOURCES_DIR)/EndelitoBridge.js"
	cp "$(SOURCES_JSON)" "$(RESOURCES_DIR)/sources.json"
	swift tools/GenerateAssets.swift "$(RESOURCES_DIR)"
	iconutil -c icns "$(RESOURCES_DIR)/AppIcon.iconset" -o "$(RESOURCES_DIR)/AppIcon.icns"
	xcrun swiftc -Osize -framework AppKit -framework WebKit -o "$(MACOS_DIR)/$(EXECUTABLE)" app/Sources/Endelito/*.swift
	codesign --force --sign - "$(APP_DIR)"
	du -sh "$(APP_DIR)"

sign-release:
	@test -n "$(CODESIGN_IDENTITY)" || { printf 'sign-release: CODESIGN_IDENTITY is required\n' >&2; exit 1; }
	codesign --force --options runtime --timestamp --sign "$(CODESIGN_IDENTITY)" "$(APP_DIR)"
	$(MAKE) verify-release-signatures

verify-release-signatures:
	codesign --verify --deep --strict --verbose=2 "$(APP_DIR)"
	@codesign -d --verbose=4 "$(APP_DIR)" 2>&1 | grep -q 'Authority=Developer ID Application:'
	@codesign -d --verbose=4 "$(APP_DIR)" 2>&1 | grep -q 'runtime'

package-release:
	@test -n "$(CODESIGN_IDENTITY)" || { printf 'package-release: CODESIGN_IDENTITY is required\n' >&2; exit 1; }
	printf '%s\n' "$(RELEASE_VERSION)" > "$(VERSION_FILE)"
	$(MAKE) build
	$(MAKE) sign-release CODESIGN_IDENTITY="$(CODESIGN_IDENTITY)"
	rm -rf "$(DIST_DIR)"
	mkdir -p "$(PACKAGE_DIR)"
	cp -R "$(APP_DIR)" "$(PACKAGE_DIR)/"
	cp "$(VERSION_FILE)" "$(PACKAGE_DIR)/"
	cp README.md LICENSE "$(PACKAGE_DIR)/"
	(cd "$(DIST_DIR)" && ditto -c -k --sequesterRsrc --keepParent "$(APP_NAME)" "endelito-$(RELEASE_VERSION)-macos-$(ARCH).zip")

notarize-release: package-release
	scripts/notarize-release.sh "$(DIST_DIR)/endelito-$(RELEASE_VERSION)-macos-$(ARCH).zip" "$(PACKAGE_DIR)/$(APP_NAME).app"

check-js:
	node --check app/Resources/EndelitoBridge.js

test-bridge:
	node scripts/test-bridge.mjs

test-playback:
	node scripts/test-playback.mjs

doctor:
	scripts/doctor.sh

run: build
	open "$(APP_DIR)"

install: build
	ditto --rsrc --extattr "$(APP_DIR)" "$(APPLICATIONS_DIR)/$(APP_NAME).app"
	@printf 'install: %s\n' "$(APPLICATIONS_DIR)/$(APP_NAME).app"
	@printf 'install: open the app once from Applications if Launch Services has not registered it yet\n'

uninstall:
	rm -rf "$(APPLICATIONS_DIR)/$(APP_NAME).app"
	rm -f "$(PREFIX)/bin/endelito"
	@printf 'uninstall: removed %s\n' "$(APPLICATIONS_DIR)/$(APP_NAME).app"

smoke: build
	scripts/smoke.sh

verify:
	$(MAKE) check-js
	$(MAKE) test-bridge
	$(MAKE) test-playback
	node scripts/test-catalog.mjs
	$(MAKE) smoke

clean: clean-app
	rm -rf "$(DIST_DIR)"

clean-app:
	rm -rf "$(APP_DIR)"
