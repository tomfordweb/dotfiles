local M = {
  "tpope/vim-fugitive",
  commit = "5f0d280b517cacb16f59316659966c7ca5e2bea2",
  event = "VeryLazy",
}

function M.config()
  require("vim-fugitive").setup {}
end

return M
