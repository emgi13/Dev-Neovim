
# Makefile for Neovim build and packaging

NEOVIM_DIR := ./neovim
BUILD_DIR := ./neovim/build
NEOVIM_BIN := $(BUILD_DIR)/bin/nvim

CC := /usr/bin/clang
CXX := /usr/bin/clang++
CFLAGS := -Ofast -march=native -flto=full -funroll-loops -ffast-math -fomit-frame-pointer -fschedule-insns2 -DNDEBUG
CXXFLAGS := -Ofast -march=native -flto=full -funroll-loops -ffast-math -fomit-frame-pointer -fschedule-insns2 -DNDEBUG
LDFLAGS := -flto=full -fuse-ld=mold
ENABLE_JEMALLOC := ON

.PHONY: all clean distclean build_release build_debug strip package install uninstall

# Default target: clean + release build + package + install
all: clean build_release package install

clean:
	@echo "Cleaning build artifacts..."
	cd $(NEOVIM_DIR) && make clean || true

distclean: clean
	@echo "Removing all build artifacts and config (distclean)..."
	cd $(NEOVIM_DIR) && make distclean || true
	rm -rf $(BUILD_DIR)

build_release:
	@echo "Building Neovim Release build with optimizations..."
	cd $(NEOVIM_DIR) && \
	CC="$(CC)" \
	CXX="$(CXX)" \
	CMAKE_BUILD_TYPE=Release \
	CMAKE_C_FLAGS="$(CFLAGS)" \
	CMAKE_CXX_FLAGS="$(CXXFLAGS)" \
	CMAKE_EXE_LINKER_FLAGS="$(LDFLAGS)" \
	ENABLE_JEMALLOC=$(ENABLE_JEMALLOC) \
	make -j$(shell nproc)
	@$(MAKE) strip

build_debug:
	@echo "Building Neovim Debug build (RelWithDebInfo)..."
	cd $(NEOVIM_DIR) && \
	CC="$(CC)" \
	CXX="$(CXX)" \
	CMAKE_BUILD_TYPE=RelWithDebInfo \
	CMAKE_C_FLAGS="" \
	CMAKE_CXX_FLAGS="" \
	CMAKE_EXE_LINKER_FLAGS="" \
	ENABLE_JEMALLOC=$(ENABLE_JEMALLOC) \
	make -j$(shell nproc)
	# No strip here, keep debug symbols

strip:
	@if [ -f $(NEOVIM_BIN) ]; then \
		echo "Stripping debug symbols from release binary..."; \
		strip --strip-unneeded $(NEOVIM_BIN); \
	else \
		echo "❌ Error: Built binary not found at $(NEOVIM_BIN)"; exit 1; \
	fi

package:
	@echo "Generating Debian package with CPack..."
	cd $(BUILD_DIR) && cpack -G DEB

install:
	@echo "Installing Neovim package..."
	sudo dpkg -i $(BUILD_DIR)/nvim-linux-x86_64.deb
	@echo "✅ Installed Neovim"

uninstall:
	@echo "Removing Neovim package..."
	sudo apt remove neovim
	@echo "✅ Removed Neovim"
