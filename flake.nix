{
  description = "A template for Nix based C++ project setup.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    ...
  } @ inputs:
    inputs.utils.lib.eachSystem [
      "x86_64-linux"
      "i686-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ] (system: let
      pkgs = import nixpkgs {
        inherit system;
        ##config.replaceStdenv = { pkgs, ... }: pkgs.llvmPackages;

        # Add overlays here if you need to override the nixpkgs
        # official packages.
        overlays = [
          ##(final: prev: { stdenv = prev.llvmPackages.stdenv; })
        ];
      };
      formatter = pkgs.alejandra;
      # llvm = pkgs.llvmPackages_19;
      mkShell = pkgs.mkShell.override {
        # stdenv = llvm.stdenv;
      };
    in {
      devShells.default = mkShell rec {
        ##stdenv = pkgs.llvmPackages_20.stdenv;
        # Update the name to something that suites your project.
        name = "message-proxy";

        nativeBuildInputs = with pkgs; [
          # Development Tools
          # llvm.clang
          # llvm.bintools
          clang-tools
          cmake
          cmakeCurses
          blas
          capstone
          ninja
          nativefiledialog-extended

          # Development time dependencies
          catch2_3
        ];
        buildInputs = with pkgs; [
          # Build time and Run time dependencies
          spdlog
          wayland
          libxkbcommon
          libglvnd
          # C++ standard library for macOS (provides -lc++)
          ##libcxx
          ##abseil-cpp
          boost178
          cli11
          readerwriterqueue

          # profiling
          tracy
          libGL
          egl-wayland
          wlroots
          libgbm
          glfw
        ];

        # Setting up the environment variables you need during
        # development.
        shellHook = let
          icon = "f121";
        in ''
          export PS1="$(echo -e '\u${icon}') {\[$(tput sgr0)\]\[\033[38;5;228m\]\w\[$(tput sgr0)\]\[\033[38;5;15m\]} (${name}) \\$ \[$(tput sgr0)\]"
        '';
      };

      packages = {
        # Full package with profiler GUI and all tools
        default = let
          tracy-pkgs = pkgs.callPackage ./extra/package.nix {
            src = pkgs.lib.cleanSource ./.;
          };
        in
          tracy-pkgs.tracy;

        # Client library only - minimal dependencies, no GUI
        client = pkgs.callPackage ./extra/client-package.nix {
          src = pkgs.lib.cleanSource ./.;
        };
      };
      inherit formatter;
    });
}
