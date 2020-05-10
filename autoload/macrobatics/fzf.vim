
function macrobatics#fzf#isAvailable()
    return !empty(globpath(&runtimepath, "plugin/fzf.vim", 1))
endfunction

function macrobatics#fzf#selectNamedMacro()
  call fzf#run({
      \ 'source': macrobatics#getNamedMacros(),
      \ 'down': '40%',
      \ 'sink': function('macrobatics#selectNamedMacro')})
endfunction

function macrobatics#fzf#playNamedMacro()
  call fzf#run({
      \ 'source': macrobatics#getNamedMacros(),
      \ 'down': '40%',
      \ 'sink': function('macrobatics#playNamedMacro')})
endfunction


