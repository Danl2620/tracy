set shell := ["bash", "-cu"]

_default:
  just --list

# Build project with CMake into the `build/` directory
# Usage: `just build` or override jobs: `JOBS=4 just build`
build dir=".":
   #!/usr/bin/env bash
   mkdir -p {{dir}}/build
   JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 1)}"
   cmake -S {{dir}} -B {{dir}}/build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -G "Ninja"
   cmake --build {{dir}}/build -- -j${JOBS}

package pkg="default":
  #!/usr/bin/env bash
  set -o pipefail
  nix build .#{{pkg}} -Lvvv 2>&1 | tee build.log

clean:
  git clean -fdx

# Build WASM profiler with Emscripten
# Requires emscripten to be installed and activated (e.g., source emsdk/emsdk_env.sh)
build-wasm:
  #!/usr/bin/env bash
  set -euo pipefail
  # Determine the correct Emscripten toolchain path
  if [ -f "${EMSDK}/share/emscripten/cmake/Modules/Platform/Emscripten.cmake" ]; then
    TOOLCHAIN="${EMSDK}/share/emscripten/cmake/Modules/Platform/Emscripten.cmake"
  elif [ -f "${EMSDK}/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake" ]; then
    TOOLCHAIN="${EMSDK}/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake"
  else
    echo "Error: Could not find Emscripten.cmake toolchain file"
    exit 1
  fi
  # Build the profiler GUI with Emscripten
  cmake -G Ninja -B profiler/build -S profiler \
    -DCMAKE_BUILD_TYPE=MinSizeRel \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN}"
  cmake --build profiler/build --parallel
  # Collect output
  mkdir -p bin
  cp profiler/build/index.html bin/
  cp profiler/build/favicon.svg bin/
  cp profiler/build/tracy-profiler.data bin/
  cp profiler/build/tracy-profiler.js bin/
  cp profiler/build/tracy-profiler.wasm bin/
  # Compress artifacts for distribution
  echo "Compressing artifacts..."
  zstd -18 -k -f profiler/build/tracy-profiler.js profiler/build/tracy-profiler.wasm
  gzip -9 -k -f profiler/build/tracy-profiler.js profiler/build/tracy-profiler.wasm
  cp profiler/build/tracy-profiler.js.gz bin/
  cp profiler/build/tracy-profiler.js.zst bin/
  cp profiler/build/tracy-profiler.wasm.gz bin/
  cp profiler/build/tracy-profiler.wasm.zst bin/
  echo "WASM profiler built successfully in bin/"

# Serve the WASM profiler locally on http://localhost:8000
# Requires the WASM profiler to be built first with 'just build-wasm'
serve-wasm:
  #!/usr/bin/env bash
  set -euo pipefail
  if [ ! -f "bin/index.html" ]; then
    echo "Error: WASM profiler not built. Run 'just build-wasm' first."
    exit 1
  fi
  cd bin && python3 ../serve-wasm.py

