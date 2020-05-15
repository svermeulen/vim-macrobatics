
let s:lastNamedMacros = v:null
let s:lastCount = v:null

let g:clap_provider_macrobatics_select = {
      \ 'source': function('s:clapSource'),
      \ 'sink': function('macrobatics#selectNamedMacro')
      \ }

let g:clap_provider_macrobatics_play = {
      \ 'source': function('s:clapSource'),
      \ 'sink': function('s:clapPlaySink')
      \ }

function macrobatics#clap#isAvailable()
    return !empty(globpath(&runtimepath, "plugin/clap.vim", 1))
endfunction

function macrobatics#clap#selectNamedMacro()
    call s:cacheData()
    Clap macrobatics_select
endfunction

function macrobatics#clap#playNamedMacro(cnt)
    let s:lastCount = a:cnt
    call s:cacheData()
    Clap macrobatics_play
endfunction

function s:clapPlaySink(name)
    call macrobatics#playNamedMacro(a:name, s:lastCount)
endfunction

function s:clapSource()
    return s:lastNamedMacros
endfunction

function s:cacheData()
    " We need to cache the named macro list because it checks current file type,
    " which will be different when the clap window is open
    let s:lastNamedMacros = macrobatics#getNamedMacros()
endfunction

