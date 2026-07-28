local M = {}

local window = require('sven.window')
local prompt = require('sven.prompt')

-- Default configuration
local M = {}
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
  -- Available placeholders: {{filetype}}, {{filepath}}, {{content}}, {{prompt}}
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

  vim.api.nvim_create_user_command('SvenPreviewPrompt', function()
    prompt.preview()
  end, { desc = 'Preview the prepared prompt for the current buffer (asks for prompt)' })

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
  local bufnr = vim.api.nvim_get_current_buf()

  if user_prompt then
    M.open_with_prompt(mode, bufnr, user_prompt)
    return
  end

  if vim.ui.input then
    vim.ui.input({ prompt = 'Ask sven: ' }, function(input)
      M.open_with_prompt(mode, bufnr, input or '')
    end)
  else
    M.open_with_prompt(mode, bufnr, vim.fn.input('Ask sven: '))
  end
end

function M.open_with_prompt(mode, bufnr, user_prompt)
  vim.schedule(function()
    local prepared = prompt.build(bufnr, user_prompt, M.config.prompt_template)

    if mode == 'float' then
      window.open_float(M.config.float, prepared)
    else
      window.open_vsplit(prepared)
    end
  end)
end

return M
