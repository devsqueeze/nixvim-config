{ lib, config, ... }:
{
  options = {
    lazygit.enable = lib.mkEnableOption "Enable lazygit module";
  };
  config = lib.mkIf config.lazygit.enable {

    plugins.lazygit = {
      enable = true;
    };

    extraConfigLua = ''
      require("telescope").load_extension("lazygit")
    '';

    keymaps = [
      {
        mode = "n";
        key = "<leader>gl";
        action = "<cmd>LazyGit<CR>";
        options = {
          desc = "LazyGit (root dir)";
        };
      }
    ];
  };
}
