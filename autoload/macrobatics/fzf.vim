
function macrobatics#fzf#isAvailable()
    return !empty(globpath(&runtimepath, "plugin/fzf.vim", 1))
endfunction

function macrobatics#fzf#makeChoice(values, sink)
    call fzf#run({
        \ 'source': a:values,
        \ 'down': '40%',
        \ 'sink': a:sink})
endfunction

