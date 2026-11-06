if vim.b.did_ftplugin then return end
vim.b.did_ftplugin = true

vim.bo.commentstring = '-- %s'
vim.bo.comments = ':---,:--'

-- `gf` on require('src/layout')
vim.bo.suffixesadd = '.erde,.lua'
vim.bo.include = [=[\v<require\s*\(?\s*['"]\zs[^'"]+\ze['"]]=]
vim.bo.includeexpr = "v:lua.require'erde'.includeexpr(v:fname)"

-- highlighting, if the parser is installed
pcall(vim.treesitter.start)

vim.b.undo_ftplugin = 'setl commentstring< comments< suffixesadd< include< includeexpr<'
  .. ' | lua pcall(vim.treesitter.stop)'
