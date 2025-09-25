# Makefile for Neovim build and packaging

NEOVIM_DIR := ./neovim
BUILD_DIR := ./neovim/build
NEOVIM_BIN := $(BUILD_DIR)/bin/nvim
# Assuming this is the default package name, adjust if needed
DEB_PACKAGE := $(BUILD_DIR)/nvim-linux-x86_64.deb

# Use `gcc` and `g++` by default, but allow overriding from the environment
CC ?= /usr/bin/gcc
CXX ?= /usr/bin/g++

# Optimization flags for a release build.
# -O3: Highest level of optimization.
# -march=native: Optimize for the current host CPU.
# -flto: Enable Link-Time Optimization for better whole-program optimization.
# -fomit-frame-pointer: Frees up a register, can make debugging slightly harder.
# -fschedule-insns2: Use a more aggressive instruction scheduler (GCC-specific).
# -ffast-math: Allow aggressive floating-point optimizations.
# -DNDEBUG: Disable assertions and other debug code.
OPTIMIZATION_FLAGS := -O3 -march=native -flto -fomit-frame-pointer -fschedule-insns2 -DNDEBUG

# Linker flags.
# -fuse-ld=mold: Use the fast `mold` linker if available.
# -Wl,--gc-sections: Remove unused code sections.
LDFLAGS := -flto -fuse-ld=mold -Wl,--gc-sections

# --- CMake Definitions ---
# Combine all CMake definitions for clarity. These are passed to both the main
# build and the dependency builds.
CMAKE_DEFS_RELEASE := \
    -DCMAKE_C_FLAGS="$(OPTIMIZATION_FLAGS)" \
    -DCMAKE_CXX_FLAGS="$(OPTIMIZATION_FLAGS)" \
    -DCMAKE_EXE_LINKER_FLAGS="$(LDFLAGS)" \
    -DENABLE_JEMALLOC=$(ENABLE_JEMALLOC)

.PHONY: all clean distclean build_release build_debug strip package install uninstall

# Default target: build, package, and install the release version.
all: install

# Proper dependency chain: install -> package -> build_release
install: package
	@echo "Installing Neovim package..."
	sudo dpkg -i $(DEB_PACKAGE)
	@echo "✅ Installed Neovim"

package: build_release
	@echo "Generating Debian package with CPack..."
	cd $(BUILD_DIR) && cpack -G DEB

build_release:
	@echo "Building Neovim Release build with optimizations..."
	cd $(NEOVIM_DIR) && \
	CC="$(CC)" \
	CXX="$(CXX)" \
	CMAKE_BUILD_TYPE=Release \
	CMAKE_EXTRA_FLAGS='$(CMAKE_DEFS_RELEASE)' \
	DEPS_CMAKE_FLAGS='$(CMAKE_DEFS_RELEASE)' \
	make -j$(shell nproc)
	@$(MAKE) strip


build_debug:
	@echo "Building Neovim Debug build (RelWithDebInfo)..."
	cd $(NEOVIM_DIR) && \
	CC="$(CC)" \
	CXX="$(CXX)" \
	CMAKE_BUILD_TYPE=RelWithDebInfo \
	ENABLE_JEMALLOC=$(ENABLE_JEMALLOC) \
	make -j$(shell nproc)
	# No strip for debug builds to keep symbols.

strip:
	@if [ -f $(NEOVIM_BIN) ]; then \
		echo "Stripping debug symbols from release binary..."; \
		strip --strip-unneeded $(NEOVIM_BIN); \
	else \
		echo "❌ Error: Built binary not found at $(NEOVIM_BIN)"; exit 1; \
	fi

clean:
	@echo "Cleaning build artifacts..."
	cd $(NEOVIM_DIR) && make clean || true

distclean: clean
	@echo "Removing all build artifacts and config (distclean)..."
	cd $(NEOVIM_DIR) && make distclean || true
	rm -rf $(BUILD_DIR)

uninstall:
	@echo "Removing Neovim package..."
	@# Try to get the package name from the .deb file for a precise uninstall.
	@if [ -f $(DEB_PACKAGE) ]; then \
		PACKAGE_NAME=$$(dpkg-deb -f $(DEB_PACKAGE) Package); \
		echo "Found package name: '$$PACKAGE_NAME'. Removing..."; \
		sudo dpkg -P $$PACKAGE_NAME; \
	else \
		echo "Package file not found. Attempting to remove known package names..."; \
		sudo apt-get remove --purge -y neovim nvim-linux-x86_64 || echo "No known packages found to remove."; \
	fi
	@echo "✅ Removed Neovim"
