{
  plugins.image = {
    enable = true;
    # The kitty backend queries the terminal over stdout at setup time, which
    # crashes when stdout isn't a real tty (e.g. nix flake check's headless
    # smoke test). Skip setup in that case; interactive `nix run .` in a real
    # terminal still initializes normally.
    callSetup = false;
    settings = {
      backend = "kitty";
      integrations.markdown.enabled = true;
    };
  };

  extraConfigLua = ''
    if vim.uv.guess_handle(1) == "tty" then
      require("image").setup({
        backend = "kitty",
        integrations = { markdown = { enabled = true } },
      })
    end
  '';
}
