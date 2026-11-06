if vim.g.loaded_erde then return end
vim.g.loaded_erde = true

vim.filetype.add({ extension = { erde = 'erde' } })

-- so `:TSInstall erde` works w/o calling setup()
require('erde').register_parser()

vim.api.nvim_create_user_command(
  'ErdeCompile',
  function() require('erde').preview() end,
  { desc = 'show the lua the current erde buffer compiles to' }
)
