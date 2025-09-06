local root_files = {
  '.luarc.json',
  '.luarc.jsonc',
  '.luacheckrc',
  '.stylua.toml',
  'stylua.toml',
  'selene.toml',
  'selene.yml',
  '.git',
}

return {
  "neovim/nvim-lspconfig",
  dependencies = {
    -- conform
    "stevearc/conform.nvim",
    -- management
    "williamboman/mason.nvim",
    "williamboman/mason-lspconfig.nvim",
    "mason-org/mason-lspconfig.nvim",
    -- autocompleteion
    "hrsh7th/cmp-nvim-lsp",
    "hrsh7th/cmp-buffer",
    "hrsh7th/cmp-path",
    "hrsh7th/cmp-cmdline",
    "hrsh7th/nvim-cmp",
    "j-hui/fidget.nvim",
    {
      "folke/lazydev.nvim",
      ft = "lua", -- only load on lua files
      opts = {
        library = {
          -- See the configuration section for more details
          -- Load luvit types when the `vim.uv` word is found
          { path = "${3rd}/luv/library", words = { "vim%.uv" } },
        },
      },
    },
    { -- optional cmp completion source for require statements and module annotations
      "hrsh7th/nvim-cmp",
      opts = function(_, opts)
        opts.sources = opts.sources or {}
        table.insert(opts.sources, {
          name = "lazydev",
          group_index = 0, -- set group index to 0 to skip loading LuaLS completions
        })
      end,
    },
  },

  config = function()
    require("conform").setup({
      formatters_by_ft = {
      }
    })
    local cmp = require('cmp')
    local cmp_lsp = require("cmp_nvim_lsp")
    local capabilities = vim.tbl_deep_extend(
      "force",
      {},
      vim.lsp.protocol.make_client_capabilities(),
      cmp_lsp.default_capabilities())

    require("fidget").setup({})
    require("mason").setup()

    require("mason-lspconfig").setup({
      ensure_installed = {
        "angularls", -- ng
        "lua_ls",    -- lua
        -- "smarty_ls",
        -- "tailwindcss",
        "intelephense", -- php
        "ansiblels",    --ansible
        "bashls",       --shell
        "marksman",     --markdown
        "docker_compose_language_service",
        "docker_language_server",
        "emmet_ls",
        "eslint",
        "gitlab_ci_ls",
        "graphql",
        "jsonls",
        -- "laravel_ls",
        "ts_ls"
      },
      handlers = {
        function(server_name) -- default handler (optional)
          require("lspconfig")[server_name].setup {
            capabilities = capabilities
          }
        end,
        ["lua_ls"] = function()
          local lspconfig = require("lspconfig")
          lspconfig.lua_ls.setup {
            capabilities = capabilities,
            settings = {
              Lua = {
                format = {
                  enable = true,
                  -- Put format options here
                  -- NOTE: the value should be STRING!!
                  defaultConfig = {
                    indent_style = "space",
                    indent_size = "2",
                  }
                },
              }
            }
          }
        end,
        -- ["intelephense"] = function()
        --   local lspconfig = require("lspconfig")
        --   lspconfig.intelephense.setup {
        --     capabilities = capabilities,
        --     settings = {
        --       intelephense = {
        --         settings = {
        --           files = {
        --             -- maxsize = 1000
        --           },
        --           -- environment = {
        --           --   includePaths = {
        --           --   }
        --           -- }
        --         }
        --       }
        --
        --     }
        --   }
        -- end,
      }
    })
    -- local lspconfig = require('lspconfig')
    -- -- https://github.com/bmewburn/intelephense-docs/blob/master/installation.md#initialisation-options
    --
    -- lspconfig.intelephense.setup({
    --   -- Optional: Function to run when the LSP client attaches to a buffer
    --   on_attach = function(client, bufnr)
    --     -- Add keybindings or other buffer-specific configurations here
    --   end,
    --   -- Optional: Capabilities for the LSP client
    --   capabilities = require('cmp_nvim_lsp').default_capabilities(vim.lsp.protocol.make_client_capabilities()),
    --   -- Intelephense-specific settings
    --   settings = {
    --     intelephense = {
    --       -- Environment settings
    --       environment = {
    --         includePaths = {
    --           -- "/home/tom/mhvillage-stack/mhvillage/libs/datacomp/foundation/src/SalesCenter.class",
    --         },
    --       },
    --       -- File-related settings
    --       files = {
    --         maxSize = 5000000,                                                     -- Maximum file size to analyze in bytes
    --         associations = { "*.php", "*.phtml", "*.module", "*.inc", "*.class" }, -- File extensions to associate
    --       },
    --       -- Stub files for built-in PHP functions and common frameworks
    --       -- stubs = {
    --       --   "Core", "bcmath", "curl", "wordpress", "woocommerce", -- Examples
    --       -- },
    --       -- License key (if using the premium version)
    --       -- licenceKey = "YOUR_LICENSE_KEY_HERE",
    --     },
    --   },
    -- })

    cmp.setup({
      mapping = cmp.mapping.preset.insert({
        ["<C-u>"] = cmp.mapping(cmp.mapping.scroll_docs(-1), { "i", "c" }),
        ["<C-d>"] = cmp.mapping(cmp.mapping.scroll_docs(1), { "i", "c" }),
        ["<C-Space>"] = cmp.mapping(cmp.mapping.complete(), { "i", "c" }),
        ["<C-e>"] = cmp.mapping {
          i = cmp.mapping.abort(),
          c = cmp.mapping.close(),
        },
        -- Accept currently selected item. If none selected, `select` first item.
        -- Set `select` to `false` to only confirm explicitly selected items.
        ["<CR>"] = cmp.mapping.confirm { select = true },
        ["<Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_next_item()
          elseif luasnip.expandable() then
            luasnip.expand()
          elseif luasnip.expand_or_jumpable() then
            luasnip.expand_or_jump()
          elseif check_backspace() then
            fallback()
          else
            fallback()
          end
        end, {
          "i",
          "s",
        }),
        ["<S-Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_prev_item()
          elseif luasnip.jumpable(-1) then
            luasnip.jump(-1)
          else
            fallback()
          end
        end, {
          "i",
          "s",
        }),
      }),
      sources = cmp.config.sources({
        { name = "copilot", group_index = 2 },
        { name = 'nvim_lsp' },
      }, {
        { name = 'buffer' },
      })
    })

    vim.diagnostic.config({
      signs = {
        text = {
          [vim.diagnostic.severity.ERROR] = '',
          [vim.diagnostic.severity.WARN] = '󰶬',
          [vim.diagnostic.severity.INFO] = '',
          [vim.diagnostic.severity.HINT] = '󰌵',
        },
        -- linehl = {
        --   [vim.diagnostic.severity.ERROR] = 'ErrorMsg',
        -- },
        numhl = {
          [vim.diagnostic.severity.WARN] = 'WarningMsg',
        },
      },
      float = {
        focusable = false,
        style = "minimal",
        border = "rounded",
        source = "always",
        header = "",
        prefix = "",
      },
    })
  end
}
