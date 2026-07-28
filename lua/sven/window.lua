local M = {}

-- Default filetype for the terminal buffer. Can be overridden via config.
M.default_filetype = 'sven'

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

-- Escape line endings so a multi-line prompt can be sent as a single line.
local function escape_line_endings(s)
  return s:gsub('\n', '\\n'):gsub('\r', '\\r')
end

-- Safely send data to a channel/job, ignoring errors if it no longer exists.
local function safe_chansend(id, data)
  if not id or id <= 0 then
    return
  end
  pcall(vim.fn.chansend, id, data)
end

-- Open a terminal running `cmd` in a window created by `make_win`.
-- If `prepared_prompt` is provided, it is sent to the job's stdin after a
-- short delay so the process has time to initialize.
local function open_terminal(cmd, prepared_prompt, make_win, config)
  local buf = vim.api.nvim_create_buf(false, true)
  local win = make_win(buf)

  -- Open the terminal job directly in the buffer. Neovim handles all
  -- keystroke forwarding between the terminal buffer and the job.
  vim.api.nvim_buf_call(buf, function()
    vim.bo[buf].filetype = (config and config.terminal_filetype) or M.default_filetype
    vim.bo[buf].syntax = (config and config.terminal_filetype) or M.default_filetype
    vim.fn.termopen(cmd, {
      on_exit = function(_, _, _)
        safe_close_win(win)
        safe_close_buf(buf)
      end,
    })
  end)

  local job_id = vim.b[buf].terminal_job_id

  -- Send the prepared prompt once the terminal is ready.
  -- Line endings are escaped so the whole prompt arrives as one input line.
  if prepared_prompt and prepared_prompt ~= '' and job_id and job_id > 0 then
    vim.defer_fn(function()
      safe_chansend(job_id, escape_line_endings(prepared_prompt) .. '\n')
    end, 100)
  end

  -- Focus the window and start insert mode so keystrokes go to sven.
  vim.defer_fn(function()
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_set_current_win(win)
      vim.cmd('startinsert')
    end
  end, 50)

  -- Pressing 'q' in normal mode closes the window
  vim.keymap.set('n', 'q', function()
    safe_close_win(win)
    safe_close_buf(buf)
  end, { buffer = buf, noremap = true, silent = true })

  return job_id
end

-- Open sven in a vertical split terminal.
-- If prepared_prompt is given, it is sent to sven's stdin.
function M.open_vsplit(prepared_prompt, config)
  open_terminal('sven', prepared_prompt, function(buf)
    vim.cmd('vsplit')
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    return win
  end, config)
end

-- Open sven in a centered floating terminal.
-- If prepared_prompt is given, it is sent to sven's stdin.
function M.open_float(opts, prepared_prompt, config)
  opts = opts or {}
  local width = math.floor(vim.o.columns * (opts.width or 0.8))
  local height = math.floor(vim.o.lines * (opts.height or 0.8))
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  open_terminal('sven', prepared_prompt, function(buf)
    local win = vim.api.nvim_open_win(buf, true, {
      relative = 'editor',
      width = width,
      height = height,
      row = row,
      col = col,
      style = 'minimal',
      border = opts.border or 'rounded',
    })

    -- Close floating window with <Esc><Esc> in terminal mode
    vim.keymap.set('t', '<Esc><Esc>', function()
      safe_close_win(win)
      safe_close_buf(buf)
    end, { buffer = buf, noremap = true, silent = true })

    return win
  end, config)
end

return M
