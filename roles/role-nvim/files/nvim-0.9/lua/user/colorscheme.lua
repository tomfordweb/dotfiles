local M = {
  "ellisonleao/gruvbox.nvim",
  commit = "df149bccb19a02c5c2b9fa6ec0716f0c0487feb0",
  lazy = false,    -- make sure we load this during startup if it is your main colorscheme
  priority = 1000, -- make sure to load this before all the other start plugins
}

M.name = "gruvbox"
function M.config()
  local status_ok, _ = pcall(vim.cmd.colorscheme, M.name)
  if not status_ok then
    return
  end
end

return M
