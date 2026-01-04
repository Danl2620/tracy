set shell := ["bash", "-cu"]

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

