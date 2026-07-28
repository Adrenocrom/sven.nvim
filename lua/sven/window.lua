local M = {}

-- Default filetype for the sven output buffer. Can be overridden via config.
M.default_filetype = 'markdown'

-- Close a window if it is still valid
local function safe_close_win(win)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
end

-- Close a buffer if it is still valid
local function safe_close_buf(buf)
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
end

-- Strip ANSI escape sequences and stray carriage returns from a string.
local function strip_ansi(s)
  return s:gsub('\27%[[%d;]*%a', ''):gsub('\r', '')
end

-- Create an appender for `buf` that handles partial lines, strips ANSI/CR
-- characters, collapses consecutive blank lines, drops duplicate "User:"
-- lines caused by stdin echo, and keeps the cursor at the end of the buffer.
--
-- Returns a table with two methods:
--   append(text)                -- append text to the buffer
--   set_last_user_content(text) -- remember the last user input for echo filtering
local function create_appender(buf)
  local pending = ''
  local prev_blank = true
  local last_user_content = nil

  local function is_blank_line(line)
    return line:match('^%s*$') ~= nil
  end

  local function normalize(s)
    return s:gsub('%s+', ' '):gsub('^%s*(.-)%s*$', '%1')
  end

  local function append(text)
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end

    text = strip_ansi(pending .. text)
    local lines = vim.split(text, '\n', { plain = true })
    pending = table.remove(lines) or ''

    local filtered = {}
    for _, line in ipairs(lines) do
      local user_content = line:match('^%s*User:%s*(.-)%s*$')

      -- Drop empty User: prompts emitted by the sven REPL.
      if user_content and user_content == '' then
        goto continue
      end

      -- Drop User: lines whose content matches the last thing we sent,
      -- even if whitespace differs. This prevents stdin echo from
      -- duplicating the prompt in the output buffer.
      if user_content and last_user_content then
        if normalize(user_content) == normalize(last_user_content) then
          goto continue
        end
      end

      local blank = is_blank_line(line)
      if blank and prev_blank then
        -- collapse consecutive blank lines
        goto continue
      end

      table.insert(filtered, line)
      prev_blank = blank

      ::continue::
    end

    if #filtered == 0 then
      return
    end

    vim.api.nvim_buf_set_lines(buf, -1, -1, false, filtered)

    local line_count = vim.api.nvim_buf_line_count(buf)
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_set_cursor(win, { math.max(1, line_count), 0 })
      end
    end
  end

  local function set_last_user_content(content)
    last_user_content = content
  end

  return {
    append = append,
    set_last_user_content = set_last_user_content,
  }
end

-- Open a markdown buffer running `cmd` as a background job.
-- If `prepared_prompt` is provided, it is sent to the job's stdin after a
-- short delay so the process has time to initialize.
local function open_markdown_chat(cmd, prepared_prompt, make_win, config)
  local buf = vim.api.nvim_create_buf(false, true)
  local filetype = (config and config.terminal_filetype) or M.default_filetype

  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = filetype
  vim.bo[buf].syntax = filetype

  local win = make_win(buf)
  local appender = create_appender(buf)
  local append = appender.append

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    '# Sven',
    '',
    '_Press `i` to send a message, `q` to close._',
    '',
  })

  local job_id

  local function send_input(text)
    if not text or text == '' then
      return
    end
    -- Send the whole message as one input line so multi-line prepared
    -- prompts are not processed line-by-line by the sven REPL.
    local single_line = text:gsub('\n', ' ')
    appender.set_last_user_content(single_line)
    append('User: ' .. single_line)
    append('')
    if job_id and job_id > 0 then
      pcall(vim.fn.chansend, job_id, single_line .. '\n')
    end
  end

  job_id = vim.fn.jobstart(cmd, {
    stdin = 'pipe',
    stdout_buffered = false,
    stderr_buffered = false,
    on_stdout = function(_, data, _)
      if not data then
        return
      end
      for i = 1, #data - 1 do
        append(data[i] .. '\n')
      end
      -- Ignore the trailing empty chunk that jobstart appends after each
      -- stdout flush; it creates spurious blank lines in the output buffer.
      local last = data[#data]
      if last and last ~= '' then
        append(last)
      end
    end,
    on_stderr = function(_, _, _)
      -- stderr is intentionally hidden
    end,
    on_exit = function(_, exit_code, _)
      append('\n_--- sven exited (' .. tostring(exit_code) .. ') ---_')
      job_id = nil
    end,
  })

  if not job_id or job_id <= 0 then
    append('_Failed to start sven._')
  elseif prepared_prompt and prepared_prompt ~= '' then
    vim.defer_fn(function()
      send_input(prepared_prompt)
    end, 100)
  end

  -- Pressing 'i' in normal mode opens an input prompt to talk to sven.
  vim.keymap.set('n', 'i', function()
    vim.ui.input({ prompt = 'sven> ' }, send_input)
  end, { buffer = buf, noremap = true, silent = true })

  -- Pressing 'q' in normal mode closes the window and stops the job.
  vim.keymap.set('n', 'q', function()
    if job_id and job_id > 0 then
      pcall(vim.fn.chanclose, job_id)
      job_id = nil
    end
    safe_close_win(win)
    safe_close_buf(buf)
  end, { buffer = buf, noremap = true, silent = true })

  -- Also close the window if the buffer is wiped out.
  vim.api.nvim_create_autocmd('BufWipeout', {
    buffer = buf,
    once = true,
    callback = function()
      if job_id and job_id > 0 then
        pcall(vim.fn.chanclose, job_id)
        job_id = nil
      end
      safe_close_win(win)
    end,
  })

  return job_id
end

-- Open sven in a vertical split markdown buffer.
-- If prepared_prompt is given, it is sent to sven's stdin.
function M.open_vsplit(prepared_prompt, config)
  return open_markdown_chat('sven', prepared_prompt, function(buf)
    vim.cmd('vsplit')
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    return win
  end, config)
end

-- Open sven in a centered floating markdown buffer.
-- If prepared_prompt is given, it is sent to sven's stdin.
function M.open_float(opts, prepared_prompt, config)
  opts = opts or {}
  local width = math.floor(vim.o.columns * (opts.width or 0.8))
  local height = math.floor(vim.o.lines * (opts.height or 0.8))
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  return open_markdown_chat('sven', prepared_prompt, function(buf)
    local win = vim.api.nvim_open_win(buf, true, {
      relative = 'editor',
      width = width,
      height = height,
      row = row,
      col = col,
      style = 'minimal',
      border = opts.border or 'rounded',
    })

    -- Close floating window with <Esc> in normal mode.
    vim.keymap.set('n', '<Esc>', function()
      safe_close_win(win)
      safe_close_buf(buf)
    end, { buffer = buf, noremap = true, silent = true })

    return win
  end, config)
end

return M
