{ ... }:
{
  extraConfigLua = ''
    local excalimath = {}
    local assets_dir = "assets"

    local function notify(msg, level)
      vim.notify("[excalimath] " .. msg, level or vim.log.levels.INFO)
    end

    local function is_excalidraw(path)
      return path:match("%.excalidraw$") ~= nil or path:match("%.excalidraw%.json$") ~= nil
    end

    local function link_at_cursor()
      local line = vim.api.nvim_get_current_line()
      local col = vim.api.nvim_win_get_cursor(0)[2]
      local start_col = 1
      while true do
        local s, e, path = line:find("%[[^%]]*%]%(([^%s)]+%.excalidraw)%)", start_col)
        if not s then
          return nil
        end
        if col >= s - 1 and col <= e - 1 then
          return path
        end
        start_col = e + 1
      end
    end

    function excalimath.open(path)
      if not path or path == "" then
        path = link_at_cursor()
      end
      if not path then
        local bufname = vim.api.nvim_buf_get_name(0)
        if bufname ~= "" and is_excalidraw(bufname) then
          path = bufname
        end
      end
      if not path then
        notify("No excalidraw link under cursor", vim.log.levels.ERROR)
        return
      end

      local current_file = vim.api.nvim_buf_get_name(0)
      if not path:match("^[/~]") and current_file ~= "" then
        local relative_to_buf = vim.fn.fnamemodify(current_file, ":h") .. "/" .. path
        if vim.fn.filereadable(relative_to_buf) == 1 then
          path = relative_to_buf
        end
      end
      path = vim.fn.fnamemodify(vim.fn.expand(path), ":p")

      if vim.fn.filereadable(path) ~= 1 then
        notify("File not found: " .. path, vim.log.levels.ERROR)
        return
      end
      if vim.fn.executable("excalimath") == 0 then
        notify("excalimath is not on PATH", vim.log.levels.ERROR)
        return
      end

      vim.fn.jobstart({ "excalimath", path }, { detach = true })
      notify("Opened " .. vim.fn.fnamemodify(path, ":t"))
    end

    local function do_create(name)
      local current_file = vim.api.nvim_buf_get_name(0)
      if current_file == "" then
        notify("No file in current buffer", vim.log.levels.ERROR)
        return
      end

      name = vim.fn.fnamemodify(name, ":t")
      if not is_excalidraw(name) then
        name = name .. ".excalidraw"
      end
      local dir = vim.fn.fnamemodify(current_file, ":h") .. "/" .. assets_dir
      local path = vim.fn.fnamemodify(dir .. "/" .. name, ":p")

      -- Excalimath shares one localStorage scene across files and only reseeds it
      -- from disk when the target exists, so the file must exist before launch.
      if vim.fn.filereadable(path) == 1 then
        notify("File already exists, opening it: " .. path, vim.log.levels.WARN)
      else
        vim.fn.mkdir(dir, "p")
        local template = vim.json.encode({
          type = "excalidraw",
          version = 2,
          source = "nixvim-config",
          elements = {},
          appState = vim.empty_dict(),
          files = vim.empty_dict(),
        })
        if vim.fn.writefile({ template }, path) == -1 then
          notify("Cannot create file: " .. path, vim.log.levels.ERROR)
          return
        end
      end

      local link = string.format("[%s](%s)", name:gsub("%.excalidraw$", ""), vim.fn.fnamemodify(path, ":~:."))
      local row, col = unpack(vim.api.nvim_win_get_cursor(0))
      local line = vim.api.nvim_get_current_line()
      vim.api.nvim_set_current_line(line:sub(1, col) .. link .. line:sub(col + 1))
      vim.api.nvim_win_set_cursor(0, { row, col + #link })

      excalimath.open(path)
    end

    function excalimath.create(name)
      if name and name ~= "" then
        do_create(name)
        return
      end
      vim.ui.input({ prompt = "Excalidraw file name: " }, function(input)
        if input and input ~= "" then
          do_create(input)
        end
      end)
    end

    vim.api.nvim_create_user_command("ExcalidrawOpen", function(opts)
      excalimath.open(opts.args)
    end, { nargs = "?", complete = "file" })

    vim.api.nvim_create_user_command("ExcalidrawCreate", function(opts)
      excalimath.create(opts.args)
    end, { nargs = "?" })
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
      options.desc = "Open Excalidraw diagram under cursor in Excalimath";
    }
    {
      mode = "n";
      key = "<leader>ec";
      action = "<CMD>ExcalidrawCreate<CR>";
      options.desc = "Create new Excalidraw diagram in assets/";
    }
  ];
}
