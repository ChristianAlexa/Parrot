.PHONY: build start clean check test release tag

APP_NAME := Parrot
VERSION := 0.4.1
BUILD_DIR := .build/arm64-apple-macosx/release
RELEASE_DIR := .build/release-app
APP_BUNDLE := $(RELEASE_DIR)/$(APP_NAME).app

PLIST := <?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n\
<plist version=\"1.0\">\n\
<dict>\n\
\t<key>CFBundleExecutable</key>\n\
\t<string>Parrot</string>\n\
\t<key>CFBundleIdentifier</key>\n\
\t<string>com.parrot.app</string>\n\
\t<key>CFBundleName</key>\n\
\t<string>Parrot</string>\n\
\t<key>CFBundleDisplayName</key>\n\
\t<string>Parrot</string>\n\
\t<key>CFBundleShortVersionString</key>\n\
\t<string>$(VERSION)</string>\n\
\t<key>CFBundleVersion</key>\n\
\t<string>$(VERSION)</string>\n\
\t<key>CFBundlePackageType</key>\n\
\t<string>APPL</string>\n\
\t<key>CFBundleIconFile</key>\n\
\t<string>AppIcon</string>\n\
\t<key>LSMinimumSystemVersion</key>\n\
\t<string>14.0</string>\n\
\t<key>LSUIElement</key>\n\
\t<true/>\n\
\t<key>NSMicrophoneUsageDescription</key>\n\
\t<string>Parrot needs microphone access to transcribe your speech.</string>\n\
</dict>\n\
</plist>

build:
	swift build

start: build
	@rm -rf .build/dev-app/Parrot.app
	@mkdir -p .build/dev-app/Parrot.app/Contents/MacOS
	@mkdir -p .build/dev-app/Parrot.app/Contents/Resources
	@mkdir -p .build/dev-app/Parrot.app/Contents/Frameworks
	@cp .build/debug/Parrot .build/dev-app/Parrot.app/Contents/MacOS/Parrot
	@cp -R .build/arm64-apple-macosx/debug/whisper.framework .build/dev-app/Parrot.app/Contents/Frameworks/ 2>/dev/null; true
	@cp -R .build/arm64-apple-macosx/debug/llama.framework .build/dev-app/Parrot.app/Contents/Frameworks/ 2>/dev/null; true
	@cp Resources/Info.plist .build/dev-app/Parrot.app/Contents/Info.plist 2>/dev/null || printf '$(PLIST)' > .build/dev-app/Parrot.app/Contents/Info.plist
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
	cp -R $(BUILD_DIR)/whisper.framework $(APP_BUNDLE)/Contents/Frameworks/ 2>/dev/null; true
	cp -R $(BUILD_DIR)/llama.framework $(APP_BUNDLE)/Contents/Frameworks/ 2>/dev/null; true
	cp Resources/images/AppIcon.icns $(APP_BUNDLE)/Contents/Resources/AppIcon.icns
	cp Resources/images/parrot.jpeg $(APP_BUNDLE)/Contents/Resources/parrot.jpeg
	@printf '$(PLIST)' > $(APP_BUNDLE)/Contents/Info.plist
	install_name_tool -add_rpath @executable_path/../Frameworks $(APP_BUNDLE)/Contents/MacOS/Parrot 2>/dev/null; true
	codesign --force --deep --sign - $(APP_BUNDLE)
	@echo "Creating DMG installer..."
	scripts/create-dmg.sh $(APP_BUNDLE) $(VERSION) $(RELEASE_DIR)/$(APP_NAME)-$(VERSION)-macos-arm64.dmg
	@echo ""
	@echo "Done! Release artifact:"
	@echo "  $(RELEASE_DIR)/$(APP_NAME)-$(VERSION)-macos-arm64.dmg"
	@echo ""
	@echo "To test: open $(APP_BUNDLE)"

tag: test
	@if git rev-parse "v$(VERSION)" >/dev/null 2>&1; then \
		echo "Error: tag v$(VERSION) already exists"; exit 1; \
	fi
	@if [ -n "$$(git status --porcelain)" ]; then \
		echo "Error: working tree is dirty — commit first"; exit 1; \
	fi
	git tag -a "v$(VERSION)"
	git push origin "v$(VERSION)"
	@echo ""
	@echo "Tagged and pushed v$(VERSION) — release workflow started"
