{
  description = "Home Manager configuration for Ubuntu";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixgl.url = "github:nix-community/nixGL";
  };

  outputs = { nixpkgs, home-manager, nixgl, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      mkHome = isDesktop: home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          nixgl.homeManagerModules.nixgl
          ./home.nix
        ];
        extraSpecialArgs = { inherit isDesktop nixgl; };
      };
    in {
      homeConfigurations = {
        "eggplants"         = mkHome false;
        "eggplants-desktop" = mkHome true;
      };
    };
}
