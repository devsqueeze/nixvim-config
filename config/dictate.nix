{ ... }: {
  extraConfigLua = ''
    local output_file = "/tmp/dictate_output.txt"

    local history_file = "/dev/shm/dictate_history.jsonl"
    local history_limit = 5 -- how many past dictations are kept, and shown in history

    local function read_history_entries()
      local entries = {}
      local f = io.open(history_file, "r")
      if f then
        for line in f:lines() do
          local ok, entry = pcall(vim.json.decode, line)
          if ok then
            table.insert(entries, entry)
          end
        end
        f:close()
      end
      return entries
    end

    local function append_history(text)
      local entries = read_history_entries()
      table.insert(entries, { text = text, time = os.date("%Y-%m-%d %H:%M") })
      if #entries > history_limit then
        entries = { table.unpack(entries, #entries - history_limit + 1) }
      end
      local out = io.open(history_file, "w")
      if out then
        for _, entry in ipairs(entries) do
          out:write(vim.json.encode(entry) .. "\n")
        end
        out:close()
      end
    end

    local function show_history()
      local entries = read_history_entries()
      if #entries == 0 then
        vim.notify("dictate: no history yet")
        return
      end

      local pickers = require("telescope.pickers")
      local finders = require("telescope.finders")
      local conf = require("telescope.config").values
      local actions = require("telescope.actions")
      local action_state = require("telescope.actions.state")
      local previewers = require("telescope.previewers")

      local target_bufnr = vim.api.nvim_get_current_buf()

      local items = {}
      for i = #entries, 1, -1 do -- most recent first
        table.insert(items, entries[i])
      end

      pickers.new({}, {
        prompt_title = "Dictation history",
        finder = finders.new_table({
          results = items,
          entry_maker = function(entry)
            local first_line = vim.split(entry.text, "\n")[1]
            return {
              value = entry,
              display = entry.time .. "  " .. first_line,
              ordinal = entry.time .. " " .. entry.text,
            }
          end,
        }),
        sorter = conf.generic_sorter({}),
        previewer = previewers.new_buffer_previewer({
          title = "Dictation text",
          define_preview = function(self, entry)
            vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, vim.split(entry.value.text, "\n"))
          end,
        }),
        attach_mappings = function(prompt_bufnr, _)
          -- Revert the dictate buffer to the selected entry's text.
          actions.select_default:replace(function()
            local selection = action_state.get_selected_entry()
            actions.close(prompt_bufnr)
            if selection and vim.api.nvim_buf_is_valid(target_bufnr) then
              vim.api.nvim_buf_set_lines(target_bufnr, 0, -1, false, vim.split(selection.value.text, "\n"))
            end
          end)
          return true
        end,
      }):find()
    end

    local function accept()
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      local text = table.concat(lines, "\n")
      local f = io.open(output_file, "w")
      if f then
        f:write(text)
        f:close()
      end
      append_history(text)
      vim.cmd("quit!")
    end

    local function discard()
      vim.cmd("quit!")
    end

    local function refine()
      local bufnr = vim.api.nvim_get_current_buf()
      local draft = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
      if draft:match("^%s*$") then
        return
      end

      vim.bo[bufnr].modifiable = false
      vim.notify("dictate: refining...")

      vim.system(
        {
          "claude", "-p", "--model", "claude-haiku-4-5-20251001",
          "--output-format", "text", "--allowedTools", "", "--strict-mcp-config",
          "--setting-sources", "", "--no-session-persistence",
          "--system-prompt",
          "You clean up dictated speech-to-text drafts. Rewrite the user's message "
            .. "into clear, concise UK English: fix dictation artefacts, grammar, "
            .. "capitalisation and punctuation, without changing its meaning or "
            .. "adding new content. Reply with ONLY the corrected text -- no "
            .. "preamble, no markdown code fences, no commentary.",
          "Refine this dictated draft:",
        },
        {
          stdin = draft,
          text = true,
          cwd = "/tmp",
          env = { CLAUDE_CONFIG_DIR = vim.fn.expand("~/.config/claude") },
        },
        function(result)
          vim.schedule(function()
            if not vim.api.nvim_buf_is_valid(bufnr) then
              return
            end
            vim.bo[bufnr].modifiable = true
            local stdout = result.stdout or ""
            if result.code == 0 and stdout:match("%S") then
              local refined = stdout:gsub("%s+$", "")
              vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(refined, "\n"))
              vim.notify("dictate: refined")
            else
              local stderr = result.stderr or ""
              local log = io.open("/tmp/dictate_refine_error.log", "w")
              if log then
                log:write("exit code: " .. tostring(result.code) .. "\n")
                log:write("--- stdout ---\n" .. stdout .. "\n")
                log:write("--- stderr ---\n" .. stderr .. "\n")
                log:close()
              end
              local detail = stderr:match("%S") and stderr or ("exit code " .. tostring(result.code) .. ", no output")
              vim.notify("dictate: refine failed: " .. detail .. " (full log: /tmp/dictate_refine_error.log)", vim.log.levels.ERROR)
            end
          end)
        end
      )
    end

    vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
      pattern = "/tmp/dictate_scratch.md",
      callback = function(args)
        local buf = args.buf
        vim.bo[buf].swapfile = false

        local opts = { buffer = buf, silent = true }
        vim.keymap.set("n", "r", refine, opts)
        vim.keymap.set("n", "<CR>", accept, opts)
        vim.keymap.set("n", "ZQ", discard, opts)
        vim.keymap.set("n", "p", show_history, opts)

        vim.cmd("startinsert")
      end,
    })
  '';
}
