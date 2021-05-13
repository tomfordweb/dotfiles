call plug#begin('~/.nvim/plugged')
    Plug 'vim-airline/vim-airline'
    Plug 'tmsvg/pear-tree'
    Plug 'tpope/vim-sensible'
    Plug 'tpope/vim-fugitive', { 'on': 'G' }
    Plug 'tpope/vim-commentary'
    Plug 'morhetz/gruvbox'
    Plug 'scrooloose/nerdtree', { 'on':  'NERDTreeToggle' } 
    Plug 'tpope/vim-dadbod', { 'on':  'DB' }               
    Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }   
    Plug 'junegunn/fzf.vim'               
    Plug 'neoclide/coc.nvim', {'branch': 'release'} 
    Plug 'beanworks/vim-phpfmt'
    " Plugins here !!!!
call plug#end()

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
set shiftwidth=2          " Fix indentation errors faster
set expandtab             " Use apropiate number of spaces
set nowrap                " Wrapping sucks (except on markdown)
autocmd BufRead,BufNewFile *.md,*.txt setlocal wrap " DO wrap on markdown files
set noswapfile            " Do not leve any backup files
set mouse=a               " Enable mouse on all modes
set scrolloff=5           " Min lines to keep above/below curor
set syntax=enable
set showmatch
set termguicolors
set visualbell
set noerrorbells
set splitright splitbelow
set title                 " Show filename
set cursorcolumn          " Show vertial column on cursor
" set cursorline            " Highlight the current line you are writing on
set list lcs=tab:\¦\      "(here is a space)
let &t_SI = "\e[6 q"      " Make cursor a line in insert
let &t_EI = "\e[2 q"      " Make cursor a line in insert

colorscheme gruvbox

" Keep VisualMode after indent with > or <
vmap < <gv
vmap > >gv

" Autocomand to remember last editing position
augroup vimrc-remember-cursor-position
  autocmd!
  autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g`\"" | endif
augroup END

" Ctrl-kk - Toggle file browser
map <C-k><C-k> :NERDTreeToggle<cr>

" Use Ctrl-P to open the fuzzy file opener
nnoremap <C-p> :GFiles<cr>

" Ctrl-e to show lint errors
nnoremap <C-e> :CocList diagnostics<cr>

" Language specific configuration
autocmd FileType yaml,bash,sh setlocal shiftwidth=2 softtabstop=2

" Code completion
runtime coc.vim


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Turn persistent undo on 
"    means that you can undo even when you close a buffer/VIM
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
try
    set undodir=~/.vim_runtime/temp_dirs/undodir
    set undofile
catch
endtry

