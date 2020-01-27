#!/bin/bash

set -eo pipefail
PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/dev/null 2>&1 && pwd )"
BUILD_DIR="$PROJECT_DIR/build"

LOVE_VER_WIN="11.3"
LOVE_VER_NX="11.2-nx2"
APP_NAME="picolove"
APP_AUTHOR="p-sam"
APP_VERSION="$(cd "$PROJECT_DIR" && git describe --dirty --always --tags)"

function http_download() {
	if [[ -f "$2" ]]; then
		return 0
	fi

	echo "- Downloading $(basename -- "$2") ..."

	RC=""
	if [[ -n "$(which wget)" ]]; then
		wget "$1" -O "$2" || RC=$?
	elif [[ -n "$(which curl)" ]]; then
		curl --fail "$1" > "$2" || RC=$?
	else
		echo "No suitable download tool found in PATH" 1>&2
		return 127
	fi
	if [[ -n "$RC" ]]; then
		echo "Download failed" 1>&2
		rm -f "$2"
		return $RC
	fi
}

function sed_escape() {
	echo "$1" | sed -e 's/\\/\\\\/g; s/\//\\\//g; s/&/\\\&/g'
}

mkdir -p "${BUILD_DIR}"

echo "* Packaging ${APP_NAME}.love"
cd "${PROJECT_DIR}"
zip -9 -r -x@pkg/ignore.txt "${BUILD_DIR}/${APP_NAME}.love" .

if [[ "$1" == "windows" || "$1" == "win" || "$1" == "all" ]]; then
	echo "* Packaging for Windows"
	mkdir -p "${BUILD_DIR}/win"
	http_download "https://bitbucket.org/rude/love/downloads/love-${LOVE_VER_WIN}-win64.zip" "${BUILD_DIR}/win/love-${LOVE_VER_WIN}-win64.zip"
	unzip -u -o -q -d "${BUILD_DIR}/win" "${BUILD_DIR}/win/love-${LOVE_VER_WIN}-win64.zip"
	mkdir -p "${BUILD_DIR}/win/publish"
	cp -f "${BUILD_DIR}/win/love-${LOVE_VER_WIN}-win64"/*.dll "${BUILD_DIR}/win/publish"
	cp -f "${BUILD_DIR}/win/love-${LOVE_VER_WIN}-win64/license.txt" "${BUILD_DIR}/win/publish/LOVE_LICENSE.txt"
	cp -f "${PROJECT_DIR}/LICENSE.md" "${PROJECT_DIR}/README.md" "${BUILD_DIR}/win/publish"

	cat "${BUILD_DIR}/win/love-${LOVE_VER_WIN}-win64/love.exe" "${BUILD_DIR}/${APP_NAME}.love" > "${BUILD_DIR}/win/publish/${APP_NAME}.exe"

	echo "- Packaging ${APP_NAME}-${APP_VERSION}-win64.zip"
	cd "${BUILD_DIR}/win/publish"
	zip -9 -r "${BUILD_DIR}/${APP_NAME}-${APP_VERSION}-win64.zip" .
fi

if [[ "$1" == "switch" || "$1" == "nx" || "$1" == "all" ]]; then
	echo "* Packaging for Switch"
	if [[ -z "$DEVKITPRO" ]]; then
		echo "DEVKITPRO env var seems to be missing." 1>&2
		echo "Check out https://switchbrew.org/wiki/Setting_up_Development_Environment for more info." 1>&2
		exit 1
	fi

	mkdir -p "${BUILD_DIR}/nx"
	http_download "https://github.com/retronx-team/love-nx/releases/download/${LOVE_VER_NX}/love.elf" "${BUILD_DIR}/nx/love-${LOVE_VER_NX}.elf"

	mkdir -p "${BUILD_DIR}/nx/romfs"
	cp -f "${BUILD_DIR}/${APP_NAME}.love" "${BUILD_DIR}/nx/romfs/game.love"

	mkdir -p "${BUILD_DIR}/nx/publish"
	"$DEVKITPRO/tools/bin/nacptool" --create "$APP_NAME" "$APP_AUTHOR" "$APP_VERSION" "${BUILD_DIR}/nx/${APP_NAME}.nacp"
	"$DEVKITPRO/tools/bin/elf2nro" "${BUILD_DIR}/nx/love-${LOVE_VER_NX}.elf" "${BUILD_DIR}/nx/publish/${APP_NAME}.nro" \
		--icon="${PROJECT_DIR}/pkg/nx_icon.jpg" --nacp="${BUILD_DIR}/nx/${APP_NAME}.nacp" --romfsdir="${BUILD_DIR}/nx/romfs"

	echo "- Packaging ${APP_NAME}-${APP_VERSION}-nx.zip"
	cd "${BUILD_DIR}/nx/publish"
	zip -9 -r "${BUILD_DIR}/${APP_NAME}-${APP_VERSION}-nx.zip" .
fi
