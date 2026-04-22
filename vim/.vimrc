" ==============================================================================
" VIM CONFIGURATION
" ==============================================================================

" --- Plugin Management (Vim-Plug) ---
call plug#begin('~/.vim/plugged')
Plug 'tomasr/molokai'
Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }
Plug 'tpope/vim-fugitive'
Plug 'preservim/nerdtree'
call plug#end()

" --- General Settings ---
set nocompatible
set history=256
set autowrite
set autoread
set timeoutlen=250

" Clipboard: macOS vs Linux
if has('unnamedplus')
  set clipboard=unnamedplus
else
  set clipboard=unnamed
endif

set pastetoggle=<F10>
set tags=./tags;$HOME
set modeline
set modelines=5

" --- Visuals ---
syntax on
colorscheme molokai
set showmatch
set matchtime=5
set laststatus=2
set ruler
set number
set mouse=a

" Show/Hide hidden chars
map <silent> <F12> :set invlist<CR>

" --- Mappings ---
let mapleader=","

" vim-go
au FileType go nmap <leader>r <Plug>(go-run)
au FileType go nmap <leader>b <Plug>(go-build)
au FileType go nmap <leader>t <Plug>(go-test)
au FileType go nmap <leader>c <Plug>(go-coverage)
au FileType go nmap <Leader>gd <Plug>(go-doc)
au FileType go nmap <Leader>gv <Plug>(go-doc-vertical)

" --- Plugin Options ---
let g:go_highlight_functions = 1
let g:go_highlight_methods = 1
let g:go_highlight_structs = 1
let g:go_highlight_operators = 1
let g:go_highlight_build_constraints = 1

" --- Cleanup ---
autocmd FileType * setlocal formatoptions-=c formatoptions-=r formatoptions-=o

