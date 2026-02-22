{
  description = "General development environment";

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
          name = "general-dev";

          packages = with pkgs; [
            # Python
            python3
            python3Packages.pip
            python3Packages.virtualenv

            # Node.js
            nodejs
            nodePackages.npm

            # Build tools
            cmake
            ninja
            gnumake
            pkg-config
            gcc

            # Utilities
            jq
            yq
            curl
            httpie
          ];

          shellHook = ''
            echo "General dev shell loaded"
            echo "  python: $(python3 --version)"
            echo "  node: $(node --version)"
          '';
        };
      });
}
