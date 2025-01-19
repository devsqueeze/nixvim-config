{
  plugins.telescope = {
    enable = true;
   
    settings = {
      defaults = {
        sorting_strategy = "ascending";
        layout_config = {
          prompt_position = "top";
        };
      };
    };
    
    keymaps = {
      "<leader>ff" = {
        action = "find_files";
        options.desc = "Find project files";
      };
      "<leader>fr" = {
        action = "oldfiles";
        options.desc = "Recent";
      };
      #"<leader>b" = {
      "<leader><space>" = {
        action = "buffers";
        options.desc = "Buffers";
      };
      "<leader>fg" = {
        action = "live_grep";
        options.desc = "Grep (root dir)";
      };
      #"<C-p>" = {
      #  action = "git_files";
      #  options = {
      #    desc = "Telescope Git Files";
      #  };
      #};
    };
    extensions.fzf-native = { enable = true; };
  };
}
