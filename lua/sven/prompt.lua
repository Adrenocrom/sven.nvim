local M = {}

local function get_buffer_content(bufnr, range_type)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return '[invalid buffer ' .. tostring(bufnr) .. ']'
	end

    if range_type == "v" then
        local start_pos = vim.fn.getpos("'<")
        local end_pos   = vim.fn.getpos("'>")
        return M.extract_visual_selection(bufnr, start_pos[2], end_pos[2])
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

-- Helper: extract text between two line numbers (inclusive on both ends). 
function M.extract_visual_selection(bufnr, start_lnum, end_lnum)
    -- getpos returns 1-indexed lnums. Convert to 0-indexed for nvim_buf_get_lines which is exclusive at the end.
	print(start_lnum)
	print(end_lnum)
    local s = math.max(0, start_lnum - 1)
    local e = end_lnum                      -- inclusive on both sides; pass +1 because get_lines excludes last line
	print(s)
	print(e)

	local ok, lines = pcall(vim.api.nvim_buf_get_text, bufnr, s, 0, math.min(e - 1, vim.fn.line('$')), -1)
	if not ok or type(lines) ~= 'table' then
        -- Fallback to get_lines if text fails (e.g., for byte offsets issues):
		lines = pcall(vim.api.nvim_buf_get_lines, bufnr, s, e + 1, false)  
	end

    if not (s < e and #lines > 0) then
		return ""
	end

    return table.concat(lines, '\n') .. "\n"  -- Add trailing newline so it looks like a file. 
end

function M.build(bufnr, user_prompt, template, range_type)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	user_prompt = user_prompt or ''
	template = template or M.default_template()
    range_type = range_type or "n"  -- Default to whole file if not specified.

	local filetype = vim.bo[bufnr].filetype or 'unknown'
	local filepath = vim.api.nvim_buf_get_name(bufnr)
	if filepath == '' then
		filepath = '[unnamed]'
	end


    local content = get_buffer_content(bufnr, range_type)  -- Pass the flag!

	local result = template
	result = replace_all(result, '{{filetype}}', filetype)
	result = replace_all(result, '{{filepath}}', filepath)
	result = replace_all(result, '{{content}}', content)
	result = replace_all(result, '{{prompt}}', user_prompt)

	return result
end

function M.default_template()
	return "Regarding the following file, {{prompt}}:\n```{{filetype}}\n{{content}}\n```"
end

-- ... (preview stays mostly unchanged but pass range_type if needed): 
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
