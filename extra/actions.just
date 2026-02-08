# GitHub Actions Tasks Module
# This module replicates the CI workflows from .github/workflows/
# allowing local execution of the same build and test sequences

# ============================================================================
# VARIABLES - Override as needed
# ============================================================================

# Git revision for profiler builds (defaults to current HEAD)
git-rev := `git rev-parse HEAD`

# CPM cache directory (speeds up dependency downloads)
cpm-cache := env_var_or_default("CPM_SOURCE_CACHE", justfile_directory() + "/cpm-cache")

# Emscripten SDK path (required for wasm builds)
emsdk-path := env_var_or_default("EMSDK", env_var_or_default("HOME", "") + "/.emsdk")

# SFTP deployment secrets (placeholders - set via environment)
sftp-username := env_var_or_default("SFTP_USERNAME", "your-username")
sftp-server := env_var_or_default("SFTP_SERVER", "your-server.com")
sftp-port := env_var_or_default("SFTP_PORT", "22")
sftp-key := env_var_or_default("SFTP_PRIVATE_KEY", "~/.ssh/id_rsa")
sftp-remote-path := env_var_or_default("SFTP_REMOTE_PATH", "/var/www/tracy")

# ============================================================================
# DEPENDENCY INFORMATION
# ============================================================================

# Show required dependencies for each workflow
[group: "06-ci"]
ci-deps:
    #!/usr/bin/env bash
    echo "GitHub Actions CI - Required Dependencies"
    echo "=========================================="
    echo ""
    echo "build.yml (Windows/macOS builds):"
    echo "  - cmake (3.16+)"
    echo "  - meson, ninja (for library build)"
    echo "  - pkg-config, glfw (macOS via brew)"
    echo "  - Python 3.x (Windows, for meson)"
    echo ""
    echo "linux.yml (Linux builds + testing):"
    echo "  - cmake (3.16+)"
    echo "  - meson"
    echo "  - freetype2, debuginfod"
    echo "  - wayland, wayland-protocols, dbus"
    echo "  - libxkbcommon, libglvnd"
    echo "  - nodejs (for build tools)"
    echo ""
    echo "emscripten.yml (WebAssembly build):"
    echo "  - cmake (3.16+)"
    echo "  - ninja"
    echo "  - emscripten SDK (4.0.10+)"
    echo "  - zstd, gzip (for compression)"
    echo "  - python, unzip"
    echo "  - lftp or sshpass (for deployment)"
    echo ""
    echo "latex.yml (Manual PDF):"
    echo "  - texlive-full or texlive-latex-extra"
    echo "  - latexmk"
    echo ""
    echo "Environment Variables:"
    echo "  CPM_SOURCE_CACHE={{cpm-cache}}"
    echo "  EMSDK={{emsdk-path}}"
    echo "  SFTP_USERNAME={{sftp-username}}"
    echo "  SFTP_SERVER={{sftp-server}}"
    echo "  SFTP_PORT={{sftp-port}}"
    echo "  SFTP_PRIVATE_KEY={{sftp-key}}"
    echo "  SFTP_REMOTE_PATH={{sftp-remote-path}}"

# ============================================================================
# build.yml - Windows/macOS Build Workflow
# ============================================================================

# Run the full build.yml workflow (all utilities + library)
[group: "06-ci"]
ci-build: ci-build-profiler ci-build-update ci-build-capture ci-build-csvexport ci-build-import ci-build-library
    @echo "✓ build.yml workflow complete"
    @echo "Artifacts in: bin/"

# Build profiler GUI (build.yml step)
[group: "06-ci"]
ci-build-profiler:
    @echo "==> Building Profiler GUI"
    cmake -B profiler/build -S profiler -DCMAKE_BUILD_TYPE=Release -DGIT_REV={{git-rev}}
    cmake --build profiler/build --parallel --config Release

# Build update utility (build.yml step)
[group: "06-ci"]
ci-build-update:
    @echo "==> Building Update utility"
    cmake -B update/build -S update -DCMAKE_BUILD_TYPE=Release
    cmake --build update/build --parallel --config Release

# Build capture utility (build.yml step)
[group: "06-ci"]
ci-build-capture:
    @echo "==> Building Capture utility"
    cmake -B capture/build -S capture -DCMAKE_BUILD_TYPE=Release
    cmake --build capture/build --parallel --config Release

# Build csvexport utility (build.yml step)
[group: "06-ci"]
ci-build-csvexport:
    @echo "==> Building Csvexport utility"
    cmake -B csvexport/build -S csvexport -DCMAKE_BUILD_TYPE=Release
    cmake --build csvexport/build --parallel --config Release

# Build import utilities (build.yml step)
[group: "06-ci"]
ci-build-import:
    @echo "==> Building Import utilities"
    cmake -B import/build -S import -DCMAKE_BUILD_TYPE=Release
    cmake --build import/build --parallel --config Release

