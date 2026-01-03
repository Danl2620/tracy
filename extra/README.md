# Tracy Nix Packages

This directory contains Nix package definitions for Tracy.

## Available Packages

### `package.nix` - Full Package (Default)
The complete Tracy profiler package including:
- Profiler GUI (tracy-profiler)
- Client library (libtracy)
- All utilities (capture, csvexport, import, update)

**Dependencies:** Many (ImGui, GLFW/Wayland, Capstone, Freetype, zstd, onetbb, etc.)

**Use when:** You need the profiler GUI and tools for active development and profiling work.

### `client-package.nix` - Client Library Only
Lightweight package containing only the Tracy client instrumentation library:
- libtracy.so (shared library)
- Headers (tracy/, client/, common/)
- CMake config files
- pkg-config file

**Dependencies:** Minimal (glibc, gcc-lib, pthreads, dl only)
**Size:** ~1.2MB total (495KB library + 624KB headers)
**Structure:** Single output - everything in `/nix/store/.../tracy-client/` for simplicity

**Use when:**
- You only need to instrument your application
- You want minimal dependencies
- You're building a library that will be used by others
- You don't need the GUI profiler on the same system

## Building

```bash
# Build client library only
nix build .#client

# Build full package with profiler
nix build .#default
```

## Design Decisions

### Why Single Output for Client?

The client package originally used Nix's multi-output feature (splitting `out` and `dev`), but we simplified to a single output because:

1. **Size:** The "dev" files (headers, cmake) are only ~600KB - negligible
2. **Usage:** Most users need headers to build anyway
3. **Complexity:** Multi-output requires understanding Nix's output system and can cause CMake path issues
4. **Practicality:** Even production deployments with Tracy often benefit from headers for debugging

For a small package like tracy-client (~1.2MB), the simplicity of a single output outweighs the minor closure size savings.

### CMake Include Path Fix

The CMakeLists.txt uses `${CMAKE_INSTALL_INCLUDEDIR}` instead of relative paths:

```cmake
# Before (broken in Nix multi-output)
$<INSTALL_INTERFACE:include/tracy>

# After (works everywhere)
$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/tracy>
```

This ensures the generated `TracyTargets.cmake` has the correct absolute path to headers, whether using single or multi-output packages.

## See Also

- `../CLIENT_NIX_PACKAGE.md` - Detailed documentation on using the client package
- `../CMAKE_PACKAGING_IMPROVEMENTS.md` - CMake packaging improvements
