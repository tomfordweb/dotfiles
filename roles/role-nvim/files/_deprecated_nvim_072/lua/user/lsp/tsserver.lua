
local tsserver_status_ok, tsserver = pcall(require, "tsserver")

if not tsserver_status_ok then
	return
end


tsserver.setup({
    -- disable tsserver formatting, use null-ls/prettier.
    -- https://github.com/jose-elias-alvarez/null-ls.nvim/discussions/244
    on_attach = function(client, bufnr)
        client.resolved_capabilities.document_formatting = false
        vim.api.nvim_buf_set_keymap(bufnr, "n", "<space>fm", "<cmd>lua vim.lsp.buf.formatting()<CR>", {})
    end,
})
