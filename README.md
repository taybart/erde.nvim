# erde.nvim

Neovim support for [erde](https://erde-lang.github.io) w/
[go-erde](https://github.com/taybart/go-erde)'s extensions (`match`, markup):

- `erde` filetype and `gf` on `require('src/layout')`
- `gc` comments markup children w/ `{--[[ ]]}` and code w/ `--` (in .rest
  files' `<<ERDE` heredocs too)
- tree-sitter highlighting w/
  [tree-sitter-erde](https://github.com/taybart/tree-sitter-erde) (css/js
  injected in `<style>` / `<script>`)
- formatting w/ `erde fmt` ([conform.nvim](https://github.com/stevearc/conform.nvim))
- diagnostics w/ `erde lint` ([nvim-lint](https://github.com/mfussenegger/nvim-lint))
- [rest](https://github.com/taybart/rest): lints `<<ERDE` heredocs in .rest
  files, and knows rest's globals in projects w/ a .rest file
- `:ErdeCompile` shows the lua a buffer compiles to, updated as you edit

Needs nvim 0.11+ and the `erde` cli:

```sh
go install github.com/taybart/go-erde/cmd/erde@latest
```

## Install

[lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'taybart/erde.nvim',
  lazy = false, -- (it's small) for erde in .rest files
  opts = {},
}
```

Then `:TSInstall erde` (nvim-treesitter's `main` branch). The parser is
registered when the plugin loads, so to install it w/ the rest of your parsers
make erde.nvim a dependency of nvim-treesitter:

```lua
{
  'nvim-treesitter/nvim-treesitter',
  branch = 'main',
  dependencies = { 'taybart/erde.nvim' },
  config = function() require('nvim-treesitter').install({ 'erde', ... }) end,
}
```

## Options

```lua
require('erde').setup({
  cmd = 'erde',
  -- passed as `-X` to fmt, lint, and compile
  extensions = { 'match', 'markup' },
  -- extra globals for `erde lint` (or per buffer: vim.b.erde_globals)
  globals = {},
  treesitter = {
    url = 'https://github.com/taybart/tree-sitter-erde',
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

`setup()` adds `erde_fmt` to conform and `erde` to nvim-lint (and sets them
for the erde filetype unless you already have). nvim-lint still needs to be
told when to lint, ex.:

```lua
vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost', 'InsertLeave' }, {
  callback = function() require('lint').try_lint() end,
})
```

To set them up yourself instead (w/ `conform = false, lint = false`):

```lua
require('conform').formatters.erde_fmt = require('erde').formatter()
require('lint').linters.erde = require('erde').linter()
```

### rest

`.rest` files' `<<ERDE` heredocs are linted (w/ rest's globals) on read, write,
and leaving insert mode, and `.erde` files in a directory w/ a `.rest` file (or
under one) get rest's globals too (`rest`, `kv`, `json`, ...). Load the plugin
on startup (not `ft = 'erde'`) so it's there for .rest files.
