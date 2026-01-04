{
  lib,
  stdenv,
  cmake,
  ninja,
  pkg-config,
  src,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "tracy-client";
  version = "0.12.1";

  # Single output - everything in one place for simplicity
  # The dev files (headers, cmake) are small and usually needed anyway

  inherit src;

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
  ];

  # Client library has minimal dependencies - just threads
  # No GUI libraries, no profiler dependencies
  buildInputs = [];

  cmakeFlags = [
    (lib.cmakeBool "TRACY_STATIC" false) # Build as shared library
    (lib.cmakeBool "TRACY_ENABLE" true) # Enable profiling
  ];

  # Only build the client library, not profiler or tools
  # The root CMakeLists.txt only builds TracyClient - perfect for our needs!

  # Standard cmake build - builds only TracyClient target by default
  # No need for custom build phase since root CMakeLists.txt is already minimal

  meta = with lib; {
    description = "Tracy Profiler - Client library only (instrumentation for applications)";
    longDescription = ''
      Tracy client library for instrumenting C/C++ applications.
      This package contains only the client library without the profiler GUI,
      making it suitable for production deployments with minimal dependencies.

      Link this library into your application to enable Tracy profiling.
      Use the full 'tracy' package to get the profiler GUI for visualization.
    '';
    homepage = "https://github.com/wolfpld/tracy";
    license = licenses.bsd3;
    maintainers = with maintainers; [];
    platforms = platforms.unix;
  };
})
