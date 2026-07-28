local M = {}

local window = require('sven.window')

-- Default configuration
M.config = {
  -- 'vsplit' | 'float'
  default_window = 'vsplit',
  -- keymap to open sven (set to false to disable)
  keymap = '<leader>sv',
  -- floating window options
  float = {
    width = 0.8,
    height = 0.8,
    border = 'rounded',
  },
}

function M.setup(user_config)
  M.config = vim.tbl_deep_extend('force', M.config, user_config or {})

  -- Create user commands
  vim.api.nvim_create_user_command('Sven', function(opts)
    local mode = opts.args ~= '' and opts.args or M.config.default_window
    M.open(mode)
  end, {
    nargs = '?',
    complete = function(_, _, _)
      return { 'vsplit', 'float' }
    end,
    desc = 'Open sven in a vertical split or floating terminal',
  })

  vim.api.nvim_create_user_command('SvenVsplit', function()
    M.open('vsplit')
  end, { desc = 'Open sven in a vertical split terminal' })

  vim.api.nvim_create_user_command('SvenFloat', function()
    M.open('float')
  end, { desc = 'Open sven in a floating terminal' })

  -- Optional keymap
  if M.config.keymap then
    vim.keymap.set('n', M.config.keymap, function()
      M.open(M.config.default_window)
    end, { desc = 'Open sven', noremap = true, silent = true })
  end
end

function M.open(mode)
  mode = mode or M.config.default_window
  if mode == 'float' then
    window.open_float(M.config.float)
  else
    window.open_vsplit()
  end
end

return M
