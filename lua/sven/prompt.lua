local M = {}

local function get_buffer_content(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return '[invalid buffer ' .. tostring(bufnr) .. ']'
	end

	local ok, lines = pcall(vim.api.nvim_buf_get_lines, bufnr, 0, -1, false)
	if not ok or type(lines) ~= 'table' then
		return '[failed to read buffer ' .. tostring(bufnr) .. ']'
	end

	return table.concat(lines, '\n')
end

local function replace_all(str, pattern, repl)
	return str:gsub(pattern, function()
		return repl
	end)
end

function M.build(bufnr, user_prompt, template)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	user_prompt = user_prompt or ''
	template = template or M.default_template()

	local filetype = vim.bo[bufnr].filetype or 'unknown'
	local filepath = vim.api.nvim_buf_get_name(bufnr)
	if filepath == '' then
		filepath = '[unnamed]'
	end
	local content = get_buffer_content(bufnr)

	local result = template
	result = replace_all(result, '{{filetype}}', filetype)
	result = replace_all(result, '{{filepath}}', filepath)
	result = replace_all(result, '{{content}}', content)
	result = replace_all(result, '{{prompt}}', user_prompt)

	return result
end

function M.default_template()
	return "Regarding the following text, {{prompt}}:\n\nFiletype: {{filetype}}\nFilepath: {{filepath}}\n\nContent:\n{{content}}"
end

function M.preview(bufnr, user_prompt, template)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	local function show(input)
		local prepared = M.build(bufnr, input or '', template)
		vim.notify('--- SVEN PREPARED PROMPT ---\n' .. prepared .. '\n--- END ---', vim.log.levels.INFO)
	end

	if user_prompt ~= nil then
		show(user_prompt)
	else
		vim.ui.input({ prompt = 'Ask sven: ' }, show)
	end
end

return M
