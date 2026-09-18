{
  description = "A nixvim configuration";

  inputs = {
    nixvim.url = "github:nix-community/nixvim";
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.follows = "nixvim/nixpkgs";
  };

  outputs = { self, nixpkgs, nixvim, flake-utils, ... }@inputs:
    let
      fullConfig = import ./config; # full profile: every plugin
      minimalConfig = import ./config/minimal.nix; # minimal profile: headless-friendly subset
    in flake-utils.lib.eachDefaultSystem (system:
      let
        nixvimLib = nixvim.lib.${system};
        pkgs = import nixpkgs { inherit system; };
        nixvim' = nixvim.legacyPackages.${system};
        mkNvim = module: nixvim'.makeNixvimWithModule {
          inherit pkgs module;
        };
        nvim = mkNvim fullConfig;
        nvimMinimal = mkNvim minimalConfig;
      in
      {
        formatter = nixpkgs.legacyPackages.${system}.nixpkgs-fmt;

        checks = {
          default = nixvimLib.check.mkTestDerivationFromNvim {
            inherit nvim;
            name = "My nixvim configuration";
          };
          minimal = nixvimLib.check.mkTestDerivationFromNvim {
            nvim = nvimMinimal;
            name = "My nixvim configuration (minimal)";
          };
        };

        packages = {
          # Lets you run `nix run .` to start nixvim
          default = nvim;
          # Lets you run `nix run .#minimal` for the headless-friendly profile
          minimal = nvimMinimal;
        };
      });
}
