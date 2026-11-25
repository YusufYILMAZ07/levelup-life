#!/usr/bin/env bash
# CEYYUS · Vercel ücretsiz build betiği.
#
# Vercel'in Node build imajında Flutter SDK yoktur. Bu betik pinlenmiş
# Flutter stable sürümünü indirir, web derlemesini üretir ve `build/web`
# çıktısını bırakır (vercel.json → outputDirectory).
#
# Yerelde aynı komut: `flutter build web --release`.
# Sürümü değiştirmek için: FLUTTER_VERSION=3.41.9 (varsayılan).
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.41.9}"
FLUTTER_DIR="${PWD}/.flutter-sdk"
ARCHIVE="${PWD}/flutter-sdk.tar.xz"

if [ ! -x "${FLUTTER_DIR}/bin/flutter" ]; then
  echo "→ Flutter ${FLUTTER_VERSION} indiriliyor…"
  curl -fsSL \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    -o "${ARCHIVE}"
  mkdir -p "${FLUTTER_DIR}"
  tar -xf "${ARCHIVE}" -C "${FLUTTER_DIR}" --strip-components=1
  rm -f "${ARCHIVE}"
fi

export PATH="${FLUTTER_DIR}/bin:${PATH}"
git config --global --add safe.directory "${FLUTTER_DIR}" || true

flutter --version
flutter config --enable-web
flutter pub get
flutter build web --release
