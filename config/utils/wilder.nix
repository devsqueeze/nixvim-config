#{ lib, ... }:
#{
#  plugins.wilder = {
#    enable = true;
#
#    settings = {
#      modes = [ "/" "?" ":" ];
#    };
#
#    options = {
#      use_python_remote_plugin = 0;
#
#      pipeline = lib.nixvim.mkRaw ''
#        {
#          wilder.branch(
#            wilder.cmdline_pipeline({
#              language = 'vim',
#              fuzzy = 1,
#              fuzzy_filter = wilder.vim_fuzzy_filter(),
#            }),
#            wilder.vim_search_pipeline()
#          ),
#        }
#      '';
#
#      renderer = lib.nixvim.mkRaw ''
#        wilder.popupmenu_renderer(
#          wilder.popupmenu_border_theme({
#            highlights = { border = 'Normal' },
#            border = 'rounded',
#            pumblend = 20,
#          })
#        )
#      '';
#    };
#  };
#}
{ lib, ... }:
{
  plugins.wilder = {
    enable = true;

    settings = {
      modes = [ "/" "?" ":" ];
    };

    options = {
      use_python_remote_plugin = 0;

      pipeline = lib.nixvim.mkRaw ''
        {
          wilder.branch(
            wilder.cmdline_pipeline({
              language = 'vim',
              fuzzy = 1,
              fuzzy_filter = wilder.vim_fuzzy_filter(),
            }),
            wilder.vim_search_pipeline()
          ),
        }
      '';

      renderer = lib.nixvim.mkRaw ''
        wilder.wildmenu_renderer({
          highlighter = wilder.basic_highlighter(),
          separator = ' | ',
          left = { ' ', wilder.wildmenu_spinner(), ' ' },
          right = { ' ', wilder.wildmenu_index() },
        })
      '';
    };
  };
}
