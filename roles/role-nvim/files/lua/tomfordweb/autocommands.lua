local augroup = vim.api.nvim_create_augroup
local TomFordWebGroup = augroup('TomFordWeb', {})

local autocmd = vim.api.nvim_create_autocmd
local yank_group = augroup('HighlightYank', {})

-- blink highlight thing - advent of neovim
autocmd('TextYankPost', {
  group = yank_group,
  pattern = '*',
  callback = function()
    vim.highlight.on_yank({
      higroup = 'IncSearch',
      timeout = 40,
    })
  end,
})


-- hit 'q' to ez close on specific buffers
autocmd("FileType", {
  pattern = { "qf", "help", "man", "lspinfo", "spectre_panel" },
  callback = function()
    vim.cmd [[
      nnoremap <silent> <buffer> q :close<CR>
      set nobuflisted
    ]]
  end,
})

autocmd("CursorHold", {
  group = TomFordWebGroup,
  callback = function()
    vim.diagnostic.open_float(nil, {
      scope = "line",
      close_events = { "CursorMoved", "CursorMovedI", "BufHidden", "InsertCharPre", "WinLeave" },
      focusable = false, -- Set to true if you want to be able to focus the float
    })
  end,
})

-- lsp keybinds
autocmd('LspAttach', {
  group = TomFordWebGroup,
  callback = function(e)
    vim.keymap.set("n", "gd", function() vim.lsp.buf.definition() end, { buffer = e.buf, desc = "Go to definition" })
    vim.keymap.set("n", "K", function() vim.lsp.buf.hover() end, { buffer = e.buf, desc = "Hover documentation" })
    vim.keymap.set("n", "<leader>ca", function() vim.lsp.buf.code_action() end, { buffer = e.buf, desc = "Code action" })
    vim.keymap.set("n", "<leader>cA", function() vim.cmd(':LspTypescriptSourceAction') end, { buffer = e.buf, desc = "Typescript language server code actions" })
    vim.keymap.set("n", "gr", function() vim.lsp.buf.references() end, { buffer = e.buf, desc = "Go to references" })
    vim.keymap.set("n", "<leader>cr", function() vim.lsp.buf.rename() end, { buffer = e.buf, desc = "Rename" })
    vim.keymap.set("n", "[j", function() vim.diagnostic.goto_next() end,
      { buffer = e.buf, desc = "Go to next diagnostic" })
    vim.keymap.set("n", "]k", function() vim.diagnostic.goto_prev() end,
      { buffer = e.buf, desc = "Go to previous diagnostic" })

    -- Format on save
    local client = assert(vim.lsp.get_client_by_id(e.data.client_id))
    if not client then return end

    if client:supports_method('textDocument/formatting') then
      vim.api.nvim_create_autocmd('BufWritePre', {
        group = TomFordWebGroup,
        buffer = e.buf,
        callback = function()
          vim.lsp.buf.format({ bufnr = e.buf, id = client.id, timeout_ms = 1000 })
        end,
      })
    end
  end
})
