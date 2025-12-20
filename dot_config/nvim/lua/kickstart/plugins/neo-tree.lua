return {
 'nvim-neo-tree/neo-tree.nvim',
 version = '*',
 dependencies = {
   'nvim-lua/plenary.nvim',
   'nvim-tree/nvim-web-devicons',
   'MunifTanjim/nui.nvim',
 },
 lazy = false,  
 keys = {
   { '<space>e', ':Neotree toggle<CR>', desc = 'Toggle NeoTree', silent = true },
 },
 opts = {
   filesystem = {
     filtered_items = {
       visible = true, -- Show hidden files
     },
     window = {
       mappings = {
         ['<space>e'] = 'close_window',
         ['j'] = 'none',
         ['k'] = 'none', 
         ['l'] = 'none',
         [';'] = 'none',
       },
     },
   },
 },
}