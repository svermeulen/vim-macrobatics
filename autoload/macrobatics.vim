
let s:defaultMacroReg = get(g:, 'Mac_DefaultRegister', 'm')
let s:playByNameMacroReg = get(g:, 'Mac_PlayByNameRegister', 'n')
let s:maxItems = get(g:, 'Mac_MaxItems', 10)
let s:saveHistoryToShada = get(g:, 'Mac_SavePersistently', 0)
let s:displayMacroMaxWidth = get(g:, 'Mac_DisplayMacroMaxWidth', 80)
let s:macroFileExtension = get(g:, 'Mac_NamedMacroFileExtension', '.bin')
let s:macroParameterInfoFileExtension = get(g:, 'Mac_NamedMacroParameterInfoFileExtension', '.txt')
let s:fuzzySearcher =  get(g:, 'Mac_NamedMacroFuzzySearcher', v:null)
let s:globalNamedMacrosSaveDirectory = v:null
let s:defaultFuzzySearchers = ['fzf', 'clap']
let s:previousCompleteOpt=v:null
let s:autoFinishRecordAfterPlay = 0
let s:namedMacroCache = {}
let s:namedMacrosForSession = {}
let s:namedMacroParamInfosForSession = {}
let s:macrosInProgress = 0
let s:repeatMacro = v:null
let s:isRecording = 0
let s:recordInfo = v:null
let s:queuedMacroInfo = v:null

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

function! macrobatics#isPlayingMacro()
    return s:macrosInProgress > 0
endfunction

function! macrobatics#getHistory()
    if s:saveHistoryToShada
        return g:MACROBATICS_HISTORY
    endif

    return s:history
endfunction

function! macrobatics#setCurrent(entry)
    call s:updateMacroReg(s:defaultMacroReg, a:entry)
    call s:addToHistory(a:entry)
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

function! macrobatics#getNamedMacros()
    let dirs = s:getNamedMacrosDirs()
    let namesSet = {}
    for name in keys(s:namedMacrosForSession)
        let namesSet[name] = 1
    endfor
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

    call s:updateMacroReg(a:reg, content)
    call s:echo("Stored to '%s' register: %s", a:reg, s:formatMacro(content))
endfunction

function! macrobatics#getGlobalNamedMacrosDir()
    if s:globalNamedMacrosSaveDirectory is v:null
        let s:globalNamedMacrosSaveDirectory = s:chooseGlobalMacroSaveDirectory()
    endif
    return s:globalNamedMacrosSaveDirectory
endfunction

function! macrobatics#saveCurrentMacroToDirectory(dirPath)
    call s:saveCurrentMacroToDirectory(resolve(expand(a:dirPath)))
endfunction

function! macrobatics#nameCurrentMacroForCurrentSession()
    let name = input('Macro Name:')
    if len(name) == 0
        echo "Save macro cancelled"
        return
    endif
    " Without this the echo below appears on the same line as input
    echo "\r"
    let overwriteParams = v:true
    if has_key(s:namedMacrosForSession, name)
        if confirm(printf(
                \ "Found existing macro with name '%s'. Overwrite?", name),
                \ "&Yes\n&No", 2, "Question") != 1
            " Any response except yes is viewed as a cancel
            echo "Save macro cancelled"
            return
        endif
        if has_key(s:namedMacroParamInfosForSession, name)
            let choice = confirm("Re-use previously saved parameter settings?", "&Yes\n&No", 2, "Question")
            if choice == 0
                echo "Save macro cancelled"
                return
            endif
            if choice == 1
                let overwriteParams = v:false
            endif
        endif
    endif
    let s:namedMacrosForSession[name] = getreg(s:defaultMacroReg)
    if overwriteParams
        let s:namedMacroParamInfosForSession[name] = s:promptForParameterInfo()
    endif
    call s:echo("Saved macro with name '%s'", name)
endfunction

