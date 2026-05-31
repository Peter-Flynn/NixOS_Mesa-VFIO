{
  description = "PeterFlynn-VFIO configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    NixVirt = {
      url = "https://flakehub.com/f/AshleyYakeley/NixVirt/*.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
    secrix = {
      url = "github:Platonic-Systems/secrix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, NixVirt, nix-cachyos-kernel, secrix, ... } @ inputs: let
    system = "x86_64-linux";
    lib = nixpkgs.lib.extend (final: prev: {
      custom = import ./main-lib.nix {
        pkgs = nixpkgs.legacyPackages.${system};
        lib = prev;
      };
    });
  in {
    nixosModules.default = {
      imports = [
        ./main.nix NixVirt.nixosModules.default secrix.nixosModules.secrix
      ];
    };

    lib.mkSystem = { modules ? [] }: nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs system lib nix-cachyos-kernel; nixvirt = NixVirt; };
      modules = [ self.nixosModules.default ] ++ modules;
    };
  };
}
