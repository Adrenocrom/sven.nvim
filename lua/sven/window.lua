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

-- Safely send data to a channel/job, ignoring errors if it no longer exists.
local function safe_chansend(id, data)
  if not id or id <= 0 then
    return
  end
  pcall(vim.fn.chansend, id, data)
end

-- Open a terminal running `cmd` in a window created by `make_win`.
-- If `prepared_prompt` is provided, it is sent to the job's stdin after the
-- first stdout is received, so sven has a chance to print its prompt first.
local function open_terminal(cmd, prepared_prompt, make_win)
  local buf = vim.api.nvim_create_buf(false, false)
  local win = make_win(buf)

  local job_id
  local prompt_sent = false

  -- Open a terminal instance in the buffer. User keystrokes are forwarded to
  -- the job, and the job's stdout is forwarded to the terminal display.
  local term_id = vim.api.nvim_open_term(buf, {
    on_input = function(_, data, _)
      if job_id and job_id > 0 and vim.api.nvim_buf_is_valid(buf) then
        safe_chansend(job_id, data)
      end
    end,
  })

  job_id = vim.fn.jobstart(cmd, {
    pty = true,
    on_stdout = function(_, data, _)
      if not data or not vim.api.nvim_buf_is_valid(buf) then
        return
      end

      -- Forward sven's output to the terminal buffer.
      safe_chansend(term_id, data)

      -- Send the prepared prompt once sven has produced its first output.
      if not prompt_sent and prepared_prompt and prepared_prompt ~= '' then
        for _, line in ipairs(data) do
          if line ~= '' then
            prompt_sent = true
            vim.defer_fn(function()
              if job_id and job_id > 0 then
                safe_chansend(job_id, prepared_prompt .. '\n')
              end
            end, 50)
            break
          end
        end
      end
    end,
    on_exit = function(_, _, _)
      safe_close_win(win)
      safe_close_buf(buf)
    end,
  })

  -- Fallback: if sven produces no stdout, send the prompt after a short delay.
  if prepared_prompt and prepared_prompt ~= '' then
    vim.defer_fn(function()
      if not prompt_sent and job_id and job_id > 0 then
        prompt_sent = true
        safe_chansend(job_id, prepared_prompt .. '\n')
      end
    end, 1000)
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
function M.open_vsplit(prepared_prompt)
  open_terminal('sven', prepared_prompt, function(buf)
    vim.cmd('vsplit')
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    return win
  end)
end

-- Open sven in a centered floating terminal.
-- If prepared_prompt is given, it is sent to sven's stdin.
function M.open_float(opts, prepared_prompt)
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
  end)
end

return M
