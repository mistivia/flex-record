{
  description = "Haskell project with cabal2nix and hoogle";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        haskellPackages = pkgs.haskellPackages;
        project = haskellPackages.callCabal2nix "flex-record" ./. {};
        devTools = [
          haskellPackages.ghc
          haskellPackages.cabal-install
          haskellPackages.hoogle
          pkgs.haskell-language-server
        ];

      in
      {
        packages.default = project;

        devShells.default = pkgs.mkShell {
          buildInputs = devTools;
        };
      });
}
