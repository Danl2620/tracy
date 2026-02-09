# Tracy Nix Flake Implementation Status

This document describes the Nix flake implementation for the Tracy profiler project.

## Overview

A complete Nix flake has been created in `flake.nix` at the project root, providing reproducible builds for Tracy components using locked dependencies from nixpkgs and upstream sources.

## Package Status

### ✅ tracy-client (Working)

The Tracy client library builds successfully.

**Build command:**
```bash
nix build .#tracy-client
```

**Status:** Fully functional

### ⚠️ tracy-profiler (Partial)

The Tracy profiler GUI application builds to 96% completion but fails during compilation of `TracyLlm.cpp`.

**Build command:**
```bash
nix build .#tracy-profiler
```

**Status:** Nearly complete - fails at 96% build progress

**Issue:** Missing fp16 headers from usearch submodule
- Error occurs in `TracyLlm.cpp` at line 11 when including usearch headers
- The usearch library depends on the fp16 library (a git submodule)
- Added `?submodules=1` to usearch flake input, but Nix's flake fetcher doesn't properly fetch submodules

**Possible fixes:**
1. Add fp16 as a separate flake input and configure include paths
2. Disable LLM features with a CMake flag (if available)
3. Investigate proper git submodule fetching in Nix flakes

**Error details:**
```
In file included from /build/usearch/include/usearch/index_dense.hpp:12,
                 from .../profiler/src/profiler/TracyLlmEmbeddings.hpp:5,
                 from .../profiler/src/profiler/TracyLlmTools.hpp:11,
                 from .../profiler/src/profiler/TracyLlm.cpp:11:
/build/usearch/include/usearch/index_plugins.hpp:37:10: fatal error: fp16/fp16.h: No such file or directory
   37 | #include <fp16/fp16.h>
```

### ❌ tracy-profiler-web (Not Working)

The WebAssembly/Emscripten build of Tracy for browsers.

**Build command:**
```bash
nix build .#tracy-profiler-web
```

**Status:** Build fails during CMake configuration

**Issue:** Capstone in-tree build error
- CPM (CMake Package Manager) tries to configure capstone directly in its source directory
- Capstone's CMakeLists.txt explicitly rejects in-tree builds
- The normal tracy-profiler build works because it uses different CPM configuration

**Error details:**
```
CMake Error at /build/capstone/CMakeLists.txt:5 (message):
  In-tree builds are not supported.  Run CMake from a separate directory:
  cmake -B build
```

