-- lua implementation better, github runs like crap
-- return {
--   "github/copilot.vim",
--   config = function()
--     vim.g.copilot_no_tab_map = true
--     vim.keymap.set('i', '<C-Space>', 'copilot#Accept("\\<CR>")', {
--       expr = true,
--       replace_keycodes = false
--     })
--   end
-- }

return {
  "zbirenbaum/copilot-cmp",
  config = function()
    require("copilot_cmp").setup()

    -- -- copilot
    -- vim.keymap.set('i', '<C-J>', 'copilot#Accept("\\<CR>")', {
    --   expr = true,
    --   replace_keycodes = false
    -- })
    -- vim.g.copilot_no_tab_map = true
  end
}
