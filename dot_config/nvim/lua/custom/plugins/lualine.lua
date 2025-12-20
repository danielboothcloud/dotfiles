return {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
        require('lualine').setup({
            options = {
                theme = 'oxocarbon',
                icons_enabled = vim.g.have_nerd_font,
                component_separators = '|',
                section_separators = '',
                globalstatus = true,
            },
        })
    end,
}
