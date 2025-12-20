-- Custom keymaps setup
local map = vim.keymap.set

map('n', '$', '$l', { noremap = true })
-- Delete operations that don't copy to clipboard
map('n', 'x', '"_x', { noremap = true })
-- Map the operators themselves to use black hole register
map('n', 'd', '"_d', { noremap = true })
map('n', 'D', '"_D', { noremap = true })
map('n', 'c', '"_c', { noremap = true })
map('n', 'C', '"_C', { noremap = true })
map('v', 'd', '"_d', { noremap = true })
map('v', 'c', '"_c', { noremap = true })
local opts = { noremap = true, silent = true }

-- Render markdown
vim.keymap.set('n', '<leader>mr', ':RenderMarkdown toggle<CR>', { desc = 'Toggle Render Markdown' })

-- Buffer navigation with Space+[ and Space+] and Tab
vim.keymap.set('n', '<leader>[', '<cmd>bp<CR>', { desc = 'Previous buffer' })
vim.keymap.set('n', '<leader>]', '<cmd>bn<CR>', { desc = 'Next buffer' })
vim.keymap.set('n', '<S-Tab>', '<cmd>bp<CR>', { desc = 'Previous buffer' })
vim.keymap.set('n', '<Tab>', '<cmd>bn<CR>', { desc = 'Next buffer' })
