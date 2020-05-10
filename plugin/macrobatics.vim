
if exists('g:Mac_Initialized')
    finish
endif
let g:Mac_Initialized = 1

nnoremap <plug>(Mac_Play) :<c-u>call macrobatics#play(v:register, v:count)<cr>
nnoremap <expr> <plug>(Mac_RecordNew) macrobatics#recordNew(v:register)

nnoremap <plug>(Mac_Append) :<c-u>call macrobatics#append(v:register, v:count)<cr>
nnoremap <plug>(Mac_Prepend) :<c-u>call macrobatics#prepend(v:register, v:count)<cr>

nnoremap <plug>(Mac_StoreCurrent) :<c-u>call macrobatics#storeCurrent(v:count, v:register)<cr>

nnoremap <plug>(Mac_RotateBack) :<c-u>call macrobatics#rotate(v:count > 0 ? v:count : 1)<cr>
nnoremap <plug>(Mac_RotateForward) :<c-u>call macrobatics#rotate(v:count > 0 ? -v:count : -1)<cr>

command! -nargs=0 Macros call macrobatics#displayHistory()
command! -nargs=0 ClearMacros call macrobatics#clearHistory()

augroup _Macrobatics
    au!
    autocmd VimEnter * call macrobatics#onVimEnter()
augroup END

