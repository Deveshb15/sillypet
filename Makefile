SWIFT_FILES := $(shell find Sources -name '*.swift')
APP_NAME := SillyPet
APP_BUNDLE := $(APP_NAME).app
BUILD_DIR := .build/release

.PHONY: all clean run build bundle

all: bundle

build:
	swift build -c release

bundle: build
	@echo "Creating app bundle..."
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@cp "$(BUILD_DIR)/$(APP_NAME)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	@cp Resources/Info.plist "$(APP_BUNDLE)/Contents/"
	@cp Resources/sillypet-hook.sh "$(APP_BUNDLE)/Contents/Resources/"
	@chmod +x "$(APP_BUNDLE)/Contents/Resources/sillypet-hook.sh"
	@if [ -f Resources/SillyPet.icns ]; then cp Resources/SillyPet.icns "$(APP_BUNDLE)/Contents/Resources/"; fi
	@codesign --force --deep --sign - "$(APP_BUNDLE)" 2>/dev/null || true
	@echo "Built $(APP_BUNDLE)"

run: bundle
	@echo "Launching SillyPet..."
	@open "$(APP_BUNDLE)"

dmg: bundle
	@echo "Creating DMG..."
	@rm -rf dmg_staging SillyPet.dmg
	@mkdir -p dmg_staging
	@cp -R "$(APP_BUNDLE)" dmg_staging/
	@ln -s /Applications dmg_staging/Applications
	@hdiutil create -volname "SillyPet" -srcfolder dmg_staging \
		-ov -format UDZO -fs HFS+ \
		-imagekey zlib-level=9 \
		SillyPet.dmg
	@rm -rf dmg_staging
	@echo "Created SillyPet.dmg"

clean:
	swift package clean
	rm -rf "$(APP_BUNDLE)"
	rm -rf .build
	rm -rf dmg_staging

# Development: build and run without creating a bundle
dev:
	swift build
	.build/debug/$(APP_NAME)

# Direct compile without SwiftPM (fallback)
compile:
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	swiftc $(SWIFT_FILES) \
		-o "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)" \
		-framework AppKit \
		-framework SpriteKit \
		-framework SwiftUI \
		-target arm64-apple-macos14.0 \
		-O
	@cp Resources/Info.plist "$(APP_BUNDLE)/Contents/"
	@cp Resources/sillypet-hook.sh "$(APP_BUNDLE)/Contents/Resources/"
	@chmod +x "$(APP_BUNDLE)/Contents/Resources/sillypet-hook.sh"
	@echo "Compiled $(APP_BUNDLE)"
