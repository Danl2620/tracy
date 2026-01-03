# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Tracy is a real-time, nanosecond resolution, remote telemetry profiler for games and other applications. The codebase consists of:
- **Client library** (`public/`): Instrumentation library integrated into target applications
- **Profiler GUI** (`profiler/`): Standalone application for visualizing and analyzing traces
- **Server components** (`server/`): Core trace processing and analysis engine
- **Utilities**: capture, csvexport, import, and update tools

## Build System

The project supports multiple build systems:
- **CMake** (primary)
- **Meson**
- **Nix** (for reproducible builds)

### Building with CMake

```bash
# Quick build using justfile
just build

# Manual build
mkdir -p build
cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -G "Ninja"
cmake --build build -- -j$(nproc)
```

### Building Components Individually

Each major component has its own CMakeLists.txt and can be built separately:
```bash
# Build profiler GUI
cmake -B profiler/build -S profiler
cmake --build profiler/build

# Build capture utility
cmake -B capture/build -S capture
cmake --build capture/build

# Build test executable
cmake -B test/build -S test
cmake --build test/build
```

### Nix Build

```bash
# Build client library only (lightweight, ~1.2MB)
nix build .#client

# Build full package with profiler GUI
nix build .#default  # or just: nix build

# Build with verbose logging
just package  # Runs: nix build -Lvvv 2>&1 | tee build.log

# Enter development shell
nix develop
```

**Nix Packages:**
- `.#client` - Client library only (single output, minimal dependencies)
- `.#default` - Full package with profiler GUI and all tools
- See `docs/NIX_PACKAGES.md` for details

## Architecture

### Client Library (`public/`)

The client library is header-only with a single implementation file:
- **`public/TracyClient.cpp`**: Main implementation (compiled into target app)
- **`public/tracy/Tracy.hpp`**: Primary C++ API for instrumentation
- **`public/tracy/TracyC.h`**: C API wrapper
- **`public/client/`**: Core client implementation (profiler, memory tracking, etc.)
- **`public/common/`**: Shared code between client and server (protocol, compression, etc.)

Key client components:
- `TracyProfiler.hpp/cpp`: Main profiler state machine
- `TracySocket.hpp/cpp`: Network communication
- `TracyCallstack.hpp/cpp`: Stack unwinding
- `TracySysTrace.hpp/cpp`: System-level tracing (context switches, sampling)

### Server/Analysis Engine (`server/`)

Server-side trace processing (used by profiler GUI and utilities):
- **`TracyWorker.cpp/hpp`**: Core trace loading, processing, and analysis (>250KB, central component)
- **`TracyEvent.hpp`**: Event data structures
- **`TracyFileRead.hpp`**: Trace file format parsing
- **`TracyFileWrite.hpp`**: Trace file format serialization
- Memory-mapped I/O support for large traces (`TracyMmap.cpp`)
- Utilities: `TracyPrint.cpp`, `TracyTaskDispatch.cpp`

### Profiler GUI (`profiler/`)

The GUI application is built with:
- **ImGui** (UI framework, fetched via CPM)
- **GLFW** (default) or **Wayland** native backend on Linux
- Backend files: `BackendGlfw.cpp`, `BackendWayland.cpp`, `BackendEmscripten.cpp`

Main profiler source files in `profiler/src/profiler/`:
- `TracyView.cpp`: Main view orchestrator
- `TracyView_*.cpp`: Modular view implementations (Timeline, Memory, Locks, etc.)
- `TracySourceView.cpp`: Source code viewer with syntax highlighting
- Connection and file management: `TracyFileselector.cpp`, `ConnectionHistory.cpp`

### Utilities

- **capture** (`capture/src/capture.cpp`): Command-line tool to capture traces from running applications
- **csvexport** (`csvexport/src/csvexport.cpp`): Export trace data to CSV format
- **import-chrome** (`import/src/import-chrome.cpp`): Import Chrome tracing format
- **import-fuchsia** (`import/src/import-fuchsia.cpp`): Import Fuchsia tracing format
- **update** (`update/src/update.cpp`): Offline symbol resolution and trace updates

## Client Configuration

The client library supports extensive configuration via preprocessor defines. Key options:

**Core Settings:**
- `TRACY_ENABLE`: Enable profiling (disabled = zero overhead)
- `TRACY_ON_DEMAND`: On-demand profiling activation
- `TRACY_NO_EXIT`: Keep client alive until all data is sent

**Callstack Options:**
- `TRACY_CALLSTACK`: Force callstack capture for all zones
- `TRACY_NO_CALLSTACK`: Disable all callstack functionality
- `TRACY_NO_CALLSTACK_INLINES`: Disable inline function resolution

**Network:**
- `TRACY_ONLY_LOCALHOST`: Only listen on localhost
- `TRACY_NO_BROADCAST`: Disable client discovery broadcasts
- `TRACY_ONLY_IPV4`: IPv4-only mode

**Feature Toggles:**
- `TRACY_NO_SAMPLING`: Disable callstack sampling
- `TRACY_NO_CONTEXT_SWITCH`: Disable context switch capture
- `TRACY_NO_SYSTEM_TRACING`: Disable system-level tracing
- `TRACY_NO_FRAME_IMAGE`: Disable frame screenshot support

These can be set via CMake options (see `CMakeLists.txt` lines 117-142) or Meson options (see `meson.options`).

## Testing

The test program demonstrates Tracy integration:
```bash
# Build and run test
cmake -B test/build -S test
cmake --build test/build
./test/build/tracy-test
```

The test (`test/test.cpp`) demonstrates:
- Zone scoping and annotations
- Memory allocation tracking (via overloaded new/delete)
- Multi-threaded profiling
- Frame marking
- Message logging

## Version Management

Version is defined in `public/common/TracyVersion.hpp` with Major/Minor/Patch constants. The CMake script `cmake/version.cmake` parses this file to set `TRACY_VERSION_STRING`.

## Platform Notes

**Linux:**
- Default backend is Wayland (set `LEGACY=ON` for X11/GLFW)
- Requires: wayland, libxkbcommon, libglvnd (Wayland) or glfw (X11)
- Context switch tracking requires root or `CAP_SYS_ADMIN`

**macOS:**
- Uses GLFW backend
- C++20 with `-fexperimental-library` for AppleClang

**Windows:**
- MSVC or MinGW supported
- Win32 manifest in `profiler/win32/`
- Link against ws2_32, dbghelp

## Key Concepts

**Zones**: Instrumented code regions tracked by Tracy
- Created via `ZoneScoped`, `ZoneNamed`, etc. macros
- Support colors, text annotations, values

**Frames**: Application frame boundaries marked via `FrameMark`
- Enables frame-time analysis and visualization

**Memory Tracking**: Allocation/deallocation events via `TracyAlloc`/`TracyFree`
- Can override global new/delete for automatic tracking

**Locks**: Mutex profiling via `TracyLockable` wrapper

**Messages**: Timestamped text messages via `TracyMessage`

**Remote Connection**: Client listens on port 8086, profiler connects to capture live data

## Documentation

The comprehensive PDF manual is generated from `manual/tracy.tex` (LaTeX source). For build/integration details not in this file, consult the [official PDF](https://github.com/wolfpld/tracy/releases/latest/download/tracy.pdf).
