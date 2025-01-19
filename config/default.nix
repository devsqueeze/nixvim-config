{
  imports = [
    ./cmp.nix
    ./git
    ./keymaps.nix 
    ./lightline.nix
    ./lsp
    ./nvim-tree.nix
    ./options.nix
    ./render-markdown.nix
    ./treesitter.nix
    ./utils
  ];

  viAlias = true;
  vimAlias = true;

  #colorschemes.dracula.enable = true;
  #colorschemes.rose-pine.enable = true;
  colorschemes.gruvbox.enable = true;

  plugins.web-devicons.enable = true;

  diagnostics = { virtual_lines.only_current_line = true; };

  extraConfigVim = ''
    autocmd BufRead,BufNewFile *.pl set filetype=prolog
  '';

  #programs.nixvim.extraConfig = ''
  #  vim.opt.makeprg = "make"
  #  vim.opt.errorformat = "%f:%l:%c:%m"
  #'';
}
