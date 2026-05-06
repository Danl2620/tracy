{
  fetchFromGitHub,
  fetchFromGitLab,
  md4c ? null,
  pugixml ? null,
  curl ? null,
}: {
  version = "0.13.3";
  srcHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Not used for local source builds
  extraBuildInputs =
    if md4c != null && pugixml != null && curl != null
    then [md4c pugixml curl]
    else [];
  cpmSrcs = [
    (fetchFromGitHub {
      name = "zstd";
      owner = "facebook";
      repo = "zstd";
      rev = "v1.5.7";
      hash = "sha256-tNFWIT9ydfozB8dWcmTMuZLCQmQudTFJIkSr0aG7S44=";
    })
    (fetchFromGitHub {
      name = "ImGui";
      owner = "ocornut";
      repo = "imgui";
      rev = "v1.92.7-docking";
      hash = "sha256-RkWDGGwBDop9AfMLZJgUi5WFqkuMSqDn7Pa/DZQUJTA=";
    })
    (fetchFromGitHub {
      name = "nfd";
      owner = "btzy";
      repo = "nativefiledialog-extended";
      rev = "v1.3.0";
      hash = "sha256-JrwJP7zt/4oW4OQHCEM23k+zm6j1AVglGJowwkWc29k=";
    })
    (fetchFromGitHub {
      name = "PPQSort";
      owner = "GabTux";
      repo = "PPQSort";
      rev = "v1.0.6";
      hash = "sha256-HgM+p2QGd9C8A8l/VaEB+cLFDrY2HU6mmXyTNh7xd0A=";
    })
    # Transitive from PPQSort
    (fetchFromGitHub {
      name = "PackageProject.cmake";
      owner = "TheLartians";
      repo = "PackageProject.cmake";
      rev = "v1.11.1";
      hash = "sha256-E7WZSYDlss5bidbiWL1uX41Oh6JxBRtfhYsFU19kzIw=";
    })
    (fetchFromGitHub {
      name = "capstone";
      owner = "capstone-engine";
      repo = "capstone";
      rev = "6.0.0-Alpha7";
      hash = "sha256-cLEMlfZdzIa52imoDSrDKSnMH+bXauh2SwMvG4VWshE=";
    })
    (fetchFromGitLab {
      name = "wayland-protocols";
      owner = "wayland";
      repo = "wayland-protocols";
      rev = "1.37";
      domain = "gitlab.freedesktop.org";
      hash = "sha256-ryyv1RZqpwev1UoXRlV8P1ujJUz4m3sR89iEPaLYSZ4=";
    })
    (fetchFromGitHub {
      name = "json";
      owner = "nlohmann";
      repo = "json";
      rev = "v3.12.0";
      hash = "sha256-cECvDOLxgX7Q9R3IE86Hj9JJUxraDQvhoyPDF03B2CY=";
    })
    (fetchFromGitHub {
      name = "base64";
      owner = "aklomp";
      repo = "base64";
      rev = "v0.5.2";
      hash = "sha256-dIaNfQ/znpAdg0/vhVNTfoaG7c8eFrdDTI0QDHcghXU=";
    })
    (fetchFromGitHub {
      name = "tidy";
      owner = "htacg";
      repo = "tidy-html5";
      rev = "5.8.0";
      hash = "sha256-vzVWQodwzi3GvC9IcSQniYBsbkJV20iZanF33A0Gpe0=";
    })
    (fetchFromGitHub {
      name = "usearch";
      owner = "unum-cloud";
      repo = "usearch";
      rev = "v2.23.0";
      fetchSubmodules = true;
      hash = "sha256-r42JShUnYxvQ7Of1hKtC0TZnMV73xLXzUjV394XyqD4=";
    })
    (fetchFromGitHub {
      name = "freetype";
      owner = "freetype";
      repo = "freetype";
      rev = "VER-2-14-3";
      hash = "sha256-qmgJK9D60Ol5prUpsLzS+zY8WTPV2bfCoHX3lajAJ4Y=";
    })
    (fetchFromGitHub {
      name = "md4c";
      owner = "mity";
      repo = "md4c";
      rev = "release-0.5.2";
      hash = "sha256-2/wi7nJugR8X2J9FjXJF1UDnbsozGoO7iR295/KSJng=";
    })
  ];
}
