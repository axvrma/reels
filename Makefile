# Vibes App - Build Commands
# Usage: make <command>

.PHONY: run build apk bundle clean install verify help

# Default target
help:
	@echo "Vibes App Build Commands"
	@echo ""
	@echo "  make run       - Run debug build"
	@echo "  make apk       - Build release APK"
	@echo "  make bundle    - Build release App Bundle (Play Store)"
	@echo "  make install   - Install APK to connected device"
	@echo "  make clean     - Clean build artifacts"
	@echo "  make verify    - Verify bundle signature"
	@echo "  make icons     - Regenerate app icons"
	@echo ""

# Run debug build
run:
	flutter run

# Build release APK (universal)
apk:
	flutter build apk --release --obfuscate --split-debug-info=build/debug-info
	@echo ""
	@echo "APK built: build/app/outputs/flutter-apk/app-release.apk"

# Build release App Bundle for Play Store
bundle:
	flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info
	@echo ""
	@echo "Bundle built: build/app/outputs/bundle/release/app-release.aab"

# Build split APKs by architecture
apk-split:
	flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/debug-info
	@echo ""
	@echo "APKs built in: build/app/outputs/flutter-apk/"

# Install APK to connected device
install: apk
	adb install build/app/outputs/flutter-apk/app-release.apk

# Clean build artifacts
clean:
	flutter clean
	rm -rf build/debug-info

# Verify bundle/APK signature
verify:
	@echo "Verifying signature..."
	keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab 2>/dev/null | head -15

# Regenerate app icons
icons:
	source .venv/bin/activate && python3 scripts/generate_icons.py
	flutter pub run flutter_launcher_icons
	flutter pub run flutter_native_splash:create

# Get dependencies
deps:
	flutter pub get

# Analyze code
analyze:
	flutter analyze

# Run tests
test:
	flutter test
