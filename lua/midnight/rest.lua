-- midnight in rest (https://github.com/taybart/rest): lints `<<MN` / `<<MIDNIGHT` heredocs in
-- .rest files, and knows the globals rest gives scripts (and pages)
local M = {}

-- the globals rest sets for scripts (setup, fn, after, cli, ...)
M.globals = {
  'rest', 'kv', 'json', 'jwt', 'form', 'inspect', 'colors', 'base64', 'url', 'html',
  'uuid', 'ulid', 'nanoid', 'tools', 'copy', 'fail', 'cli', 'input', 'expired_token',
}

M.ns = vim.api.nvim_create_namespace('midnight.rest')
M.runs = {} ---@type table<integer, integer>

--- the midnight heredocs in a rest buffer: { first = 0-based row of the first
--- line of code, lines = { ... } }
---@param buf integer
function M.heredocs(buf)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, 'hcl')
  if not ok or not parser then return {} end
  local tree = parser:parse()[1]
  local query = vim.treesitter.query.parse(
    'hcl',
    '(heredoc_template (heredoc_identifier) @id) @doc'
  )
  local docs, seen = {}, {}
  for _, match in query:iter_matches(tree:root(), buf, 0, -1, { all = true }) do
    local doc, id
    for capture, nodes in pairs(match) do
      local name = query.captures[capture]
      if name == 'doc' then doc = nodes[1] end
      if name == 'id' then id = nodes[#nodes] end
    end
    -- (matches each identifier: `<<MN` / `<<-MIDNIGHT`, etc. and the closing one)
    if doc and id and not seen[doc:id()] and vim.list_contains({ 'MN', 'MIDNIGHT' }, vim.treesitter.get_node_text(id, buf):upper()) then
      seen[doc:id()] = true
      local start_row, _, end_row = doc:range()
      docs[#docs + 1] = {
        first = start_row + 1,
        lines = vim.api.nvim_buf_get_lines(buf, start_row + 1, end_row, false),
      }
    end
  end
  return docs
end

--- is (0-based) row code in a midnight heredoc?
---@param buf integer
---@param row integer
function M.in_heredoc(buf, row)
  for _, doc in ipairs(M.heredocs(buf)) do
    if row >= doc.first and row < doc.first + #doc.lines then return true end
  end
  return false
end

--- runs `midnight lint` on each midnight heredoc in a rest buffer
---@param buf? integer
function M.lint(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local midnight = require('midnight')
  local args = vim.list_extend({ midnight.config.cmd, 'lint' }, midnight.ext_args())
  local globals = vim.list_extend(vim.deepcopy(M.globals), midnight.config.globals)
  vim.list_extend(args, { '-g', table.concat(globals, ','), '-' })

  local docs = M.heredocs(buf)
  -- only the latest run's results are used
  M.runs[buf] = (M.runs[buf] or 0) + 1
  local run = M.runs[buf]
  local diagnostics, pending = {}, #docs
  if pending == 0 then return vim.diagnostic.reset(M.ns, buf) end

  for _, doc in ipairs(docs) do
    vim.system(args, { stdin = table.concat(doc.lines, '\n'), text = true }, vim.schedule_wrap(function(res)
      for _, d in ipairs(midnight.parse_lint(res.stdout or '')) do
        d.lnum = d.lnum + doc.first
        diagnostics[#diagnostics + 1] = d
      end
      pending = pending - 1
      if pending == 0 and M.runs[buf] == run and vim.api.nvim_buf_is_valid(buf) then
        vim.diagnostic.set(M.ns, buf, diagnostics)
      end
    end))
  end
end

--- lints rest buffers' heredocs on read, write, and leaving insert mode
function M.setup()
  local group = vim.api.nvim_create_augroup('midnight.rest', { clear = true })
  vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost', 'InsertLeave' }, {
    group = group,
    pattern = '*.rest',
    callback = function(ev) M.lint(ev.buf) end,
  })
end

--- is buf part of a rest project (there's a .rest file in it, or a parent dir)?
---@param buf integer
function M.in_project(buf)
  return vim.fs.root(buf, function(name) return name:match('%.rest$') ~= nil end) ~= nil
end

return M
