{ ... }: {
  extraConfigLua = ''
    local output_file = "/tmp/dictate_output.txt"

    local history_file = "/dev/shm/dictate_history.jsonl"
    local history_limit = 5 -- how many past dictations are kept, and shown in history

    -- Keep in sync with STATUS_FILE in dictate.py. The daemon writes its
    -- desktop-notification text here and remote-calls this so the same
    -- "Listening...", "Processing...", "Inserted." etc. cues show up inside
    -- the dictate window itself, not just as a desktop notification.
    local status_file = "/tmp/dictate_status.json"

    _G.dictate_show_status = function()
      local f = io.open(status_file, "r")
      if not f then
        return
      end
      local content = f:read("*a")
      f:close()
      local ok, decoded = pcall(vim.json.decode, content)
      if not ok or not decoded.text then
        return
      end
      local level = decoded.level == "error" and vim.log.levels.ERROR or vim.log.levels.INFO
      vim.notify("dictate: " .. decoded.text, level)
    end

    -- A window closed without <CR> must still reach the history, but exit
    -- hooks can't be relied on for that: when the ghostty window goes away,
    -- the TUI client and the --embed server see the hangup differently, and
    -- in testing VimLeavePre either never ran or saw an empty buffer. So
    -- the buffer is written here on every change instead, and the next
    -- session moves whatever is left into the history (ingest_draft). Keep
    -- in sync with DRAFT_FILE in dictate.py -- the daemon appends a round
    -- that finishes after the window has already closed.
    local draft_file = "/dev/shm/dictate_draft.txt"
    local scratch_file = "/tmp/dictate_scratch.md"

    -- Only a session in which at least one word was dictated counts for the
    -- history. One that recorded nothing, was muted, or just restored or
    -- re-sent an old entry doesn't.
    local dictated = false

    local function write_draft()
      if not dictated then
        return
      end
      local buf = vim.fn.bufnr(scratch_file)
      if buf == -1 then
        return
      end
      local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
      if text:match("^%s*$") then
        os.remove(draft_file)
        return
      end
      local f = io.open(draft_file, "w")
      if f then
        f:write(text)
        f:close()
      end
    end

    -- Keep in sync with INSERT_FILE in dictate.py. The daemon writes each
    -- finished transcription here and remote-calls dictate_insert_text(),
    -- which puts it straight into the scratch buffer. Unlike typing it with
    -- wtype, this lands here even if another window has focus, and works in
    -- any mode. The return value tells the daemon what happened: "ok",
    -- "busy" (buffer locked by a refine), "empty", or "error: ...".
    local insert_file = "/tmp/dictate_insert.txt"

    _G.dictate_insert_text = function()
      local f = io.open(insert_file, "r")
      if not f then
        return "empty"
      end
      local text = f:read("*a")
      f:close()
      if text == "" then
        return "empty"
      end

      local buf = vim.fn.bufnr(scratch_file)
      if buf == -1 then
        return "error: dictate buffer not found"
      end
      local win = vim.fn.bufwinid(buf)
      if win == -1 then
        return "error: dictate buffer is not shown in any window"
      end
      if not vim.bo[buf].modifiable then
        return "busy"
      end

      -- Run in the scratch buffer's own window, so this still works when
      -- e.g. the history picker has focus inside nvim.
      local ok, err = pcall(vim.api.nvim_win_call, win, function()
        local col = vim.api.nvim_win_get_cursor(0)[2]
        local line = vim.api.nvim_get_current_line()
        -- Like Vim's "a": after the character under the cursor in Normal
        -- mode. In Insert mode the cursor already sits between characters,
        -- so put the text right there instead.
        local insert_mode = vim.api.nvim_get_mode().mode:sub(1, 1) == "i"
        local prev_char = insert_mode and line:sub(col, col) or line:sub(col + 1, col + 1)
        -- Separate from the text already there, or consecutive dictations
        -- run together ("Hello.World").
        if prev_char ~= "" and not prev_char:match("%s") and not text:match("^%s") then
          text = " " .. text
        end
        vim.api.nvim_put(vim.split(text, "\n"), "c", not insert_mode and line ~= "", false)
        -- Leave the cursor on the last inserted character (after it, in
        -- Insert mode), so the next dictation continues from there.
        local mark = vim.api.nvim_buf_get_mark(0, "]")
        if insert_mode then
          local last_line = vim.api.nvim_buf_get_lines(0, mark[1] - 1, mark[1], false)[1]
          local char_len = #vim.fn.strcharpart(last_line:sub(mark[2] + 1), 0, 1)
          vim.api.nvim_win_set_cursor(0, { mark[1], mark[2] + char_len })
        else
          vim.api.nvim_win_set_cursor(0, mark)
        end
      end)
      if not ok then
        return "error: " .. tostring(err)
      end
      if text:match("%w") then
        dictated = true
      end
      write_draft()
      return "ok"
    end

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

    local function append_history(text, timestamp)
      local entries = read_history_entries()
      table.insert(entries, { text = text, time = os.date("%Y-%m-%d %H:%M", timestamp) })
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

    -- A draft still here at startup is from a window closed without <CR>.
    -- Timestamped with when it was last written, not now.
    local function ingest_draft()
      local f = io.open(draft_file, "r")
      if not f then
        return
      end
      local text = f:read("*a")
      f:close()
      if not text:match("^%s*$") then
        local stat = vim.uv.fs_stat(draft_file)
        append_history(text, stat and stat.mtime.sec or nil)
      end
      os.remove(draft_file)
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
              write_draft()
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
      if dictated and not text:match("^%s*$") then
        append_history(text)
      end
      -- Already in the history (or not meant for it) -- don't ingest it
      -- again next session.
      os.remove(draft_file)
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
      write_draft()
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
      pattern = scratch_file,
      callback = function(args)
        local buf = args.buf
        vim.bo[buf].swapfile = false

        -- Before this session can write a draft of its own.
        ingest_draft()
        -- Manual edits; the API-driven changes (dictation, refine, history
        -- restore) call write_draft() themselves.
        vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
          buffer = buf,
          callback = write_draft,
        })

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
      end,
    })
  '';
}
