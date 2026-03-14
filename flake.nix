{
  description = "Haskell project with cabal2nix and hoogle";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    accessor-hs = {
      url = "github:mistivia/accessor-hs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = { self, nixpkgs, flake-utils, accessor-hs }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        haskellPackages = pkgs.haskellPackages.override {
          overrides = hself: hsuper: {
            "accessor-hs" = accessor-hs.packages.${system}.default;
          };
        };
        project = haskellPackages.callCabal2nix "flex-record" ./. {};
        devTools = with haskellPackages; [
          cabal-install
          hoogle
          haskell-language-server
        ];

      in
      {
        packages.default = project;

        devShells.default = haskellPackages.shellFor {
          packages = p: [ project ];
          nativeBuildInputs = devTools;
        };
      });
}
