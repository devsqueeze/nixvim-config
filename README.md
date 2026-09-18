# nixvim-config

A personal Neovim setup, configured entirely in Nix using [nixvim](https://github.com/nix-community/nixvim).
Instead of Lua or Vimscript config files, every plugin, keybinding, and setting is declared in
`.nix` files under `config/`, and Nix builds it all into a single, reproducible Neovim package.

Two versions are available:

- **Default** — the full setup, with everything below.
- **Minimal** — a lighter setup for headless or remote machines (e.g. servers you SSH into),
  with GUI-, terminal-graphics-, and audio-dependent features left out.

## Features

### Included in both versions

- Language support (autocomplete, go-to-definition, diagnostics) for Bash, C/C++, Nix, Python, and Rust
- Automatic code completion, with snippet support
- Syntax highlighting and smart indentation for a wide range of languages
- Fuzzy file search, text search, and buffer switching (Telescope)
- A file explorer sidebar
- Git integration: inline change markers and a full diff viewer
- Automatic code formatting and linting (Nix, shell scripts, Markdown)
- A diagnostics list for jumping between errors and warnings
- A status line, indent guides, and keybinding hints as you type
- Automatic removal of trailing whitespace on save
- The Gruvbox colour theme

### Additional features in the default version only

- Java language support
- Viewing images directly in the terminal (requires a terminal with image support, e.g. Kitty)
- Creating and previewing Excalidraw diagrams inline in Markdown files
- Voice dictation, with AI-assisted cleanup of the transcribed text
- Easier navigation between tmux panes and Neovim splits

## Using this configuration

This is a Nix flake, so you'll need [Nix installed](https://nixos.org/download) with flakes enabled.
Replace `devsqueeze/nixvim-config` below with this repository's actual location if you're using a
fork or a local copy.

### Try it without installing anything

```sh
# Default version
nix run github:devsqueeze/nixvim-config

# Minimal version
nix run github:devsqueeze/nixvim-config#minimal
```

This downloads and runs Neovim with this configuration, without changing anything on your system.

### Install it permanently

```sh
# Default version
nix profile install github:devsqueeze/nixvim-config

# Minimal version
nix profile install github:devsqueeze/nixvim-config#minimal
```

After this, `nvim` on your `PATH` will be this configured Neovim.

### Add it to your own flake

If you manage your machine (or a NixOS/home-manager setup) with your own flake, you can pull this
configuration in as an input and reference either the `default` or `minimal` package, for example
in your list of installed packages:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixvim-config.url = "github:devsqueeze/nixvim-config";
  };

  outputs = { self, nixpkgs, nixvim-config, ... }:
    let
      system = "x86_64-linux";
    in
    {
      # Example: home-manager
      homeConfigurations.myuser = /* ... */ {
        home.packages = [
          # Full-featured Neovim on a desktop machine
          nixvim-config.packages.${system}.default

          # Or, on a headless/remote machine, use the minimal version instead:
          # nixvim-config.packages.${system}.minimal
        ];
      };
    };
}
```

Only use one of `default` or `minimal` per machine — pick whichever matches how you'll use that
machine.

## Building locally

If you've cloned this repository yourself:

```sh
# Build and run the default version
nix build .
./result/bin/nvim

# Build and run the minimal version
nix build .#minimal
./result/bin/nvim

# Check that everything still builds correctly
nix flake check
```
