#!/bin/bash
#
# Generate dSYMs for embedded frameworks that ship WITHOUT one — notably Flutter
# native-asset / FFI frameworks like objective_c.framework (pulled in by
# path_provider_foundation). Those binaries are stripped, so neither the Xcode
# build settings nor the Podfile can emit a dSYM for them, and App Store Connect
# then warns "Upload Symbols Failed … did not include a dSYM for …".
#
# This runs as a Run Script build phase on the Runner target. During an Archive
# it writes a UUID-matching dSYM for any embedded framework still missing one
# into the archive's dSYM folder, which silences the warning. (Because the
# frameworks ship stripped the dSYM is symbol-table-level, not full DWARF, but
# it satisfies the upload check and gives function-name symbolication.)
#
# No-op for Debug / non-archive builds (no dSYM folder to write into).
set -euo pipefail

# Only act when Xcode is producing dSYMs (Release/Profile archive).
if [ "${DEBUG_INFORMATION_FORMAT:-}" != "dwarf-with-dsym" ]; then
  echo "generate_dsyms: DEBUG_INFORMATION_FORMAT is '${DEBUG_INFORMATION_FORMAT:-}', skipping."
  exit 0
fi

DSYM_DIR="${DWARF_DSYM_FOLDER_PATH:-}"
FRAMEWORKS_DIR="${TARGET_BUILD_DIR:-}/${FRAMEWORKS_FOLDER_PATH:-}"

if [ -z "${DSYM_DIR}" ] || [ ! -d "${FRAMEWORKS_DIR}" ]; then
  echo "generate_dsyms: no dSYM folder or frameworks dir, skipping."
  exit 0
fi

mkdir -p "${DSYM_DIR}"

shopt -s nullglob
for framework in "${FRAMEWORKS_DIR}"/*.framework; do
  name="$(basename "${framework}" .framework)"
  binary="${framework}/${name}"
  [ -f "${binary}" ] || continue

  target_dsym="${DSYM_DIR}/${name}.framework.dSYM"
  if [ -d "${target_dsym}" ]; then
    continue  # Xcode/CocoaPods already produced one.
  fi

  echo "generate_dsyms: creating dSYM for ${name}.framework"
  dsymutil "${binary}" -o "${target_dsym}" 2>/dev/null || \
    echo "generate_dsyms: dsymutil could not process ${name} (continuing)."
done

# Also cover the app itself (Runner.app). Its dSYM normally comes straight from
# the Xcode archive (Release is dwarf-with-dsym); this is a safety net for when
# it's missing, so App Store Connect stops warning about Runner.app. Skipped
# when Xcode already produced the real (full-DWARF) one.
app_dsym="${DSYM_DIR}/${WRAPPER_NAME:-Runner.app}.dSYM"
app_binary="${TARGET_BUILD_DIR:-}/${EXECUTABLE_PATH:-}"
if [ ! -d "${app_dsym}" ] && [ -f "${app_binary}" ]; then
  echo "generate_dsyms: creating dSYM for ${WRAPPER_NAME:-Runner.app}"
  dsymutil "${app_binary}" -o "${app_dsym}" 2>/dev/null || \
    echo "generate_dsyms: dsymutil could not process the app binary (continuing)."
fi

echo "generate_dsyms: done."
