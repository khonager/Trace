{
  description = "Trace Flutter development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            android_sdk.accept_license = true;
          };
        };
        android = pkgs.androidenv.composeAndroidPackages {
          platformVersions = [ "35" "36" "37" ];
          buildToolsVersions = [ "35.0.0" "37.0.0" ];
          cmakeVersions = [ "3.22.1" ];
          includeNDK = true;
          ndkVersions = [ "28.2.13676358" ];
        };
        androidSdk = android.androidsdk;
      in {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            flutter
            rustup
            jdk17
            androidSdk
            android-tools
            clang
            cmake
            ninja
            patchelf
            pkg-config
            gtk3
            libsecret
          ];

          ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";
          ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
          JAVA_HOME = pkgs.jdk17.home;

          shellHook = ''
            # Nix's rustup patches the downloaded Rust linker wrapper with a
            # store path. Refresh the toolchain if that path was collected.
            rustc_path=$(rustup which rustc --toolchain stable 2>/dev/null || true)
            if [ -n "$rustc_path" ]; then
              rust_toolchain=$(dirname "$(dirname "$rustc_path")")
              for linker_wrapper in "$rust_toolchain"/lib/rustlib/*/bin/gcc-ld/ld.lld; do
                [ -f "$linker_wrapper" ] || continue
                wrapper_target=$(sed -n 's/.*"\(\/nix\/store\/[^\"]*\/nix-support\/ld-wrapper.sh\)".*/\1/p' "$linker_wrapper" | head -n 1)
                if [ -n "$wrapper_target" ] && [ ! -x "$wrapper_target" ]; then
                  echo "Refreshing Rust toolchain: its Nix linker wrapper is missing"
                  rustup toolchain install stable --force || return $?
                  break
                fi
              done
            fi
            echo "Trace development shell"
            echo "Flutter: $(flutter --version | head -n 1)"
          '';
        };
      });
}
