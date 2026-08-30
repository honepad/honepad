#!/usr/bin/env bash
# Install Scala 2.13.16 (same pin as CI coursier/setup-action) when scalac is missing.
# Usage: ensure-scala.sh
# Exit 0 installed-or-present, 1 hard fail.
set -euo pipefail

SCALA_VER="2.13.16"
echo "PLAN: ensure scalac ${SCALA_VER} is on PATH"

coursier_bins() {
  printf '%s\n' \
    "${HOME}/Library/Application Support/Coursier/bin" \
    "${HOME}/.local/share/coursier/bin"
}

find_tool() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    command -v "$name"
    return 0
  fi
  local dir
  while IFS= read -r dir; do
    if [[ -x "${dir}/${name}" ]]; then
      echo "${dir}/${name}"
      return 0
    fi
  done < <(coursier_bins)
  return 1
}

prepend_bin() {
  local dir="$1"
  case ":${PATH}:" in
    *":${dir}:"*) ;;
    *) export PATH="${dir}:${PATH}" ;;
  esac
}

if scalac_path="$(find_tool scalac)" && scala_path="$(find_tool scala)"; then
  prepend_bin "$(dirname "$scalac_path")"
  echo "OK: scalac=${scalac_path}"
  echo "OK: scala=${scala_path}"
  echo "DONE: ok=true installed=false"
  echo "NEXT: none"
  exit 0
fi

cs_cmd() {
  if command -v cs >/dev/null 2>&1; then
    echo cs
    return 0
  fi
  if command -v coursier >/dev/null 2>&1; then
    echo coursier
    return 0
  fi
  return 1
}

echo "DO: install coursier if needed"
if ! launcher="$(cs_cmd)"; then
  if command -v brew >/dev/null 2>&1; then
    echo "DO: brew install coursier"
    HOMEBREW_NO_AUTO_UPDATE=1 brew install coursier
  else
    echo "DO: download cs launcher"
    tmp="$(mktemp -d)"
    arch="$(uname -m)"
    os="$(uname -s)"
    case "${os}-${arch}" in
      Darwin-arm64) asset="cs-aarch64-apple-darwin.gz" ;;
      Darwin-x86_64) asset="cs-x86_64-apple-darwin.gz" ;;
      Linux-aarch64) asset="cs-aarch64-pc-linux.gz" ;;
      Linux-x86_64) asset="cs-x86_64-pc-linux.gz" ;;
      *)
        echo "FAIL: no coursier launcher for ${os}-${arch}"
        echo "DONE: ok=false error=unsupported-arch"
        echo "NEXT: install Scala ${SCALA_VER} by hand"
        exit 1
        ;;
    esac
    url="https://github.com/coursier/launchers/raw/master/${asset}"
    curl -fsSL "$url" | gzip -d >"${tmp}/cs"
    chmod +x "${tmp}/cs"
    dest="${HOME}/.local/share/coursier/bin"
    mkdir -p "$dest"
    mv "${tmp}/cs" "${dest}/cs"
    prepend_bin "$dest"
    echo "OK: cs=${dest}/cs"
  fi
  if ! launcher="$(cs_cmd)"; then
    echo "FAIL: coursier launcher still missing"
    echo "DONE: ok=false error=no-cs"
    echo "NEXT: install coursier and retry"
    exit 1
  fi
fi

echo "DO: ${launcher} install scala:${SCALA_VER} scalac:${SCALA_VER}"
"$launcher" install "scala:${SCALA_VER}" "scalac:${SCALA_VER}"

bin=""
if scalac_path="$(find_tool scalac)"; then
  bin="$(dirname "$scalac_path")"
  prepend_bin "$bin"
fi
if ! find_tool scalac >/dev/null || ! find_tool scala >/dev/null; then
  echo "FAIL: scalac or scala still missing after cs install"
  echo "DONE: ok=false error=install-missed"
  echo "NEXT: add Coursier bin to PATH and retry"
  exit 1
fi

echo "OK: scalac=$(find_tool scalac)"
echo "OK: scala=$(find_tool scala)"
echo "DONE: ok=true installed=true bin=${bin}"
echo "NEXT: none"
exit 0
