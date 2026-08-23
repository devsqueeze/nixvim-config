{ pkgs, ... }: {
  imports = [
    ./cmp.nix
    ./dictate.nix
    ./excalidraw.nix
    ./excalidraw-preview.nix
    ./ftplugin.nix
    ./git
    ./image.nix
    ./keymaps.nix
    ./lightline.nix
    ./lsp
    ./nvim-tree.nix
    ./options.nix
    ./render-markdown.nix
    ./treesitter.nix
    ./tmux-navigator.nix
    ./utils
  ];

  viAlias = true;
  vimAlias = true;

  #colorschemes.dracula.enable = true;
  #colorschemes.rose-pine.enable = true;
  colorschemes.gruvbox.enable = true;

  plugins.web-devicons.enable = true;

  diagnostic.settings = { virtual_lines.only_current_line = true; };

  # Plugins without special nixvim modules
  extraPlugins = with pkgs; [
    vimPlugins.vim-eunuch
  ];

  extraPython3Packages = ps: with ps; [
    pynvim
  ];

  autoCmd = [
    {
      event = ["BufWritePre"];
      pattern = ["*"];
      command = ''
          if !&binary && &filetype != 'diff' && &filetype != 'markdown'
            %s/\s\+$//e
          endif
      '';
    }
  ];
}
