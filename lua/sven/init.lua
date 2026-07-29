local window = require('sven.window')
local prompt = require('sven.prompt')

local M = {}
M.config = {
	default_window = 'vsplit',
	keymap = '<leader>sv',
	keymap_ask = '<leader>sa',
	float = {
		width = 0.8,
		height = 0.8,
		border = 'rounded',
	},
	prompt_template = prompt.default_template(),
	terminal_filetype = 'markdown',
}

function M.setup(user_config)
	M.config = vim.tbl_deep_extend('force', M.config, user_config or {})

	vim.api.nvim_create_user_command('Sven', function(opts)
		local mode = opts.args ~= '' and opts.args or M.config.default_window
		local list = ["ask", "chat"]
		vim.ui.select(list, {prompt = "Choose:" }, function(item) 
			if item == "ask" then
				M.ask(mode)
			elif  item == "chat" then
				M.open(mode)
			end
		end)
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
		window.open_float(M.config.float, nil, M.config)
	else
		window.open_vsplit(nil, M.config)
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
			window.open_float(M.config.float, prepared, M.config)
		else
			window.open_vsplit(prepared, M.config)
		end
	end)
end

return M
