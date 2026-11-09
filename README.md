# midnight.nvim

Neovim support for [Midnight](https://github.com/taybart/midnight) (including
`match`, `if` / `match` expressions, and markup):

- `midnight` filetype and `gf` on `require('src/layout')`
- `gc` comments markup children w/ `{--[[ ]]}` and code w/ `--` (in .rest
  files' `<<MIDNIGHT` heredocs too)
- tree-sitter highlighting w/
  [tree-sitter-midnight](https://github.com/taybart/tree-sitter-midnight) (css/js
  injected in `<style>` / `<script>`)
- formatting w/ `midnight fmt` ([conform.nvim](https://github.com/stevearc/conform.nvim))
- diagnostics w/ `midnight lint` ([nvim-lint](https://github.com/mfussenegger/nvim-lint)),
  ex. `and-or`: `a && b || c` where `b` can be nil (use `if a { b } else { c }`)
- [rest](https://github.com/taybart/rest): lints `<<MIDNIGHT` heredocs in .rest
  files, and knows rest's globals in projects w/ a .rest file
- `:MidnightCompile` shows the lua a buffer compiles to, updated as you edit

Needs nvim 0.11+ and the `midnight` cli:

```sh
go install github.com/taybart/midnight/cmd/midnight@latest
```

## Install

[lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'taybart/midnight.nvim',
  lazy = false, -- (it's small) for midnight in .rest files
  opts = {},
}
```

Then `:TSInstall midnight` (nvim-treesitter's `main` branch). The parser is
registered when the plugin loads, so to install it w/ the rest of your parsers
make midnight.nvim a dependency of nvim-treesitter:

```lua
{
  'nvim-treesitter/nvim-treesitter',
  branch = 'main',
  dependencies = { 'taybart/midnight.nvim' },
  config = function() require('nvim-treesitter').install({ 'midnight', ... }) end,
}
```

## Options

```lua
require('midnight').setup({
  cmd = 'midnight',
  -- function markup elements call, passed as `-markup-factory` to lint and
  -- compile (nil: midnight's default, `h`)
  markup_factory = nil,
  -- extra globals for `midnight lint` (or per buffer: vim.b.midnight_globals)
  globals = {},
  treesitter = {
    url = 'https://github.com/taybart/tree-sitter-midnight',
    path = nil, -- a local checkout of the grammar, instead of url
  },
  -- register the formatter / linter if conform / nvim-lint are installed
  conform = true,
  lint = true,
  -- markup aware commentstrings for `gc`
  comments = true,
  -- lint .rest heredocs, rest's globals in rest projects
  rest = true,
})
```

`setup()` adds `midnight_fmt` to conform and `midnight` to nvim-lint (and sets them
for the midnight filetype unless you already have). nvim-lint still needs to be
told when to lint, ex.:

```lua
vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost', 'InsertLeave' }, {
  callback = function() require('lint').try_lint() end,
})
```

To set them up yourself instead (w/ `conform = false, lint = false`):

```lua
require('conform').formatters.midnight_fmt = require('midnight').formatter()
require('lint').linters.midnight = require('midnight').linter()
```

### rest

`.rest` files' `<<MIDNIGHT` heredocs are linted (w/ rest's globals) on read, write,
and leaving insert mode, and `.mn` files in a directory w/ a `.rest` file (or
under one) get rest's globals too (`rest`, `kv`, `json`, ...). Load the plugin
on startup (not `ft = 'midnight'`) so it's there for .rest files.
