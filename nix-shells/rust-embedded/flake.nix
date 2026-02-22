{
  description = "Rust embedded development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };

        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "rust-src" "rust-analyzer" "llvm-tools-preview" ];
          targets = [
            "thumbv6m-none-eabi"      # Cortex-M0/M0+
            "thumbv7m-none-eabi"      # Cortex-M3
            "thumbv7em-none-eabi"     # Cortex-M4/M7 (no FPU)
            "thumbv7em-none-eabihf"   # Cortex-M4/M7 (with FPU)
            "riscv32imc-unknown-none-elf"  # RISC-V
          ];
        };
      in
      {
        devShells.default = pkgs.mkShell {
          name = "rust-embedded-dev";

          packages = with pkgs; [
            # Rust
            rustToolchain

            # Flash / debug
            probe-rs-tools
            cargo-embed
            flip-link
            cargo-binutils

            # Build support
            cmake
            ninja
            pkg-config

            # Utilities
            minicom
            picocom
          ];

          shellHook = ''
            echo "Rust embedded dev shell loaded"
            echo "  rustc: $(rustc --version)"
            echo "  targets: thumbv6m, thumbv7m, thumbv7em, thumbv7em-hf, riscv32imc"
          '';
        };
      });
}
