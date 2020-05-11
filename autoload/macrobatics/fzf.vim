
function macrobatics#fzf#isAvailable()
    return !empty(globpath(&runtimepath, "plugin/fzf.vim", 1))
endfunction

function macrobatics#fzf#selectNamedMacro()
    call fzf#run({
        \ 'source': macrobatics#getNamedMacros(),
        \ 'down': '40%',
        \ 'sink': function('macrobatics#selectNamedMacro')})
endfunction

function s:fzfPlaySink(name)
    call macrobatics#playNamedMacro(a:name, s:lastCount)
endfunction

function macrobatics#fzf#playNamedMacro(cnt)
    let s:lastCount = a:cnt
    call fzf#run({
        \ 'source': macrobatics#getNamedMacros(),
        \ 'down': '40%',
        \ 'sink': function('s:fzfPlaySink')})
endfunction


