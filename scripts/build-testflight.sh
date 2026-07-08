#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_NUMBER_FILE="${SCRIPT_DIR}/build-testflight-number.txt"

if [[ ! -f "${BUILD_NUMBER_FILE}" ]]; then
    printf "17\n" > "${BUILD_NUMBER_FILE}"
fi

LAST_BUILD_NUMBER="$(tr -d '[:space:]' < "${BUILD_NUMBER_FILE}")"
if [[ ! "${LAST_BUILD_NUMBER}" =~ ^[0-9]+$ ]]; then
    echo "Invalid build number in ${BUILD_NUMBER_FILE}: ${LAST_BUILD_NUMBER}" >&2
    exit 1
fi

BUILD_NUMBER=$((LAST_BUILD_NUMBER + 1))

cd "${REPO_ROOT}"

echo "Starting TestFlight build ${BUILD_NUMBER}"

python3 build-system/Make/Make.py \
    --overrideXcodeVersion \
    build \
    --buildNumber "${BUILD_NUMBER}" \
    --configurationPath build-system/appstore-configuration.json \
    --codesigningInformationPath my-codesigning \
    --configuration release_arm64 \
    --outputBuildArtifactsPath ./TestFlightBuild

printf "%s\n" "${BUILD_NUMBER}" > "${BUILD_NUMBER_FILE}"
