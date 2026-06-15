#!/usr/bin/env bash
#
# Build a release IPA for App Store / TestFlight distribution.
#
# Usage:
#   ./scripts/ios_appstore_build.sh
#   ./scripts/ios_appstore_build.sh --upload
#   ./scripts/ios_appstore_build.sh --build-name 1.0.1 --build-number 2
#   ./scripts/ios_appstore_build.sh --upload --env-file scripts/ios_release.env
#
# Prerequisites (one-time):
#   1. Apple Developer Program membership
#   2. App record in App Store Connect for bundle id com.mollyexpenses.mollyExpenses
#   3. Open ios/Runner.xcworkspace in Xcode once and enable automatic signing
#   4. Firebase iOS config: ios/Runner/GoogleService-Info.plist
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BUNDLE_ID="com.mollyexpenses.mollyExpenses"
TEAM_ID="NEUU9JKC4B"
EXPORT_PLIST="$ROOT_DIR/ios/ExportOptions.plist"
DIST_DIR="$ROOT_DIR/dist/ios"
ENV_FILE=""
DO_UPLOAD=0
DO_CLEAN=1
BUILD_NAME=""
BUILD_NUMBER=""

usage() {
  sed -n '3,12p' "$0"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --upload)
      DO_UPLOAD=1
      shift
      ;;
    --skip-clean)
      DO_CLEAN=0
      shift
      ;;
    --build-name)
      BUILD_NAME="${2:-}"
      shift 2
      ;;
    --build-number)
      BUILD_NUMBER="${2:-}"
      shift 2
      ;;
    --env-file)
      ENV_FILE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

require_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Error: iOS builds must run on macOS with Xcode installed." >&2
    exit 1
  fi
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: Required command not found: $1" >&2
    exit 1
  fi
}

preflight() {
  require_macos
  require_command flutter
  require_command xcodebuild

  if [[ ! -f "$ROOT_DIR/ios/Runner/GoogleService-Info.plist" ]]; then
    echo "Error: Missing ios/Runner/GoogleService-Info.plist" >&2
    echo "Run: dart pub global run flutterfire_cli:flutterfire configure --project=molly-expenses --platforms=ios" >&2
    exit 1
  fi

  if [[ ! -f "$EXPORT_PLIST" ]]; then
    echo "Error: Missing $EXPORT_PLIST" >&2
    exit 1
  fi

  if ! xcodebuild -version >/dev/null 2>&1; then
    echo "Error: Xcode command line tools are not available." >&2
    exit 1
  fi

  echo "==> Flutter doctor (ios toolchain)"
  flutter doctor -v | sed -n '1,40p'
  echo
}

prepare_project() {
  echo "==> Installing Dart dependencies"
  flutter pub get

  if [[ "$DO_CLEAN" -eq 1 ]]; then
    echo "==> Cleaning previous builds"
    flutter clean
    flutter pub get
  fi

  mkdir -p "$DIST_DIR"
}

build_ipa() {
  local build_args=(build ipa --release --export-options-plist="$EXPORT_PLIST")

  if [[ -n "$BUILD_NAME" ]]; then
    build_args+=(--build-name="$BUILD_NAME")
  fi
  if [[ -n "$BUILD_NUMBER" ]]; then
    build_args+=(--build-number="$BUILD_NUMBER")
  fi

  echo "==> Building App Store IPA"
  echo "    Bundle ID : $BUNDLE_ID"
  echo "    Team ID   : $TEAM_ID"
  flutter "${build_args[@]}"
}

copy_artifacts() {
  local ipa_source=""
  if compgen -G "$ROOT_DIR/build/ios/ipa/"*.ipa >/dev/null; then
    ipa_source="$(ls -t "$ROOT_DIR/build/ios/ipa/"*.ipa | head -n 1)"
  elif compgen -G "$ROOT_DIR/build/ios/ipa/"*.IPA >/dev/null; then
    ipa_source="$(ls -t "$ROOT_DIR/build/ios/ipa/"*.IPA | head -n 1)"
  else
    echo "Error: IPA not found in build/ios/ipa/" >&2
    exit 1
  fi

  local timestamp
  timestamp="$(date +%Y%m%d-%H%M%S)"
  local version
  version="$(grep '^version:' pubspec.yaml | awk '{print $2}')"
  local ipa_dest="$DIST_DIR/molly-expenses-${version}-${timestamp}.ipa"

  cp "$ipa_source" "$ipa_dest"
  ln -sf "$(basename "$ipa_dest")" "$DIST_DIR/molly-expenses-latest.ipa"

  echo
  echo "Build complete."
  echo "  IPA: $ipa_dest"
  echo "  Latest symlink: $DIST_DIR/molly-expenses-latest.ipa"
  echo
  echo "Next steps:"
  echo "  1. Upload with Transporter app, or run:"
  echo "       ./scripts/ios_appstore_build.sh --upload --env-file scripts/ios_release.env"
  echo "  2. In App Store Connect, add build to TestFlight / submit for review"
}

upload_ipa() {
  local ipa_path="$DIST_DIR/molly-expenses-latest.ipa"
  if [[ ! -f "$ipa_path" ]]; then
    echo "Error: No IPA found at $ipa_path" >&2
    exit 1
  fi

  if [[ -n "$ENV_FILE" && -f "$ENV_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE"
  fi

  echo "==> Uploading IPA to App Store Connect"

  if [[ -n "${APP_STORE_CONNECT_API_KEY_ID:-}" && -n "${APP_STORE_CONNECT_ISSUER_ID:-}" && -n "${APP_STORE_CONNECT_API_KEY_PATH:-}" ]]; then
    require_command xcrun
    xcrun altool --upload-app \
      --type ios \
      --file "$ipa_path" \
      --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
      --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID"
    return
  fi

  if [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
    require_command xcrun
    xcrun altool --upload-app \
      --type ios \
      --file "$ipa_path" \
      --username "$APPLE_ID" \
      --password "$APPLE_APP_SPECIFIC_PASSWORD"
    return
  fi

  echo "Error: Upload credentials not configured." >&2
  echo "Copy scripts/ios_release.env.example to scripts/ios_release.env and fill in credentials." >&2
  exit 1
}

main() {
  preflight
  prepare_project
  build_ipa
  copy_artifacts

  if [[ "$DO_UPLOAD" -eq 1 ]]; then
    upload_ipa
    echo "Upload finished."
  fi
}

main "$@"
