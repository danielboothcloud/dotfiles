return {
  'nvim-telescope/telescope.nvim',
  tag = '0.1.8',
  dependencies = {
    'nvim-lua/plenary.nvim',
    { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
  },

  config = function()
    require('telescope').setup {
      defaults = {
        prompt_prefix = ' 🔍 ',
        selection_caret = ' ❯ ',
        path_display = { 'truncate' },
        sorting_strategy = 'ascending',
        layout_config = {
          horizontal = {
            prompt_position = 'top',
            preview_width = 0.55,
          },
          vertical = {
            mirror = false,
          },
          width = 0.87,
          height = 0.80,
          preview_cutoff = 120,
        },
        file_ignore_patterns = { '.git/' },
      },
      pickers = {
        find_files = {
          hidden = true,
        },
      },
    }

    -- Enable telescope fzf native, if installed
    pcall(require('telescope').load_extension, 'fzf')

    -- Telescope keymaps
    local builtin = require 'telescope.builtin'
    local map = vim.keymap.set

    map('n', '<Space><Space>', builtin.find_files, { desc = 'Find Files' })
    map('n', '<leader>rg', builtin.live_grep, { desc = 'Live Grep' })
    map('n', '<leader>fb', builtin.buffers, { desc = 'Buffers' })
    map('n', '<leader>fh', builtin.help_tags, { desc = 'Help Tags' })
  end,
}
