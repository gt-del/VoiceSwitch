#!/bin/sh
set -eu

PACKAGE_DIR="$1"
OUTPUT_DIR="$2"
SHELL_CANDIDATE="${SHELL:-/bin/zsh}"

if [ -n "${HOME:-}" ]; then
  export PATH="$HOME/.cargo/bin:$PATH"
fi

cargo_bin="$(command -v cargo 2>/dev/null || true)"

if [ -z "$cargo_bin" ] && [ -x "$SHELL_CANDIDATE" ]; then
  cargo_bin="$("$SHELL_CANDIDATE" -lc 'command -v cargo' 2>/dev/null || true)"
fi

if [ -z "$cargo_bin" ] && [ -x /bin/zsh ]; then
  cargo_bin="$(/bin/zsh -lc 'command -v cargo' 2>/dev/null || true)"
fi

if [ -z "$cargo_bin" ] || [ ! -x "$cargo_bin" ]; then
  echo "error: cargo not found; install Rust or expose cargo in your login shell PATH before building VoiceSwitch FFI" >&2
  exit 1
fi

export PATH="$(dirname "$cargo_bin"):$PATH"

"$cargo_bin" build \
  --target-dir "$OUTPUT_DIR/rust-target" \
  --manifest-path "$PACKAGE_DIR/RustCore/Cargo.toml" \
  --lib

mkdir -p "$OUTPUT_DIR"
cp "$OUTPUT_DIR/rust-target/debug/libvoiceswitch_core.a" "$OUTPUT_DIR/libvoiceswitch_core.a"
printf "built\n" > "$OUTPUT_DIR/rust-ffi.stamp"
