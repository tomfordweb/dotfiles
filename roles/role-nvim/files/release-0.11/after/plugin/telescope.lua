local builtin = require('telescope.builtin')

vim.keymap.set('n', '<leader>T', builtin.find_files, { desc = 'Telescope find files' })
vim.keymap.set('n', '<leader>f', builtin.git_files, { desc = 'Telescope git files' })
vim.keymap.set('n', '<leader>F', builtin.live_grep, { desc = 'Telescope live grep' })
vim.keymap.set('n', '<leader>F', builtin.live_grep, { desc = 'Telescope live grep' })
vim.keymap.set('n', '<leader>b', builtin.buffers, { desc = 'Telescope buffers' })
vim.keymap.set('n', '<leader>H', builtin.help_tags, { desc = 'Telescope help tags' })
