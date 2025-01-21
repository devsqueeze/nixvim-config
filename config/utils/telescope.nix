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
      #"<leader>fr" = {
      #  action = "oldfiles";
      #  options.desc = "Recent files";
      #};
      #"<leader>b" = {
      "<leader><space>" = {
        action = "buffers";
        options.desc = "Buffers";
      };
      "<leader>fg" = {
        action = "live_grep";
        options.desc = "Grep (root dir)";
      };
      "<leader>fw" = {
        action = "grep_string";
        mode = "n";
        options = {
          desc = "Search word under cursor";
        };
      };

      #see https://github.com/elythh/nixvim/blob/main/config/plug/ui/telescope.nix
      "<leader>f'" = {
        action = "marks";
        options.desc = "View marks";
      };
      "<leader>f/" = {
        action = "current_buffer_fuzzy_find";
        options.desc = "Fuzzy find in current buffer";
      };
      "<leader>f<CR>" = {
        action = "resume";
        options.desc = "Resume action";
      };
      "<leader>fa" = {
        action = "autocommands";
        options.desc = "View autocommands";
      };
      "<leader>fC" = {
        action = "commands";
        options.desc = "View commands";
      };
      "<leader>fb" = {
        action = "buffers";
        options.desc = "View buffers";
      };
      "<leader>fc" = {
        action = "grep_string";
        options.desc = "Grep string";
      };
      "<leader>fd" = {
        action = "diagnostics";
        options.desc = "View diagnostics";
      };
      "<leader><leader>" = {
        action = "find_files";
        options.desc = "Find files";
      };
      "<leader>fh" = {
        action = "help_tags";
        options.desc = "View help tags";
      };
      "<leader>fm" = {
        action = "man_pages";
        options.desc = "View man pages";
      };
      "<leader>fo" = {
        action = "oldfiles";
        options.desc = "View old files";
      };
      "<leader>fr" = {
        action = "registers";
        options.desc = "View registers";
      };
      "<leader>fs" = {
        action = "lsp_document_symbols";
        options.desc = "Search symbols";
      };
      "<leader>fq" = {
        action = "quickfix";
        options.desc = "Search quickfix";
      };
      "<leader>gB" = {
        action = "git_branches";
        options.desc = "View git branches";
      };
      "<leader>gC" = {
        action = "git_commits";
        options.desc = "View git commits";
      };
      "<leader>gs" = {
        action = "git_status";
        options.desc = "View git status";
      };
      "<leader>gS" = {
        action = "git_stash";
        options.desc = "View git stashes";
      };


      #"<leader>fw" = {
      #  #action = "<Cmd>lua require('telescope.builtin').grep_string({ search = vim.fn.expand(\"<cword>\") })<CR>";
      #  #action = ":lua require('telescope.builtin').grep_string({ search = vim.fn.expand('<cword>') })<CR>";
      #  action = "lua require('telescope.builtin').grep_string({ search = vim.fn.expand('<cword>') })";
      #  mode = "n";
      #  options = {
      #    desc = "Search word under cursor";
      #  };
      #};
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
