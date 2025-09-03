#!/bin/bash
set -e

NEOVIM_DIR="./neovim"

echo "Cleaning previous build..."
cd "$NEOVIM_DIR"
make distclean || true

# Optimization flags
export CC=cc
export CFLAGS="-O3 -march=native -flto -fomit-frame-pointer -DNDEBUG"
export CXXFLAGS="-O3 -march=native -flto -fomit-frame-pointer -DNDEBUG"
export LDFLAGS="-flto"

# Build Neovim with optimizations
echo "Building Neovim with optimizations (using bundled deps)..."
make CMAKE_BUILD_TYPE=Release \
  CMAKE_C_FLAGS="$CFLAGS" \
  CMAKE_CXX_FLAGS="$CXXFLAGS" \
  CMAKE_EXE_LINKER_FLAGS="$LDFLAGS -fuse-ld=mold" \
  ENABLE_JEMALLOC=ON \
  -j$(nproc)

# Package into .deb
echo "✅ Generating Debian package with CPack..."
cd build
cpack -G DEB
echo "✅ Build and package complete. .deb file is inside build/"
sudo dpkg -i nvim-linux-x86_64.deb
echo "✅ Installed Neovim"
