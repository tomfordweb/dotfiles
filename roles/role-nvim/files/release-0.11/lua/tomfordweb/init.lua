require("tomfordweb.remap");
require("tomfordweb.options")
require("tomfordweb.lazy");
require("tomfordweb.autocommands");


function SetColors(color)
  color = color or "tokyonight-night"
  vim.cmd.colorscheme(color)
  -- https://neovim.io/doc/user/syntax.html#_13.-highlight-command
  vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
  vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
  vim.api.nvim_set_hl(0, "NormalNC", { bg = "none" })
end

SetColors()
