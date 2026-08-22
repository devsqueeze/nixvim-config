{ pkgs, ... }:
let
  excalidrawCli = pkgs.buildNpmPackage rec {
    pname = "excalidraw-cli";
    version = "1.3.0";
    src = pkgs.fetchFromGitHub {
      owner = "swiftlysingh";
      repo = "excalidraw-cli";
      rev = "ad13ea91e485d3acb5c1058b9fb12e4c27dd0460";
      hash = "sha256-T0kV+P7v3jlSr4V/VS0kdmGf+poD5C0ipmjHdnreM1g=";
    };
    npmDepsHash = "sha256-PJSNun8N89GLWjWqKfgw11sK963u5tE0UfG9FlzEW3w=";
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    # @resvg/resvg-js ships both glibc and musl native addons as optional
    # deps; only the glibc one is ever loaded on NixOS. It needs libgcc_s,
    # and the musl one's libc dependency has no equivalent here (harmless
    # to leave unpatched since it's never loaded at runtime).
    buildInputs = [ pkgs.stdenv.cc.cc.lib ];
    autoPatchelfIgnoreMissingDeps = [ "libc.musl-x86_64.so.1" ];
  };
in
{
  extraPackages = [ excalidrawCli ];

  extraConfigLua = ''
    local excalidraw_preview = {}
    local cache_dir = vim.fn.stdpath("cache") .. "/excalidraw-preview"
    local tracked = {} -- bufnr -> { [link_id] = true }

    local function find_links(bufnr)
      local links = {}
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      for row, line in ipairs(lines) do
        local start_col = 1
        while true do
          local s, e, path = line:find("%[.-%]%(([^)]+%.excalidraw)%)", start_col)
          if not s then
            break
          end
          table.insert(links, { row = row - 1, col = s - 1, path = path })
          start_col = e + 1
        end
      end
      return links
    end

    local function render_link(bufnr, win, link)
      local bufname = vim.api.nvim_buf_get_name(bufnr)
      local dir = vim.fn.fnamemodify(bufname, ":h")
      local abspath = vim.fn.fnamemodify(link.path, ":p")
      if vim.fn.filereadable(abspath) == 0 then
        abspath = vim.fn.simplify(dir .. "/" .. link.path)
      end
      if vim.fn.filereadable(abspath) == 0 then
        return
      end

      local mtime = vim.fn.getftime(abspath)
      local id = "excalidraw-preview:" .. vim.fn.sha256(abspath) .. ":" .. mtime
      tracked[bufnr] = tracked[bufnr] or {}
      tracked[bufnr][id] = true

      local cache_path = cache_dir .. "/" .. vim.fn.sha256(abspath) .. "-" .. mtime .. "-dark.png"

      local function show()
        local ok, image = pcall(require, "image")
        if not ok then
          return
        end
        local existing = image.get_images({ window = win, buffer = bufnr, namespace = "excalidraw-preview" })
        for _, img in ipairs(existing) do
          if img.id == id then
            return
          end
        end
        local img = image.from_file(cache_path, {
          id = id,
          window = win,
          buffer = bufnr,
          with_virtual_padding = true,
          namespace = "excalidraw-preview",
        })
        if img then
          img:render({ x = link.col, y = link.row })
        end
      end

      if vim.fn.filereadable(cache_path) == 1 then
        show()
        return
      end

      vim.fn.mkdir(cache_dir, "p")
      vim.system(
        { "excalidraw-cli", "convert", abspath, "--format", "png", "--dark", "-o", cache_path },
        {},
        function(result)
          if result.code == 0 then
            vim.schedule(show)
          end
        end
      )
    end

    function excalidraw_preview.refresh(bufnr)
      if vim.uv.guess_handle(1) ~= "tty" then
        return
      end
      bufnr = bufnr or vim.api.nvim_get_current_buf()
      local win = vim.api.nvim_get_current_win()
      local ok, image = pcall(require, "image")
      if not ok then
        return
      end

      local links = find_links(bufnr)
      local seen = {}
      for _, link in ipairs(links) do
        render_link(bufnr, win, link)
      end
      for _, link in ipairs(links) do
        local bufname = vim.api.nvim_buf_get_name(bufnr)
        local dir = vim.fn.fnamemodify(bufname, ":h")
        local abspath = vim.fn.fnamemodify(link.path, ":p")
        if vim.fn.filereadable(abspath) == 0 then
          abspath = vim.fn.simplify(dir .. "/" .. link.path)
        end
        local mtime = vim.fn.getftime(abspath)
        seen["excalidraw-preview:" .. vim.fn.sha256(abspath) .. ":" .. mtime] = true
      end

      local previously = tracked[bufnr] or {}
      local existing = image.get_images({ window = win, buffer = bufnr, namespace = "excalidraw-preview" })
      for _, img in ipairs(existing) do
        if previously[img.id] and not seen[img.id] then
          img:clear()
        end
      end
      tracked[bufnr] = seen
    end

    vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
      pattern = { "*.md" },
      callback = function(args)
        excalidraw_preview.refresh(args.buf)
      end,
    })

    _G.excalidraw_preview = excalidraw_preview
  '';

  keymaps = [
    {
      mode = "n";
      key = "<leader>er";
      action = "<CMD>lua excalidraw_preview.refresh()<CR>";
      options.desc = "Refresh Excalidraw previews in buffer";
    }
  ];
}
