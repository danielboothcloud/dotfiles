return {
  'windwp/nvim-autopairs',
  event = 'InsertEnter',
  config = function()
    local npairs = require('nvim-autopairs')
    npairs.setup({
      check_ts = true, -- Enable treesitter integration
      ts_config = {
        lua = { 'string' }, -- Don't add pairs in lua string treesitter nodes
        javascript = { 'template_string' },
      },
      disable_filetype = { 'TelescopePrompt', 'vim' },
    })

    -- Remove quote autopairs
    local Rule = require('nvim-autopairs.rule')
    npairs.remove_rule("'")
    npairs.remove_rule('"')
  end,
}
