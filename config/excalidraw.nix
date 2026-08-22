{ pkgs, ... }:
{
  extraPlugins = [
    (pkgs.vimUtils.buildVimPlugin {
      pname = "markdown-excalidraw-nvim";
      version = "unstable-2026-08-20";
      src = pkgs.fetchFromGitHub {
        owner = "Cosipa";
        repo = "markdown-excalidraw.nvim";
        rev = "6baf0c2c498aeec62a85c178733cfd4d84d4bf40";
        hash = "sha256-srOvX+ELrLtMBPUcqYeNkFs9h00xXrzhPqRES4fPQck=";
      };
    })
  ];

  extraPackages = [ pkgs.python3 ];

  extraConfigLua = ''
    require("markdown-excalidraw").setup({
      auto_open = true,
      theme = "auto",
      assets_dir = "assets",
    })
  '';

  keymaps = [
    {
      mode = "n";
      key = "<leader>e";
      action = "+excalidraw";
    }
    {
      mode = "n";
      key = "<leader>eo";
      action = "<CMD>ExcalidrawOpen<CR>";
      options.desc = "Open Excalidraw diagram under cursor";
    }
    {
      mode = "n";
      key = "<leader>ec";
      action = "<CMD>ExcalidrawCreate<CR>";
      options.desc = "Create new Excalidraw diagram";
    }
    {
      mode = "n";
      key = "<leader>es";
      action = "<CMD>ExcalidrawStatus<CR>";
      options.desc = "Excalidraw server status";
    }
    {
      mode = "n";
      key = "<leader>eq";
      action = "<CMD>ExcalidrawStop<CR>";
      options.desc = "Stop Excalidraw server";
    }
  ];
}
