local actions = require("telescope.actions")
local builtin = require('telescope.builtin')

require('telescope').setup {
  defaults = {
    path_display = { "smart" },
    file_ignore_patterns = { ".git/", "node_modules" },
    pickers = {
      find_files = {
        hidden = true
      },
    },
    mappings = {
      i = {
        ["<Down>"] = actions.move_selection_next,
        ["<Up>"] = actions.move_selection_previous,
        ["<C-j>"] = actions.move_selection_next,
        ["<C-k>"] = actions.move_selection_previous,
        ["<C-d>"] = actions.delete_buffer + actions.move_to_top
      },
    },
  }
}


vim.keymap.set('n', '<leader>f', builtin.find_files, { desc = 'Telescope find files' })
vim.keymap.set('n', '<leader>F', builtin.live_grep, { desc = 'Telescope live grep' })
vim.keymap.set('n', '<leader>G', builtin.git_files, { desc = 'Telescope git files' })
vim.keymap.set('n', '<leader>b', builtin.buffers, { desc = 'Telescope buffers' })
vim.keymap.set('n', '<leader>H', builtin.help_tags, { desc = 'Telescope help tags' })
