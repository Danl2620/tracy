{
  description = "Tracy - A real time, nanosecond resolution, remote telemetry, hybrid frame and sampling profiler for games and other applications";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # CPM dependencies from tracy-0.13.nix
    imgui = {
      url = "github:ocornut/imgui/v1.92.5-docking";
      flake = false;
    };

    nativefiledialog-extended = {
      url = "github:btzy/nativefiledialog-extended/v1.2.1";
      flake = false;
    };

    ppqsort = {
      url = "github:GabTux/PPQSort/v1.0.6";
      flake = false;
    };

    packageproject-cmake = {
      url = "github:TheLartians/PackageProject.cmake/v1.11.1";
      flake = false;
    };

    capstone = {
      url = "github:capstone-engine/capstone/6.0.0-Alpha5";
      flake = false;
    };

    base64 = {
      url = "github:aklomp/base64/v0.5.2";
      flake = false;
    };

    usearch = {
      url = "github:unum-cloud/usearch/v2.21.3?submodules=1";
      flake = false;
    };

    glfw = {
      url = "github:glfw/glfw/3.4";
      flake = false;
    };

    freetype = {
      url = "github:freetype/freetype/VER-2-14-1";
      flake = false;
    };

    zstd-src = {
      url = "github:facebook/zstd/v1.5.7";
      flake = false;
    };

    nlohmann-json = {
      url = "github:nlohmann/json/v3.12.0";
      flake = false;
    };

    md4c = {
      url = "github:mity/md4c/release-0.5.2";
      flake = false;
    };

    tidy-html5 = {
      url = "github:htacg/tidy-html5/5.8.0";
      flake = false;
    };

    pugixml = {
      url = "github:zeux/pugixml/v1.15";
      flake = false;
    };

    curl = {
      url = "github:curl/curl/curl-8_17_0";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      nixpkgsFor = forAllSystems (system: import nixpkgs {
        inherit system;
        config = { };
      });
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgsFor.${system};

          # CPM dependency sources - these will be passed via -DCPM_<name>_SOURCE flags
          cpmSources = {
            ImGui = inputs.imgui;
            nfd = inputs.nativefiledialog-extended;
            PPQSort = inputs.ppqsort;
            "PackageProject.cmake" = inputs.packageproject-cmake;
            capstone = inputs.capstone;
            base64 = inputs.base64;
            usearch = inputs.usearch;
            glfw = inputs.glfw;
            freetype = inputs.freetype;
            zstd = inputs.zstd-src;
            json = inputs.nlohmann-json;
            md4c = inputs.md4c;
            tidy = inputs.tidy-html5;
            pugixml = inputs.pugixml;
            libcurl = inputs.curl;
          };

        in {
          # Tracy Client Library
          tracy-client = pkgs.stdenv.mkDerivation {
            pname = "tracy-client";
            version = "0.13.2";

            src = ./.;

            nativeBuildInputs = with pkgs; [
              cmake
              pkg-config
            ];

            buildInputs = with pkgs; [
              # Required for TracyClient
            ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
              # Linux-specific dependencies
            ];

            cmakeFlags = [
              "-DTRACY_ENABLE=ON"
              "-DTRACY_STATIC=ON"
            ];

            meta = with pkgs.lib; {
              description = "Tracy profiler client library";
              homepage = "https://github.com/wolfpld/tracy";
              license = licenses.bsd3;
              platforms = platforms.unix;
            };
          };

          # Tracy Profiler GUI
          tracy-profiler = pkgs.stdenv.mkDerivation rec {
            pname = "tracy-profiler";
            version = "0.13.2";

            src = ./.;

            nativeBuildInputs = with pkgs; [
              cmake
              pkg-config
              wayland-scanner
            ];

            buildInputs = with pkgs; [
              # System dependencies
              dbus
              wayland
              wayland-protocols
              libxkbcommon
              libGL

              # Build dependencies from tracy-0.13.nix
              curl
              zstd
            ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
              # Linux-specific
              gtk3
            ] ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
              # macOS-specific
              pkgs.darwin.apple_sdk.frameworks.Cocoa
              pkgs.darwin.apple_sdk.frameworks.OpenGL
              pkgs.darwin.apple_sdk.frameworks.IOKit
            ];

            postUnpack = ''
              # Copy CPM sources to writable locations
              ${pkgs.lib.concatStringsSep "\n" (pkgs.lib.mapAttrsToList (name: src: ''
                cp -R ${src} ${name}
                chmod -R u+w ${name}
              '') cpmSources)}

              # PPQSort needs the newer CPM.cmake from tracy
              if [ -d PPQSort ] && [ -d $sourceRoot ]; then
                cp $sourceRoot/cmake/CPM.cmake PPQSort/cmake/CPM.cmake
              fi
            '';

            cmakeDir = "../profiler";

            preConfigure = ''
              # Add CPM source flags to cmakeFlags using absolute paths
              ${pkgs.lib.concatStringsSep "\n" (pkgs.lib.mapAttrsToList (name: src: ''
                export cmakeFlags="$cmakeFlags -DCPM_${name}_SOURCE=$NIX_BUILD_TOP/${name}"
              '') cpmSources)}

              # wayland-protocols is special - use system package's share directory
              export cmakeFlags="$cmakeFlags -DCPM_wayland-protocols_SOURCE=${pkgs.wayland-protocols}/share/wayland-protocols"
            '';

            cmakeFlags = [
              "-DNO_ISA_EXTENSIONS=ON"
              "-DDOWNLOAD_CAPSTONE=ON"
              "-DDOWNLOAD_GLFW=ON"
              "-DDOWNLOAD_FREETYPE=ON"
            ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
              "-DLEGACY=OFF"  # Use Wayland by default on Linux
              "-DGTK_FILESELECTOR=OFF"  # Use xdg-portal
            ];

            postInstall = ''
              # Install the profiler binary
              mkdir -p $out/bin
              cp tracy-profiler $out/bin/ || cp Tracy $out/bin/tracy-profiler || true
            '';

            meta = with pkgs.lib; {
              description = "Tracy profiler GUI application";
              homepage = "https://github.com/wolfpld/tracy";
              license = licenses.bsd3;
              platforms = platforms.unix;
              mainProgram = "tracy-profiler";
            };
          };

          # Convenience: default package is the profiler
          default = self.packages.${system}.tracy-profiler;
        });

      # Development shells
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgsFor.${system};
        in {
          default = pkgs.mkShell {
            name = "tracy-dev";

            inputsFrom = [
              self.packages.${system}.tracy-profiler
            ];

            nativeBuildInputs = with pkgs; [
              cmake
              pkg-config
              clang-tools  # For clang-format, clang-tidy
              gdb
              valgrind
            ];

            buildInputs = with pkgs; [
              # All dependencies for development
              curl
              zstd
              dbus
              wayland
              wayland-protocols
              libxkbcommon
              libGL
            ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
              gtk3
            ];

            shellHook = ''
              echo "Tracy development environment"
              echo "Version: 0.13.2"
              echo ""
              echo "Available commands:"
              echo "  cmake -B build -S ."
              echo "  cmake --build build"
              echo "  cmake -B profiler/build -S profiler"
              echo "  cmake --build profiler/build"
              echo ""
              echo "CPM sources are managed by Nix flake inputs"
            '';

            # Set CPM cache to use flake inputs
            CPM_SOURCE_CACHE = "${self.packages.${system}.tracy-profiler.cpmSourcesDir or ""}";
          };

          # Minimal shell for just building the client library
          client-only = pkgs.mkShell {
            name = "tracy-client-dev";

            nativeBuildInputs = with pkgs; [
              cmake
              pkg-config
              gcc
            ];

            shellHook = ''
              echo "Tracy Client Library development environment"
              echo "Build with: cmake -B build -S . && cmake --build build"
            '';
          };
        });

      # Apps for easy running
      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.tracy-profiler}/bin/tracy-profiler";
        };

        profiler = {
          type = "app";
          program = "${self.packages.${system}.tracy-profiler}/bin/tracy-profiler";
        };
      });
    };
}
