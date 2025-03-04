{
  inputs = {
    nixpkgs-matrix = {
      type = "indirect";
      id = "nixpkgs-matrix";
      inputs.nixpkgs.url =
        "github:NixOS/nixpkgs?rev=e69e710edfed397959507bcee120ec8a9c7ff03e";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs-matrix, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs-matrix.legacyPackages.${system};
        shell = { ci ? false }:
          with pkgs;
          mkShell {
            nativeBuildInputs = [
              nodejs_20
              shellcheck
              gitAndTools.gh
              rustc
              cargo
              cmake
              rustPlatform.bindgenHook
              # Cross compilation tools
              pkgsCross.arm-embedded.buildPackages.gcc
              pkgsCross.aarch64-multiplatform.buildPackages.gcc
            ] ++ lib.optionals stdenv.isLinux [
              gcc_multi
              pkg-config
              libudev-zero
            ];
            
            buildInputs = [
              openssl
            ];

            NIX_DONT_SET_RPATH = true;
            NIX_NO_SELF_RPATH = true;
            RUST_SRC_PATH = "${rustPlatform.rustLibSrc}";
            
            shellHook = ''
              echo "Entering $(npm pkg get name)"
              set -o allexport
              . <(polykey secrets env js-quic)
              set +o allexport
              set -v

              # Setup cross compilation environment variables
              export CARGO_TARGET_ARM_UNKNOWN_LINUX_GNUEABIHF_LINKER=arm-none-eabi-gcc
              export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc
              export PKG_CONFIG_PATH_arm_unknown_linux_gnueabihf=/usr/lib/arm-linux-gnueabihf/pkgconfig
              export PKG_CONFIG_PATH_aarch64_unknown_linux_gnu=/usr/lib/aarch64-linux-gnu/pkgconfig
              
              # Add Rust targets for cross compilation
              rustup target add arm-unknown-linux-gnueabihf
              rustup target add aarch64-unknown-linux-gnu

              ${lib.optionalString ci ''
                set -o errexit
                set -o nounset
                set -o pipefail
                shopt -s inherit_errexit
              ''}
              mkdir --parents "$(pwd)/tmp"
              export PATH="$(pwd)/dist/bin:$(npm root)/.bin:$PATH"
              npm install --ignore-scripts
              set +v
            '';
          };
      in {
        devShells = {
          default = shell { ci = false; };
          ci = shell { ci = true; };
        };
      });
}
