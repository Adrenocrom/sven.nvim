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

-- Build the shell command used to launch sven.
-- When a prepared prompt is provided, wrap sven in `script` so it sees stdin as
-- a TTY. This avoids the "Input is not a terminal" warning and lets sven read
-- the full multi-line prompt.
local function build_command(prepared_prompt)
  if not prepared_prompt or prepared_prompt == '' then
    return 'sven'
  end

  -- `script -q -c '<cmd>' /dev/null` runs <cmd> attached to a pseudo-terminal.
  -- We pass the prompt through stdin of `script`, which forwards it to sven.
  local cmd = "script -q -c 'sven' /dev/null"
  if vim.fn.executable('script') == 0 then
    -- Fall back if `script` is unavailable.
    cmd = 'sven'
  end

  return cmd
end



-- Open sven in a vertical split terminal.
-- If prepared_prompt is given, it is sent to sven's stdin.
function M.open_vsplit(prepared_prompt)
  vim.cmd('vsplit')
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_win_set_buf(win, buf)

  local job_id = vim.fn.termopen(build_command(prepared_prompt), {
    on_exit = function(_, _, _)
      safe_close_win(win)
      safe_close_buf(buf)
    end,
  })

  if prepared_prompt and prepared_prompt ~= '' and job_id and job_id > 0 then
    vim.defer_fn(function()
      vim.fn.chansend(job_id, prepared_prompt .. '\n')
      vim.fn.chanclose(job_id, 'stdin')
    end, 100)
  end

  -- Start in insert mode so keystrokes go directly to sven
  vim.defer_fn(function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_set_current_win(win)
      vim.cmd('startinsert')
    end
  end, 50)

  -- Pressing 'q' in normal mode closes the window
  vim.keymap.set('n', 'q', function()
    safe_close_win(win)
    safe_close_buf(buf)
  end, { buffer = buf, noremap = true, silent = true })
end

-- Open sven in a centered floating terminal.
-- If prepared_prompt is given, it is sent to sven's stdin.
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

  local job_id = vim.fn.termopen(build_command(prepared_prompt), {
    on_exit = function(_, _, _)
      safe_close_win(win)
      safe_close_buf(buf)
    end,
  })

  if prepared_prompt and prepared_prompt ~= '' and job_id and job_id > 0 then
    vim.defer_fn(function()
      vim.fn.chansend(job_id, prepared_prompt .. '\n')
      vim.fn.chanclose(job_id, 'stdin')
    end, 100)
  end

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
