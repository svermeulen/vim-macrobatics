
function! s:getDefaultFzfOptions()
    if has('nvim') || version >= 802
        return {'window': {'width': 0.75, 'height': 0.6}}
    endif
    return {'down': '40%'}
endfunction

let s:fzfOpts =  get(g:, 'Mac_FzfOptions', s:getDefaultFzfOptions())
let s:sink2 = v:null

function macrobatics#fzf#isAvailable()
    return !empty(globpath(&runtimepath, "plugin/fzf.vim", 1))
endfunction

" Use an intermediate sink so we can redraw so that the fzf popup goes away
function! s:sink1(choice)
    redraw
    call s:sink2(a:choice)
endfunction

function macrobatics#fzf#makeChoice(values, sink)
    let s:sink2 = a:sink
    let opts = {
        \ 'source': a:values,
        \ 'sink': function('s:sink1')
        \ }
    call fzf#run(extend(copy(s:fzfOpts), opts))
endfunction

