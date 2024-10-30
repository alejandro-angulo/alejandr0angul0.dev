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
        locales = ["en_US.UTF-8/UTF-8"];
      };
    in {
      packages.alejandr0angul0-dot-dev = pkgs.stdenv.mkDerivation {
        name = "alejandr0angul0-dot-dev";
        src = self;

        buildPhase = ''
          ${pkgs.hugo}/bin/hugo --minify
        '';

        doCheck = true;
        checkPhase = ''
          env LOCALE_ARCHIVE=${utf8Locale}/lib/locale/locale-archive LC_ALL=en_US.UTF-8 \
          ${pkgs.html-proofer}/bin/htmlproofer public \
            --allow-hash-href \
            --ignore-empty-alt \
            --disable-external \
            --no-enforce-https
        '';

        installPhase = ''
          cp -r public "$out"
        '';
      };

      # Workaround for cachix/devenv#756
      # See here: https://github.com/cachix/devenv/issues/756
      packages.devenv-up = self.devShell.${system}.config.procfileScript;

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
                  settings.configuration = {
                    MD013.code_blocks = false;
                  };
                };
                prettier = {
                  enable = true;
                  excludes = ["flake.lock"];
                };
              };
            };

            processes.hugo-server.exec = "${pkgs.hugo}/bin/hugo server";

            enterShell = ''
              export PATH=./node_modules/.bin:$PATH
            '';
          })
        ];
      };
    });
}
