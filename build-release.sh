#!/bin/bash
set -euo pipefail

# Load signing config from .env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/.env" ]]; then
    source "${SCRIPT_DIR}/.env"
else
    echo "Error: .env file not found. Copy .env.example to .env and fill in your values."
    exit 1
fi

if [[ -z "${SIGNING_IDENTITY:-}" ]]; then
    echo "Error: SIGNING_IDENTITY not set in .env"
    exit 1
fi
if [[ -z "${KEYCHAIN_PROFILE:-}" ]]; then
    echo "Error: KEYCHAIN_PROFILE not set in .env"
    exit 1
fi
if [[ -z "${TEAM_ID:-}" ]]; then
    echo "Error: TEAM_ID not set in .env"
    exit 1
fi

APP_NAME="Shelve"
BINARY_NAME="shelve"
PROJECT_DIR="Shelve"
BUNDLE_ID="com.muchbetteradventures.shelve.app"

# --- Auto-version from conventional commits ---

LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
CURRENT_VERSION="${LATEST_TAG#v}"

IFS='.' read -r MAJOR MINOR PATCH <<< "${CURRENT_VERSION}"

COMMITS=$(git log "${LATEST_TAG}..HEAD" --pretty=format:"%s" 2>/dev/null || git log --pretty=format:"%s")

BUMP="patch"
while IFS= read -r msg; do
    if echo "$msg" | grep -qiE "^breaking[:(]|^[a-z]+!:"; then
        BUMP="major"
        break
    elif echo "$msg" | grep -qiE "^feat[:(]"; then
        BUMP="minor"
    fi
done <<< "$COMMITS"

case "$BUMP" in
    major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
    minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
    patch) PATCH=$((PATCH + 1)) ;;
esac

VERSION="${MAJOR}.${MINOR}.${PATCH}"
echo "==> Version bump: ${CURRENT_VERSION} -> ${VERSION} (${BUMP})"

# Commit any pending changes and tag
if ! git diff --quiet HEAD 2>/dev/null; then
    git add .env.example build-release.sh Makefile Shelve/ ExportOptions.plist.template
    git commit -m "release: v${VERSION}"
fi
git tag "v${VERSION}"

echo "==> Tagged v${VERSION}"

# --- Generate ExportOptions.plist from template ---

echo "==> Generating ExportOptions.plist..."
cat > ExportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>developer-id</string>
	<key>teamID</key>
	<string>${TEAM_ID}</string>
	<key>signingStyle</key>
	<string>manual</string>
	<key>provisioningProfiles</key>
	<dict>
		<key>${BUNDLE_ID}</key>
		<string>Shelve App Provisioning</string>
		<key>${BUNDLE_ID}.extension</key>
		<string>Shelve App Extension Provisioning</string>
	</dict>
	<key>signingCertificate</key>
	<string>Developer ID Application</string>
</dict>
</plist>
PLIST

# --- Generate Xcode project ---

echo "==> Injecting TEAM_ID into project.yml..."
sed -i '' "s/DEVELOPMENT_TEAM: \"\"/DEVELOPMENT_TEAM: \"${TEAM_ID}\"/" "${PROJECT_DIR}/project.yml"

echo "==> Generating Xcode project..."
cd "${PROJECT_DIR}"
xcodegen generate
cd "${SCRIPT_DIR}"

# Restore project.yml (keep team ID out of git)
sed -i '' "s/DEVELOPMENT_TEAM: \"${TEAM_ID}\"/DEVELOPMENT_TEAM: \"\"/" "${PROJECT_DIR}/project.yml"

# --- Archive & Export (Developer ID) ---

ARCHIVE_PATH=".build/${APP_NAME}.xcarchive"
EXPORT_DIR=".build/export"

echo "==> Archiving..."
xcodebuild -project "${PROJECT_DIR}/${APP_NAME}.xcodeproj" \
    -scheme "${APP_NAME}" \
    -configuration Release \
    -archivePath "${ARCHIVE_PATH}" \
    DEVELOPMENT_TEAM="${TEAM_ID}" \
    archive

echo "==> Exporting with Developer ID signing..."
xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportPath "${EXPORT_DIR}" \
    -exportOptionsPlist ExportOptions.plist

APP_PATH="${EXPORT_DIR}/${APP_NAME}.app"

if [[ ! -d "${APP_PATH}" ]]; then
    echo "Error: Export product not found at ${APP_PATH}"
    exit 1
fi

echo "==> Verifying signature..."
codesign --verify --verbose --deep "${APP_PATH}"

# --- Package ---

DMG_NAME="${BINARY_NAME}-${VERSION}.dmg"
TAR_NAME="${BINARY_NAME}-${VERSION}.tar.gz"

echo "==> Creating ${DMG_NAME}..."
STAGING_DIR=$(mktemp -d)
cp -R "${APP_PATH}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

rm -f "${DMG_NAME}"
hdiutil create -volname "${APP_NAME} ${VERSION}" \
    -srcfolder "${STAGING_DIR}" \
    -ov -format UDZO \
    "${DMG_NAME}"
rm -rf "${STAGING_DIR}"

echo "==> Signing .dmg..."
codesign --sign "${SIGNING_IDENTITY}" "${DMG_NAME}"

echo "==> Creating ${TAR_NAME} for Homebrew..."
tar -czf "${TAR_NAME}" -C "${EXPORT_DIR}" "${APP_NAME}.app"

# --- Notarize ---

echo "==> Submitting .dmg for notarization (this may take a minute)..."
xcrun notarytool submit "${DMG_NAME}" \
    --keychain-profile "${KEYCHAIN_PROFILE}" \
    --wait

echo "==> Waiting for ticket propagation..."
sleep 15

echo "==> Stapling notarization ticket to .dmg..."
xcrun stapler staple "${DMG_NAME}"

echo ""
echo "==> Build complete. v${VERSION}"
echo "  App bundle:       ${APP_PATH}"
echo "  DMG:              ${DMG_NAME}"
echo "  Homebrew tarball:  ${TAR_NAME}"

# --- Publish ---

echo ""
echo "==> Merging to main and pushing..."
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "${CURRENT_BRANCH}" != "main" ]]; then
    git checkout main
    git merge "${CURRENT_BRANCH}" --no-edit
fi
git push origin main --tags

echo "==> Creating GitHub release..."
gh release create "v${VERSION}" "${DMG_NAME}" "${TAR_NAME}" \
    --title "v${VERSION}" --generate-notes

# --- Update Homebrew tap ---

TAP_REPO="${TAP_REPO:-${HOME}/Experimental/homebrew-tap}"
CASK="${TAP_REPO}/Casks/shelve.rb"

if [[ -f "${CASK}" ]]; then
    echo "==> Updating Homebrew cask..."
    SHA=$(shasum -a 256 "${DMG_NAME}" | awk '{print $1}')
    sed -i '' "s/version \".*\"/version \"${VERSION}\"/" "${CASK}"
    sed -i '' "s/sha256 \".*\"/sha256 \"${SHA}\"/" "${CASK}"
    git -C "${TAP_REPO}" add Casks/shelve.rb
    git -C "${TAP_REPO}" commit -m "shelve ${VERSION}"
    git -C "${TAP_REPO}" push origin main
    echo "==> Homebrew tap updated"
else
    echo "Warning: cask not found at ${CASK}, skipping tap update"
fi

echo ""
echo "==> Released v${VERSION}"
