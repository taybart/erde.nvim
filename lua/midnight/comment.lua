-- markup aware 'commentstring' for `gc`: markup children are commented w/
-- `{--[[ ]]}`, everything else (code, attributes, code inside `{ ... }`) w/
-- `--`. Works in .mn buffers and midnight injected in others (ex. rest's
-- `<<MIDNIGHT` heredocs).
local M = {}

M.code = '-- %s'
M.markup = '{--[[ %s ]]}'

-- parts of an element (or attribute): look at what they belong to
local parts = {
  markup_opening_element = true,
  markup_closing_element = true,
  markup_tag_name = true,
  markup_attribute_name = true,
}

-- what can be commented out between elements
local children = {
  markup_element = true,
  markup_self_closing_element = true,
  markup_text = true,
  markup_expression = true,
}

--- the commentstring for the current line (from its first non-blank)
---@return string
function M.get()
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1] or ''
  local col = (line:match('^%s*()') or 1) - 1
  local ok, node = pcall(vim.treesitter.get_node, { pos = { row, col }, ignore_injections = false })
  if not ok then return M.code end
  while node and parts[node:type()] do
    node = node:parent()
  end
  if node and children[node:type()] then
    local parent = node:parent()
    if parent and parent:type() == 'markup_element' then return M.markup end
  end
  return M.code
end

--- answers vim.filetype.get_option(<midnight>, 'commentstring') (which `gc` uses
--- for tree-sitter languages, incl. injected ones) w/ M.get()
function M.setup()
  if M._get_option then return end
  M._get_option = vim.filetype.get_option
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.filetype.get_option = function(filetype, option)
    if option == 'commentstring' then
      if filetype == 'midnight' then return M.get() end
      -- `gc` only sees the injected midnight from where a heredoc's code starts,
      -- so w/ the cursor in the indentation it'd use hcl's `#`
      if (filetype == 'rest' or filetype == 'hcl') and vim.bo.filetype == 'rest' then
        local row = vim.api.nvim_win_get_cursor(0)[1] - 1
        if require('midnight.rest').in_heredoc(0, row) then return M.get() end
      end
    end
    return M._get_option(filetype, option)
  end
  -- ts-comments.nvim wraps get_option too, and calls the one from when it
  -- loaded: if that was before us, point it at ours
  local ts_comments = package.loaded['ts-comments.config']
  if ts_comments and ts_comments._get_option == M._get_option then
    ts_comments._get_option = vim.filetype.get_option
  end
end

return M
