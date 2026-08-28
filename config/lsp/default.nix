{
  imports = [
    ./fidget.nix
    ./ionide.nix
    ./none-ls.nix
    ./trouble.nix
  ];

  plugins = {
    lsp = {
      enable = true;
      onAttach = ''
        if vim.wo.diff then
          vim.diagnostic.enable(false)
          vim.lsp.stop_client(vim.lsp.get_clients())
        end
      '';
      servers = {
        bashls.enable = true;
        clangd.enable = true;
        jdtls.enable = true;
        nixd.enable = true;
        ruff.enable = true;
      };
      keymaps.lspBuf = {
        "gd" = "definition";
        "gD" = "references";
        "gt" = "type_definition";
        "gi" = "implementation";
        "K" = "hover";
      };
    };
    rustaceanvim.enable = true;
  };
}
