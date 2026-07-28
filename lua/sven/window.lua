local M = {}

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

-- Build the shell command to run sven with an optional prepared prompt.
-- If prepared_prompt is given, it is piped into sven via stdin.
local function sven_command(prepared_prompt)
  if prepared_prompt and prepared_prompt ~= '' then
    -- Escape single quotes for the echo command
    local safe = prepared_prompt:gsub("'", "'\\''")
    return "printf '%s' '" .. safe .. "' | sven"
  end
  return 'sven'
end

-- Open sven in a vertical split terminal
function M.open_vsplit(prepared_prompt)
  vim.cmd('vsplit')
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_win_set_buf(win, buf)

  vim.fn.termopen(sven_command(prepared_prompt), {
    on_exit = function(_, _, _)
      safe_close_win(win)
      safe_close_buf(buf)
    end,
  })

  -- Start in insert mode so keystrokes go directly to sven
  vim.defer_fn(function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_set_current_win(win)
      vim.cmd('startinsert')
    end
  end, 50)

  -- Pressing <Esc> in terminal mode lets you navigate the buffer
  -- Pressing 'q' in normal mode closes the window
  vim.keymap.set('n', 'q', function()
    safe_close_win(win)
    safe_close_buf(buf)
  end, { buffer = buf, noremap = true, silent = true })
end

-- Open sven in a centered floating terminal
function M.open_float(opts, prepared_prompt)
  opts = opts or {}
  local width = math.floor(vim.o.columns * (opts.width or 0.8))
  local height = math.floor(vim.o.lines * (opts.height or 0.8))
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, false)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = opts.border or 'rounded',
  })

  vim.fn.termopen(sven_command(prepared_prompt), {
    on_exit = function(_, _, _)
      safe_close_win(win)
      safe_close_buf(buf)
    end,
  })

  vim.defer_fn(function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_set_current_win(win)
      vim.cmd('startinsert')
    end
  end, 50)

  -- Close floating window with 'q' in normal mode or <Esc> twice
  vim.keymap.set('n', 'q', function()
    safe_close_win(win)
    safe_close_buf(buf)
  end, { buffer = buf, noremap = true, silent = true })

  vim.keymap.set('t', '<Esc><Esc>', function()
    safe_close_win(win)
    safe_close_buf(buf)
  end, { buffer = buf, noremap = true, silent = true })
end

return M
