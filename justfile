# Tracy Profiler Justfile
# User-friendly commands for building and working with Tracy

# Default build type (can be overridden: just build-type=Debug client)
build-type := "Release"

# Default recipe - show available commands
default:
    @just --list

# ============================================================================
# SETUP - Information and Configuration
# ============================================================================

# Show build configuration info
[group: "01-setup"]
info:
    @echo "Tracy Profiler Build Configuration"
    @echo "==================================="
    @echo "Build Type: {{build-type}}"
    @echo "CMake:      $(cmake --version | head -n1)"
    @echo "Compiler:   $(c++ --version | head -n1)"
    @echo "Platform:   $(uname -s)"
    @echo "Architecture: $(uname -m)"
    @just version

# Show Tracy version from git
[group: "01-setup"]
version:
    @git describe --tags --long --match "v*" 2>/dev/null || echo "Version info not available"

# Show usage examples
[group: "01-setup"]
examples:
    @echo "Tracy Profiler - Common Usage Examples"
    @echo "======================================="
    @echo ""
    @echo "Basic workflow:"
    @echo "  just quick              # Build profiler + test"
    @echo "  just run-test &         # Run test app in background"
    @echo "  just run-profiler       # Open profiler GUI"
    @echo ""
    @echo "Build variations:"
    @echo "  just build-type=Debug profiler"
    @echo "  just client-on-demand"
    @echo "  just profiler-x11       # Force X11 on Linux"
    @echo "  just profiler-no-stats  # Faster trace processing"
    @echo ""
    @echo "Tools:"
    @echo "  just capture            # Build headless capture"
    @echo "  just csvexport          # Build CSV exporter"
    @echo "  just tools              # Build all tools"
    @echo ""
    @echo "Testing:"
    @echo "  just test-on-demand     # Test with on-demand mode"
    @echo "  just test-demangle      # Test with demangling"
    @echo ""
    @echo "Cleanup:"
    @echo "  just clean-all          # Remove all build dirs"
    @echo "  just clean-profiler     # Remove only profiler build"

# ============================================================================
# HOUSEKEEPING - Clean and Maintenance
# ============================================================================

# Clean all build directories
[group: "02-housekeeping"]
clean-all: clean-client clean-profiler clean-tools clean-test clean-meson
    @echo "All build directories cleaned"

# Clean client library build
[group: "02-housekeeping"]
clean-client:
    rm -rf build

# Clean profiler build
[group: "02-housekeeping"]
clean-profiler:
    rm -rf profiler/build

# Clean all command-line tools
[group: "02-housekeeping"]
clean-tools:
    rm -rf capture/build csvexport/build update/build import/build

# Clean test application build
[group: "02-housekeeping"]
clean-test:
    rm -rf test/build

# Clean Meson build
[group: "02-housekeeping"]
clean-meson:
    rm -rf build-meson

# Format code using clang-format (only format changed files in git)
[group: "02-housekeeping"]
format:
    @echo "Formatting modified files..."
    @git diff --name-only --diff-filter=ACMR | grep -E '\.(cpp|hpp|h|c)$$' | xargs -r clang-format -i
    @git diff --cached --name-only --diff-filter=ACMR | grep -E '\.(cpp|hpp|h|c)$$' | xargs -r clang-format -i
    @echo "Done"

# ============================================================================
# BUILD - Client Library
# ============================================================================

# Build the Tracy client library
[group: "03-build"]
client:
    cmake -B build -S . -DCMAKE_BUILD_TYPE={{build-type}} -DTRACY_ENABLE=ON
    cmake --build build --parallel

# Build client library with on-demand profiling
[group: "03-build"]
client-on-demand:
    cmake -B build -S . -DCMAKE_BUILD_TYPE={{build-type}} -DTRACY_ENABLE=ON -DTRACY_ON_DEMAND=ON
    cmake --build build --parallel

# Build client library with callstack capture (depth: default 10)
[group: "03-build"]
client-callstack depth="10":
    cmake -B build -S . -DCMAKE_BUILD_TYPE={{build-type}} -DTRACY_ENABLE=ON -DTRACY_CALLSTACK={{depth}}
    cmake --build build --parallel

# Build client library for localhost only
[group: "03-build"]
client-localhost:
    cmake -B build -S . -DCMAKE_BUILD_TYPE={{build-type}} -DTRACY_ENABLE=ON -DTRACY_ONLY_LOCALHOST=ON
    cmake --build build --parallel

# Build client library using Meson (alternative build system)
[group: "03-build"]
client-meson:
    meson setup build-meson
    meson compile -C build-meson

# ============================================================================
# BUILD - Profiler GUI
# ============================================================================

# Build the Tracy profiler GUI
[group: "03-build"]
profiler:
    cmake -B profiler/build -S profiler -DCMAKE_BUILD_TYPE={{build-type}}
    cmake --build profiler/build --parallel
    @echo "\nProfiler built at: profiler/build/tracy-profiler"

