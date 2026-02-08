# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Tracy is a real-time, nanosecond-resolution profiler consisting of three main components:
1. **Client Library** (`/public/`) - Instrumentation library that applications integrate
2. **Server Library** (`/server/`) - Data processing and trace analysis engine
3. **Profiler GUI** (`/profiler/`) - Interactive visualization tool
4. **Command-line utilities** - Capture, csvexport, update, import tools

## Build Commands

### Building the Client Library
```bash
# CMake (primary build system)
cmake -B build -S . -DCMAKE_BUILD_TYPE=Release -DTRACY_ENABLE=ON
cmake --build build --parallel

# Meson (alternative)
meson setup build
meson compile -C build
```

### Building the Profiler GUI
```bash
cmake -B profiler/build -S profiler -DCMAKE_BUILD_TYPE=Release
cmake --build profiler/build --parallel

# Output: profiler/build/tracy-profiler
```

### Building Command-Line Tools
```bash
# Capture utility (headless trace capture)
cmake -B capture/build -S capture -DCMAKE_BUILD_TYPE=Release
cmake --build capture/build --parallel

# CSV export
cmake -B csvexport/build -S csvexport -DCMAKE_BUILD_TYPE=Release
cmake --build csvexport/build --parallel

# Update utility (offline symbol resolution)
cmake -B update/build -S update -DCMAKE_BUILD_TYPE=Release
cmake --build update/build --parallel

# Import utilities
cmake -B import/build -S import -DCMAKE_BUILD_TYPE=Release
cmake --build import/build --parallel
```

### Building Test Application
```bash
cmake -B test/build -S test -DCMAKE_BUILD_TYPE=Release
cmake --build test/build --parallel

# Test with different configurations
cmake -B test/build -S test -DCMAKE_BUILD_TYPE=Release -DTRACY_ON_DEMAND=ON
cmake --build test/build --parallel
```

### Important Client Library Options
The client library (root `CMakeLists.txt`) supports 30+ configuration options:
- `TRACY_ENABLE=ON` - Enable profiling (default: ON)
- `TRACY_ON_DEMAND=ON` - On-demand profiling
- `TRACY_CALLSTACK=10` - Enable callstack capture with depth
- `TRACY_NO_CALLSTACK=ON` - Disable all callstack functionality
- `TRACY_ONLY_LOCALHOST=ON` - Listen only on localhost
- `TRACY_NO_BROADCAST=ON` - Disable client discovery
- `TRACY_NO_SAMPLING=ON` - Disable call stack sampling
- `TRACY_DELAYED_INIT=ON` - Delay initialization
- `TRACY_MANUAL_LIFETIME=ON` - Manual lifetime management (requires TRACY_DELAYED_INIT)

See root `CMakeLists.txt` lines 118-157 for the complete list.

