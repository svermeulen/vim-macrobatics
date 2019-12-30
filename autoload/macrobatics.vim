
let s:defaultMacroReg = get(g:, 'Mac_DefaultRegister', 'm')
let s:maxItems = get(g:, 'Mac_MaxItems', 10)
let s:saveHistoryToShada = get(g:, 'Mac_SavePersistently', 0)
let s:displayMacroMaxWidth = get(g:, 'Mac_DisplayMacroMaxWidth', 80)

let s:playInfoStack = []

let s:isRecording = 0

if s:saveHistoryToShada
    if !exists("g:MACROBATICS_HISTORY")
        let g:MACROBATICS_HISTORY = []
    endif

    if !has("nvim")
        echoerr "Neovim is required when setting g:Mac_SavePersistently to 1"
    elseif &shada !~ '\V!'
        echoerr "Must enable global variable support by including ! in the shada property when setting g:Mac_SavePersistently to 1.  See macrobatics documentation for details or run :help 'shada'."
    endif
else
    let s:history = []
    " If the setting is off then clear it to not keep taking up space
    let g:MACROBATICS_HISTORY = []
endif

function! macrobatics#getHistory()
    if s:saveHistoryToShada
        return g:MACROBATICS_HISTORY
    endif

    return s:history
endfunction

function s:assert(value, ...)
    if !a:value
        let message = a:0 ? a:1 : 'Assert hit inside vim-macrobatics plugin'
        throw message
    endif
endfunction

function! s:popPlayInfo()
    call s:assert(len(s:playInfoStack) != 0)

    if len(s:playInfoStack) == 1
        return s:playInfoStack[0]
    endif

    let result = s:playInfoStack[-1]
    call remove(s:playInfoStack, len(s:playInfoStack) - 1)
    return result
endfunction

function! macrobatics#play(_)
    let data = s:popPlayInfo()
    exec "normal! " . data.cnt . "@" . data.reg
endfunction

function! macrobatics#getDefaultReg()
    let clipboardFlags = split(&clipboard, ',')
    if index(clipboardFlags, 'unnamedplus') >= 0
        return "+"
    elseif index(clipboardFlags, 'unnamed') >= 0
        return "*"
    else
        return "\""
    endif
endfunction

function! macrobatics#addToHistory(entry)
    let history = macrobatics#getHistory()

    if len(history) == 0 || history[0] != a:entry
        call insert(history, a:entry, 0)
        if len(history) > s:maxItems
            call remove(history, s:maxItems, -1)
        endif
    endif
endfunction

function! macrobatics#displayHistory()
    echohl WarningMsg | echo "--- Macros ---" | echohl None
    let i = 0
    for macro in macrobatics#getHistory()
        call s:displayMacro(macro, i)
        let i += 1
    endfor
endfunction

function! macrobatics#storeCurrent(cnt, reg)
    if a:cnt == 0
        let content = getreg(s:defaultMacroReg)
    else
        let history = macrobatics#getHistory()
        let content = history[a:cnt]
    endif

    call setreg(a:reg, content)
    echo "Stored to '" . a:reg "' register: " . s:formatMacro(content)
endfunction

function! macrobatics#onVimEnter()
    " This should still work when saving persisently since it should be a no-op
    call macrobatics#addToHistory(getreg(s:defaultMacroReg))
endfunction

function! s:formatMacro(macro)
    let result = strtrans(a:macro)
    if len(result) > s:displayMacroMaxWidth
        return result[: s:displayMacroMaxWidth] . '…'
    endif
    return result
endfunction

function! s:displayMacro(macro, index)
    if a:index == 0
        echohl Directory | echo  'm   '
    else
        echohl Directory | echo  printf("%-4d", a:index)
    endif

    echohl None      | echon s:formatMacro(a:macro)
    echohl None
endfunction

