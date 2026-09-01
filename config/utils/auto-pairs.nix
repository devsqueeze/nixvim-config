{
  plugins.nvim-autopairs = { enable = true; };

  extraConfigLua = ''
    require('nvim-autopairs').remove_rule('"')
  '';
}
