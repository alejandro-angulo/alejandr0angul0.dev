+++
title = "Now With More Nix"
date = "2023-08-27T17:25:57-07:00"
author = "alejandro"
authorTwitter = "" #do not include @
cover = ""
tags = ["nix flake", "cachix", "devenv", "meta"]
keywords = ["nix"]
showFullContent = false
+++

It's been about a year since my last post into the void. Since [my last
post](/posts/dotfiles) I've completely overhauled how my computers are
configured. I now have [a nix
flake](https://github.com/alejandro-angulo/dotfiles) to manage my personal
machines. I'm going all in on nix and wanted to update the deployment process
for this site to use nix flakes as well.

## Managing Development Environments with devenv and nix flakes

It's been a while since I touched anything on this site and I didn't have any
of the right packages installed to work on this. I could have installed
programs like [hugo](https://gohugo.io/) system-wide. But, since I have been
tinkering with nix, I wanted to use [a flake to manage all the
things](https://github.com/alejandro-angulo/alejandr0angul0.dev/blob/b8174db2150f3ac9925f8450bc75264678cf06c9/flake.nix)
needed for development (including writing posts).

Here's what the devenv configuration looked like at the time I was writing this
post.

```nix
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

              settings.markdownlint.config = {
                MD013.code_blocks = false;
              };
            };

            enterShell = ''
              export PATH=./node_modules/.bin:$PATH
            '';
          })
        ];
      };
```

This completely configures my development environment! It has all the packages
I want and sets up some pre-commit hooks for me in a single file. I don't need
to manage a `.pre-commit-config.yaml` and an `.mdlrc` file separately (these
files configure [pre-commit](https://pre-commit.com/) and
[markdownlint](https://github.com/markdownlint/markdownlint) respectively). The
best part is that I can easily get this development environment set up on any
machine (assuming I have [nix set up with flakes
support](https://nixos.wiki/wiki/Flakes#Enable_flakes) of course).

My `flake.nix` can accomplish what would traditionally be done with
[make](https://www.gnu.org/software/make/) and a `Makefile`. This section
handles building the site

```nix
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
```

This snippet defines how to build a
[derivation](https://nixos.org/manual/nix/stable/language/derivations.html)
that describes the site. It took me a while to make sense of all of this but
basically there are a bunch of [build
phases](https://nixos.org/manual/nixpkgs/stable/#sec-stdenv-phases). I only
needed three phases (build, check, and install). Nothing super special is going
on here.

I tell `hugo` to build a minified version of the site

```nix
        buildPhase = ''
          ${pkgs.hugo}/bin/hugo --minify
        '';
```

I enabled an optional check phase which tests the results of the build phase.
Here I run [htmlproofer](https://github.com/gjtorikian/html-proofer) to do some
quick sanity checks (like making sure I don't have broken internal links).

I did run into a small issue with this. `htmlproofer` was reading file contents
as if it were [US-ASCII](https://en.wikipedia.org/wiki/ASCII) but I have some
unicode characters in my source. The `env` below configures the
[locale](https://wiki.archlinux.org/title/Locale) to be
[UTF-8](https://en.wikipedia.org/wiki/UTF-8).

```nix
        doCheck = true;
        checkPhase = ''
          env LOCALE_ARCHIVE=${utf8Locale}/lib/locale/locale-archive LC_ALL=en_US.UTF-8 \
          ${pkgs.html-proofer}/bin/htmlproofer public \
            --allow-hash-href \
            --ignore-empty-alt \
            --disable-external \
            --no-enforce-https
        '';
```

The results of the build process should live in the `$out` directory. I just
need to move what `hugo` generated (it defaults to creating a `public/` folder)
into `$out`.

```nix
        installPhase = ''
          cp -r public "$out"
        '';
```

## Updating CI/CD

This site is deployed to an S3 bucket just like before switching over to using
nix. However, I don't need to use docker containers anymore and can use nix
fully. Here's the [github actions
configuration](https://github.com/alejandro-angulo/alejandr0angul0.dev/blob/97a655bc0c3e18f8c8921b90f14f87f5a07ae837/.github/workflows/ci.yml)
at the time of writing.

```yaml
name: "CI"

on:
  pull_request:
  push:

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: cachix/install-nix-action@v22
      - uses: cachix/cachix-action@v12
        with:
          name: devenv
      - uses: cachix/cachix-action@v12
        with:
          name: alejandr0angul0-dev
          authToken: "${{ secrets.CACHIX_AUTH_TOKEN }}"
      - name: Run pre-commit hooks
        run: |
          git fetch origin
          nix develop --accept-flake-config --impure --command bash -c \
            "pre-commit run --from-ref origin/main --to-ref $GITHUB_SHA"
  build:
    needs: [lint]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: cachix/install-nix-action@v22
      - uses: cachix/cachix-action@v12
        with:
          name: devenv
      - uses: cachix/cachix-action@v12
        with:
          name: alejandr0angul0-dev
          authToken: "${{ secrets.CACHIX_AUTH_TOKEN }}"
      - run: nix build --accept-flake-config -L
      # Convoluted upload below is a workaround for #92
      # See:
      # - https://github.com/actions/upload-artifact/issues/92
      # - https://github.com/actions/upload-artifact/issues/92#issuecomment-1080347032
      - run: echo "UPLOAD_PATH=$(readlink -f result)" >> "$GITHUB_ENV"
      - uses: actions/upload-artifact@v3
        with:
          name: built-site
          path: ${{ env.UPLOAD_PATH }}

  deploy:
    needs: [build]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    env:
      PROD_DEPLOY_CONFIG_PATH: config/production/deployment.toml
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      AWS_DEFAULT_REGION: ${{ secrets.AWS_DEFAULT_REGION }}
      HUGO_ENV: production
    steps:
      - uses: actions/checkout@v3
      - uses: cachix/install-nix-action@v22
      - uses: cachix/cachix-action@v12
        with:
          name: devenv
      - uses: cachix/cachix-action@v12
        with:
          name: alejandr0angul0-dev
          authToken: "${{ secrets.CACHIX_AUTH_TOKEN }}"
      - uses: actions/download-artifact@v3
        with:
          name: built-site
          path: public/
      - name: Deploy
        run: |
          sed 's~{{S3URL}}~${{ secrets.S3URL }}~g' "${PROD_DEPLOY_CONFIG_PATH}.sample" > "${PROD_DEPLOY_CONFIG_PATH}"
          sed -i 's~{{CLOUDFRONTDISTRIBUTIONID}}~${{ secrets.CLOUDFRONTDISTRIBUTIONID }}~g' "${PROD_DEPLOY_CONFIG_PATH}"
          nix develop --accept-flake-config --impure --command bash \
            -c 'hugo deploy --invalidateCDN'
```

[cachix](https://www.cachix.org) is a nix binary cache hosting service ran by
[Domen Kožar](https://github.com/domenkozar). (Cachix also happens to be the
entity behind devenv.) They've also provided some github actions to make that
allow me to cache the results of my nix commands to help speed up CI/CD
run times. I'm taking advantage of the
[install-nix-action](https://github.com/cachix/install-nix-action) (installs
nix on the ubuntu runners I'm using) and
[cachix-action](https://github.com/cachix/cachix-action) (gives me access to
the binaries hosted in cachix caches -- the site has its own cache) actions.

I only have three steps: lint -> build -> deploy. The lint step runs all the
pre-commit hooks I defined in my flake.nix file. I initially ran into errors
telling me that there was no `main` branch so I had to fetch origin and make
sure to explicitly reference the branch's remote (e.g. `origin/main`) .

```yaml
- name: Run pre-commit hooks
  run: |
    git fetch origin
    nix develop --accept-flake-config --impure --command bash -c \
      "pre-commit run --from-ref origin/main --to-ref $GITHUB_SHA"
```

Notice I didn't need to explicitly install `pre-commit`. That happens
automagically when I run `nix develop`.

Once those checks are ready it's time to make sure the site can be built
successfully. I ran into another snafu with [a bug in github's
`upload-artifacts`
action](https://github.com/actions/upload-artifact/issues/92); luckily
[`exFalso` shared a
workaround](https://github.com/actions/upload-artifact/issues/92#issuecomment-1080347032).

```yaml
- run: nix build --accept-flake-config -L
# Convoluted upload below is a workaround for #92
# See:
# - https://github.com/actions/upload-artifact/issues/92
# - https://github.com/actions/upload-artifact/issues/92#issuecomment-1080347032
- run: echo "UPLOAD_PATH=$(readlink -f result)" >> "$GITHUB_ENV"
- uses: actions/upload-artifact@v3
  with:
    name: built-site
    path: ${{ env.UPLOAD_PATH }}
```

Building the site (running `hugo`, `htmlproofer`, and whatever else I decide to
add to my build process) is done with a single call to `nix build`. The output
lives in a `result/` directory which I upload as [a build
artifact](https://docs.github.com/en/actions/using-workflows/storing-workflow-data-as-artifacts)
so it can be deployed later (if the commit being checked is on the `main`
branch).

The deploy step configures some secrets and uses hugo's provided deploy subcommand.

```yaml
- uses: actions/download-artifact@v3
  with:
    name: built-site
    path: public/
- name: Deploy
  run: |
    sed 's~{{S3URL}}~${{ secrets.S3URL }}~g' "${PROD_DEPLOY_CONFIG_PATH}.sample" > "${PROD_DEPLOY_CONFIG_PATH}"
    sed -i 's~{{CLOUDFRONTDISTRIBUTIONID}}~${{ secrets.CLOUDFRONTDISTRIBUTIONID }}~g' "${PROD_DEPLOY_CONFIG_PATH}"
    nix develop --accept-flake-config --impure --command bash \
      -c 'hugo deploy --invalidateCDN'
```

## "...cool I guess?"

So yeah, I have exactly the same site now. Nothing changes from a reader's
perspective but this scratched my tinkering itch.
