# Tracy Client-Only Nix Package

This document describes the lightweight Tracy client package for Nix users who only need the instrumentation library without the profiler GUI.

## Overview

The Tracy project now provides two Nix packages:

1. **`tracy` (default)** - Full package with profiler GUI, all tools, heavy dependencies (ImGui, GLFW/Wayland, Capstone, Freetype, zstd, etc.)
2. **`tracy-client` (new)** - Lightweight client library only, minimal dependencies (just glibc, gcc-lib, threads)

## Package Comparison

### Full Package (`packages.default`)
```bash
nix build .#default
```
**Builds:**
- TracyClient library
- Profiler GUI (tracy-profiler)
- capture utility
- csvexport utility
- import utilities
- update utility

**Dependencies:**
- ImGui, GLFW/Wayland, Capstone, Freetype, zstd, onetbb, libffi, dbus, etc.
- ~40+ build dependencies via CPM

**Size:** ~Large (includes GUI frameworks)

### Client-Only Package (`packages.client`)
```bash
nix build .#client
```
**Builds:**
- TracyClient library only (libtracy.so)

**Dependencies:**
- glibc
- gcc-lib (libstdc++)
- pthreads
- dl

**Size:** ~495KB shared library + headers

## Using the Client Package

### In a Nix Flake

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    tracy.url = "github:wolfpld/tracy";
  };

  outputs = { self, nixpkgs, tracy }: {
    packages.x86_64-linux.default = let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
    in pkgs.stdenv.mkDerivation {
      name = "myapp";
      src = ./.;

      buildInputs = [
        tracy.packages.x86_64-linux.client  # Client library only!
      ];

      # Link against Tracy
      makeFlags = [ "LDFLAGS=-ltracy" ];
    };
  };
}
```

### In a Shell Environment

```nix
# shell.nix or nix develop
{ pkgs ? import <nixpkgs> {} }:
let
  tracy-client = pkgs.callPackage ./path/to/tracy/extra/client-package.nix {
    src = pkgs.lib.cleanSource ./path/to/tracy;
  };
in pkgs.mkShell {
  buildInputs = [
    tracy-client
  ];
}
```

### Direct Build

```bash
# Build just the client library
nix build .#client

# Result has two outputs:
# result/lib/libtracy.so.0.12.1 - shared library
# result-dev/include/tracy/     - headers
# result-dev/lib/cmake/Tracy/   - CMake config files
# result-dev/lib/pkgconfig/     - pkg-config file
```

## Package Outputs

The client package uses Nix's multiple-output feature:

### `out` Output (Runtime)
```
/nix/store/.../tracy-client-0.12.1/
└── lib/
    ├── libtracy.so -> libtracy.so.0
    ├── libtracy.so.0 -> libtracy.so.0.12.1
    └── libtracy.so.0.12.1  (495KB)
```

### `dev` Output (Development)
```
/nix/store/.../tracy-client-0.12.1-dev/
├── include/tracy/
│   ├── tracy/       (Main API headers: Tracy.hpp, TracyC.h, etc.)
│   ├── client/      (Client implementation headers)
│   └── common/      (Shared headers: protocol, compression, etc.)
└── lib/
    ├── cmake/Tracy/
    │   ├── TracyConfig.cmake
    │   ├── TracyConfigVersion.cmake
    │   └── TracyTargets.cmake
    └── pkgconfig/
        └── tracy.pc
```

## Integration Examples

### With CMake

```cmake
# Your project's flake.nix provides tracy-client in buildInputs
find_package(Tracy 0.12 REQUIRED)

add_executable(myapp main.cpp)
target_link_libraries(myapp PRIVATE Tracy::TracyClient)

# TRACY_ENABLE is automatically defined!
```

### With pkg-config

```bash
# In your build scripts
gcc myapp.c $(pkg-config --cflags --libs tracy) -o myapp
```

### With Makefiles

```makefile
TRACY_CFLAGS := $(shell pkg-config --cflags tracy)
TRACY_LIBS := $(shell pkg-config --libs tracy)

myapp: main.c
	$(CC) $(CFLAGS) $(TRACY_CFLAGS) main.c $(TRACY_LIBS) -o myapp
```

## Configuration

The client library is built with these defaults:
- `TRACY_ENABLE=ON` - Profiling enabled
- `TRACY_STATIC=OFF` - Shared library
- All other options at defaults (see CMakeLists.txt)

To customize, override in your own CMake configuration or build Tracy with different flags.

## When to Use Each Package

### Use `tracy-client` when:
- ✅ You only need to instrument your application
- ✅ You want minimal dependencies
- ✅ You're building a library that will be used by others
- ✅ You're deploying to production (profiling can be disabled at runtime)
- ✅ You don't need the GUI profiler on the same system

### Use `tracy` (full package) when:
- ✅ You want both client and profiler GUI
- ✅ You're doing active profiling work
- ✅ You need the capture/export/import tools
- ✅ You're on a development machine with desktop environment

## Profiler GUI

The client package does NOT include the profiler GUI. To view traces:

1. Install full `tracy` package on your development machine
2. Run `tracy-profiler` to connect to your instrumented app
3. Or use `tracy-capture` to save traces for later analysis

## Benefits

**For Application Developers:**
- Minimal bloat - no GUI dependencies in your application
- Fast builds - no ImGui/GLFW compilation
- Clean closure - only essential runtime dependencies

**For Library Authors:**
- Can include Tracy profiling without imposing heavy dependencies
- Users who don't care about profiling get minimal overhead

**For Package Maintainers:**
- Separate packages for client vs profiler
- Allows users to install only what they need
- Reduces dependency conflicts

## Source Code Isolation

The client package builds ONLY from the root `CMakeLists.txt`, which:
- Does NOT include `cmake/vendor.cmake` (profiler dependencies)
- Does NOT include `cmake/server.cmake` (server library)
- Does NOT build profiler, capture, or other tools
- Has minimal dependencies (threads, dl)

See the comment at the top of `CMakeLists.txt` for details.
