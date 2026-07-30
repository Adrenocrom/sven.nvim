local window = require('sven.window')
local prompt = require('sven.prompt')

local M = {}
M.config = {
	default_window = 'vsplit',
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
		local display_mode = opts.args ~= '' and opts.args or M.config.default_window

		local range_type
		if opts.range == 0 then
			range_type = "n"
		else
			range_type = "v"
		end
		local list = {"ask", "chat"}
		vim.ui.select(list, {prompt = "Choose:" }, function(item) 
			if item == "ask" then
				M.ask(display_mode, range_type)
			elseif item == "chat" then
				M.open(display_mode)
			end
		end)
	end, {
	range = true,
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
end

function M.open(display_mode)
	display_mode = mode or M.config.default_window
	if display_mode == 'float' then
		window.open_float(M.config.float, nil, M.config)
	else
		window.open_vsplit(nil, M.config)
	end
end

function M.ask(display_mode, range_type, user_prompt)
	display_mode = display_mode or M.config.default_window
	local bufnr = vim.api.nvim_get_current_buf()

	if user_prompt then
		M.open_with_prompt(display_mode, range_type, bufnr, user_prompt)
		return
	end

	vim.ui.input({ prompt = 'Ask sven: ' }, function(input)
		M.open_with_prompt(display_mode, range_type, bufnr, input or '')
	end)
end

function M.open_with_prompt(display_mode, range_type, bufnr, user_prompt)
	vim.schedule(function()
		local prepared = prompt.build(bufnr, user_prompt, M.config.prompt_template, range_type)

		if display_mode == 'float' then
			window.open_float(M.config.float, prepared, M.config)
		else
			window.open_vsplit(prepared, M.config)
		end
	end)
end

return M
