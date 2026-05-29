.PHONY: build start clean check test release tag changelog

APP_NAME := Parrot
VERSION := 0.6.9
BUILD_DIR := .build/arm64-apple-macosx/release
RELEASE_DIR := .build/release-app
APP_BUNDLE := $(RELEASE_DIR)/$(APP_NAME).app
PLIST_BUDDY := /usr/libexec/PlistBuddy

build:
	swift build

start: build
	@rm -rf .build/dev-app/Parrot.app
	@mkdir -p .build/dev-app/Parrot.app/Contents/MacOS
	@mkdir -p .build/dev-app/Parrot.app/Contents/Resources
	@mkdir -p .build/dev-app/Parrot.app/Contents/Frameworks
	@cp .build/debug/Parrot .build/dev-app/Parrot.app/Contents/MacOS/Parrot
	@cp -R .build/arm64-apple-macosx/debug/whisper.framework .build/dev-app/Parrot.app/Contents/Frameworks/
	@cp -R .build/arm64-apple-macosx/debug/llama.framework .build/dev-app/Parrot.app/Contents/Frameworks/
	@cp Resources/Info.plist .build/dev-app/Parrot.app/Contents/Info.plist
	@$(PLIST_BUDDY) -c "Set :CFBundleShortVersionString $(VERSION)" .build/dev-app/Parrot.app/Contents/Info.plist
	@$(PLIST_BUDDY) -c "Set :CFBundleVersion $(VERSION)" .build/dev-app/Parrot.app/Contents/Info.plist
	@cp Resources/images/AppIcon.icns .build/dev-app/Parrot.app/Contents/Resources/AppIcon.icns 2>/dev/null; true
	@cp Resources/images/parrot.jpeg .build/dev-app/Parrot.app/Contents/Resources/parrot.jpeg 2>/dev/null; true
	@install_name_tool -add_rpath @executable_path/../Frameworks .build/dev-app/Parrot.app/Contents/MacOS/Parrot 2>/dev/null; true
	@codesign --force --deep --sign - .build/dev-app/Parrot.app 2>/dev/null; true
	open .build/dev-app/Parrot.app

test:
	swift test

check:
	swift build -c release

clean:
	swift package clean
	rm -rf $(RELEASE_DIR)

release: test
	@echo "Building release binary..."
	swift build -c release
	@echo "Assembling $(APP_NAME).app..."
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	mkdir -p $(APP_BUNDLE)/Contents/Frameworks
	cp .build/release/Parrot $(APP_BUNDLE)/Contents/MacOS/Parrot
	cp -R $(BUILD_DIR)/whisper.framework $(APP_BUNDLE)/Contents/Frameworks/
	cp -R $(BUILD_DIR)/llama.framework $(APP_BUNDLE)/Contents/Frameworks/
	cp Resources/images/AppIcon.icns $(APP_BUNDLE)/Contents/Resources/AppIcon.icns
	cp Resources/images/parrot.jpeg $(APP_BUNDLE)/Contents/Resources/parrot.jpeg
	cp Resources/Info.plist $(APP_BUNDLE)/Contents/Info.plist
	$(PLIST_BUDDY) -c "Set :CFBundleShortVersionString $(VERSION)" $(APP_BUNDLE)/Contents/Info.plist
	$(PLIST_BUDDY) -c "Set :CFBundleVersion $(VERSION)" $(APP_BUNDLE)/Contents/Info.plist
	install_name_tool -add_rpath @executable_path/../Frameworks $(APP_BUNDLE)/Contents/MacOS/Parrot 2>/dev/null; true
	codesign --force --deep --sign - $(APP_BUNDLE)
	@echo "Creating DMG installer..."
	scripts/create-dmg.sh $(APP_BUNDLE) $(VERSION) $(RELEASE_DIR)/$(APP_NAME)-$(VERSION)-macos-arm64.dmg
	@echo ""
	@echo "Done! Release artifact:"
	@echo "  $(RELEASE_DIR)/$(APP_NAME)-$(VERSION)-macos-arm64.dmg"
	@echo ""
	@echo "To test: open $(APP_BUNDLE)"

changelog:
	git cliff -o CHANGELOG.md

tag: test
	@if git rev-parse "v$(VERSION)" >/dev/null 2>&1; then \
		echo "Error: tag v$(VERSION) already exists"; exit 1; \
	fi
	@if [ -n "$$(git status --porcelain)" ]; then \
		echo "Error: working tree is dirty — commit first"; exit 1; \
	fi
	@if ! git show HEAD:Makefile | grep -q "^VERSION := $(VERSION)$$"; then \
		echo "Error: VERSION $(VERSION) not in HEAD's Makefile — commit the bump first"; exit 1; \
	fi
	git tag -a "v$(VERSION)"
	git push origin "v$(VERSION)"
	@echo ""
	@echo "Tagged and pushed v$(VERSION) — release workflow started"
