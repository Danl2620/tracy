# GitHub Actions Just Module

This module (`extra/action.just`) replicates the CI workflows from `.github/workflows/` as `just` tasks, allowing you to run the same build and test sequences locally.

## Quick Start

```bash
# Show all CI tasks
just --list | grep ci-

# Show required dependencies
just ci-deps

# Run the Linux workflow (most comprehensive)
just ci-linux

# Run all workflows except deployment
just ci-all

# Clean CI artifacts
just ci-clean
```

## Available Workflows

### 1. `ci-build` - Windows/macOS Build Workflow
Replicates `.github/workflows/build.yml`

```bash
# Full workflow
just ci-build

# Individual steps
just ci-build-profiler
just ci-build-update
just ci-build-capture
just ci-build-csvexport
just ci-build-import
just ci-build-library
just ci-build-artifacts
```

**Dependencies:**
- cmake (3.16+)
- meson, ninja
- pkg-config, glfw (macOS)
- Python 3.x (Windows)

### 2. `ci-linux` - Linux Build + Test Workflow
Replicates `.github/workflows/linux.yml` (most comprehensive - includes testing)

```bash
# Full workflow
just ci-linux

# Build steps
just ci-linux-builds

# Test configurations
just ci-linux-tests
just ci-linux-test-default
just ci-linux-test-on-demand
just ci-linux-test-manual
just ci-linux-test-demangle

# Collect artifacts
just ci-linux-artifacts
```

**Dependencies:**
- cmake (3.16+)
- meson
- freetype2, debuginfod
- wayland, wayland-protocols, dbus
- libxkbcommon, libglvnd
- nodejs

**Arch Linux (recommended):**
```bash
pacman -S freetype2 debuginfod wayland dbus libxkbcommon libglvnd meson cmake git wayland-protocols nodejs
```

### 3. `ci-emscripten` - WebAssembly Build Workflow
Replicates `.github/workflows/emscripten.yml`

```bash
# Full workflow (build + compress)
just ci-emscripten

# Individual steps
just ci-emscripten-build
just ci-emscripten-compress
just ci-emscripten-artifacts

# Deploy (requires SFTP credentials)
just ci-emscripten-deploy
```

**Dependencies:**
- cmake (3.16+)
- ninja
- emscripten SDK (4.0.10+)
- zstd, gzip
- python, unzip
- lftp (for deployment)

**Emscripten Setup:**
```bash
git clone https://github.com/emscripten-core/emsdk.git ~/.emsdk
cd ~/.emsdk
./emsdk install 4.0.10
./emsdk activate 4.0.10
source ~/.emsdk/emsdk_env.sh
```

### 4. `ci-latex` - Manual PDF Build Workflow
Replicates `.github/workflows/latex.yml`

```bash
# Build manual PDF
just ci-latex

# Clean LaTeX build files
just ci-latex-clean
```

**Dependencies:**
- texlive-full or texlive-latex-extra
- latexmk

## Environment Variables

The module respects the following environment variables:

### Build Configuration
- `CPM_SOURCE_CACHE` - Cache directory for CMake Package Manager downloads
  - Default: `<project-root>/cpm-cache`
  - Same as GitHub Actions for consistent dependency caching

### Emscripten
- `EMSDK` - Path to Emscripten SDK
  - Default: `~/.emsdk`
  - Required for WebAssembly builds

### SFTP Deployment (Emscripten)
Required for `just ci-emscripten-deploy`:
- `SFTP_USERNAME` - SSH username (default: `your-username`)
- `SFTP_SERVER` - Server hostname (default: `your-server.com`)
- `SFTP_PORT` - SSH port (default: `22`)
- `SFTP_PRIVATE_KEY` - SSH private key path (default: `~/.ssh/id_rsa`)
- `SFTP_REMOTE_PATH` - Remote deployment path (default: `/var/www/tracy`)

Example:
```bash
export SFTP_USERNAME=deploy
export SFTP_SERVER=tracy.example.com
export SFTP_PORT=22
export SFTP_PRIVATE_KEY=~/.ssh/deploy_key
export SFTP_REMOTE_PATH=/var/www/tracy-profiler
just ci-emscripten-deploy
```

## Artifacts

All workflows collect build artifacts in the `bin/` directory:

### build.yml / linux.yml artifacts:
- `bin/tracy-profiler` (or `.exe` on Windows)
- `bin/tracy-update`
- `bin/tracy-capture`
- `bin/tracy-csvexport`
- `bin/tracy-import-chrome`
- `bin/tracy-import-fuchsia`
- `bin/lib/` (library installation)

### emscripten.yml artifacts:
- `bin/index.html`
- `bin/favicon.svg`
- `bin/tracy-profiler.data`
- `bin/tracy-profiler.js.{gz,zst}`
- `bin/tracy-profiler.wasm.{gz,zst}`

### latex.yml artifacts:
- `bin/tracy.pdf`

## Platform-Specific Notes

### Linux
The `ci-linux` workflow is the most comprehensive and is recommended for local CI testing. It uses Arch Linux packages by default (matching GitHub Actions).

### macOS
Use `ci-build` workflow. Install dependencies via Homebrew:
```bash
brew install pkg-config glfw meson
```

### Windows
Use `ci-build` workflow. Requires:
- Visual Studio (for MSBuild)
- Python 3.x
- Meson and Ninja (via pip)

```powershell
pip install meson ninja
```

### Cross-Platform
The `ci-build-artifacts` task automatically detects the platform and copies the correct binary extensions (`.exe` on Windows, no extension on Unix).

## Differences from GitHub Actions

1. **No containerization**: Tasks run directly on your system, not in containers
2. **No automatic dependency installation**: You must install dependencies manually
3. **No artifact upload**: Artifacts are collected locally in `bin/` instead of uploaded to GitHub
4. **Deployment requires manual credentials**: SFTP credentials must be provided via environment variables
5. **No parallel matrix builds**: Each task runs sequentially, not across multiple OS versions

## Tips

### Speed up builds with CPM cache
```bash
export CPM_SOURCE_CACHE=~/.cache/CPM
```

### Run specific test configuration
```bash
just ci-linux-test-on-demand  # Only test on-demand mode
```

### Build without testing
```bash
just ci-linux-builds  # Skip test configurations
```

### Clean between runs
```bash
just ci-clean  # Remove all build artifacts
```

### Check dependencies before running
```bash
just ci-deps  # Show all required dependencies
```
