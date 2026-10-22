" fakevim config sourced by CopyQ (VimRcPath)
" Translated from ~/.config/nvim lua/config/options.lua + keymaps.lua
" Only options supported by FakeVim (see fakevimactions.cpp) are included.

" --- options ---
set backspace=indent,eol,start
set tabstop=2
set shiftwidth=2
set expandtab
set autoindent
set smartindent
set smarttab
set hlsearch
set incsearch
set ignorecase
set smartcase
set wrapscan
set showcmd
set scrollOff=0
set nowrap
set tildeop
set iskeyword=@,48-57,_,192-255,a-z,A-Z
set formatoptions=jcroqlnt
" clipboard sync with system
set clipboard=unnamedplus

" --- keymaps ---
" Insert-mode escape
inoremap jj <Esc>
inoremap kk <Esc>
inoremap jk <Esc>
inoremap kj <Esc>

" terminal mode not available in fakevim; skip

" clear search highlight on Esc
nnoremap <Esc> :nohlsearch<CR>

" undo break-points on punctuation
inoremap , ,<C-g>u
inoremap . .<C-g>u
inoremap ; ;<C-g>u

" smart dd (black hole on empty line) not supported: FakeVim has no <expr> mappings

" split line
nnoremap <S-CR> a<CR><Esc>
inoremap <S-CR> <CR>







" markdown heading navigation
nnoremap gj /^#\+ .*<CR>
nnoremap gk ?^#\+ .*<CR>

" ufo folds not available in fakevim; skip zR/zM/zr/zm

" K smart peek not available; skip
