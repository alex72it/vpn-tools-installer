#!/usr/bin/env bash
set -euo pipefail

REPO="alex72it/vpn-tools-installer"
VERSION="latest"
BIN_NAME="vpn-opt"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Ошибка: не найдена команда '$1'"
    exit 1
  }
}

detect_arch() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) echo "linux-amd64" ;;
    aarch64|arm64) echo "linux-arm64" ;;
    *)
      echo "Неподдерживаемая архитектура: $arch"
      exit 1
      ;;
  esac
}

main() {
  need_cmd curl
  need_cmd chmod
  need_cmd mktemp
  need_cmd install
  need_cmd sha256sum

  local suffix url sha_url tmpdir bin_path sha_path expected actual
  suffix="$(detect_arch)"

  if [[ "$VERSION" == "latest" ]]; then
    url="https://github.com/${REPO}/releases/latest/download/${BIN_NAME}-${suffix}"
    sha_url="https://github.com/${REPO}/releases/latest/download/${BIN_NAME}-${suffix}.sha256"
  else
    url="https://github.com/${REPO}/releases/download/${VERSION}/${BIN_NAME}-${suffix}"
    sha_url="https://github.com/${REPO}/releases/download/${VERSION}/${BIN_NAME}-${suffix}.sha256"
  fi

  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT

  bin_path="$tmpdir/${BIN_NAME}"
  sha_path="$tmpdir/${BIN_NAME}.sha256"

  echo "[1/4] Скачиваю бинарник..."
  curl -fsSL "$url" -o "$bin_path"

  echo "[2/4] Скачиваю checksum..."
  curl -fsSL "$sha_url" -o "$sha_path"

  echo "[3/4] Проверяю checksum..."
  expected="$(awk '{print $1}' "$sha_path")"
  actual="$(sha256sum "$bin_path" | awk '{print $1}')"

  if [[ "$expected" != "$actual" ]]; then
    echo "Ошибка: checksum не совпадает"
    echo "Ожидалось: $expected"
    echo "Получено:  $actual"
    exit 1
  fi

  echo "[4/4] Устанавливаю в /usr/local/bin/${BIN_NAME} ..."
  install -m 0755 "$bin_path" "/usr/local/bin/${BIN_NAME}"

  echo
  echo "Готово: /usr/local/bin/${BIN_NAME}"
  echo "Запускаю..."

  if [ -t 0 ] && [ -t 1 ]; then
    exec /usr/local/bin/${BIN_NAME}
  elif [ -e /dev/tty ]; then
    exec </dev/tty >/dev/tty 2>/dev/tty /usr/local/bin/${BIN_NAME}
  else
    echo "Установлено, но интерактивный запуск невозможен без терминала."
    echo "Запустите вручную: /usr/local/bin/${BIN_NAME}"
    exit 0
  fi
}

main "$@"
