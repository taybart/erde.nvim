if vim.g.loaded_midnight then return end
vim.g.loaded_midnight = true

vim.filetype.add({ extension = { mn = 'midnight', midnight = 'midnight' } })

-- so `:TSInstall midnight` works w/o calling setup()
require('midnight').register_parser()

vim.api.nvim_create_user_command(
  'MidnightCompile',
  function() require('midnight').preview() end,
  { desc = 'show the lua the current midnight buffer compiles to' }
)
