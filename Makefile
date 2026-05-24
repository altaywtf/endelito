APP_NAME := Endelito
EXECUTABLE := Endelito
BUILD_DIR := build
BIN_DIR := bin
APP_DIR := $(BUILD_DIR)/$(APP_NAME).app
CONTENTS_DIR := $(APP_DIR)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
RESOURCES_DIR := $(CONTENTS_DIR)/Resources
DIST_DIR := dist
PACKAGE_DIR := $(DIST_DIR)/$(APP_NAME)
VERSION_FILE := VERSION
RELEASE_VERSION ?= $(shell if test -f "$(VERSION_FILE)"; then tr -d '[:space:]' < "$(VERSION_FILE)"; else printf dev; fi)
ARCH := $(shell uname -m)

.PHONY: build build-cli build-app package-release check-js doctor run smoke smoke-live verify clean clean-app

build: build-cli build-app

build-cli:
	mkdir -p "$(BIN_DIR)"
	go build -trimpath -ldflags="-s -w -X main.version=$(RELEASE_VERSION)" -o "$(BIN_DIR)/endelito" ./cmd/endelito
	du -sh "$(BIN_DIR)/endelito"

build-app:
	mkdir -p "$(MACOS_DIR)" "$(RESOURCES_DIR)"
	cp app/Info.plist "$(CONTENTS_DIR)/Info.plist"
	cp app/Resources/EndelitoBridge.js "$(RESOURCES_DIR)/EndelitoBridge.js"
	swift tools/GenerateAssets.swift "$(RESOURCES_DIR)"
	iconutil -c icns "$(RESOURCES_DIR)/AppIcon.iconset" -o "$(RESOURCES_DIR)/AppIcon.icns"
	xcrun swiftc -Osize -framework AppKit -framework WebKit -o "$(MACOS_DIR)/$(EXECUTABLE)" app/Sources/Endelito/main.swift
	codesign --force --sign - "$(APP_DIR)"
	du -sh "$(APP_DIR)"

package-release:
	printf '%s\n' "$(RELEASE_VERSION)" > "$(VERSION_FILE)"
	$(MAKE) build
	rm -rf "$(DIST_DIR)"
	mkdir -p "$(PACKAGE_DIR)"
	cp -R "$(APP_DIR)" "$(PACKAGE_DIR)/"
	cp "$(BIN_DIR)/endelito" "$(PACKAGE_DIR)/"
	cp "$(VERSION_FILE)" "$(PACKAGE_DIR)/"
	cp README.md LICENSE* "$(PACKAGE_DIR)/" 2>/dev/null || true
	(cd "$(DIST_DIR)" && ditto -c -k --sequesterRsrc --keepParent "$(APP_NAME)" "endelito-macos-$(ARCH).zip")

check-js:
	node --check app/Resources/EndelitoBridge.js

doctor:
	scripts/doctor.sh

run: build
	"$(BIN_DIR)/endelito" launch

smoke: build
	scripts/smoke.sh

smoke-live: build
	ENDELITO_SMOKE_LAUNCH=1 scripts/smoke.sh

verify:
	$(MAKE) check-js
	go test ./...
	$(MAKE) smoke

clean: clean-app
	rm -rf "$(BIN_DIR)" "$(DIST_DIR)"

clean-app:
	rm -rf "$(APP_DIR)"
