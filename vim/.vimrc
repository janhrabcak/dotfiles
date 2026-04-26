" ==============================================================================
" VIM CONFIGURATION (v3.0 - Power Pack)
" ==============================================================================

" --- 1. Plugin Management (Vim-Plug) ---
if !filereadable(expand('~/.vim/autoload/plug.vim'))
  if !has('batch') | echohl WarningMsg | echo "Vim-Plug not found. Run bootstrap.sh to install." | echohl None | endif
else
  call plug#begin('~/.vim/plugged')
  " Navigation & Productivity
  Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
  Plug 'junegunn/fzf.vim'
  Plug 'preservim/nerdtree'
  
  " Git & Languages
  Plug 'tpope/vim-fugitive'
  Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }
  
  " Appearance
  Plug 'altercation/vim-colors-solarized'
  Plug 'itchyny/lightline.vim'
  call plug#end()
endif

" --- 2. General Settings ---
set nocompatible
set history=1000
set autowrite
set autoread
set timeoutlen=250
set hidden             " Allow buffer switching without saving
set encoding=utf-8
set nobackup           " No clunky backup files
set updatetime=300     " Faster completion/updates

" Persistence: Remember undo history across sessions
if has('undofile')
  set undofile
  set undodir=~/.vim/undo//
endif

" Clipboard: macOS vs Linux
if has('unnamedplus')
  set clipboard=unnamedplus
else
  set clipboard=unnamed
endif

" --- 3. Search & Interaction ---
set ignorecase         " Search case-insensitive...
set smartcase          " ...until you use a capital letter
set incsearch          " Highlight as you type
set hlsearch           " Keep matches highlighted
set mouse=a            " Enable mouse support

" --- 4. Visuals & Layout ---
syntax on
set background=dark
try
  colorscheme solarized
  " Make background transparent to match terminal exactly
  hi Normal ctermbg=none guibg=none
  hi NonText ctermbg=none guibg=none
  hi LineNr ctermbg=none guibg=none
  hi Folded ctermbg=none guibg=none
  hi EndOfBuffer ctermbg=none guibg=none
catch
  colorscheme desert
endtry

" Status Line: Lightline configuration
set laststatus=2
set noshowmode         " Lightline shows the mode already
let g:lightline = {
      \ 'colorscheme': 'solarized',
      \ 'active': {
      \   'left': [ [ 'mode', 'paste' ],
      \             [ 'gitbranch', 'readonly', 'filename', 'modified' ] ]
      \ },
      \ 'component_function': {
      \   'gitbranch': 'FugitiveHead'
      \ },
      \ }

" Line Numbers: Hybrid mode (Relative + Absolute for current line)
set number
set relativenumber

set showmatch
set matchtime=5
set ruler

" --- 5. Custom Mappings ---
let mapleader=","

" Fuzzy Finding (FZF)
nnoremap <C-p> :Files<CR>
nnoremap <leader>b :Buffers<CR>
nnoremap <leader>f :Rg<CR>

" Toggle Hidden Chars
map <silent> <F12> :set invlist<CR>

" vim-go
au FileType go nmap <leader>r <Plug>(go-run)
au FileType go nmap <leader>b <Plug>(go-build)
au FileType go nmap <leader>t <Plug>(go-test)
au FileType go nmap <leader>c <Plug>(go-coverage)
au FileType go nmap <Leader>gd <Plug>(go-doc)
au FileType go nmap <Leader>gv <Plug>(go-doc-vertical)

" --- 6. Cleanup & Auto-formatting ---
autocmd FileType * setlocal formatoptions-=c formatoptions-=r formatoptions-=o
