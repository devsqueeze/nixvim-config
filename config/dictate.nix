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
        local trimmed = {}
        for i = #entries - history_limit + 1, #entries do
          table.insert(trimmed, entries[i])
        end
        entries = trimmed
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

    -- Line breaks made just for editing convenience in this buffer get
    -- collapsed to spaces before being typed back (see dictate_toggle.sh),
    -- so an accidental Enter can't submit a chat message mid-paste. This
    -- marker (converted back to a real Enter keypress by dictate_toggle.sh)
    -- lets a specific line break be kept for scenarios that do want one --
    -- multi-paragraph text, code, etc.
    local newline_marker = "␤"

    local function insert_newline_marker()
      local pos = vim.api.nvim_win_get_cursor(0)
      local row, col = pos[1], pos[2]
      local line = vim.api.nvim_get_current_line()
      vim.api.nvim_set_current_line(line:sub(1, col) .. newline_marker .. line:sub(col + 1))
      vim.api.nvim_win_set_cursor(0, { row, col + #newline_marker })
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

    local function save_to_history()
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      local text = table.concat(lines, "\n")
      if text:match("^%s*$") then
        return
      end
      append_history(text)
      vim.notify("dictate: saved to history")
    end

    local refine_system_prompt = "You clean up dictated speech-to-text drafts. Rewrite the user's message "
      .. "into clear, concise UK English: fix dictation artefacts, grammar, "
      .. "capitalisation and punctuation, without changing its meaning or "
      .. "adding new content. Reply with ONLY the corrected text -- no "
      .. "preamble, no markdown code fences, no commentary."

    local function apply_refine_result(bufnr, refined_text)
      if not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end
      vim.bo[bufnr].modifiable = true
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(refined_text, "\n"))
      vim.notify("dictate: refined")
    end

    local function fail_refine(bufnr, detail, log_body)
      if not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end
      vim.bo[bufnr].modifiable = true
      local log = io.open("/tmp/dictate_refine_error.log", "w")
      if log then
        log:write(log_body)
        log:close()
      end
      vim.notify("dictate: refine failed: " .. detail .. " (full log: /tmp/dictate_refine_error.log)", vim.log.levels.ERROR)
    end

    -- Slow but always-correct path: the CLI handles its own OAuth refresh, so
    -- this is the fallback whenever the direct API call can't be used.
    local function call_claude_cli(draft, bufnr)
      vim.system(
        {
          "claude", "-p", "--model", "claude-haiku-4-5-20251001",
          "--output-format", "text", "--allowedTools", "", "--strict-mcp-config",
          "--setting-sources", "", "--no-session-persistence",
          "--system-prompt", refine_system_prompt,
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
            local stdout = result.stdout or ""
            if result.code == 0 and stdout:match("%S") then
              apply_refine_result(bufnr, (stdout:gsub("%s+$", "")))
            else
              local stderr = result.stderr or ""
              local detail = stderr:match("%S") and stderr or ("exit code " .. tostring(result.code) .. ", no output")
              fail_refine(
                bufnr,
                detail,
                "exit code: " .. tostring(result.code) .. "\n--- stdout ---\n" .. stdout .. "\n--- stderr ---\n" .. stderr .. "\n"
              )
            end
          end)
        end
      )
    end

    local function read_access_token()
      local f = io.open(vim.fn.expand("~/.config/claude/.credentials.json"), "r")
      if not f then
        return nil
      end
      local content = f:read("*a")
      f:close()
      local ok, decoded = pcall(vim.json.decode, content)
      if not ok or not decoded.claudeAiOauth then
        return nil
      end
      return decoded.claudeAiOauth.accessToken
    end

    -- Fast path: calls the Messages API directly with the same OAuth token
    -- Claude Code itself uses (subscription-billed, not pay-per-token -- see
    -- shared/anthropic-cli.md in the claude-api skill). This machine's token
    -- is kept fresh by ordinary Claude Code use; this function doesn't
    -- implement the OAuth refresh flow itself, so any failure here (stale
    -- token, network issue, unexpected response shape) just falls back to
    -- call_claude_cli instead of surfacing an error.
    local function call_direct_api(draft, token, bufnr)
      local body = vim.json.encode({
        model = "claude-haiku-4-5-20251001",
        max_tokens = 1024,
        system = refine_system_prompt,
        messages = { { role = "user", content = "Refine this dictated draft: " .. draft } },
      })

      vim.system(
        {
          "curl", "-sS", "-f", "https://api.anthropic.com/v1/messages",
          "-H", "Authorization: Bearer " .. token,
          "-H", "anthropic-version: 2023-06-01",
          "-H", "anthropic-beta: oauth-2025-04-20",
          "-H", "content-type: application/json",
          "-d", body,
        },
        { text = true },
        function(result)
          vim.schedule(function()
            if result.code == 0 then
              local ok, decoded = pcall(vim.json.decode, result.stdout or "")
              local text = ok and decoded.content and decoded.content[1] and decoded.content[1].text
              if text and text:match("%S") then
                apply_refine_result(bufnr, (text:gsub("%s+$", "")))
                return
              end
            end
            call_claude_cli(draft, bufnr)
          end)
        end
      )
    end

    local function refine()
      local bufnr = vim.api.nvim_get_current_buf()
      local draft = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
      if draft:match("^%s*$") then
        return
      end

      vim.bo[bufnr].modifiable = false
      vim.notify("dictate: refining...")

      local token = read_access_token()
      if token then
        call_direct_api(draft, token, bufnr)
      else
        call_claude_cli(draft, bufnr)
      end
    end

    vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
      pattern = "/tmp/dictate_scratch.md",
      callback = function(args)
        local buf = args.buf
        vim.bo[buf].swapfile = false

        local opts = { buffer = buf, silent = true }
        -- <leader>-prefixed so these don't shadow basic Vim editing commands
        -- (bare "r" replaces a character, bare "p" pastes) while the user is
        -- fixing up dictated text in this buffer.
        vim.keymap.set("n", "<leader>r", refine, opts)
        vim.keymap.set("n", "<CR>", accept, opts)
        vim.keymap.set("n", "ZQ", discard, opts)
        vim.keymap.set("n", "<leader>h", show_history, opts)
        vim.keymap.set("n", "<leader>n", insert_newline_marker, opts)
        vim.keymap.set("n", "<leader>s", save_to_history, opts)

        vim.cmd("startinsert")
      end,
    })
  '';
}
