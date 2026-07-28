local M = {}

-- Read the entire content of a buffer.
-- Returns a diagnostic string if the buffer is invalid or unreadable.
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

-- Escape line breaks so the prepared prompt stays on a single line when sent
-- to a terminal process. This avoids the terminal interpreting newlines as
-- multiple separate inputs.
local function escape_line_endings(s)
  return s:gsub('\n', '\\n'):gsub('\r', '\\r')
end

-- Escape percent signs so string.gsub treats the replacement as plain text.
local function escape_repl(s)
  return s:gsub('%%', '%%%%')
end

-- Plain-text replacement: replace all occurrences of `pattern` in `str` with `repl`.
local function replace_all(str, pattern, repl)
  return str:gsub(pattern, escape_repl(repl))
end

-- Build a prepared prompt for sven.
-- The returned string is plain text; no shell escaping is done here.
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

  -- Sanitize the final prompt so line breaks are escaped before sending it
  -- to a terminal process. This keeps the whole prompt as one input.
  return escape_line_endings(result)
end

function M.default_template()
  return "Filetype: {{filetype}}\nFilepath: {{filepath}}\n\nContent:\n{{content}}\n\nRequest:\n{{prompt}}"
end

-- Print the prepared prompt for the current buffer to :messages.
-- If user_prompt is nil, asks for input interactively.
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
