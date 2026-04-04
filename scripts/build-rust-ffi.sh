#!/bin/sh
set -eu

PACKAGE_DIR="$1"
OUTPUT_DIR="$2"
if [ -n "${HOME:-}" ]; then
  export PATH="$HOME/.cargo/bin:$PATH"
fi

if ! command -v cargo >/dev/null 2>&1; then
  if [ -x "/Users/didi/.cargo/bin/cargo" ]; then
    export PATH="/Users/didi/.cargo/bin:$PATH"
  fi
fi

cargo build \
  --target-dir "$OUTPUT_DIR/rust-target" \
  --manifest-path "$PACKAGE_DIR/RustCore/Cargo.toml" \
  --lib

mkdir -p "$OUTPUT_DIR"
cp "$OUTPUT_DIR/rust-target/debug/libvoiceswitch_core.a" "$OUTPUT_DIR/libvoiceswitch_core.a"
printf "built\n" > "$OUTPUT_DIR/rust-ffi.stamp"