# Build profiler with X11 instead of Wayland (Linux)
[group: "03-build"]
profiler-x11:
    cmake -B profiler/build -S profiler -DCMAKE_BUILD_TYPE={{build-type}} -DLEGACY=ON
    cmake --build profiler/build --parallel
    @echo "\nProfiler built at: profiler/build/tracy-profiler"

# Build profiler without statistics (faster processing)
[group: "03-build"]
profiler-no-stats:
    cmake -B profiler/build -S profiler -DCMAKE_BUILD_TYPE={{build-type}} -DNO_STATISTICS=ON
    cmake --build profiler/build --parallel
    @echo "\nProfiler built at: profiler/build/tracy-profiler"

# Build profiler with self-profiling enabled
[group: "03-build"]
profiler-self:
    cmake -B profiler/build -S profiler -DCMAKE_BUILD_TYPE={{build-type}} -DSELF_PROFILE=ON
    cmake --build profiler/build --parallel
    @echo "\nProfiler built at: profiler/build/tracy-profiler"

# Build profiler with sanitizers enabled
[group: "03-build"]
profiler-sanitize:
    cmake -B profiler/build -S profiler -DCMAKE_BUILD_TYPE={{build-type}} -DSANITIZE=ON
    cmake --build profiler/build --parallel
    @echo "\nProfiler built at: profiler/build/tracy-profiler"

# ============================================================================
# BUILD - Command-Line Tools
# ============================================================================

# Build the capture utility (headless trace capture)
[group: "03-build"]
capture:
    cmake -B capture/build -S capture -DCMAKE_BUILD_TYPE={{build-type}}
    cmake --build capture/build --parallel
    @echo "\nCapture utility built at: capture/build/tracy-capture"

# Build the CSV export utility
[group: "03-build"]
csvexport:
    cmake -B csvexport/build -S csvexport -DCMAKE_BUILD_TYPE={{build-type}}
    cmake --build csvexport/build --parallel
    @echo "\nCSV export utility built at: csvexport/build/tracy-csvexport"

# Build the update utility (offline symbol resolution)
[group: "03-build"]
update:
    cmake -B update/build -S update -DCMAKE_BUILD_TYPE={{build-type}}
    cmake --build update/build --parallel
    @echo "\nUpdate utility built at: update/build/tracy-update"

# Build the import utilities
[group: "03-build"]
import:
    cmake -B import/build -S import -DCMAKE_BUILD_TYPE={{build-type}}
    cmake --build import/build --parallel
    @echo "\nImport utilities built in: import/build/"

# Build all command-line tools
[group: "03-build"]
tools: capture csvexport update import

# ============================================================================
# BUILD - Composite Targets
# ============================================================================

# Build everything (client, profiler, tools, test)
[group: "03-build"]
all: client profiler tools test
    @echo "\n=== All components built successfully ==="
    @echo "Profiler:      profiler/build/tracy-profiler"
    @echo "Capture:       capture/build/tracy-capture"
    @echo "CSV Export:    csvexport/build/tracy-csvexport"
    @echo "Update:        update/build/tracy-update"
    @echo "Import:        import/build/"
    @echo "Test:          test/build/tracy-test"

# Build only the most commonly used components (profiler + test)
[group: "03-build"]
quick: profiler test
    @echo "\n=== Quick build complete ==="
    @echo "Profiler:      profiler/build/tracy-profiler"
    @echo "Test:          test/build/tracy-test"

# ============================================================================
# TEST - Build and Run Tests
# ============================================================================

# Build the test application
[group: "04-test"]
test:
    cmake -B test/build -S test -DCMAKE_BUILD_TYPE={{build-type}}
    cmake --build test/build --parallel
    @echo "\nTest application built at: test/build/tracy-test"

# Build test with on-demand profiling
[group: "04-test"]
test-on-demand:
    cmake -B test/build -S test -DCMAKE_BUILD_TYPE={{build-type}} -DTRACY_ON_DEMAND=ON
    cmake --build test/build --parallel
    @echo "\nTest application built at: test/build/tracy-test"

# Build test with delayed init and manual lifetime
[group: "04-test"]
test-manual:
    cmake -B test/build -S test -DCMAKE_BUILD_TYPE={{build-type}} -DTRACY_DELAYED_INIT=ON -DTRACY_MANUAL_LIFETIME=ON
    cmake --build test/build --parallel
    @echo "\nTest application built at: test/build/tracy-test"

# Build test with demangling enabled
[group: "04-test"]
test-demangle:
    cmake -B test/build -S test -DCMAKE_BUILD_TYPE={{build-type}} -DTRACY_DEMANGLE=ON
    cmake --build test/build --parallel
    @echo "\nTest application built at: test/build/tracy-test"

# Run the test application
[group: "04-test"]
run-test: test
    ./test/build/tracy-test

# ============================================================================
# RUN - Execute Built Binaries
# ============================================================================

# Run the profiler GUI
[group: "05-run"]
run-profiler: profiler
    ./profiler/build/tracy-profiler
