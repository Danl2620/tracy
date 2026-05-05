{
  lib,
  stdenv,
  src,
  fetchFromGitHub,
  fetchFromGitLab,
  fetchurl,
  callPackage,
  coreutils,
  cmake,
  ninja,
  emscripten,
  nodejs,
  python3,
  zstd,
  gzip,
  git,
}:
let
  mkTracyWasmPackage = {
    version,
    srcHash,
    cpmSrcs ? [],
    patches ? [],
    extraBuildInputs ? [],
    embedTracy ? null,
  }: let
    sourceRoot = "source";
  in
    stdenv.mkDerivation {
      inherit patches sourceRoot;

      pname = "tracy-profiler-wasm";
      version = "${version}";

      srcs = [src] ++ cpmSrcs;

      postUnpack = (
        lib.strings.concatLines (
          lib.lists.forEach cpmSrcs (
            s:
            # Make CPM sources writable for patches and set CPM_<package>_SOURCE flags
              ''
                chmod -R u+w ${s.name}
                appendToVar cmakeFlags -DCPM_${s.name}_SOURCE=$(pwd)/${s.name}
              ''
              # PPQSort tries to download CPM.cmake
              # Provide it the newer version from tracy instead
              + (lib.optionalString (s.name == "PPQSort") ''
                cp ./${sourceRoot}/cmake/CPM.cmake PPQSort/cmake/CPM.cmake
              '')
          )
        )
      );

      nativeBuildInputs = [
        cmake
        ninja
        emscripten
        nodejs
        python3
        zstd
        gzip
        git
      ];

      cmakeFlags = [
        (lib.cmakeBool "BUILD_SHARED_LIBS" false)
        (lib.cmakeBool "CPM_LOCAL_PACKAGES_ONLY" true)
        (lib.cmakeBool "DOWNLOAD_CAPSTONE" false)
        (lib.cmakeBool "DOWNLOAD_FREETYPE" false)
        "-DCMAKE_TOOLCHAIN_FILE=${emscripten}/share/emscripten/cmake/Modules/Platform/Emscripten.cmake"
      ];

      dontUseCmakeBuildDir = true;

      configurePhase = ''
        export EMSDK=${emscripten}

        # Patch CMakeLists.txt to skip download if embed.tracy already exists
        substituteInPlace profiler/CMakeLists.txt \
          --replace-fail \
            'file(DOWNLOAD https://share.nereid.pl/i/embed.tracy ''${CMAKE_CURRENT_BINARY_DIR}/embed.tracy EXPECTED_MD5 ca0fa4f01e7b8ca5581daa16b16c768d)' \
            'if(NOT EXISTS "''${CMAKE_CURRENT_BINARY_DIR}/embed.tracy")
              file(DOWNLOAD https://share.nereid.pl/i/embed.tracy ''${CMAKE_CURRENT_BINARY_DIR}/embed.tracy EXPECTED_MD5 ca0fa4f01e7b8ca5581daa16b16c768d)
            endif()'

        # Copy the pre-fetched embed.tracy file
        ${lib.optionalString (embedTracy != null) ''
          mkdir -p profiler/build
          cp ${embedTracy} profiler/build/embed.tracy
        ''}

        cmake -G Ninja -B profiler/build -S profiler -DCMAKE_BUILD_TYPE=MinSizeRel $cmakeFlags
      '';

      buildPhase = ''
        cmake --build profiler/build --parallel
      '';

      installPhase = ''
        mkdir -p $out/bin

        # Copy main files
        cp profiler/build/index.html $out/bin/
        cp profiler/build/favicon.svg $out/bin/
        cp profiler/build/tracy-profiler.data $out/bin/
        cp profiler/build/tracy-profiler.js $out/bin/
        cp profiler/build/tracy-profiler.wasm $out/bin/

        # Create compressed versions
        ${zstd}/bin/zstd -18 -k profiler/build/tracy-profiler.js -o $out/bin/tracy-profiler.js.zst
        ${zstd}/bin/zstd -18 -k profiler/build/tracy-profiler.wasm -o $out/bin/tracy-profiler.wasm.zst
        ${gzip}/bin/gzip -9 -k -c profiler/build/tracy-profiler.js > $out/bin/tracy-profiler.js.gz
        ${gzip}/bin/gzip -9 -k -c profiler/build/tracy-profiler.wasm > $out/bin/tracy-profiler.wasm.gz

        # Install server script
        cp ${../serve-wasm.py} $out/bin/serve-wasm.py
        chmod +x $out/bin/serve-wasm.py
      '';

      meta = {
        description = "Tracy Profiler WASM build for web browsers";
        homepage = "https://github.com/wolfpld/tracy";
        license = lib.licenses.bsd3;
        platforms = lib.platforms.all;
      };
    };
in {
  tracy-wasm = let
    cpmData = import ./cpm-srcs.nix {
      inherit
        fetchFromGitHub
        fetchFromGitLab
        ;
      # Don't pass system packages - use CPM versions for WASM
      md4c = null;
      pugixml = null;
      curl = null;
    };
    # Filter out packages not needed for WASM build
    # These are inside if(NOT EMSCRIPTEN) blocks in cmake/vendor.cmake
    excludeForWasm = ["base64" "tidy" "usearch" "pugixml" "libcurl"];
    filteredCpmSrcs = builtins.filter (src: !(builtins.elem src.name excludeForWasm)) cpmData.cpmSrcs;

    # Pre-fetch the embed.tracy file needed for WASM build
    embedTracy = fetchurl {
      url = "https://share.nereid.pl/i/embed.tracy";
      hash = "sha256-XoRoxINIquvEB+iIK6EwtV/xVMKUk/5EQmvvEtPm3wI=";
    };
  in mkTracyWasmPackage (cpmData // {
    cpmSrcs = filteredCpmSrcs;
    embedTracy = embedTracy;
  });
}