**Attempted fixes:**
1. Used `buildEmscriptenPackage` - failed (tries to run ./configure which doesn't exist)
2. Switched to `emscriptenStdenv.mkDerivation` with manual cmake/build phases
3. Tried creating `/src` subdirectories for CPM sources - didn't help
4. Reverted to same approach as tracy-profiler (direct source paths) - still fails

**Likely solution:** The issue requires deeper investigation into how CPM handles out-of-tree builds with Emscripten. The CMake configuration may need to be adjusted to provide explicit build directories for each dependency.

## Flake Structure

### Inputs

All CPM dependencies are declared as flake inputs for reproducibility:

- **nixpkgs**: NixOS/nixpkgs/nixos-unstable
- **imgui**: ocornut/imgui v1.92.5-docking
- **nativefiledialog-extended**: btzy/nativefiledialog-extended v1.2.1
- **ppqsort**: GabTux/PPQSort v1.0.6
- **packageproject-cmake**: TheLartians/PackageProject.cmake v1.11.1
- **capstone**: capstone-engine/capstone 6.0.0-Alpha5
- **base64**: aklomp/base64 v0.5.2
- **usearch**: unum-cloud/usearch v2.21.3 (with submodules flag)
- **glfw**: glfw/glfw 3.4
- **freetype**: freetype/freetype VER-2-14-1
- **zstd-src**: facebook/zstd v1.5.7
- **nlohmann-json**: nlohmann/json v3.12.0
- **md4c**: mity/md4c release-0.5.2
- **tidy-html5**: htacg/tidy-html5 5.8.0
- **pugixml**: zeux/pugixml v1.15
- **curl**: curl/curl curl-8_17_0

### Packages

1. **tracy-client** - Client library for instrumentation
2. **tracy-profiler** - GUI profiler application (partial)
3. **tracy-profiler-web** - WebAssembly build (not working)
4. **default** - Alias for tracy-profiler

### Development Shells

Two development shells are provided:

1. **default** - Full Tracy development environment with all dependencies
2. **client-only** - Minimal shell for building just the client library

**Usage:**
```bash
nix develop          # Enter default dev shell
nix develop .#client-only  # Enter client-only shell
```

### Apps

Convenience apps for running the profiler:

```bash
nix run          # Run tracy-profiler
nix run .#profiler   # Run tracy-profiler
```

## Key Implementation Details

### CPM Dependency Management

The flake uses `-DCPM_<package>_SOURCE` CMake flags to provide pre-fetched sources to CPM, preventing network access during builds:

```nix
cpmSources = {
  ImGui = inputs.imgui;
  nfd = inputs.nativefiledialog-extended;
  # ... etc
};
```

Sources are copied to writable locations in `postUnpack`:

```nix
postUnpack = ''
  ${pkgs.lib.concatStringsSep "\n" (pkgs.lib.mapAttrsToList (name: src: ''
    cp -R ${src} ${name}
    chmod -R u+w ${name}
  '') cpmSources)}
'';
```

Then passed to CMake in `preConfigure`:

```nix
preConfigure = ''
  ${pkgs.lib.concatStringsSep "\n" (pkgs.lib.mapAttrsToList (name: src: ''
    export cmakeFlags="$cmakeFlags -DCPM_${name}_SOURCE=$NIX_BUILD_TOP/${name}"
  '') cpmSources)}
'';
```

### Special Handling

**wayland-protocols:** Uses the system package's share directory instead of a source checkout:
```nix
export cmakeFlags="$cmakeFlags -DCPM_wayland-protocols_SOURCE=${pkgs.wayland-protocols}/share/wayland-protocols"
```

**PPQSort:** Requires the newer CPM.cmake from Tracy's cmake/ directory:
```nix
if [ -d PPQSort ] && [ -d $sourceRoot ]; then
  cp $sourceRoot/cmake/CPM.cmake PPQSort/cmake/CPM.cmake
fi
```

**embed.tracy (WebAssembly only):** Fixed-output derivation for the required preloaded data file:
```nix
embedTracy = pkgs.fetchurl {
  url = "https://share.nereid.pl/i/embed.tracy";
  hash = "sha256-XoRoxINIquvEB+iIK6EwtV/xVMKUk/5EQmvvEtPm3wI=";
};
```

## Build Instructions

### Building tracy-client

```bash
# Build the client library
nix build .#tracy-client

# Result will be in ./result/
```

### Building tracy-profiler (Partial)

```bash
# Attempt to build the profiler (will fail at 96%)
nix build .#tracy-profiler

# Build with detailed logs
nix build .#tracy-profiler --print-build-logs
```

### Development Workflow

```bash
# Enter development shell
nix develop

# Standard CMake workflow is now available
cmake -B build -S .
cmake --build build

# For profiler
cmake -B profiler/build -S profiler
cmake --build profiler/build
```

## Future Work

### High Priority

1. **Fix usearch/fp16 submodule issue** for tracy-profiler
   - Add fp16 as separate flake input
   - Or investigate disabling LLM features
   - Or find proper way to fetch git submodules in Nix flakes

2. **Fix capstone in-tree build error** for tracy-profiler-web
   - Investigate CPM's out-of-tree build configuration with Emscripten
   - May need to patch CPM or provide explicit build directories

### Nice to Have

1. Add more derivation outputs (capture, csvexport, update utilities)
2. Add NixOS module for tracy-profiler
3. Cross-compilation support for other platforms
4. CI/CD integration using the flake

## References

- Original nixpkgs package: `~/proj/nixpkgs/pkgs/by-name/tr/tracy/tracy-0.13.nix`
- Package versions reference: `~/proj/nixpkgs/pkgs/by-name/tr/tracy/package-versions.nix`
- Tracy CI Emscripten workflow: `.github/workflows/emscripten.yml`
- Just actions for CI: `extra/actions.just` (ci-emscripten task)

## Testing

The flake has been tested on:
- System: Linux x86_64 (NixOS/nixos-unstable)
- Nix version: 2.x with flakes enabled
- Tracy version: 0.13.2

### Test Commands

```bash
# Check flake structure
nix flake show

# Check flake metadata
nix flake metadata

# List all packages
nix flake show --json | jq '.packages."x86_64-linux" | keys'

# Build all working packages
nix build .#tracy-client

# Enter dev shell and verify tools
nix develop -c cmake --version
nix develop -c ninja --version
```
