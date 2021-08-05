call plug#begin('~/.nvim/plugged')
    " " editor enhancements
    Plug 'vim-airline/vim-airline'
    " Plug 'airblade/vim-gitgutter' "see git changes in gutter...not very
    " performant
    Plug 'tpope/vim-commentary' 
    Plug 'morhetz/gruvbox' " theme
    Plug 'tpope/vim-vinegar'
    Plug 'sbdchd/neoformat'

    Plug 'tpope/vim-fugitive' " git tool
    " telescope
    Plug 'nvim-lua/popup.nvim'
    Plug 'nvim-lua/plenary.nvim'
    Plug 'nvim-telescope/telescope.nvim'
    Plug 'nvim-telescope/telescope-fzy-native.nvim'

    " js/ts
    Plug 'HerringtonDarkholme/yats.vim' " typescript syntax

    Plug 'neoclide/coc.nvim', {'branch': 'release'} 
    Plug 'neoclide/coc-tsserver', {'do': 'npm ci'}
call plug#end()

lua <<EOF
local actions = require('telescope.actions')
require('telescope').setup {
    defaults = {
        file_sorter = require('telescope.sorters').get_fzy_sorter,
        prompt_prefix = ' >',
        color_devicons = true,

        file_previewer   = require('telescope.previewers').vim_buffer_cat.new,
        grep_previewer   = require('telescope.previewers').vim_buffer_vimgrep.new,
        qflist_previewer = require('telescope.previewers').vim_buffer_qflist.new,

        mappings = {
            i = {
                ["<C-x>"] = false,
                ["<C-q>"] = actions.send_to_qflist,
            },
        }
    },
    extensions = {
        fzy_native = {
            override_generic_sorter = false,
            override_file_sorter = true,
        }
    }
}
require('telescope').load_extension('fzy_native')
local M = {}
M.git_branches = function()
    require("telescope.builtin").git_branches({
        attach_mappings = function(_, map)
            map('i', '<c-d>', actions.git_delete_branch)
            map('n', '<c-d>', actions.git_delete_branch)
            return true
        end
    })
end

return M
EOF

let mapleader = ","

set nocompatible
set number                " Show numbers on the left
set hlsearch              " Highlight search results
set ignorecase            " Search ingnoring case
set smartcase             " Do not ignore case if the search patter has uppercase
set tabstop=4             " Tab size of 4 spaces
set incsearch             " Search shows partial matches
set lazyredraw            " Don't animate macros
set softtabstop=4         " On insert use 4 spaces for tab
set shiftwidth=4          " Fix indentation errors faster
set expandtab             " Use apropiate number of spaces
set nowrap                " Wrapping sucks (except on markdown)
autocmd BufRead,BufNewFile *.md,*.txt setlocal wrap " DO wrap on markdown files
set noswapfile            " Do not leve any backup files
set scrolloff=5           " Min lines to keep above/below curor
set syntax=enable
set showmatch
set termguicolors
set splitright splitbelow
set title                 " Show filename
set cursorcolumn          " Show vertial column on cursor

" allows globbing on netrw stuff
set path+=**

" Nice menu when typing `:find *.py`
set wildmode=longest,list,full
set wildmenu
" Ignore files
set wildignore+=*.pyc
set wildignore+=*_build/*
set wildignore+=**/coverage/*
set wildignore+=**/node_modules/*
set wildignore+=**/vendor/*
set wildignore+=**/.git/*


set mouse=a
set list lcs=tab:\¦\      
let &t_SI = "\e[6 q"      " Make cursor a line in insert
let &t_EI = "\e[2 q"      " Make cursor a line in inserto



" Shows line number on current line, relative numbers off that
set number                     " Show current line number
set relativenumber             " Show relative line numbers


" Prettier config
" when running at every change you may want to disable quickfix
" let g:prettier#quickfix_enabled = 0
" let g:prettier#autoformat = 1
" let g:prettier#autoformat_require_pragma = 0
" autocmd BufWritePre *.js,*.jsx,*.mjs,*.ts,*.tsx,*.css,*.less,*.scss,*.json,*.graphql,*.md,*.vue,*.svelte,*.yaml,*.html PrettierAsync

augroup fmt
  autocmd!
  autocmd BufWritePre * undojoin | Neoformat
augroup END


" .class files are almost always some hairy php where I come from
autocmd BufNewFile,BufRead *.class set syntax=php


colorscheme gruvbox

" Keep VisualMode after indent with > or <
vmap < <gv
vmap > >gv

" Autocomand to remember last editing position
augroup vimrc-remember-cursor-position
  autocmd!
  autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g`\"" | endif
augroup END

"
" CUSTOM KEYBINDS
" 
" Ctrl-kk - Toggle file browser
map <C-k><C-k> :e .<cr>


" Ripgrep
nnoremap <C-I> :Rg<cr>

" Ctrl-e to show lint errors
nnoremap <C-e> :CocList diagnostics<cr>

vnoremap <leader>p "_dP
nnoremap <leader>y "+y
nnoremap <leader>Y gg"+yG
nnoremap <leader>d "_d
vnoremap <leader>d "_d

" Language specific configuration
autocmd FileType yaml,bash,sh setlocal shiftwidth=2 softtabstop=2

" I hate those psr4 inline comments
autocmd FileType php setlocal commentstring=#\ %s

" Telescope bindings
nnoremap <C-p> :lua require('telescope.builtin').git_files()<CR>
nnoremap <leader>ff <cmd>lua require('telescope.builtin').find_files()<cr>
nnoremap <leader>fg <cmd>lua require('telescope.builtin').live_grep()<cr>
nnoremap <leader>fb <cmd>lua require('telescope.builtin').buffers()<cr>
nnoremap <leader>fB <cmd>lua require('telescope.builtin').git_branches()<cr>
nnoremap <leader>fh <cmd>lua require('telescope.builtin').help_tags()<cr>

nnoremap <Leader><CR> :so ~/.config/nvim/init.vim<CR>
nnoremap <Leader>+ :vertical resize +5<CR>
nnoremap <Leader>- :vertical resize -5<CR>

" Code completion
runtime coc.vim

" Turn persistent undo on 
try
    set undodir=~/.vim_runtime/temp_dirs/undodir
    set undofile
catch
endtry

" COC configuration
" Run these commands:
" CocInstall coc-phpls
source $HOME/.config/nvim/coc-init.vim
