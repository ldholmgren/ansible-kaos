{
  description = "Embedded development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          name = "embedded-dev";

          packages = with pkgs; [
            # Toolchain
            gcc-arm-embedded
            openocd

            # Debug / flash
            probe-rs-tools
            segger-jlink

            # Build tools
            cmake
            ninja
            pkg-config

            # Serial
            minicom
            picocom

            # Utilities
            dtc  # device tree compiler
            hexdump
          ];

          shellHook = ''
            echo "Embedded dev shell loaded"
            echo "  gcc-arm: $(arm-none-eabi-gcc --version | head -1)"
          '';
        };
      });
}
