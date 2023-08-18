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
      utf8Locale = pkgs.glibcLocales.override {
        allLocales = false;
      };
    in {
      packages.alejandr0angul0-dot-dev = pkgs.stdenv.mkDerivation {
        name = "alejandr0angul0-dot-dev";
        src = self;

        buildInputs = with pkgs; [
          git
          nodePackages.prettier
        ];
        buildPhase = ''
          ${pkgs.hugo}/bin/hugo --minify
        '';

        doCheck = true;
        nativeCheckInputs = with pkgs; [html-proofer utf8Locale];
        checkPhase = ''
          env LOCALE_ARCHIVE=${utf8Locale}/lib/locale/locale-archive LC_ALL=en_US.UTF-8 \
          ${pkgs.html-proofer}/bin/htmlproofer public \
            --allow-hash-href \
            --ignore-empty-alt \
            --disable-external \
            --no-enforce-https
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
              actionlint
              alejandra
              hugo
              html-proofer
              awscli2
            ];

            pre-commit = {
              hooks = {
                actionlint.enable = true;
                alejandra.enable = true;
                eslint.enable = true;
                markdownlint = {
                  enable = true;
                  excludes = ["node_modules"];
                };
                prettier = {
                  enable = true;
                  excludes = ["flake.lock"];
                };
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
