vim.api.nvim_create_autocmd("BufWritePre", {
	pattern = "*.lua", -- Adjust for desired file types
	callback = function()
		vim.lsp.buf.format({ async = false })
	end,
})