function! macrobatics#nameCurrentMacroForFileType()
    let saveDir = s:getFileTypeNamedMacrosDirs()[0]
    call s:saveCurrentMacroToDirectory(saveDir)
endfunction

function! macrobatics#renameNamedMacro(macroName)
    let newName = input('New Name:', a:macroName)
    echo "\r"
    if len(newName) == 0
        " View this as a cancel
        echo "Save macro cancelled"
        return
    endif
    if has_key(s:namedMacrosForSession, a:macroName)
        if has_key(s:namedMacrosForSession, newName) && confirm(printf(
                \ "Found existing macro with name '%s'. Overwrite?", newName),
                \ "&Yes\n&No", 2, "Question") != 1
            " Any response except yes is viewed as a cancel
            echo "Save macro cancelled"
            return
        endif
        let s:namedMacrosForSession[newName] = s:namedMacrosForSession[a:macroName]
        let s:namedMacroParamInfosForSession[newName] = s:namedMacroParamInfosForSession[a:macroName]
        unlet s:namedMacrosForSession[a:macroName]
        unlet s:namedMacroParamInfosForSession[a:macroName]
        return
    endif
    let macroDir = s:findNamedMacroDir(a:macroName)
    let newFilePath = s:constructMacroPath(macroDir, newName)
    if filereadable(newFilePath) && confirm(
            \ printf("Found existing macro with name '%s'. Overwrite?", newName),
            \ "&Yes\n&No", 2, "Question") != 1
            " Any response except yes is viewed as a cancel
        echo "Save macro cancelled"
        return
    endif
    let dataFilePath = s:constructMacroPath(macroDir, a:macroName)
    let paramInfoListFilePath = s:constructMacroParameterFilePath(macroDir, a:macroName)
    call s:assert(filereadable(dataFilePath))
    let macroData = s:loadNamedMacroData(dataFilePath)
    let paramInfoList = s:tryLoadNamedMacroParameterInfoFromFile(paramInfoListFilePath)
    call delete(dataFilePath)
    call delete(paramInfoListFilePath)
    call s:saveMacroFile(macroData, newFilePath)
    if (!(paramInfoList is v:null))
        let newParamInfoListFilePath = s:constructMacroParameterFilePath(macroDir, newName)
        call s:saveMacroParameterFile(paramInfoList, newParamInfoListFilePath)
    endif
    call s:echo("Renamed macro from '%s' to '%s'", a:macroName, newName)
endfunction

function! macrobatics#overwriteNamedMacro(macroName)
    if has_key(s:namedMacrosForSession, a:macroName)
        let paramInfo = s:namedMacroParamInfosForSession[a:macroName]
        let overwriteParams = v:true
        if len(paramInfo) > 0
            let choice = confirm("Re-use previously saved parameter settings?", "&Yes\n&No", 2, "Question")
            if choice == 0
                echo "Save macro cancelled"
                return
            endif
            if choice == 1
                let overwriteParams = v:false
            endif
        endif
        if overwriteParams
            let s:namedMacroParamInfosForSession[a:macroName] = s:promptForParameterInfo()
        endif
        let s:namedMacrosForSession[a:macroName] = getreg(s:defaultMacroReg)
        return
    endif
    let macroDir = s:findNamedMacroDir(a:macroName)
    let filePath = s:constructMacroPath(macroDir, a:macroName)
    call s:assert(filereadable(filePath))
    let paramFilePath = s:constructMacroParameterFilePath(macroDir, a:macroName)
    let overwriteParamFile = v:true
    if filereadable(paramFilePath)
        let choice = confirm("Re-use previously saved parameter settings?", "&Yes\n&No", 2, "Question")
        if choice == 0
            echo "Save macro cancelled"
            return
        endif
        if choice == 1
            let overwriteParamFile = v:false
        endif
    endif
    let macroData = getreg(s:defaultMacroReg)
    call s:saveMacroFile(macroData, filePath)
    if overwriteParamFile
        call s:saveMacroParameterFile(s:promptForParameterInfo(), paramFilePath)
    endif
    call s:echo("Updated macro with name '%s'", a:macroName)
