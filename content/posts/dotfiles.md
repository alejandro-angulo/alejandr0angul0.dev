+++
title = "Dotfiles"
date = "2022-01-05T11:36:47-08:00"
author = "alejandro"
tags = ["info-dump"]
keywords = ["dotfiles"]
showFullContent = false
+++

Not too long ago I had completely different configurations across different
computers. Terminal color schemes between computers weren't consistent. Git was
configured slightly differently between all computers. Lucky for me, there's a
program that's well suited for this task:
[stow](https://www.gnu.org/software/stow/).

Special thanks to [Brandon Invergo](http://brandon.invergo.net/) for [his blog
post](http://brandon.invergo.net/news/2012-05-26-using-gnu-stow-to-manage-your-dotfiles.html)
documenting how he uses stow to manage dotfiles.

## Git & Stow

Before I found stow I was using a [purely git-based
workflow](https://git.alejandr0angul0.dev/alejandro-angulo/dotfiles-bak). It
worked but it was a little clunky keeping a git repo at the root of my home
directory. One minor annoyance was that the repo's README would show up in my
home directory whenever I ran `ls` (minor, I know, but it didn't feel _right_ to
me). I was always a little paranoid that I would accidentally commit some secret
inside of `~/.cache` too.

My [updated
workflow](https://git.alejandr0angul0.dev/alejandro-angulo/dotfiles/tree/0af75c92fdbf908f9445bfbaf5e07b0e223db97d)
still uses git but I no longer maintain a repo at the root of my home folder.
Instead, I use stow to manage symlinks for me. My directory structure is cleaner
now with a directory for each set of configuration files (below are my git and
[terminal emulator](https://alacritty.org/) configurations).

```zsh
❯ tree -a git alacritty
git
└── .config
    └── git
        ├── config
        └── global_ignore
alacritty
└── .config
    └── alacritty
        └── alacritty.yml

4 directories, 3 files
```

Installing the configurations for those two programs is as easy as running `stow
-t ~ alacritty && stow -t ~ git`.

## Handling Plugins (and Plugin Managers)

There are some utilities ([vundle](https://github.com/VundleVim/Vundle.vim),
[base16-shell](https://github.com/chriskempson/base16-shell), [Oh My
ZSH](https://github.com/ohmyzsh/ohmyzsh), etc) that I want to have available
regardless of my underlying system's environment. I set up submodules in my git
repo for these utilities so that I have those utilities available without having
to go through my system's package manager (brew, apt, yay, etc).

As an added bonus, I can rely on plugin managers to pull in the bulk of my
dependencies without cluttering up my git repo with a bunch of submodules.

```zsh ❯ tree -a -L 3 vim
vim
├── .vim
│   ├── bundle
│   │   ├── ale
│   │   ├── base16-vim
│   │   ├── fzf
│   │   ├── fzf.vim
│   │   ├── nerdcommenter
│   │   ├── nerdtree
│   │   ├── tmuxline.vim
│   │   ├── vim-airline
│   │   ├── vim-airline-themes
│   │   ├── vim-devicons
│   │   ├── vim-fugitive
│   │   ├── vim-gitgutter
│   │   ├── vimspector
│   │   ├── vim-tmux-navigator
│   │   ├── vim-toml
│   │   └── Vundle.vim
│   └── ftplugin
│       ├── css.vim
│       ├── go.vim
│       ├── javascript.vim
│       ├── python.vim
│       ├── rust.vim
│       └── yaml.vim
├── .vimrc
└── .vimrc_background

19 directories, 8 files

❯ git ls-files vim/.vim/bundle/
vim/.vim/bundle/Vundle.vim
```

Instead of setting up submodules for each individual vim plugin I only have a
submodule for vundle (a vim plugin manager) and then I run `vim +PluginInstall
+qall` to pull in my vim plugins.

## Special Snowflake Configurations

There are some cases where I don't want to use the exact same configuration
across all my devices. I've found that this situation comes up in one of two
cases:

- device-specific configuration
- environment-specific configuration

### Device-Specific Configurations

I have certain configurations that are device-specific. For example, I have a
`sway` configuration but there are slight differences between my laptop and
desktop because the output configuration isn't the same (one display vs multiple
displays). To handle this I have `sway-carbon` and `sway-gospel` directories in
my dotfiles repo.

```zsh
❯ tree -a sway*
sway
└── .config
    ├── sway
    │   ├── config
    │   └── status
    └── waybar
        ├── config
        └── style.css
sway-carbon
└── .config
    └── sway
        └── includes
            └── carbon
sway-gospel
└── .config
    └── sway
        └── includes
            └── gospel

9 directories, 6 files
```

My main sway configuration has this line `include ~/.config/sway/includes/*`
which loads all files inside of `~/.config/sway/includes/`. My `sway-carbon` and
`sway-gospel` configurations will place the correct device-specific
configuration once stowed.

### Environment-Specific Configurations

I don't use the same set of programs on all my devices. Sometimes there's no
need to install something everywhere (I wouldn't use my sway configuration on a
device running OS X). Sometimes I just want to play around with a new program
first before deciding it's something that I want to install everywhere.

For example, I wanted to try out [delta](https://github.com/dandavison/delta)
for pretty git output on a personal device. The configuration for delta requires
changes to git's configuration file which depend on having `delta` in `$PATH`.
To prevent breaking things on devices, like my work computer or one of my
raspberry pi's, I updated git's configuration so that there would be fallback.

```ini
[pager]
    diff = "$(which delta 2>/dev/null) | less"
    log = "$(which delta 2>/dev/null) | less"
    reflog = "$(which delta 2>/dev/null) | less"
    show = "$(which delta 2>/dev/null) | less"
```

So now on devices with delta installed that'll be used, otherwise less will be
used.
