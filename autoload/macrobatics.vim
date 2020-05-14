
let s:defaultMacroReg = get(g:, 'Mac_DefaultRegister', 'm')
let s:maxItems = get(g:, 'Mac_MaxItems', 10)
let s:saveHistoryToShada = get(g:, 'Mac_SavePersistently', 0)
let s:displayMacroMaxWidth = get(g:, 'Mac_DisplayMacroMaxWidth', 80)
let s:macroFileExtension = get(g:, 'Mac_NamedMacroFileExtension', '.bin')
let s:fuzzySearcher =  get(g:, 'Mac_NamedMacroFuzzySearcher', v:null)
let s:namedMacrosSaveDirectory = v:null
let s:defaultFuzzySearchers = ['clap', 'fzf']
let s:previousCompleteOpt=v:null
let s:autoFinishRecordAfterPlay = 0
let s:namedMacroCache = {}
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

function! s:removeFromHistory(entry)
    let history = macrobatics#getHistory()

    let i = 0
    for candidate in history
        if candidate == a:entry
            call remove(history, i)
            return 1
        endif
        let i += 1
    endfor
    return 0
endfunction

function! s:addToHistory(entry)
    let history = macrobatics#getHistory()

    if len(history) == 0 || history[0] != a:entry
        call s:removeFromHistory(a:entry)
        call insert(history, a:entry, 0)
        if len(history) > s:maxItems
            call remove(history, s:maxItems, -1)
        endif
    endif
endfunction

function! macrobatics#displayNamedMacros()
    echohl WarningMsg | echo "--- Named Macros ---" | echohl None
    for macro in macrobatics#getNamedMacros()
        echo  macro
    endfor
endfunction

function! macrobatics#displayHistory()
    echohl WarningMsg | echo "--- Macro History ---" | echohl None
    let i = 0
    for macro in macrobatics#getHistory()
        call s:displayMacro(macro, i)
        let i += 1
    endfor
endfunction

function! s:getMacroPathFromName(directoryPath, name)
    return printf("%s/%s%s", a:directoryPath, a:name, s:macroFileExtension)
endfunction

function! s:getMacroNameFromPath(filePath)
    let matchIndex = match(a:filePath, '\v[\\/]\zs[^\\/]*' . s:macroFileExtension . '$')
    call s:assert(matchIndex != -1)
    return strpart(a:filePath, matchIndex, len(a:filePath) - matchIndex - len(s:macroFileExtension))
endfunction

function! macrobatics#getNamedMacros()
    let dirs = s:getNamedMacrosDirs()
    let namesSet = {}
    for dir in dirs
        for filePath in globpath(dir, "*" . s:macroFileExtension, 0, 1)
            let name = s:getMacroNameFromPath(filePath)
            let namesSet[name] = 1
        endfor
    endfor
    return keys(namesSet)
endfunction

function! macrobatics#copyCurrentMacroToRegister(cnt, reg)
    if a:cnt == 0
        let content = getreg(s:defaultMacroReg)
    else
        let history = macrobatics#getHistory()
        let content = history[a:cnt]
    endif

    call setreg(a:reg, content)
    call s:echo("Stored to '%s' register: %s", a:reg, s:formatMacro(content))
endfunction

" This was copied from coc.nvim
function! s:chooseGlobalMacroSaveDirectory()
    let saveDir = get(g:, 'Mac_NamedMacrosDirectory', v:null)
    if saveDir is v:null
        if exists('$XDG_CONFIG_HOME')
          let saveDir = resolve($XDG_CONFIG_HOME."/macrobatics")
        else
          if has('win32') || has('win64')
            let saveDir = resolve(expand('~/AppData/Local/macrobatics'))
          else
            let saveDir = resolve(expand('~/.config/macrobatics'))
          endif
        endif
    else
        let saveDir = resolve(expand(saveDir))
    endif
    return saveDir
endfunction

function! s:getBufferLocalNamedMacrosDirs()
    return get(b:, 'Mac_NamedMacrosDirectories', [])
endfunction

function! macrobatics#getGlobalNamedMacrosDir()
    if s:namedMacrosSaveDirectory is v:null
        let s:namedMacrosSaveDirectory = s:chooseGlobalMacroSaveDirectory()
    endif
    return s:namedMacrosSaveDirectory
endfunction

