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
          platformVersions = [ "36" ];
          buildToolsVersions = [ "36.0.0" ];
          includeNDK = true;
          ndkVersions = [ "28.2.13676358" ];
        };
        androidSdk = android.androidsdk;
      in {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            flutter
            jdk17
            androidSdk
            android-tools
            clang
            cmake
            ninja
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
