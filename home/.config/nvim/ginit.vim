" GUI-only settings; guarded
if exists(':GuiFont')
  " keep current font; adjust size only if desired
  " GuiFont! Monospace:h12
endif
if exists(':GuiTabline')
  GuiTabline 0
endif
if exists(':GuiPopupmenu')
  GuiPopupmenu 0
endif
if exists(':GuiScrollBar')
  GuiScrollBar 1
endif

nnoremap <silent><RightMouse> :call GuiShowContextMenu()<CR>
inoremap <silent><RightMouse> <Esc>:call GuiShowContextMenu()<CR>
xnoremap <silent><RightMouse> :call GuiShowContextMenu()<CR>gv