function! s:getNamedMacrosDirs()
    " Place buffer local dirs first so they override global macros
    return s:getBufferLocalNamedMacrosDirs() + [macrobatics#getGlobalNamedMacrosDir()] 
endfunction

function s:echo(...)
    echo call('printf', a:000)
endfunction

function s:echom(...)
    echom call('printf', a:000)
endfunction

function! macrobatics#saveCurrentMacroToDirectory(dirPath)
    let name = input('Macro Name:')
    if len(name) == 0
        " View this as a cancel
        return
    endif
    " Without this the echo below appears on the same line as input
    echo "\r"
    " Ensure directory exists
    call mkdir(a:dirPath, "p", 0755)
    let filePath = s:getMacroPathFromName(a:dirPath, name)
    if filereadable(filePath) && confirm(
            \ printf("Found existing macro with name '%s'. Overwrite?", name),
            \ "&Yes\n&No", 2, "Question") != 1
        " Any response except yes is viewed as a cancel
        return
    endif
    let macroData = getreg(s:defaultMacroReg)
    call writefile([macroData], filePath, 'b')
    call s:echo("Saved macro with name '%s'", name)
endfunction

function! macrobatics#nameCurrentMacro()
    call macrobatics#saveCurrentMacroToDirectory(macrobatics#getGlobalNamedMacrosDir())
endfunction

function! s:getFuzzySearchMethod()
    if s:fuzzySearcher is v:null
        for fuzzyName in s:defaultFuzzySearchers
            if call("macrobatics#" . fuzzyName . "#isAvailable", [])
                let s:fuzzySearcher = fuzzyName
                break
            endif
        endfor

        call s:assert(!(s:fuzzySearcher is v:null), 
            \ "Could not find an available fuzzy searcher for macrobatics! "
            \ . "This can also be set explicitly with 'Mac_NamedMacroFuzzySearcher'. "
            \ . "See documentation for details.")
    endif

    return s:fuzzySearcher
endfunction

function! macrobatics#searchThenPlayNamedMacro(cnt)
    let cnt = a:cnt > 0 ? a:cnt : 1
    call call("macrobatics#" . s:getFuzzySearchMethod() . "#playNamedMacro", [cnt])
endfunction

function! macrobatics#searchThenSelectNamedMacro()
    call call("macrobatics#" . s:getFuzzySearchMethod() . "#selectNamedMacro", [])
endfunction

function s:inputMacroParameters(macroName)
    let params = get(g:, 'Mac_NamedMacroParameters', {})
    if !has_key(params, a:macroName)
        return 1
    endif
    
    for item in items(params[a:macroName])
        let paramReg = item[0]
        let paramName = item[1]
        let value = input(paramName . ": ")
        if len(value) == 0
            return 0
        endif
        call s:assert(len(paramReg) == 1, "Expected register value for macro parameter")
        call s:assert(paramReg != s:defaultMacroReg, "Macro parameter register cannot be the same as the macro register")
        call setreg(paramReg, value)
    endfor
    return 1
endfunction

function! macrobatics#playNamedMacro(name, ...)
    if !s:inputMacroParameters(a:name)
        call s:echo("Cancelled macro '%s'", a:name)
        return
    endif
    let cnt = a:0 ? a:1 : 1
    call macrobatics#selectNamedMacro(a:name)
    call macrobatics#play(s:defaultMacroReg, cnt)
endfunction

function s:loadNamedMacroData(filePath)
    let macroDataList = readfile(a:filePath, 'b')
    call s:assert(len(macroDataList) == 1)
    return macroDataList[0]
endfunction

function! macrobatics#tryGetFilePathForNameMacro(name)
    for macroDir in s:getNamedMacrosDirs()
        let filePath = s:getMacroPathFromName(macroDir, a:name)
        if filereadable(filePath)
            return filePath
        endif
    endfor
    return v:null
endfunction

function! macrobatics#selectNamedMacro(name)
    let macInfo = get(s:namedMacroCache, a:name, v:null)
    let filePath = macrobatics#tryGetFilePathForNameMacro(a:name)
    let isValidFile = !(filePath is v:null) && filereadable(filePath)
    if macInfo is v:null
        call s:assert(isValidFile,
            \ "Could not find macro with name '%s'!", a:name)
        let macInfo = {'data':s:loadNamedMacroData(filePath), 'timestamp':getftime(filePath)}
        let s:namedMacroCache[a:name] = macInfo
    else
        " Auto reload if the file is changed
        " This would occur when over-writing from the same or different vim instance
        if isValidFile && macInfo.timestamp != getftime(filePath)
            let macInfo.data = s:loadNamedMacroData(filePath)
        endif
    endif

    call macrobatics#setCurrent(macInfo.data)
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
    call s:echo("Cleared macro history of %s entries", previousSize)
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
    call s:echo("Current Macro: %s", s:formatMacro(history[0]))
endfunction

function! s:onRecordingFullyComplete()
    call s:resetPopupMenu()
    let info = s:recordInfo
    let s:recordInfo = v:null
    let fullContent = info.recordContent
    if !(info.prependContents is v:null)
        let fullContent = info.prependContents . fullContent
    endif
    if !(info.appendContents is v:null)
        let fullContent = fullContent . info.appendContents
    endif
    if fullContent == ''
        " In this case, reset the macro register and do not add to history
        " View this as a cancel
        call setreg(info.reg, info.previousContents)
    else
        call setreg(info.reg, fullContent)
        if !(info.prependContents is v:null) || !(info.appendContents is v:null)
            call s:removeFromHistory(info.previousContents)
        endif
        call s:addToHistory(fullContent)
        let s:repeatMacro = s:createPlayInfo(info.reg, 1)
        call s:markForRepeat()
    endif
endfunction

function! s:markForRepeat()
    silent! call repeat#set("\<plug>(Mac__RepeatLast)")
    " Force disable the logic in vim-repeat that waits for CursorMove
    " This cause a bug where if you make a change immediately after recording a macro
    " and then attempt to repeat that change it will repeat the macro instead
    " Not sure why this logic is necessary in vim-repeat
    augroup repeat_custom_motion
        autocmd!
    augroup END
endfunction

function! macrobatics#onRecordingComplete(_)

    if (s:recordInfo is v:null)
        call s:resetPopupMenu()
        " This can happen when repeat.vim is not installed, so just do nothing in this case
        return
    endif

    let info = s:recordInfo
    let info.recordContent = getreg(info.reg)
    if !(info.appendContents is v:null)
        let s:autoFinishRecordAfterPlay = 1
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

    call s:temporarilyDisablePopupMenu()
    let s:isRecording = 1
    return "q" . recordReg
endfunction

function! macrobatics#append(reg, cnt)
    call s:assert(!s:isRecording)
    call s:assert(a:cnt == 0 || a:cnt == 1)

    let recordReg = s:getMacroRegister(a:reg)
    call s:setRecordInfo(recordReg, getreg(recordReg), v:null)

    call s:temporarilyDisablePopupMenu()
    let s:isRecording = 1
    " I don't know why this works and yet 
    " call feedkeys("@" . recordReg . "q" . recordReg, 'n') does not
    " and neither does changing the map to be an <expr>
    " and then returning "@" . recordReg . "q" . recordReg
    " Also, for some reason, reversing these lines and removing the 'i'
    " works too
    call feedkeys("@" . recordReg, 'ni')
    call feedkeys("q" . recordReg, 'ni')
endfunction

function! s:resetPopupMenu()
    call s:assert(s:previousCompleteOpt != v:null)
    exec "set completeopt=" . s:previousCompleteOpt 
    let s:previousCompleteOpt=v:null
endfunction

function! s:temporarilyDisablePopupMenu()
    let s:previousCompleteOpt=&completeopt
    set completeopt=noselect
endfunction

function! macrobatics#prepend(reg, cnt)
    call s:assert(!s:isRecording)
    call s:assert(a:cnt == 0 || a:cnt == 1)

    let recordReg = s:getMacroRegister(a:reg)

    call s:setRecordInfo(recordReg, v:null, getreg(recordReg))

    call s:temporarilyDisablePopupMenu()
    let s:isRecording = 1
    call feedkeys("q" . recordReg, 'n')
endfunction

function! s:createPlayInfo(reg, cnt)
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

function! s:assert(value, ...)
    if !a:value
        if len(a:000) == 0
            throw 'Assert hit inside vim-macrobatics plugin'
        else
            throw call('printf', a:000)
        endif
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

function! s:onPlayMacroCompleted()
    let s:macrosInProgress -= 1

    call s:assert(s:macrosInProgress >= 0)

    if s:macrosInProgress == 0
        if s:autoFinishRecordAfterPlay
            let s:autoFinishRecordAfterPlay = 0
            call s:assert(!(s:recordInfo is v:null))
            call s:assert(!(s:recordInfo.appendContents is v:null))
            call s:onRecordingFullyComplete()
        else
            call s:markForRepeat()
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

function! s:getMacroRegister(requestedReg)
    if a:requestedReg == "_" || a:requestedReg == s:getDefaultReg()
        return s:defaultMacroReg
    endif
    return a:requestedReg
endfunction

function! s:setRecordInfo(reg, prependContents, appendContents)
    call s:assert(s:recordInfo is v:null)
    let s:recordInfo = {'reg': a:reg, 'prependContents': a:prependContents, 'appendContents': a:appendContents, 'previousContents': getreg(a:reg)}
endfunction

