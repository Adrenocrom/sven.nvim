local M = {}

local window = require('sven.window')
local prompt = require('sven.prompt')

-- Default configuration
M.config = {
  -- 'vsplit' | 'float'
  default_window = 'vsplit',
  -- keymap to open sven (set to false to disable)
  keymap = '<leader>sv',
  -- keymap to open sven with a prepared prompt
  keymap_ask = '<leader>sa',
  -- floating window options
  float = {
    width = 0.8,
    height = 0.8,
    border = 'rounded',
  },
  -- Template for prepared prompts.
  -- Available placeholders: {{filetype}}, {{content}}, {{prompt}}
  prompt_template = prompt.default_template(),
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

  -- Prepared prompt commands
  vim.api.nvim_create_user_command('SvenAsk', function(opts)
    local mode = opts.args ~= '' and opts.args or M.config.default_window
    M.ask(mode)
  end, {
    nargs = '?',
    complete = function(_, _, _)
      return { 'vsplit', 'float' }
    end,
    desc = 'Open sven with a prepared prompt from the current buffer',
  })

  vim.api.nvim_create_user_command('SvenAskVsplit', function()
    M.ask('vsplit')
  end, { desc = 'Open sven with a prepared prompt in a vertical split' })

  vim.api.nvim_create_user_command('SvenAskFloat', function()
    M.ask('float')
  end, { desc = 'Open sven with a prepared prompt in a floating window' })

  -- Optional keymaps
  if M.config.keymap then
    vim.keymap.set('n', M.config.keymap, function()
      M.open(M.config.default_window)
    end, { desc = 'Open sven', noremap = true, silent = true })
  end

  if M.config.keymap_ask then
    vim.keymap.set('n', M.config.keymap_ask, function()
      M.ask(M.config.default_window)
    end, { desc = 'Ask sven about current buffer', noremap = true, silent = true })
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

function M.ask(mode, user_prompt)
  mode = mode or M.config.default_window
  user_prompt = user_prompt or M.prompt_for_input()

  local prepared = prompt.build(
    vim.api.nvim_get_current_buf(),
    user_prompt,
    M.config.prompt_template
  )

  if mode == 'float' then
    window.open_float(M.config.float, prepared)
  else
    window.open_vsplit(prepared)
  end
end

function M.prompt_for_input()
  if vim.ui.input then
    local result = nil
    vim.ui.input({ prompt = 'Ask sven: ' }, function(input)
      result = input
    end)
    return result or ''
  else
    return vim.fn.input('Ask sven: ')
  end
end

return M