### Profiler GUI Options
- `NO_FILESELECTOR=ON` - Disable native file selector
- `LEGACY=ON` - Use X11 instead of Wayland on Linux
- `NO_ISA_EXTENSIONS=ON` - Disable ISA extensions (don't use -march=native)
- `NO_STATISTICS=ON` - Disable statistics calculation for faster processing
- `SELF_PROFILE=ON` - Enable Tracy self-profiling
- `SANITIZE=ON` - Enable sanitizers

## Architecture Overview

### Client Library (`/public/`)
- **Unity build pattern**: `TracyClient.cpp` includes all implementation files for optimal inlining
- **Lock-free queues**: Uses moodycamel::ConcurrentQueue and SPSCQueue for minimal instrumentation overhead
- **Key components**:
  - `public/tracy/Tracy.hpp` - Main C++ API (ZoneScoped, FrameMark, TracyPlot, etc.)
  - `public/tracy/TracyC.h` - C API bindings
  - `public/client/TracyProfiler.hpp/.cpp` - Core profiler logic, network communication
  - `public/client/TracyCallstack.hpp/.cpp` - Callstack capture
  - `public/common/` - Code shared between client and server (protocol, sockets, compression)
  - `public/libbacktrace/` - Symbol resolution (ELF, Mach-O, DWARF parsing)

### Server Library (`/server/`)
- **TracyWorker** (`TracyWorker.hpp/.cpp`, 8,790 lines) - Core data processing engine
  - Receives profiling data over network or from .tracy files
  - Processes events (zones, locks, memory, plots, GPU events)
  - Builds analysis structures (callstack trees, statistics, timelines)
  - Handles versioned trace file format
- Built as static library (TracyServer) via `/cmake/server.cmake`
- Shared by all tools (profiler, capture, csvexport, import, update)

### Profiler GUI (`/profiler/`)
- **ImGui-based** with custom widgets
- **Modular view architecture**: Main view split into 29 specialized files:
  - `TracyView_Timeline.cpp` - Main timeline visualization
  - `TracyView_Zones.cpp`, `TracyView_FindZone.cpp` - Zone analysis
  - `TracyView_FlameGraph.cpp` - Flame graphs
  - `TracyView_Memory.cpp` - Memory profiling
  - `TracyView_Locks.cpp` - Lock contention
  - `TracyView_Statistics.cpp` - Statistics (can be disabled with NO_STATISTICS)
  - `TracyView_Compare.cpp` - Trace comparison
  - And 22+ more specialized views
- **LLM Integration**: New feature (v0.13.0) with AI assistant
  - `TracyLlm.cpp`, `TracyLlmApi.cpp`, `TracyLlmChat.cpp`, `TracyLlmTools.cpp`
  - System prompts in `/profiler/src/llm/system.prompt.md`
- **Multiple rendering backends**:
  - `BackendGlfw.cpp` - GLFW (Windows, macOS, Linux/X11)
  - `BackendWayland.cpp` - Native Wayland support
  - `BackendEmscripten.cpp` - WebAssembly/browser
- **Resource embedding**: Custom `embed` tool embeds fonts, manual, prompts at build time

### Build System (`/cmake/`)
- **Modular CMake**: Each component has its own CMakeLists.txt
- **Key infrastructure files**:
  - `/cmake/version.cmake` - Version extraction from git
  - `/cmake/config.cmake` - Compiler flags, ISA extensions, platform detection
  - `/cmake/vendor.cmake` - Dependency management using CPM (CMake Package Manager)
    - Downloads/manages: capstone, GLFW, freetype, zstd, ImGui, NFD, nlohmann_json, md4c, libcurl, tidy-html5, usearch, pugixml
    - Applies patches to some libraries (imgui-emscripten.patch, etc.)
  - `/cmake/server.cmake` - Builds TracyServer static library
  - `/cmake/CPM.cmake` - CMake Package Manager
- **Minimum versions**:
  - Client library: CMake 3.10, C++11
  - Tools/GUI: CMake 3.16-3.25, C++20

## Code Style

### Formatting
- **Style**: Based on Microsoft style with modifications (see `.clang-format`)
- **Key conventions**:
  - Allman-style bracing for most constructs
  - No column limit (ColumnLimit: 0)
  - Spaces inside parentheses: `if( condition )`
  - Short functions/lambdas on single line allowed
  - 4-space indentation
  - Pointer alignment left: `Type* ptr`
- **Usage**: Only use clang-format to fit surrounding code style - don't reformat entire files

### Shadow Warning Suppression
- Variable redefinition by nested zone macros is suppressed by default
- This is intentional - nested `ZoneScoped` macros create same-named variables
- Old behavior can be restored with `TRACY_ALLOW_SHADOW_WARNING`

## Testing

### Test Application (`/test/`)
- Comprehensive integration test exercising the Tracy API
- Tests: zones, locks, plots, memory, callstacks, frame marks, GPU contexts, messages
- CI runs multiple build configurations:
  - Default flags
  - `TRACY_ON_DEMAND=ON`
  - `TRACY_DELAYED_INIT=ON TRACY_MANUAL_LIFETIME=ON`
  - `TRACY_DEMANGLE=ON`

### No Unit Tests
Testing is integration-based via the test application and real-world usage.

## Key Design Patterns

### Unity Build
`TracyClient.cpp` includes all implementation files. This enables:
- Aggressive inlining across translation units
- Better LTO optimization
- Single compilation unit for minimal overhead

### Lock-Free Data Collection
Instrumentation uses lock-free queues (ConcurrentQueue, SPSCQueue) to minimize overhead in hot paths.

### Shared Server Core
TracyWorker + TracyServer library used by all tools to ensure consistent trace processing behavior.

### Versioned Protocol
`TracyProtocol.hpp` defines network/file format versions. Forward/backward compatibility is carefully managed. Version mismatches between client and server may not work together.

### Memory Efficiency
Custom data structures for large datasets:
- `TracyShortPtr.hpp` - Compressed pointers
- `TracySlab.hpp` - Slab allocator
- `TracyVector.hpp` - Custom vector
- Thread compression for large traces

## Common Workflows

### Adding a New Client API Feature
1. Update public headers in `/public/tracy/` or `/public/client/`
2. Implement in corresponding `.cpp` file (included by `TracyClient.cpp`)
3. Update protocol if needed (`/public/common/TracyProtocol.hpp`)
4. Update server-side handling in `/server/TracyWorker.cpp`
5. Add visualization in appropriate `/profiler/src/profiler/TracyView_*.cpp` file
6. Test with `/test/test.cpp`

### Adding a New View to Profiler GUI
1. Create new `TracyView_*.cpp` file in `/profiler/src/profiler/`
2. Add method declarations to `TracyView.hpp`
3. Call from main view rendering in `TracyView.cpp` or appropriate parent view
4. Update CMakeLists.txt if needed

### Working with Dependencies
Dependencies are managed by `/cmake/vendor.cmake` using CPM. To update or add dependencies, modify this file. CPM will download and configure them automatically.

### Cross-Platform Development
- Platform-specific code is abstracted in `/public/common/` (socket, system) and `/public/client/` (callstack, threads)
- Use existing abstractions rather than platform-specific APIs
- Test on Linux, Windows, macOS, and FreeBSD if possible

## Important Files

### Client Integration Entry Points
- `public/tracy/Tracy.hpp` - Main C++ API
- `public/tracy/TracyC.h` - C API
- `public/TracyClient.cpp` - Implementation (single compilation unit)

### Server Core
- `server/TracyWorker.hpp/.cpp` - Data processing engine (8,790 lines)
- `server/TracyEvent.hpp` - Event data structures

### Protocol & Communication
- `public/common/TracyProtocol.hpp` - Network/file format version
- `public/common/TracySocket.hpp` - Network abstraction
- `public/common/TracyQueue.hpp` - Event queue structures

### Main GUI
- `profiler/src/main.cpp` - GUI entry point
- `profiler/src/profiler/TracyView.cpp` - Main view controller
- `profiler/src/profiler/TracyView_*.cpp` - Specialized views (29 files)

## GPU Profiling Support

Tracy supports all major GPU APIs with dedicated headers in `/public/tracy/`:
- `TracyVulkan.hpp` - Vulkan
- `TracyD3D11.hpp`, `TracyD3D12.hpp` - Direct3D 11/12
- `TracyOpenGL.hpp` - OpenGL
- `TracyOpenCL.hpp` - OpenCL
- `TracyCUDA.hpp` - CUDA
- `TracyMetal.hmm` - Metal
- ROCm/Rocprof support (v0.13.0+) with `TRACY_ROCPROF` define

## Recent Major Features (v0.13.x)

### LLM Integration (v0.13.0)
- Optional AI assistant in profiler GUI
- Can query manual, analyze callstacks/assembly
- Requires local LLM service
- System prompts in `/profiler/src/llm/system.prompt.md`

### ROCm Support (v0.13.0)
- AMD GPU profiling via rocprofiler-sdk
- Enable with `TRACY_ROCPROF` define
- Optional continuous calibration with `TRACY_ROCPROF_CALIBRATION`

### Memory Fault Tolerance (v0.13.1)
- `TRACY_IGNORE_MEMORY_FAULTS` option to ignore free events without matching allocations

## Documentation

- **Manual**: `/manual/tracy.md` (338KB markdown, also available as LaTeX and PDF)
- **Embedded in GUI**: Manual viewer accessible from profiler (added in v0.13.1)
- **Changelog**: `/NEWS` - Detailed version history with breaking changes noted
- **README**: `/README.md` - Project overview and links

## Development Notes

### Performance Considerations
- ISA extensions enabled by default (`-march=native`) for profiler/tools
- LTO enabled in Release builds
- Optional mold linker on Linux/Clang for faster linking
- ccache support for faster rebuilds
- Statistics can be disabled (`NO_STATISTICS`) for faster trace processing

### Platform-Specific Notes
- **Linux**: Wayland is preferred over X11 (use `LEGACY=ON` to force X11)
- **macOS**: C++20 support issues on older machines - workarounds in place
- **Windows**: MinGW builds have limitations (safe symbol retrieval unavailable)
- **FreeBSD**: Requires libexecinfo

### Dependency Management
- CPM (CMake Package Manager) handles dependencies automatically
- Cache directory: `CPM_SOURCE_CACHE` env var or default CMake location
- Patches applied to some dependencies (see `/cmake/vendor.cmake`)

## Language Bindings

### Official Support
- **C++**: Main API (`public/tracy/Tracy.hpp`)
- **C**: C API (`public/tracy/TracyC.h`)
- **Lua**: Lua bindings (`public/tracy/TracyLua.hpp`)
- **Python**: Python bindings via pybind11 (`/python/`, enable with `TRACY_CLIENT_PYTHON=ON`)
- **Fortran**: Fortran bindings (`public/TracyClient.F90`, enable with `TRACY_Fortran=ON`)

### Third-Party Bindings
Rust, Zig, C#, OCaml, Odin, and others available from community (see README)
