local Terminal  = require('toggleterm.terminal').Terminal

local generic_float = Terminal:new({
  direction = "float",
  float_opts = {
    border = "double",
  },
  -- function to run on opening the terminal
  on_open = function(term)
    vim.cmd("startinsert!")
    vim.api.nvim_buf_set_keymap(term.bufnr, "n", "q", "<cmd>close<CR>", {noremap = true, silent = true})
  end,
  -- function to run on closing the terminal
  on_close = function(term)
    vim.cmd("startinsert!")
  end,
})


function _generic_float_toggle()
  generic_float:toggle()
end

vim.api.nvim_set_keymap("n", "<leader>tf", "<cmd>lua _generic_float_toggle()<CR>", {noremap = true, silent = true})