endfunction

function! macrobatics#deleteNamedMacro(macroName)
    if has_key(s:namedMacrosForSession, a:macroName)
        unlet s:namedMacrosForSession[a:macroName]
        unlet s:namedMacroParamInfosForSession[a:macroName]
        return
    endif
    let macroDir = s:findNamedMacroDir(a:macroName)
    let paramFilePath = s:constructMacroParameterFilePath(macroDir, a:macroName)
    if filereadable(paramFilePath)
        call delete(paramFilePath)
    endif
    let filePath = s:constructMacroPath(macroDir, a:macroName)
    if filereadable(filePath)
        call delete(filePath)
        call s:echo("Deleted macro with name '%s'", a:macroName)
    endif
endfunction

function! macrobatics#searchAndRenameNamedMacro()
    call s:chooseNamedMacro({choice -> macrobatics#renameNamedMacro(choice)})
endfunction

function! macrobatics#searchAndDeleteNamedMacro()
    call s:chooseNamedMacro({choice -> macrobatics#deleteNamedMacro(choice)})
endfunction

function! macrobatics#searchAndOverwriteNamedMacro()
    call s:chooseNamedMacro({choice -> macrobatics#overwriteNamedMacro(choice)})
endfunction

function! macrobatics#nameCurrentMacro()
    call s:saveCurrentMacroToDirectory(macrobatics#getGlobalNamedMacrosDir())
endfunction

function! s:makeChoice(values, sink)
    if macrobatics#isPlayingMacro()
        " Require that they type it in exactly when recording, for this to work
        call a:sink(input(''))
    else
        let makeChoiceArgs = v:null

        if type(a:values) == type({})
            let makeChoiceArgs = [keys(a:values), {choice -> a:sink(a:values[choice])}]
        else
            let makeChoiceArgs = [a:values, a:sink]
        endif

        call call("macrobatics#" . s:getFuzzySearchMethod() . "#makeChoice", makeChoiceArgs)
    endif
endfunction

function! s:chooseNamedMacro(sink)
    call s:makeChoice(macrobatics#getNamedMacros(), a:sink)
endfunction

function! macrobatics#searchThenPlayNamedMacro(cnt)
    let playCount = a:cnt > 0 ? a:cnt : 1
    call s:chooseNamedMacro({choice -> macrobatics#playNamedMacro(choice, playCount)})
endfunction

function! macrobatics#searchThenSelectNamedMacro()
    call s:chooseNamedMacro(function('macrobatics#selectNamedMacro'))
endfunction

function! s:updateMacroReg(reg, value)
    " It's important that we always set in charwise mode, otherwise it can add unnecessary
    " newline characters to the end of the macro, when it ends with a ^M character
    call setreg(a:reg, a:value, 'c')
endfunction

function s:paramValueSink(reg, value)
    call s:assert(len(a:reg) == 1, "Expected register value for macro parameter")
    call s:updateMacroReg(a:reg, a:value)
    call s:queuedMacroNext()
endfunction

function s:queuedMacroNext()
    let info = s:queuedMacroInfo
    call s:assert(!(info is v:null))

    if len(info.paramInputQueue) == 0
        call s:updateMacroReg(info.destinationRegister, info.macroData)
        if info.destinationRegister == s:defaultMacroReg
            call s:addToHistory(info.macroData)
        endif
        if (info.autoplay)
            call macrobatics#play(info.destinationRegister, info.playCount)
        endif
        return
    endif

    let paramInfo = remove(info.paramInputQueue, 0)

    call s:assert(type(paramInfo) == v:t_dict,
        \ "Expected named parameter info for macro '%s' to be type dictionary", info.macroName)

    if has_key(paramInfo, 'value')
        call s:paramValueSink(paramInfo.register, paramInfo.value)
    elseif has_key(paramInfo, 'valueProvider')
        if get(paramInfo, 'is_async', 0)
            call paramInfo.valueProvider(paramInfo.name, {choice -> s:paramValueSink(paramInfo.register, choice)})
        else
            call s:paramValueSink(paramInfo.register, paramInfo.valueProvider(paramInfo.name))
        endif
    elseif has_key(paramInfo, 'choices')
        call s:echo("Choose value for '%s'", paramInfo.name)
        call s:makeChoice(paramInfo.choices, {choice -> s:paramValueSink(paramInfo.register, choice)})
    elseif has_key(paramInfo, 'choicesProvider')
        if get(paramInfo, 'is_async', 0)
            call s:echo("Choose value for '%s'", paramInfo.name)
            call paramInfo.choicesProvider(paramInfo.name, {
                \ choices -> s:makeChoice(
                    \ choices, {choice -> s:paramValueSink(paramInfo.register, choice)})})
        else
            call s:makeChoice(paramInfo.choicesProvider(paramInfo.name),
                \ {choice -> s:paramValueSink(paramInfo.register, choice)})
        endif
    elseif has_key(paramInfo, 'name')
        let paramValue = input(paramInfo.name . ": ")
        if len(paramValue) == 0
            call s:echo("Cancelled macro '%s'", info.macroName)
            return
        endif
        call s:assert(paramInfo.register != info.destinationRegister, "Macro parameter register cannot be the same as the macro register")
        call s:paramValueSink(paramInfo.register, paramValue)
    else
        call s:assert(0,
            \ "Unexpected value for macro '%s' and register '%s'", info.macroName, paramInfo.register)
    endif
endfunction

function! macrobatics#playNamedMacro(name, ...)
    let playCount = a:0 ? a:1 : 1
    call s:processNamedMacro(a:name, 1, s:playByNameMacroReg, playCount)
endfunction

function! s:getPlayMacroInfoForName(name)
    if has_key(s:namedMacrosForSession, a:name)
        return {
            \ 'data': s:namedMacrosForSession[a:name],
            \ 'paramInfoList': s:namedMacroParamInfosForSession[a:name],
            \ }
    endif

    let macroDir = s:findNamedMacroDir(a:name)
    let dataFilePath = s:constructMacroPath(macroDir, a:name)
    let paramInfoListFilePath = s:constructMacroParameterFilePath(macroDir, a:name)
    let cache = s:getMacroCacheForDir(macroDir)
    let cachedInfo = get(cache, a:name, v:null)
    if cachedInfo is v:null
        call s:assert(filereadable(dataFilePath),
            \ "Could not find macro with name '%s'!", a:name)
        let cachedInfo = {
            \ 'data':s:loadNamedMacroData(dataFilePath),
            \ 'timestamp':getftime(dataFilePath),
            \ 'paramInfoListFromFile':s:tryLoadNamedMacroParameterInfoFromFile(paramInfoListFilePath),
            \ }
        let cache[a:name] = cachedInfo
    else
        let currentFileTime = getftime(dataFilePath)
        " Auto reload if the file is changed
        " This would occur when over-writing from the same or different vim instance
        if filereadable(dataFilePath) && cachedInfo.timestamp != currentFileTime
            let cachedInfo.data = s:loadNamedMacroData(dataFilePath)
            let cachedInfo.paramInfoListFromFile = s:tryLoadNamedMacroParameterInfoFromFile(paramInfoListFilePath)
            let cachedInfo.timestamp = currentFileTime
        endif
    endif
    let result = {'data': cachedInfo.data}
    " Reload from settings every time
    let result.paramInfoList = s:tryGetMacroParametersInfoFromSettings(a:name)
    if result.paramInfoList is v:null
        let result.paramInfoList = cachedInfo.paramInfoListFromFile
        if result.paramInfoList is v:null
            let result.paramInfoList = []
        endif
    endif
    return result
endfunction

function s:tryGetMacroParametersInfoFromSettings(name)
    let bufferLocalMap = get(b:, 'Mac_NamedMacroParameters', {})
    if has_key(bufferLocalMap, a:name)
        return bufferLocalMap[a:name]
    endif

    let fileTypeMap = get(g:, 'Mac_NamedMacroParametersByFileType', {})
    for fileType in s:getCurrentFileTypes()
        let fileTypeParamMap = get(fileTypeMap, fileType, v:null)
        if !(fileTypeParamMap is v:null) && has_key(fileTypeParamMap, a:name)
            return fileTypeParamMap[a:name]
        endif
    endfor

    let globalMap = get(g:, 'Mac_NamedMacroParameters', {})
    return get(globalMap, a:name, v:null)
endfunction

function! s:processNamedMacro(macroName, autoplay, destinationRegister, cnt)
    let playInfo = s:getPlayMacroInfoForName(a:macroName)
    let s:queuedMacroInfo = {
        \   'macroData': playInfo.data,
        \   'macroName': a:macroName,
        \   'autoplay': a:autoplay,
        \   'playCount': a:cnt,
        \   'destinationRegister': a:destinationRegister,
        \   'paramInputQueue': copy(playInfo.paramInfoList),
        \ }

    call s:queuedMacroNext()
endfunction

function! macrobatics#selectNamedMacro(name)
    call s:processNamedMacro(a:name, 0, s:defaultMacroReg, 0)
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
        call s:updateMacroReg(s:defaultMacroReg, history[0])
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

    call s:updateMacroReg(s:defaultMacroReg, history[0])
    call s:echo("Current Macro: %s", s:formatMacro(history[0]))
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
        call s:updateMacroReg(info.reg, info.appendContents)
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

function! macrobatics#prepend(reg, cnt)
    call s:assert(!s:isRecording)
    call s:assert(a:cnt == 0 || a:cnt == 1)

    let recordReg = s:getMacroRegister(a:reg)

    call s:setRecordInfo(recordReg, v:null, getreg(recordReg))

    call s:temporarilyDisablePopupMenu()
    let s:isRecording = 1
    call feedkeys("q" . recordReg, 'n')
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

function! s:constructMacroPath(directoryPath, name)
    return a:directoryPath . '/' . a:name . s:macroFileExtension
endfunction

function! s:constructMacroParameterFilePath(directoryPath, name)
    return a:directoryPath . '/' . a:name . s:macroParameterInfoFileExtension
endfunction

function! s:getMacroNameFromPath(filePath)
    let matchIndex = match(a:filePath, '\v[\\/]\zs[^\\/]*' . s:macroFileExtension . '$')
    call s:assert(matchIndex != -1)
    return strpart(a:filePath, matchIndex, len(a:filePath) - matchIndex - len(s:macroFileExtension))
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

function s:getCurrentFileTypes()
    return split(&ft, '\.')
endfunction

function! s:getFileTypeNamedMacrosDirs()
    let dirs = []
    for ft in s:getCurrentFileTypes()
        call add(dirs, macrobatics#getGlobalNamedMacrosDir() . "/filetype/" . ft)
    endfor
    return dirs
endfunction

function! s:getBufferLocalNamedMacrosDirs()
    return get(b:, 'Mac_NamedMacrosDirectories', [])
endfunction

function! s:getNamedMacrosDirs()
    " Place buffer local dirs first so they override global macros
    return s:getBufferLocalNamedMacrosDirs() + s:getFileTypeNamedMacrosDirs() + [macrobatics#getGlobalNamedMacrosDir()] 
endfunction

function s:echo(...)
    echo call('printf', a:000)
endfunction

function s:echom(...)
    echom call('printf', a:000)
endfunction

function! s:saveMacroFile(macroData, filePath)
    call writefile([a:macroData], a:filePath, 'b')
endfunction

function! s:saveMacroParameterFile(paramInfo, filePath)
    call delete(a:filePath)
    if len(a:paramInfo) > 0
        call writefile([string(a:paramInfo)], a:filePath)
    endif
endfunction

function! s:promptForParameterInfo()
    let result = []
    while v:true
        let prompt = ""
        if len(result) == 0
            let prompt = "Add parameters?"
        else
            let prompt = "Add another parameter?"
        endif

        let choice = confirm(prompt, "&Yes\n&No", 2, "Question")

        if choice == 0
            return v:null
        endif

        if choice != 1
            break
        endif

        let paramInfo = {}

        while v:true
            let paramInfo.register = input('Parameter Register: ')

            if len(paramInfo.register) == 0
                " interpret this as a cancel
                return v:null
            endif

            if len(paramInfo.register) != 1
                echo "\nInvalid register given.  Please try again"
            else
                break
            endif
        endwhile

        let paramInfo.name = input('Parameter Name: ')

        if len(paramInfo.name) == 0
            " interpret this as a cancel
            return v:null
        endif

        call add(result, paramInfo)
    endwhile
    return result
endfunction

function! s:saveCurrentMacroToDirectory(dirPath)
    let name = input('Macro Name:')
    if len(name) == 0
        echo "Save macro cancelled"
        " View this as a cancel
        return
    endif
    " Without this the echo below appears on the same line as input
    echo "\r"
    " Ensure directory exists
    call mkdir(a:dirPath, "p", 0755)
    let dataFilePath = s:constructMacroPath(a:dirPath, name)
    let paramFilePath = s:constructMacroParameterFilePath(a:dirPath, name)
    let overwriteParamFile = v:true
    if filereadable(dataFilePath)
        if confirm(
                \ printf("Found existing macro with name '%s'. Overwrite?", name),
                \ "&Yes\n&No", 2, "Question") != 1
                " Any response except yes is viewed as a cancel
            echo "Save macro cancelled"
            return
        endif
        if filereadable(paramFilePath)
            let choice = confirm("Re-use previously saved parameter settings?", "&Yes\n&No", 2, "Question")
            if choice == 0
                echo "Save macro cancelled"
                return
            endif
            if choice == 1
                let overwriteParamFile = v:false
            endif
        endif
    endif
    let macroData = getreg(s:defaultMacroReg)
    call s:saveMacroFile(macroData, dataFilePath)
    if overwriteParamFile
        call s:saveMacroParameterFile(s:promptForParameterInfo(), paramFilePath)
    endif
    call s:echo("Saved macro with name '%s'", name)
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

function s:tryLoadNamedMacroParameterInfoFromFile(filePath)
    if !filereadable(a:filePath)
        return v:null
    endif
    let lines = readfile(a:filePath)
    call s:assert(len(lines) == 1)
    return eval(lines[0])
endfunction

function s:loadNamedMacroData(filePath)
    let macroDataList = readfile(a:filePath, 'b')
    call s:assert(len(macroDataList) == 1)
    return macroDataList[0]
endfunction

function s:findNamedMacroDir(name)
    for macroDir in s:getNamedMacrosDirs()
        let filePath = s:constructMacroPath(macroDir, a:name)
        if filereadable(filePath)
            return macroDir
        endif
    endfor
    return v:null
endfunction

function! s:getMacroCacheForDir(dirPath)
    let cache = get(s:namedMacroCache, a:dirPath, v:null)
    if cache is v:null
        let cache = {}
        let s:namedMacroCache[a:dirPath] = cache
    endif
    return cache
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
        call s:updateMacroReg(info.reg, info.previousContents)
    else
        call s:updateMacroReg(info.reg, fullContent)
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

function! s:resetPopupMenu()
    call s:assert(!(s:previousCompleteOpt is v:null))
    exec "set completeopt=" . s:previousCompleteOpt 
    let s:previousCompleteOpt=v:null
endfunction

function! s:temporarilyDisablePopupMenu()
    let s:previousCompleteOpt=&completeopt
    set completeopt=noselect
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