# Build library with Meson (build.yml step - non-Windows)
[group: "06-ci"]
ci-build-library:
    @echo "==> Building Library with Meson"
    meson setup -Dprefix={{justfile_directory()}}/bin/lib build
    meson compile -C build
    meson install -C build

# Collect build artifacts into bin/ directory (build.yml step)
[group: "06-ci"]
ci-build-artifacts:
    #!/usr/bin/env bash
    echo "==> Collecting artifacts"
    mkdir -p bin

    # Copy binaries (adjust for platform)
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
        # Windows
        cp profiler/build/Release/tracy-profiler.exe bin/
        cp update/build/Release/tracy-update.exe bin/
        cp capture/build/Release/tracy-capture.exe bin/
        cp csvexport/build/Release/tracy-csvexport.exe bin/
        cp import/build/Release/tracy-import-chrome.exe bin/
        cp import/build/Release/tracy-import-fuchsia.exe bin/
    else
        # Unix-like (macOS/Linux)
        cp profiler/build/tracy-profiler bin/
        cp update/build/tracy-update bin/
        cp capture/build/tracy-capture bin/
        cp csvexport/build/tracy-csvexport bin/
        cp import/build/tracy-import-chrome bin/
        cp import/build/tracy-import-fuchsia bin/
    fi

    echo "✓ Artifacts collected in bin/"

# ============================================================================
# linux.yml - Linux Build + Test Workflow
# ============================================================================

# Run the full linux.yml workflow (builds + all test configurations)
[group: "06-ci"]
ci-linux: ci-linux-builds ci-linux-tests ci-linux-artifacts
    @echo "✓ linux.yml workflow complete"
    @echo "Artifacts in: bin/"

# Build all components (linux.yml build steps)
[group: "06-ci"]
ci-linux-builds: ci-build-profiler ci-build-update ci-build-capture ci-build-csvexport ci-build-import ci-build-library
    @echo "✓ Linux builds complete"

# Run all test configurations (linux.yml test step)
[group: "06-ci"]
ci-linux-tests: ci-linux-test-default ci-linux-test-on-demand ci-linux-test-manual ci-linux-test-demangle
    @echo "✓ All test configurations passed"

# Test with default flags
[group: "06-ci"]
ci-linux-test-default:
    @echo "==> Testing with default flags"
    cmake -B test/build -S test -DCMAKE_BUILD_TYPE=Release
    cmake --build test/build --parallel
    rm -rf test/build

# Test with TRACY_ON_DEMAND
[group: "06-ci"]
ci-linux-test-on-demand:
    @echo "==> Testing with TRACY_ON_DEMAND"
    cmake -B test/build -S test -DCMAKE_BUILD_TYPE=Release -DTRACY_ON_DEMAND=ON
    cmake --build test/build --parallel
    rm -rf test/build

# Test with TRACY_DELAYED_INIT + TRACY_MANUAL_LIFETIME
[group: "06-ci"]
ci-linux-test-manual:
    @echo "==> Testing with TRACY_DELAYED_INIT + TRACY_MANUAL_LIFETIME"
    cmake -B test/build -S test -DCMAKE_BUILD_TYPE=Release -DTRACY_DELAYED_INIT=ON -DTRACY_MANUAL_LIFETIME=ON
    cmake --build test/build --parallel
    rm -rf test/build

# Test with TRACY_DEMANGLE
[group: "06-ci"]
ci-linux-test-demangle:
    @echo "==> Testing with TRACY_DEMANGLE"
    cmake -B test/build -S test -DCMAKE_BUILD_TYPE=Release -DTRACY_DEMANGLE=ON
    cmake --build test/build --parallel
    rm -rf test/build

# Collect and strip Linux artifacts (linux.yml artifacts step)
[group: "06-ci"]
ci-linux-artifacts:
    #!/usr/bin/env bash
    echo "==> Collecting and stripping Linux artifacts"
    mkdir -p bin
    cp profiler/build/tracy-profiler bin/
    cp update/build/tracy-update bin/
    cp capture/build/tracy-capture bin/
    cp csvexport/build/tracy-csvexport bin/
    cp import/build/tracy-import-chrome bin/
    cp import/build/tracy-import-fuchsia bin/
    strip bin/tracy-*
    echo "✓ Artifacts stripped and collected in bin/"

# ============================================================================
# emscripten.yml - WebAssembly Build + Deploy Workflow
# ============================================================================

# Run the full emscripten.yml workflow (build + compress, skip deploy)
[group: "06-ci"]
ci-emscripten: ci-emscripten-build ci-emscripten-compress ci-emscripten-artifacts
    @echo "✓ emscripten.yml build complete"
    @echo "Artifacts in: bin/"
    @echo "To deploy: just ci-emscripten-deploy"

