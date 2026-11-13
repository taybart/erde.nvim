local M = {}

---@class midnight.Config
M.config = {
  -- the midnight cli (`go install github.com/taybart/midnight/cmd/midnight@latest`)
  cmd = 'midnight',
  -- function markup elements call, passed as `-markup-factory` to lint and
  -- compile (nil: midnight's default, `h`)
  markup_factory = nil,
  -- extra globals for `midnight lint -g` (ex. ones set by the host: rest, kv, json, ...)
  -- buffers can add more w/ `vim.b.midnight_globals`
  globals = {},
  -- register the tree-sitter parser w/ nvim-treesitter (main branch)
  -- set `path` to use a local checkout of the grammar instead of `url`
  treesitter = {
    url = 'https://github.com/taybart/tree-sitter-midnight',
    path = nil,
  },
  -- register the `midnight_fmt` formatter w/ conform.nvim (if it's installed)
  conform = true,
  -- register the `midnight` linter w/ nvim-lint (if it's installed)
  lint = true,
  -- the .mn / .midnight file icon, registered w/ nvim-web-devicons (if it's
  -- installed), where snacks, lualine, oil, ... get file icons from
  -- (false: don't register one)
  icon = { glyph = '󰖔', color = '#5b8fd9', cterm_color = '68' },
  -- `gc` comments markup children w/ `{--[[ ]]}` (see lua/midnight/comment.lua)
  comments = true,
  -- rest (https://github.com/taybart/rest): lint `<<MIDNIGHT` heredocs in .rest
  -- files, and know rest's globals in .mn files of projects w/ a .rest file
  rest = true,
}

---@param opts? midnight.Config
function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})
  M.register_parser()
  if M.config.conform then
    local ok, conform = pcall(require, 'conform')
    if ok then
      conform.formatters.midnight_fmt = M.formatter()
      conform.formatters_by_ft.midnight = conform.formatters_by_ft.midnight or { 'midnight_fmt' }
    end
  end
  if M.config.lint then
    local ok, lint = pcall(require, 'lint')
    if ok then
      lint.linters.midnight = M.linter()
      lint.linters_by_ft.midnight = lint.linters_by_ft.midnight or { 'midnight' }
    end
  end
  M.register_icon()
  if M.config.comments then require('midnight.comment').setup() end
  if M.config.rest then require('midnight.rest').setup() end
end

--- globals for `midnight lint`: the configured ones, rest's (in rest projects),
--- and the buffer's (vim.b.midnight_globals)
---@param buf? integer
---@return string[]
function M.globals(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local globals = vim.deepcopy(M.config.globals)
  if M.config.rest and require('midnight.rest').in_project(buf) then
    vim.list_extend(globals, require('midnight.rest').globals)
  end
  return vim.list_extend(globals, vim.b[buf].midnight_globals or {})
end

--- `-markup-factory name` (or nothing w/o a configured factory)
---@return string[]
function M.factory_args()
  if not M.config.markup_factory then return {} end
  return { '-markup-factory', M.config.markup_factory }
end

--- registers the midnight file icon (config.icon) w/ nvim-web-devicons, for
--- .mn and .midnight files and the midnight filetype
function M.register_icon()
  local icon = M.config.icon
  if not icon then return end
  local ok, devicons = pcall(require, 'nvim-web-devicons')
  if not ok then return end
  local data = {
    icon = icon.glyph,
    color = icon.color,
    cterm_color = icon.cterm_color,
    name = 'Midnight', -- (its highlight group is DevIconMidnight)
  }
  devicons.set_icon({ mn = data, midnight = data })
  devicons.set_icon_by_filetype({ midnight = 'mn' })
end

--- nvim-treesitter (main) parser info for midnight
function M.parser_info()
  local ts = M.config.treesitter
  local info = { queries = 'queries' }
  if ts.path then
    info.path = ts.path
    -- local checkouts may not have a generated parser.c committed
    info.generate = true
    info.generate_from_json = false
  else
    info.url = ts.url
  end
  return { install_info = info }
end

--- registers midnight w/ nvim-treesitter, now and whenever its parser list reloads
--- (`:TSInstall midnight` installs it)
function M.register_parser()
  if not M.config.treesitter then return end
  local ok, parsers = pcall(require, 'nvim-treesitter.parsers')
  if ok and type(parsers) == 'table' then parsers.midnight = M.parser_info() end
  if M._ts_autocmd then return end
  M._ts_autocmd = vim.api.nvim_create_autocmd('User', {
    pattern = 'TSUpdate',
    group = vim.api.nvim_create_augroup('midnight.treesitter', { clear = true }),
    callback = function()
      if M.config.treesitter then require('nvim-treesitter.parsers').midnight = M.parser_info() end
    end,
  })
end

--- conform.nvim formatter
function M.formatter()
  return {
    command = M.config.cmd,
    args = { 'fmt', '-' },
    stdin = true,
  }
end

--- `<stdin>:12: message (rule)` -> diagnostics
---@param output string
---@return vim.Diagnostic[]
function M.parse_lint(output)
  local diagnostics = {}
  for line in vim.gsplit(output, '\n', { trimempty = true }) do
    local lnum, message, rule = line:match('^[^:]+:(%d+): (.+) %(([%w-]+)%)$')
    if lnum then
      diagnostics[#diagnostics + 1] = {
        lnum = tonumber(lnum) - 1,
        col = 0,
        message = message,
        code = rule,
        source = 'midnight lint',
        severity = rule == 'syntax' and vim.diagnostic.severity.ERROR
          or vim.diagnostic.severity.WARN,
      }
    end
  end
  return diagnostics
end

--- nvim-lint linter (a function, so the args are built for each run)
function M.linter()
  return function()
    local args = vim.list_extend({ 'lint' }, M.factory_args())
    local globals = M.globals()
    if #globals > 0 then vim.list_extend(args, { '-g', table.concat(globals, ',') }) end
    args[#args + 1] = '-'
    return {
      cmd = M.config.cmd,
      args = args,
      stdin = true,
      ignore_exitcode = true, -- exits 1 when there are problems
      parser = function(output) return M.parse_lint(output) end,
    }
  end
end

--- `midnight -c` the buffer, ie. the lua it compiles to
---@param buf integer
---@return string[]? lines, string? err
function M.compile(buf)
  local src = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
  local cmd = vim.list_extend({ M.config.cmd }, M.factory_args())
  vim.list_extend(cmd, { '-c', '-' })
  local res = vim.system(cmd, { stdin = src, text = true }):wait()
  if res.code ~= 0 then return nil, vim.trim((res.stderr or '') .. (res.stdout or '')) end
  return vim.split(res.stdout, '\n', { trimempty = false })
end

--- shows the compiled lua in a split, kept up to date as the buffer changes
function M.preview(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local preview = vim.b[buf].midnight_preview
  if preview and vim.api.nvim_buf_is_valid(preview) then
    local win = vim.fn.bufwinid(preview)
    if win ~= -1 then return vim.api.nvim_set_current_win(win) end
    vim.cmd.vsplit()
    return vim.api.nvim_win_set_buf(0, preview)
  end

  preview = vim.api.nvim_create_buf(false, true)
  vim.bo[preview].bufhidden = 'wipe'
  vim.bo[preview].filetype = 'lua'
  vim.api.nvim_buf_set_name(preview, 'midnight://' .. vim.api.nvim_buf_get_name(buf) .. '.lua')
  vim.b[buf].midnight_preview = preview

  local function update()
    local lines, err = M.compile(buf)
    if not lines then
      -- keep the last good output, show the error up top
      lines = vim.list_extend(
        vim.tbl_map(function(l) return '-- ' .. l end, vim.split(err, '\n')),
        vim.list_slice(vim.api.nvim_buf_get_lines(preview, 0, -1, false), 1)
      )
    end
    vim.bo[preview].modifiable = true
    vim.api.nvim_buf_set_lines(preview, 0, -1, false, lines)
    vim.bo[preview].modifiable = false
  end

  local group = vim.api.nvim_create_augroup('midnight.preview.' .. buf, { clear = true })
  vim.api.nvim_create_autocmd({ 'TextChanged', 'InsertLeave', 'BufWritePost' }, {
    group = group,
    buffer = buf,
    callback = function()
      if vim.api.nvim_buf_is_valid(preview) then update() end
    end,
  })
  vim.api.nvim_create_autocmd('BufWipeout', {
    group = group,
    buffer = preview,
    callback = function()
      pcall(vim.api.nvim_del_augroup_by_id, group)
      if vim.api.nvim_buf_is_valid(buf) then vim.b[buf].midnight_preview = nil end
    end,
  })

  local src_win = vim.api.nvim_get_current_win()
  vim.cmd.vsplit()
  vim.api.nvim_win_set_buf(0, preview)
  update()
  vim.api.nvim_set_current_win(src_win)
end

--- `gf` on require('src/layout') or require('src.layout')
---@param fname string
function M.includeexpr(fname)
  if fname:find('/', 1, true) then return fname end
  return (fname:gsub('%.', '/'))
end

return M
