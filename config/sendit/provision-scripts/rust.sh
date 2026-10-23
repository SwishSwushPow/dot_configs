#!/bin/bash
# Installs Rust with rustup. rustup adds ~/.cargo/bin to the PATH in
# ~/.profile, so the commands after `sendit-provision rust.sh` find cargo.

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs |
    sh -s -- -y --profile minimal -c clippy -c rustfmt

# Target dir for Rust project
LINE='export CARGO_TARGET_DIR=/home/dev/rust-build'
FILE="$HOME/.profile"
grep -qxF "$LINE" "$FILE" || echo "$LINE" >> "$FILE"
