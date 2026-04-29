#!/bin/bash
set -e

echo "Building CPPlayer Rust JNI backend module for arm64..."

# Require cargo-ndk
if ! command -v cargo-ndk &> /dev/null; then
    echo "Error: cargo-ndk is not installed. Please install it using: cargo install cargo-ndk"
    exit 1
fi

# Automatically set ANDROID_NDK_HOME if not set, assuming default Android Studio path on Linux
if [ -z "$ANDROID_NDK_HOME" ] && [ -d "$HOME/Android/Sdk/ndk" ]; then
    LATEST_NDK=$(ls -d $HOME/Android/Sdk/ndk/* | sort -V | tail -n 1)
    if [ -n "$LATEST_NDK" ]; then
        export ANDROID_NDK_HOME="$LATEST_NDK"
        echo "Set ANDROID_NDK_HOME to $ANDROID_NDK_HOME"
    fi
fi

# Set appropriate rust flags for Android NDK
export RUSTFLAGS="-Clink-arg=-Wl,-z,max-page-size=16384"

# Compile the project for arm64-v8a with the JNI feature
echo "Running cargo build..."
cargo ndk -t arm64-v8a -o ./target/jniLibs build --release --features jni

# Check if the .so was generated
# The library name might depend on your Cargo.toml, usually libncm_api_rs.so or similar.
# We will just find the built .so in the output directory.
SO_FILE=$(find ./target/jniLibs/arm64-v8a -name "*.so" | head -n 1)

if [ -z "$SO_FILE" ] || [ ! -f "$SO_FILE" ]; then
    echo "Error: Could not find compiled .so file in ./target/jniLibs/arm64-v8a"
    exit 1
fi

echo "Found library: $SO_FILE"

# Prepare packaging directory
MODULE_DIR="./target/cp_module"
rm -rf "$MODULE_DIR"
mkdir -p "$MODULE_DIR"

# Copy the .so file
cp "$SO_FILE" "$MODULE_DIR/libcp_api.so"

# Create manifest.json
cat <<EOF > "$MODULE_DIR/manifest.json"
{
  "id": "cp.provider.rust.default",
  "name": "Default Rust NCM Provider",
  "version": "1.0.0",
  "type": "jni",
  "entryPoint": "libcp_api.so",
  "apiMap": {}
}
EOF

# Zip the module
echo "Packaging module to ./target/cp_rust_provider.zip..."
cd "$MODULE_DIR"
zip -r ../cp_rust_provider.zip ./*
cd ../..

echo "✅ Module built successfully: ./target/cp_rust_provider.zip"
echo "You can now import this .zip file directly into the CPPlayer App."
