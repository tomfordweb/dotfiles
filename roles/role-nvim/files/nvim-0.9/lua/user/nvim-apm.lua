local M = {
  "pseudocc/nvim-apm",
  lazy = false,
  commit = "0e96b6222f322377063d1940648bd78a15cf55e9",
  config = function()
    vim.cmd([[:NvimApm]])

  end,

}

return M