function! macrobatics#clearHistory()
    let history = macrobatics#getHistory()
    let previousSize = len(history)
    call remove(history, 0, -1)
    call macrobatics#addToHistory(getreg(s:defaultMacroReg))
    echo "Cleared macro history of " . previousSize . " entries"
endfunction

function! macrobatics#rotate(offset)
    let history = macrobatics#getHistory()

    if empty(history) || a:offset == 0
        return
    endif

    " If the default register has contents different than the first entry in our history,
    " then it must have changed through a delete operation or directly via setreg etc.
    " In this case, don't rotate and instead just update the default register
    if history[0] != getreg(s:defaultMacroReg)
        call setreg(s:defaultMacroReg, history[0])
        return
    endif

    let actualOffset = float2nr(fmod(a:offset, len(history)))
    " Mod to save ourselves some work
    let offsetLeft = actualOffset

    while offsetLeft != 0
        if offsetLeft > 0
            let l:entry = remove(history, 0)
            call add(history, l:entry)
            let offsetLeft -= 1
        elseif offsetLeft < 0
            let l:entry = remove(history, -1)
            call insert(history, l:entry)
            let offsetLeft += 1
        endif
    endwhile

    call setreg(s:defaultMacroReg, history[0])
    echo "Current Macro: " . s:formatMacro(history[0])
endfunction

function! macrobatics#onRecordingComplete(_)
    let playInfo = s:playInfoStack[-1]
    let recordReg = playInfo.reg
    let recordContent = getreg(recordReg)
    if playInfo.prependContents != v:null
        let recordContent = playInfo.prependContents . recordContent
    endif
    if playInfo.appendContents != v:null
        let recordContent = recordContent . playInfo.appendContents
        call setreg(recordReg, playInfo.appendContents)
        exec "normal! @" . recordReg
    endif
    call setreg(recordReg, recordContent)
    call macrobatics#addToHistory(recordContent)
    set opfunc=macrobatics#play
endfunction

function! s:pushPlayInfo(reg, cnt)
    let item = {'reg': a:reg, 'cnt': a:cnt, 'prependContents': v:null, 'appendContents': v:null}
    call add(s:playInfoStack, item)
    return item
endfunction

function s:getMacroRegister(requestedReg)
    if a:requestedReg == "_" || a:requestedReg == macrobatics#getDefaultReg()
        return s:defaultMacroReg
    endif
    return a:requestedReg
endfunction

function! macrobatics#recordNew(reg)
    if s:isRecording
        let s:isRecording = 0
        " We use onRecordingComplete here instead of play because we don't actually
        " want to run the macro again after it is recorded
        set opfunc=macrobatics#onRecordingComplete
        return "qg@l"
    endif

    let recordReg = s:getMacroRegister(a:reg)

    call s:pushPlayInfo(recordReg, 1)

    let s:isRecording = 1
    return "q" . recordReg
endfunction

function! macrobatics#append(reg, cnt)
    call s:assert(!s:isRecording)
    call s:assert(a:cnt == 0 || a:cnt == 1)

    let recordReg = s:getMacroRegister(a:reg)

    let playInfo = s:pushPlayInfo(recordReg, 1)
    let playInfo.prependContents = getreg(recordReg)

    let s:isRecording = 1
    call feedkeys("q" . recordReg, 'nt')
    return "@" . recordReg
endfunction

function! macrobatics#prepend(reg, cnt)
    call s:assert(!s:isRecording)
    call s:assert(a:cnt == 0 || a:cnt == 1)

    let recordReg = s:getMacroRegister(a:reg)

    let playInfo = s:pushPlayInfo(recordReg, 1)
    let playInfo.appendContents = getreg(recordReg)

    let s:isRecording = 1
    echom "executing: " . "q" . recordReg
    return "q" . recordReg
endfunction

function! macrobatics#setupPlay(reg, cnt)
    let cnt = a:cnt > 0 ? a:cnt : 1
    let playReg = s:getMacroRegister(a:reg)
    call s:pushPlayInfo(playReg, cnt)
endfunction
