-- Migrated from tmux, Herdr and Ghostty.

-- Opens lazygit in a new tab, in the focused pane's directory.
rex.action{
  name  = "lazygit",
  title = "Open lazygit",
  run   = function(ctx)
    local terminal = "com.superlogical.terminal"
    local process = rex.block.call(terminal, "process", { block_id = ctx.block_id })
    local window, err = rex.session.new_window{
      window_label = "lazygit",
      layout = rex.layout.block{
        flavor  = terminal .. ".shell",
        options = {
          command = { "lazygit" },
          cwd     = process and process.foreground and process.foreground.cwd,
        },
      },
    }
    if err ~= nil then error(err, 0) end
    -- The server creates the tab; the app only switches to it when asked.
    rex.client.queue("session.select", {
      session_id = ctx.session_id,
      window_id  = window.window_id,
    })
  end,
}

-- Pastes the clipboard into the pane as a Markdown quote. Copy the text first.
rex.action{
  name  = "quote_clipboard",
  title = "Paste Clipboard as Quote",
  run   = function(ctx)
    -- Without a UTF-8 locale, pbpaste mangles non-ASCII text.
    local copied, paste_error = rex.exec({ "pbpaste" }, { env = { LC_ALL = "en_US.UTF-8" } })
    if copied == nil then error(paste_error, 0) end

    local lines = {}
    for line in (copied.stdout .. "\n"):gmatch("(.-)\r?\n") do
      local trimmed = line:gsub("%s+$", "")
      lines[#lines + 1] = trimmed
    end
    while lines[1] == "" do table.remove(lines, 1) end
    while lines[#lines] == "" do table.remove(lines) end
    if #lines == 0 then error("the clipboard has no text", 0) end

    local shared_indent = math.huge
    for _, line in ipairs(lines) do
      local indent = line:match("^(%s*)%S")
      if indent then shared_indent = math.min(shared_indent, #indent) end
    end
    for index, line in ipairs(lines) do
      lines[index] = line:sub(shared_indent + 1)
    end

    -- One paste per line: agents collapse a larger paste into a placeholder.
    for _, line in ipairs(lines) do
      local _, event_error = rex.call("block.event", {
        session_id = ctx.session_id,
        block_id   = ctx.block_id,
        event      = { type = "paste", payload = { text = "> " .. line .. "\n" } },
      })
      if event_error ~= nil then error(event_error, 0) end
    end
  end,
}
rex.bind("ctrl+q", "quote_clipboard")

-- tmux (prefix ctrl+b)
rex.bind("shift+left", "client.tab.previous")
rex.bind("shift+right", "client.tab.next")
rex.bind("ctrl+b>g", "lazygit")
rex.bind("ctrl+b>r", "client.config.reload")
rex.bind("ctrl+b>c", "client.tab.new")
-- ctrl+b now starts a sequence; press it twice to send ctrl+b to the program.
rex.bind("ctrl+b>ctrl+b", "pane.send_key", { key = "ctrl+b" })

-- Herdr (shift+left / shift+right are bound above; tmux's lines won)
rex.bind("shift+up", "session.previous")
rex.bind("shift+down", "session.next")

-- Ghostty
rex.bind("alt+cmd+left", "client.tab.previous")
rex.bind("alt+cmd+right", "client.tab.next")
rex.bind("shift+cmd+r", "client.config.reload")
