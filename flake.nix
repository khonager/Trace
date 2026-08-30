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
            echo "Trace development shell"
            echo "Flutter: $(flutter --version | head -n 1)"
          '';
        };
      });
}
