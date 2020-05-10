
let s:defaultMacroReg = get(g:, 'Mac_DefaultRegister', 'm')
let s:maxItems = get(g:, 'Mac_MaxItems', 10)
let s:saveHistoryToShada = get(g:, 'Mac_SavePersistently', 0)
let s:displayMacroMaxWidth = get(g:, 'Mac_DisplayMacroMaxWidth', 80)

let s:macrosInProgress = 0
let s:repeatMacro = v:null

let s:isRecording = 0
let s:recordInfo = v:null

nnoremap <silent> <plug>(Mac__OnPlayMacroCompleted) :<c-u>call <sid>onPlayMacroCompleted()<cr>
nnoremap <silent> <plug>(Mac__RepeatLast) :<c-u>call <sid>repeatLast()<cr>

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

function! macrobatics#getRecordRegister()
    return s:defaultMacroReg
endfunction

function! macrobatics#getHistory()
    if s:saveHistoryToShada
        return g:MACROBATICS_HISTORY
    endif

    return s:history
endfunction

function! macrobatics#setCurrent(entry)
    call setreg(s:defaultMacroReg, a:entry)
    call s:addToHistory(a:entry)
endfunction

function! s:addToHistory(entry)
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
    call s:addToHistory(getreg(s:defaultMacroReg))
endfunction

function! macrobatics#clearHistory()
    let history = macrobatics#getHistory()
    let previousSize = len(history)
    call remove(history, 0, -1)
    call s:addToHistory(getreg(s:defaultMacroReg))
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

function s:onRecordingFullyComplete()
    let info = s:recordInfo
    let s:recordInfo = v:null
    let fullContent = info.recordContent
    if !(info.prependContents is v:null)
        let fullContent = info.prependContents . fullContent
    endif
    if !(info.appendContents is v:null)
        let fullContent = fullContent . info.appendContents
    endif
    call setreg(info.reg, fullContent)
    call s:addToHistory(fullContent)
    let s:repeatMacro = s:createPlayInfo(info.reg, 1)
    silent! call repeat#set("\<plug>(Mac__RepeatLast)")
endfunction

function! macrobatics#onRecordingComplete(_)

    if (s:recordInfo is v:null)
        " This can happen when repeat.vim is not installed, so just do nothing in this case
        return
    endif

    let info = s:recordInfo
    let info.recordContent = getreg(info.reg)
    if !(info.appendContents is v:null)
        call setreg(info.reg, info.appendContents)
        call macrobatics#play(info.reg, 1)
    else
        call s:onRecordingFullyComplete()
    endif
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
    call s:setRecordInfo(recordReg, v:null, v:null)
    let s:isRecording = 1
    return "q" . recordReg
endfunction

function! macrobatics#append(reg, cnt)
    call s:assert(!s:isRecording)
    call s:assert(a:cnt == 0 || a:cnt == 1)

    let recordReg = s:getMacroRegister(a:reg)
    call s:setRecordInfo(recordReg, getreg(recordReg), v:null)

    let s:isRecording = 1
    call feedkeys("q" . recordReg, 'nt')
    return "@" . recordReg
endfunction

function! macrobatics#prepend(reg, cnt)
    call s:assert(!s:isRecording)
    call s:assert(a:cnt == 0 || a:cnt == 1)

    let recordReg = s:getMacroRegister(a:reg)

    call s:setRecordInfo(recordReg, v:null, getreg(recordReg))

    let s:isRecording = 1
    return "q" . recordReg
endfunction

function s:createPlayInfo(reg, cnt)
    return { 
        \ 'reg': s:getMacroRegister(a:reg),
        \ 'cnt': a:cnt > 0 ? a:cnt : 1
        \ }
endfunction

function! s:repeatLast()
    call macrobatics#play(s:repeatMacro.reg, s:repeatMacro.cnt)
endfunction

function! macrobatics#play(reg, cnt)
    let playInfo = s:createPlayInfo(
        \ s:getMacroRegister(a:reg), a:cnt > 0 ? a:cnt : 1) 

    if s:macrosInProgress == 0
        let s:repeatMacro = playInfo
    endif

    let s:macrosInProgress += 1

    " We need to use 'i' to allow nested macros to work
    " Also note that using `normal! @` instead of feedkeys
    " Doesn't work sometimes
    call feedkeys(playInfo.cnt . "@" . playInfo.reg, 'ni')
    " Don't need to use i here though, because we only want this to run at the very end
    " Since otherwise it will overwrite s:repeatMacro
    call feedkeys("\<plug>(Mac__OnPlayMacroCompleted)", 'm')
endfunction

function s:assert(value, ...)
    if !a:value
        let message = a:0 ? a:1 : 'Assert hit inside vim-macrobatics plugin'
        throw message
    endif
endfunction

function! s:getDefaultReg()
    let clipboardFlags = split(&clipboard, ',')
    if index(clipboardFlags, 'unnamedplus') >= 0
        return "+"
    elseif index(clipboardFlags, 'unnamed') >= 0
        return "*"
    else
        return "\""
    endif
endfunction

function s:onPlayMacroCompleted()
    let s:macrosInProgress -= 1

    call s:assert(s:macrosInProgress >= 0)

    if s:macrosInProgress == 0
        let info = s:recordInfo
        if info is v:null
            silent! call repeat#set("\<plug>(Mac__RepeatLast)")
        else
            call s:assert(!(info.appendContents is v:null))
            call s:onRecordingFullyComplete()
        endif
    endif
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

function s:getMacroRegister(requestedReg)
    if a:requestedReg == "_" || a:requestedReg == s:getDefaultReg()
        return s:defaultMacroReg
    endif
    return a:requestedReg
endfunction

function s:setRecordInfo(reg, prependContents, appendContents)
    call s:assert(s:recordInfo is v:null)
    let s:recordInfo = {'reg': a:reg, 'prependContents': a:prependContents, 'appendContents': a:appendContents, 'previousContents': getreg(a:reg)}
endfunction

