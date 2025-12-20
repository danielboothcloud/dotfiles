return {
  'windwp/nvim-autopairs',
  event = 'InsertEnter',
  opts = {
    check_ts = true, -- Enable treesitter integration
    ts_config = {
      lua = { 'string' }, -- Don't add pairs in lua string treesitter nodes
      javascript = { 'template_string' },
    },
    disable_filetype = { 'TelescopePrompt', 'vim' },
  },
}