# Build profiler for WebAssembly (emscripten.yml build step)
[group: "06-ci"]
ci-emscripten-build:
    #!/usr/bin/env bash
    echo "==> Building Profiler for WebAssembly"

    # Check if emscripten is available
    if [[ ! -f "{{emsdk-path}}/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake" ]]; then
        echo "ERROR: Emscripten SDK not found at {{emsdk-path}}"
        echo "Please install emsdk and set EMSDK environment variable"
        echo "  git clone https://github.com/emscripten-core/emsdk.git ~/.emsdk"
        echo "  cd ~/.emsdk && ./emsdk install 4.0.10 && ./emsdk activate 4.0.10"
        echo "  source ~/.emsdk/emsdk_env.sh"
        exit 1
    fi

    source {{emsdk-path}}/emsdk_env.sh
    cmake -G Ninja -B profiler/build -S profiler \
        -DCMAKE_BUILD_TYPE=MinSizeRel \
        -DGIT_REV={{git-rev}} \
        -DCMAKE_TOOLCHAIN_FILE={{emsdk-path}}/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake
    cmake --build profiler/build --parallel

# Compress WebAssembly artifacts (emscripten.yml compress step)
[group: "06-ci"]
ci-emscripten-compress:
    @echo "==> Compressing artifacts (zstd + gzip)"
    zstd -18 -f profiler/build/tracy-profiler.js profiler/build/tracy-profiler.wasm
    gzip -9 -f profiler/build/tracy-profiler.js profiler/build/tracy-profiler.wasm

# Collect WebAssembly artifacts (emscripten.yml artifacts step)
[group: "06-ci"]
ci-emscripten-artifacts:
    @echo "==> Collecting WebAssembly artifacts"
    mkdir -p bin
    cp profiler/build/index.html bin/
    cp profiler/build/favicon.svg bin/
    cp profiler/build/tracy-profiler.data bin/
    cp profiler/build/tracy-profiler.js.gz bin/
    cp profiler/build/tracy-profiler.js.zst bin/
    cp profiler/build/tracy-profiler.wasm.gz bin/
    cp profiler/build/tracy-profiler.wasm.zst bin/
    @echo "✓ WebAssembly artifacts collected in bin/"

# Deploy WebAssembly build via SFTP (emscripten.yml deploy job)
[group: "06-ci"]
ci-emscripten-deploy:
    #!/usr/bin/env bash
    echo "==> Deploying WebAssembly build via SFTP"
    echo "Server: {{sftp-server}}:{{sftp-port}}"
    echo "Remote path: {{sftp-remote-path}}"

    if [[ "{{sftp-username}}" == "your-username" ]]; then
        echo "ERROR: SFTP credentials not configured"
        echo "Set environment variables:"
        echo "  export SFTP_USERNAME=your-username"
        echo "  export SFTP_SERVER=your-server.com"
        echo "  export SFTP_PORT=22"
        echo "  export SFTP_PRIVATE_KEY=~/.ssh/id_rsa"
        echo "  export SFTP_REMOTE_PATH=/var/www/tracy"
        exit 1
    fi

    # Using lftp for SFTP deployment (alternative: use scp/sftp directly)
    lftp -c "
        set sftp:auto-confirm yes
        set sftp:connect-program 'ssh -i {{sftp-key}} -p {{sftp-port}}'
        open sftp://{{sftp-username}}@{{sftp-server}}
        mirror -R bin {{sftp-remote-path}}
        bye
    "

    echo "✓ Deployment complete"

# ============================================================================
# latex.yml - Manual PDF Build Workflow
# ============================================================================

# Build the Tracy manual PDF (latex.yml workflow)
[group: "06-ci"]
ci-latex:
    @echo "==> Building Tracy manual PDF"
    cd manual && latexmk -pdf tracy.tex
    mkdir -p bin
    cp manual/tracy.pdf bin/
    @echo "✓ Manual PDF generated: bin/tracy.pdf"

# Clean LaTeX build files
[group: "06-ci"]
ci-latex-clean:
    @echo "==> Cleaning LaTeX build files"
    cd manual && latexmk -C

# ============================================================================
# COMPOSITE WORKFLOWS
# ============================================================================

# Run all CI workflows (except deployment)
[group: "06-ci"]
ci-all: ci-linux ci-latex
    @echo "✓ All CI workflows complete"
    @echo "Note: Emscripten build skipped (requires emsdk setup)"
    @echo "To build WASM: just ci-emscripten"

# Clean all CI build artifacts
[group: "06-ci"]
ci-clean:
    @echo "==> Cleaning CI artifacts"
    rm -rf bin/
    rm -rf profiler/build update/build capture/build csvexport/build import/build test/build build
    @just ci-latex-clean
    @echo "✓ CI artifacts cleaned"
