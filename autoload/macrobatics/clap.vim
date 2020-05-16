
let s:values = v:null
let s:sink = v:null

function macrobatics#clap#isAvailable()
    return !empty(globpath(&runtimepath, "plugin/clap.vim", 1))
endfunction

function macrobatics#clap#makeChoice(values, sink)
    let s:sink = a:sink
    let s:values = a:values
    Clap macrobatics
endfunction

function s:clapPlaySink(choice)
    call s:sink(a:choice)
endfunction

function s:clapSource()
    return s:values
endfunction

let g:clap_provider_macrobatics = {
      \ 'source': function('s:clapSource'),
      \ 'sink': function('s:clapPlaySink')
      \ }
