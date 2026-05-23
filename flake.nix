{
  description = "lightweight Haskell Record library based on type-level field lists";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
    accessor-hs = {
      url = "https://github.com/mistivia/releases/releases/download/accessor-hs-0.1.0/accessor-hs-0.1.0.tar.gz";
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
