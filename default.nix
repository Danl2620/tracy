##     hash = "sha256-JiLY/rCZVdFFq/taWmk8nzY868DEm8vhCf231tFjuIg=";
{ lib
, stdenv
, fetchFromGitHub
, cmake
, pkg-config
, capstone
, imgui
, freetype
, glfw
, tbb
, zstd
, libGL
, dbus
, libxkbcommon
, wayland
, wayland-protocols
, withWayland ? stdenv.hostPlatform.isLinux
, legacyX11 ? false
}:

stdenv.mkDerivation rec {
  pname = "tracy";
  version = "0.12.1";

  src = fetchFromGitHub {
    owner = "wolfpld";
    repo = "tracy";
    rev = "v${version}";
    hash = "sha256-JiLY/rCZVdFFq/taWmk8nzY868DEm8vhCf231tFjuIg=";
  };

  sourceRoot = "${src.name}/profiler";

  nativeBuildInputs = [
    cmake
    pkg-config
    capstone
    imgui
  ];

  # Patch the CMakeLists to not use CPM for dependencies we provide
  # postPatch = ''
  #   substituteInPlace CMakeLists.txt \
  #     --replace-fail 'CPMAddPackage("gh:capstone-engine/capstone@6.0.0-Alpha1")' "" \
  #     --replace-fail 'CPMAddPackage(' '# CPMAddPackage('
  # '';

  buildInputs = [
    capstone
    freetype
    glfw
    tbb
    zstd
  ] ++ lib.optionals stdenv.hostPlatform.isLinux [
    dbus
    libGL
    libxkbcommon
  ] ++ lib.optionals withWayland [
    wayland
    wayland-protocols
  ];

  cmakeFlags = [
    (lib.cmakeBool "LEGACY" legacyX11)
    "-DCPM_USE_LOCAL_PACKAGES=ON"
    "-DCPM_LOCAL_PACKAGES_ONLY=ON"
    "-DBUILD_SHARED_LIBS=0"
    "-DDOWNLOAD_CAPSTONE=OFF"
    "-DDOWNLOAD_IMGUI=OFF"
    "-DTRACY_IMGUI_SOURCE_DIR=${imgui}/include/imgui"
  ];

  # Prevent CPM from trying to download packages
  env.CPM_SOURCE_CACHE = "/build/cpm-cache";

  meta = with lib; {
    description = "Real-time, nanosecond resolution, remote telemetry frame profiler";
    longDescription = ''
      Tracy is a real time, nanosecond resolution, remote telemetry, hybrid
      frame and sampling profiler for games and other applications.
      
      This package provides the GUI profiler application for viewing traces.
    '';
    homepage = "https://github.com/wolfpld/tracy";
    changelog = "https://github.com/wolfpld/tracy/blob/v${version}/NEWS";
    license = licenses.bsd3;
    maintainers = with maintainers; [ ];
    platforms = platforms.linux ++ platforms.darwin;
    mainProgram = "tracy-profiler";
  };
}
