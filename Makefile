.PHONY: generate build install clean release

XCODE_PROJECT = Shelve/Shelve.xcodeproj
BUILD_DIR = build
APP_NAME = Shelve.app
INSTALL_DIR = /Applications

generate:
	cd Shelve && xcodegen generate

build: generate
	xcodebuild -project $(XCODE_PROJECT) \
		-scheme Shelve \
		-configuration Release \
		-derivedDataPath $(BUILD_DIR) \
		build

install: build
	cp -R "$(BUILD_DIR)/Build/Products/Release/$(APP_NAME)" "$(INSTALL_DIR)/$(APP_NAME)"
	@echo ""
	@echo "Shelve installed to $(INSTALL_DIR)/$(APP_NAME)"
	@echo "Enable the extension: Safari > Settings > Extensions > Shelve"

release:
	./build-release.sh

clean:
	rm -rf $(BUILD_DIR) .build
	rm -rf $(XCODE_PROJECT)
