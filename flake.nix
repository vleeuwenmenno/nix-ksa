{
  description = "Kitten Space Agency (KSA) - space exploration and rocket building game";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        dotnet-runtime = pkgs.dotnetCorePackages.runtime_10_0;

        # Libraries that the bundled .so files dlopen() at runtime:
        #  - libglfw.so  → X11 / Wayland / Vulkan (dlopen'd backends in GLFW 3.5)
        #  - libfmod.so  → ALSA / PulseAudio / PipeWire (dlopen'd audio backends)
        # These won't appear in ldd output but are required at runtime.
        runtimeLibs = pkgs.lib.makeLibraryPath (
          with pkgs;
          [
            # Vulkan (also directly linked by libVulkanEx.so)
            vulkan-loader

            # X11 — GLFW X11 backend
            libx11
            libxcursor
            libxi
            libxext
            libxrandr
            libxxf86vm
            libxkbcommon

            # Wayland — GLFW Wayland backend (libwayland-client/egl/cursor)
            wayland
            libdecor # window decorations on Wayland (required for GLFW 3.4+)

            # Audio — FMOD backends
            alsa-lib
            pulseaudio

            # C++ runtime (libfmod, others)
            stdenv.cc.cc.lib

            # ICU — required by .NET globalization (both KSA and Brutal.Monitor.Subprocess)
            icu
          ]
        );

      in
      {
        packages.default = pkgs.stdenv.mkDerivation rec {
          pname = "ksa";
          version = "2026.4.4.3969";

          src = pkgs.fetchurl {
            # Official download URL from the KSA alpha page
            url = "https://ksa-linux.ahwoo.com/download?file=setup_ksa_v${version}.tar.gz";
            name = "setup_ksa_v${version}.tar.gz";
            hash = "sha256-p62aKLKXNsB0k83sHhb3Dn5qYt5/LHkG7OipBdqSSRU=";
          };

          # The tarball extracts into linux-x64/
          sourceRoot = "linux-x64";

          nativeBuildInputs = [
            pkgs.makeWrapper
            pkgs.autoPatchelfHook
          ];

          # Direct link-time dependencies (found via ldd):
          #  - libVulkanEx.so → libvulkan.so.1
          #  - KSA, libfmod.so → libstdc++, libgcc_s (via stdenv.cc.cc.lib)
          buildInputs = [
            pkgs.stdenv.cc.cc.lib
            pkgs.vulkan-loader
          ];

          dontBuild = true;
          dontStrip = true;

          # Let autoPatchelfHook resolve inter-bundle dependencies
          # (e.g. libimplot.so → libimgui.so, both bundled inside $out/opt/ksa).
          preFixup = ''
            addAutoPatchelfSearchPath "$out/opt/ksa"
          '';

          installPhase = ''
            runHook preInstall

            install -dm755 "$out/opt/ksa" "$out/bin"
            cp -a . "$out/opt/ksa/"
            chmod +x "$out/opt/ksa/KSA"

            makeWrapper "$out/opt/ksa/KSA" "$out/bin/ksa" \
              --set DOTNET_ROOT "${dotnet-runtime}/share/dotnet" \
              --set GLFW_PLATFORM "x11" \
              --prefix LD_LIBRARY_PATH : "$out/opt/ksa" \
              --prefix LD_LIBRARY_PATH : "${runtimeLibs}" \
              --run "cd $out/opt/ksa"

            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "Kitten Space Agency — space exploration and rocket building game (VERY ALPHA)";
            homepage = "https://ksa-linux.ahwoo.com";
            license = licenses.unfree;
            platforms = [ "x86_64-linux" ];
            mainProgram = "ksa";
          };
        };

        apps.default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/ksa";
        };
      }
    );
}
