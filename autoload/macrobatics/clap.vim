
let g:clap_provider_macrobatics_select = {
      \ 'source': function('macrobatics#getNamedMacros'),
      \ 'sink': function('macrobatics#selectNamedMacro')
      \ }

let g:clap_provider_macrobatics_play = {
      \ 'source': function('macrobatics#getNamedMacros'),
      \ 'sink': function('macrobatics#playNamedMacro')
      \ }

function macrobatics#clap#isAvailable()
    return !empty(globpath(&runtimepath, "plugin/clap.vim", 1))
endfunction

function macrobatics#clap#selectNamedMacro()
    Clap macrobatics_select
endfunction

function macrobatics#clap#playNamedMacro()
    Clap macrobatics_play
endfunction

