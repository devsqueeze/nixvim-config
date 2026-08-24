{ ... }: {
  extraConfigLua = ''
    local output_file = "/tmp/dictate_output.txt"

    local function accept()
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      local text = table.concat(lines, "\n")
      local f = io.open(output_file, "w")
      if f then
        f:write(text)
        f:close()
      end
      vim.fn.setreg("+", text)
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

        vim.cmd("startinsert")
      end,
    })
  '';
}
