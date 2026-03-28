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
	@echo "Built $(APP_BUNDLE)"

run: bundle
	@echo "Launching SillyPet..."
	@open "$(APP_BUNDLE)"

clean:
	swift package clean
	rm -rf "$(APP_BUNDLE)"
	rm -rf .build

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
