local M = {}

M.default_filetype = 'markdown'

-- State of the single live sven session:
--   { buf, win, job_id, append, flush, send }
-- Kept across :Sven invocations so an already-open session is reused
-- instead of spawning a new buffer/window/job every time.
M.state = nil

local function safe_close_win(win)
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_close(win, true)
	end
end

local function safe_close_buf(buf)
	if buf and vim.api.nvim_buf_is_valid(buf) then
		vim.api.nvim_buf_delete(buf, { force = true })
	end
end

local function strip_ansi(s)
	return s:gsub('\27%[[%d;]*%a', ''):gsub('\r', '')
end

local function strip_end_marker(s)
	return s:gsub('###END_OF_INPUT###', '')
end

local function create_appender(buf)
	local pending = ''

	local function append(text)
		if not vim.api.nvim_buf_is_valid(buf) then
			return
		end

		text = strip_end_marker(strip_ansi(pending .. text))
		local lines = vim.split(text, '\n', { plain = true })
		pending = table.remove(lines) or ''

		if #lines == 0 then
			return
		end

		vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)

		local line_count = vim.api.nvim_buf_line_count(buf)
		for _, win in ipairs(vim.fn.win_findbuf(buf)) do
			if vim.api.nvim_win_is_valid(win) then
				vim.api.nvim_win_set_cursor(win, { math.max(1, line_count), 0 })
			end
		end
	end

	local function flush()
		if pending == '' then
			return
		end
		local text = pending
		pending = ''
		append(text .. '\n')
	end

	return append, flush
end

local function format_display(text)
	local kept = {}
	for line in text:gmatch('[^\r\n]+') do
		table.insert(kept, line)
		if #kept == 5 then
			break
		end
	end

	local display_text = table.concat(kept, '\n')
	if #kept == 5 and #text > #display_text then
		display_text = display_text .. '\n…'
	end

	return '\n## Prompt:\n\n> ' ..
		display_text:gsub('\n', '\n> ') ..
		'\n\n---\n'
end

local function header_lines()
	return {
		'# Sven',
		'',
		'_Press `<CR>` to send a message, `q` to close._',
		'',
	}
end

local function job_running(state)
	return state ~= nil and state.job_id ~= nil and state.job_id > 0
end

local function start_job(state, cmd)
	state.job_id = vim.fn.jobstart(cmd .. ' --end-of-prompt="###END_OF_INPUT###"', {
		stdin = 'pipe',
		stdout_buffered = false,
		stderr_buffered = false,
		on_stdout = function(_, data, _)
			if not data then
				return
			end
			for i = 1, #data - 1 do
				state.append(data[i] .. '\n')
			end
			local last = data[#data]
			if last and last ~= '' then
				state.append(last)
			end
		end,
		on_stderr = function(_, _, _)
		end,
		on_exit = function(_, exit_code, _)
			state.flush()
			state.append('\n_--- sven exited (' .. tostring(exit_code) .. ') ---_')
			state.job_id = nil
		end,
	})
end

local function make_send(state)
	return function(text)
		if not text or text == '' then
			return
		end
		state.append(format_display(text))
		if job_running(state) then
			pcall(vim.fn.chansend, state.job_id, text .. '\n###END_OF_INPUT###\n')
		end
	end
end

-- Focus the session's window, or open a new one for its buffer if needed.
local function ensure_window(state, make_win)
	if state.win and vim.api.nvim_win_is_valid(state.win) then
		if vim.api.nvim_win_get_buf(state.win) ~= state.buf then
			vim.api.nvim_win_set_buf(state.win, state.buf)
		end
		vim.api.nvim_set_current_win(state.win)
	else
		state.win = make_win(state.buf)
	end
end

local function close_session(state)
	if job_running(state) then
		pcall(vim.fn.jobstop, state.job_id)
		state.job_id = nil
	end
	safe_close_win(state.win)
	safe_close_buf(state.buf) -- triggers BufWipeout, which clears M.state
end

local function open_markdown_chat(cmd, prepared_prompt, make_win, config)
	local state = M.state

	-- Reuse the existing session if its buffer is still alive.
	if state and vim.api.nvim_buf_is_valid(state.buf) then
		ensure_window(state, make_win)

		if not job_running(state) then
			-- Previous session exited: restart in the same buffer.
			vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, header_lines())
			start_job(state, cmd)
			if not job_running(state) then
				state.append('_Failed to start sven._')
			end
		end

		if prepared_prompt and prepared_prompt ~= '' then
			vim.defer_fn(function()
				state.send(prepared_prompt)
			end, 100)
		end
		return state.job_id
	end

	-- No live session: create buffer, window and job from scratch.
	local filetype = (config and config.terminal_filetype) or M.default_filetype
	local buf = vim.api.nvim_create_buf(false, true)

	vim.bo[buf].buftype = 'nofile'
	vim.bo[buf].bufhidden = 'wipe'
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = filetype
	vim.bo[buf].syntax = filetype

	state = { buf = buf, win = nil, job_id = nil }
	M.state = state

	local append, flush = create_appender(buf)
	state.append = append
	state.flush = flush
	state.send = make_send(state)

	state.win = make_win(buf)

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, header_lines())

	start_job(state, cmd)
	if not job_running(state) then
		state.append('_Failed to start sven._')
	end

	if prepared_prompt and prepared_prompt ~= '' then
		vim.defer_fn(function()
			state.send(prepared_prompt)
		end, 100)
	end

	vim.keymap.set('n', '<CR>', function()
		vim.ui.input({ prompt = 'sven> ' }, function(text)
			state.send(text)
		end)
	end, { buffer = buf, noremap = true, silent = true })

	vim.keymap.set('n', 'q', function()
		close_session(state)
	end, { buffer = buf, noremap = true, silent = true })

	vim.api.nvim_create_autocmd('BufWipeout', {
		buffer = buf,
		once = true,
		callback = function()
			if job_running(state) then
				pcall(vim.fn.jobstop, state.job_id)
				state.job_id = nil
			end
			safe_close_win(state.win)
			if M.state == state then
				M.state = nil
			end
		end,
	})

	return state.job_id
end

function M.open_vsplit(prepared_prompt, config)
	return open_markdown_chat('sven-rs', prepared_prompt, function(buf)
		vim.cmd('vsplit')
		local win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(win, buf)
		return win
	end, config)
end

function M.open_float(opts, prepared_prompt, config)
	opts = opts or {}
	local width = math.floor(vim.o.columns * (opts.width or 0.8))
	local height = math.floor(vim.o.lines * (opts.height or 0.8))
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	return open_markdown_chat('sven-rs', prepared_prompt, function(buf)
		local win = vim.api.nvim_open_win(buf, true, {
			relative = 'editor',
			width = width,
			height = height,
			row = row,
			col = col,
			style = 'minimal',
			border = opts.border or 'rounded',
		})

		return win
	end, config)
end

return M