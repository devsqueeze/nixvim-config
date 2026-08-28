{
  plugins.none-ls = {
    enable = true;
    sources = {
      diagnostics = {
        statix.enable = true;
      };
      formatting = {
        fantomas.enable = true;
        nixfmt.enable = true;
        markdownlint.enable = true;
        shellharden.enable = true;
        shfmt.enable = true;
      };
    };
  };
}
