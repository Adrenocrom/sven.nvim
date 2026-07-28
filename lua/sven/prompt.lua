local M = {}

-- Read the entire content of a buffer
local function get_buffer_content(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  return table.concat(lines, '\n')
end

-- Build a prepared prompt for sven
function M.build(bufnr, user_prompt, template)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  user_prompt = user_prompt or ''
  template = template or M.default_template()

  local filetype = vim.bo[bufnr].filetype or 'unknown'
  local content = get_buffer_content(bufnr)

  -- Escape single quotes in content so the shell command stays valid
  local safe_content = content:gsub("'", "'\\''")
  local safe_prompt = user_prompt:gsub("'", "'\\''")

  return template
    :gsub('{{filetype}}', filetype)
    :gsub('{{content}}', safe_content)
    :gsub('{{prompt}}', safe_prompt)
end

function M.default_template()
  return "Filetype: {{filetype}}\n\nContent:\n{{content}}\n\nRequest:\n{{prompt}}"
end

return M
