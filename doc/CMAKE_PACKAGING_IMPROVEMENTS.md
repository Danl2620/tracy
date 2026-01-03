# CMake Client Packaging Improvements

This document describes the improvements made to the Tracy client CMake packaging to make it more robust and easier to use for downstream consumers.

## Summary of Changes

### 1. Version Compatibility File (TracyConfigVersion.cmake)

**What Changed:**
- Added `write_basic_package_version_file()` to generate `TracyConfigVersion.cmake`
- Configured with `SameMajorVersion` compatibility policy

**Why:**
- Enables `find_package(Tracy <version>)` with version requirements
- Consumers can specify minimum required versions (e.g., `find_package(Tracy 0.12 REQUIRED)`)
- Ensures ABI compatibility through major version checking
- Standard CMake package practice

**Usage Example:**
```cmake
# In consuming project
find_package(Tracy 0.12 REQUIRED)  # Will fail if version < 0.12.x
find_package(Tracy 0.13 EXACT)     # Requires exactly 0.13.x
```

### 2. Enhanced Config.cmake.in

**What Changed:**
- Added build configuration variables (`Tracy_ENABLE`, `Tracy_ON_DEMAND`, etc.)
- Improved handling of optional dependencies (libunwind, debuginfod)
- Added platform-specific library requirements
- Added `check_required_components()` call

**Why:**
- Consumers can query how Tracy was built
- Automatically finds required platform libraries
- Properly propagates optional dependency requirements
- Follows CMake package configuration best practices

**Usage Example:**
```cmake
find_package(Tracy REQUIRED)
if(Tracy_ENABLE)
    message("Tracy profiling is enabled in this build")
endif()
# TracyClient target automatically links required dependencies
target_link_libraries(myapp PRIVATE Tracy::TracyClient)
```

### 3. pkg-config Support (tracy.pc)

**What Changed:**
- Added `tracy.pc.in` template
- Generates `tracy.pc` file during configuration
- Installs to `${CMAKE_INSTALL_LIBDIR}/pkgconfig`

**Why:**
- Enables non-CMake build systems to find Tracy
- Provides compiler flags and linker flags
- Standard for Unix/Linux systems
- Useful for Makefile-based projects

**Usage Example:**
```bash
# In Makefile or other build system
pkg-config --cflags tracy   # Get include paths
pkg-config --libs tracy     # Get linker flags

# Example compilation
gcc myapp.c $(pkg-config --cflags --libs tracy) -o myapp
```

### 4. SOVERSION Property

**What Changed:**
- Added `SOVERSION ${TRACY_VERSION_MAJOR}` to library properties
- Added `OUTPUT_NAME tracy` for consistent library naming

**Why:**
- Enables proper shared library versioning on Unix systems
- Creates symlinks: `libtracy.so.0 -> libtracy.so.0.12.1`
- Allows multiple major versions to coexist
- Standard practice for shared libraries

**Result:**
```
libtracy.so -> libtracy.so.0       (symbolic link)
libtracy.so.0 -> libtracy.so.0.12.1 (symbolic link)
libtracy.so.0.12.1                  (actual library)
```

### 5. Improved Header Installation

**What Changed:**
- Replaced manual header lists with `file(GLOB ...)`
- Automatically collects all headers in public directories

**Why:**
- Easier maintenance - new headers are automatically included
- Reduces chance of forgetting to add headers to install
- Cleaner CMakeLists.txt

**Note:**
While generally `file(GLOB)` is discouraged in CMake, for installation of existing headers it's acceptable and more maintainable.

### 6. Build Configuration Visibility

**What Changed:**
- Config file now exports build configuration variables
- Consumers can query which features were enabled

**Why:**
- Downstream projects can adapt to Tracy's configuration
- Useful for conditional compilation based on Tracy features
- Provides transparency about library capabilities

**Available Variables:**
- `Tracy_ENABLE` - Whether profiling is enabled
- `Tracy_ON_DEMAND` - On-demand profiling support
- `Tracy_CALLSTACK` - Callstack collection enforced
- `Tracy_NO_CALLSTACK` - Callstack functionality disabled
- `Tracy_LIBUNWIND_BACKTRACE` - libunwind backend used
- `Tracy_DEBUGINFOD` - debuginfod support enabled
- `Tracy_STATIC` - Whether library is static

## Testing the Changes

### Build and Install
```bash
# Configure
cmake -S . -B build -DCMAKE_INSTALL_PREFIX=/usr/local

# Build
cmake --build build

# Install
cmake --install build
```

### Using in a CMake Project
```cmake
cmake_minimum_required(VERSION 3.10)
project(MyApp)

# Find Tracy
find_package(Tracy 0.12 REQUIRED)

# Link against Tracy
add_executable(myapp main.cpp)
target_link_libraries(myapp PRIVATE Tracy::TracyClient)

# Optional: Check configuration
if(Tracy_ENABLE)
    message(STATUS "Tracy profiling enabled")
endif()
```

### Using with pkg-config
```makefile
CFLAGS := $(shell pkg-config --cflags tracy)
LDFLAGS := $(shell pkg-config --libs tracy)

myapp: main.c
	$(CC) $(CFLAGS) main.c $(LDFLAGS) -o myapp
```

## Backwards Compatibility

All changes are backwards compatible:
- Existing CMakeLists.txt files will continue to work
- No changes to the Tracy API or headers
- No changes to build options or default behavior
- Only the packaging and installation improved

## Files Modified

1. `CMakeLists.txt` - Added version file generation, pkg-config support, improved properties
2. `Config.cmake.in` - Enhanced with build configuration and dependency handling
3. `tracy.pc.in` - New file for pkg-config support

## Benefits for Downstream Consumers

1. **Easier Integration**: Standard CMake `find_package()` with version support
2. **Better Dependency Management**: Automatic propagation of required dependencies
3. **Cross-Platform**: Works with both CMake and non-CMake build systems
4. **Version Safety**: Can specify minimum required versions
5. **Configuration Transparency**: Can query how Tracy was built
6. **Industry Standard**: Follows CMake and pkg-config best practices
