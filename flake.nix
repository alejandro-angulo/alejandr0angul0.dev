{
  description = "Alejandro Angulo's Personal Website";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    devenv.url = "github:cachix/devenv";
  };

  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    devenv,
    ...
  } @ inputs:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      packages.alejandr0angul0-dot-dev = pkgs.stdenv.mkDerivation {
        name = "alejandr0angul0-dot-dev";
        src = self;
        buildInputs = [pkgs.git pkgs.nodePackages.prettier];
        buildPhase = ''
          ${pkgs.hugo}/bin/hugo
        '';
        installPhase = "cp -r public $out";
      };

      defaultPackage = self.packages.${system}.alejandr0angul0-dot-dev;

      apps = rec {
        hugo = flake-utils.lib.mkApp {drv = pkgs.hugo;};
        default = hugo;
      };

      devShell = devenv.lib.mkShell {
        inherit inputs pkgs;
        modules = [
          ({pkgs, ...}: {
            languages.javascript = {
              enable = true;
              npm.install.enable = true;
              corepack.enable = true;
            };

            packages = with pkgs; [
              alejandra
              hugo
            ];

            pre-commit = {
              hooks = {
                alejandra.enable = true;
                eslint.enable = true;
                markdownlint = {
                  enable = true;
                  excludes = ["node_modules"];
                };
                prettier.enable = true;
              };
              settings = {
                eslint.binPath = self.outPath + "/node_modules/.bin/es-lint";
                prettier.binPath = self.outPath + "/node_modules/.bin/prettier";
              };
            };

            enterShell = ''
              export PATH=./node_modules/.bin:$PATH
            '';
          })
        ];
      };
    });
}
