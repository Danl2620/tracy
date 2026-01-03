# Tracy Nix Packages

## Overview

The Tracy Nix flake provides two packages:

### 1. `tracy-client` (`.#client`)
Lightweight client library for instrumenting applications.

**Contents:**
- `libtracy.so` - Shared library (495KB)
- Headers - tracy/, client/, common/ (624KB)
- CMake config files
- pkg-config file

**Total:** ~1.2MB
**Dependencies:** Minimal (glibc, gcc-lib, pthreads, dl)
**Structure:** Single output (everything in `/nix/store/.../tracy-client-0.12.1/`)

### 2. `tracy` (`.#default`)
Complete profiler package with GUI and all tools.

**Contents:**
- Profiler GUI (tracy-profiler)
- Client library
- Utilities: capture, csvexport, import, update

**Dependencies:** Heavy (ImGui, GLFW/Wayland, Capstone, Freetype, zstd, onetbb, libffi, dbus, etc.)

## Usage

### In a Flake

```nix
{
  inputs.tracy.url = "github:wolfpld/tracy";

  outputs = { self, nixpkgs, tracy }: {
    packages.x86_64-linux.myapp =
      let pkgs = import nixpkgs { system = "x86_64-linux"; };
      in pkgs.stdenv.mkDerivation {
        name = "myapp";
        buildInputs = [
          tracy.packages.x86_64-linux.client  # Just the client library
        ];

        # Link against Tracy
        # TRACY_ENABLE is automatically defined by CMake!
      };
  };
}
```

### With CMake

```cmake
find_package(Tracy 0.12 REQUIRED)

add_executable(myapp main.cpp)
target_link_libraries(myapp PRIVATE Tracy::TracyClient)

# Headers and compile definitions automatically available!
```

### With pkg-config

```bash
gcc myapp.c $(pkg-config --cflags --libs tracy) -o myapp
```

## Building

```bash
# Client library only
nix build .#client

# Full package with profiler
nix build .#default

# Both packages in parallel
nix build .#client .#default
```

## Design: Single Output for Client

The client package uses a **single output** instead of Nix's typical multi-output split:

**Advantages:**
- ✅ Simple - No need to reference `.dev` output
- ✅ No CMake path issues - Everything in one place
- ✅ Practical - Build-time headers are always needed
- ✅ Small - Only 1.2MB total, splitting provides no real benefit

**Structure:**
```
/nix/store/.../tracy-client-0.12.1/
├── lib/
│   ├── libtracy.so.0.12.1
│   ├── cmake/Tracy/
│   └── pkgconfig/tracy.pc
└── include/tracy/
    ├── tracy/
    ├── client/
    └── common/
```

## When to Use Which Package

| Use Case | Package | Reason |
|----------|---------|--------|
| Instrument your application | `client` | Minimal dependencies, fast builds |
| Build a library with Tracy | `client` | Don't impose GUI dependencies on users |
| Active profiling work | `default` | Need the GUI to visualize traces |
| Development machine | `default` | Want both instrumentation and visualization |
| Production deployment | `client` | Lean runtime, profiling can be toggled |
| CI/CD builds | `client` | Faster builds, no unnecessary tools |

## Remote Profiling

You don't need the profiler GUI on the same machine as your instrumented app:

1. **Build server / Production:** Use `tracy-client` to instrument your app
2. **Development machine:** Use `tracy` (full package) for the profiler GUI
3. **Network:** Tracy profiler connects remotely to instrumented apps

This is why the client-only package is useful even for teams with profiling GUI licenses.

## See Also

- `/extra/package.nix` - Full package definition
- `/extra/client-package.nix` - Client-only package definition
- `/extra/README.md` - Package design decisions
- `/CMakeLists.txt` - Client library CMake configuration
