
<img align="right" width="300" height="300" src="https://i.imgur.com/4BdGxV8.png">

# Macrobatics.vim

Macrobatics is a plugin for vim/neovim with the goal of making vim macros easier to use.

## Features

* Macro history, which can be navigated to play previously recorded macros
* Repeatable macros with the `.` operator
* Edit existing macros by appending or prepending content to it
* Named macros (saved persistently)
* Parameterized macros
* File type specific macros
* Written in pure vim-script
* Nested macros (create macros that play other macros)

## Installation

Install into vim using your preferred plugin manager (eg. [vim-plug](https://github.com/junegunn/vim-plug)).

Note that in order for macros to be repeatable with the `.` key, you will need to also install [tpope/vim-repeat](https://github.com/tpope/vim-repeat).

Note also that this plugin contains no default mappings and will have no effect until you add your own maps to one of the `<plug>` bindings.

For example, to add just the most basic functionality:

```viml
" Use <nowait> to override the default bindings which wait for another key press
nmap <nowait> q <plug>(Mac_Play)
nmap <nowait> gq <plug>(Mac_RecordNew)
```

We choose `q` here because we don't need it anymore when using this plugin.  Of course you might not want these specific bindings so you can use what makes sense for your config.

## Recording

With the above mappings, you can then press `gq` in Vim to begin recording a new macro.

However - Note that this mapping works differently than Vim's default way of recording a macro with the `q` key.  Unlike `q`, which is immediately followed by the register you want to record the macro to, `gq` will always record to the same register unless a register is explicitly given (eg. `"xgq` to record the macro to the `x` register).  By default this register is `m` however this is [configurable](#configuration).

It works this way just because specifying the register this way is more consistent with other actions in Vim like delete, yank, etc.

You can then stop recording by pressing the same keys again (`gq`)

## Playback and repeat

Again assuming the above plug mappings, you can replay the current macro by pressing `q`.  Similar to `gq`, you can also pass a register to use using the standard Vim convention (eg. `"xq` to execute the macro stored in the `x` register).   And when a register is not specified, it will play whatever macro is stored in the default macro register (`m`  by default but also [configurable](#configuration))

Assuming [vim-repeat](https://github.com/tpope/vim-repeat) is installed, after playback or recording, you can use the standard repeat operator `.` to replay the same macro again in a different spot.  Or, you can also execute `q` / `"xq` again for the same effect.

You can also pass a count to the play command to immediately repeat the macro a given number of times.

## Navigating history

To view the current history of macros, you can execute `:DisplayMacroHistory`.  By default the history contains a maximum of 10 items, however this is [configurable](#configuration).  You might also consider adding a binding for this:

```viml
nmap <leader>mh :DisplayMacroHistory<cr>
```

You will notice that the current macro is displayed alongside the `m` letter (the default value for `g:Mac_DefaultRegister`) and the rest are displayed as indexes into the history buffer.

To navigate the history, you can add bindings similar to the following to your `.vimrc`:

```viml
nmap [m <plug>(Mac_RotateBack)
nmap ]m <plug>(Mac_RotateForward)
```

Then if you execute `[m` or `]m` you should see a preview of the newly selected macro in status bar.  Note that you can also pass a count to the `[m` or `]m` commands.

## Editing Macros

In many cases, after recording a macro, you realize that you would like to tweak it slightly, usually by either inserting something in the beginning or adding something to the end.  Macrobatics provides two bindings to make this process very easy.  For example, you could add the following bindings to your `.vimrc`:

```viml
nmap <leader>ma <plug>(Mac_Append)
nmap <leader>mp <plug>(Mac_Prepend)
```

Then, you can append behaviour to the current macro by pressing `<leader>ma`.  This will play the current macro and then immediately enter record mode to record any new content to the end of it.

The prepend `<leader>mp` command works similarly except that it will enter record mode immediately, and then play the previous macro immediately after the recording is stopped.

Then in both cases, the macro will be updated to contain the new change.

## <a id="named-macros"></a>Named Macros

If you find yourself re-using a macro quite often, then you might consider giving it a name, and maybe even adding a direct key mapping for it.  You can do this by first adding the following mapping or similar to your `.vimrc`:

```viml
nmap <leader>mn <plug>(Mac_NameCurrentMacro)
```

Now, every time you create a new macro that you want to name, you can execute `<leader>mn`, and you will then be prompted to type in a name for it.  You will also be prompted for whether you want to [named parameters](#parameterized-macros) to which you can respond no for now.

Then, to add a mapping for it, you can add the following to your `.vimrc`:

```viml
nnoremap <leader>mf :call macrobatics#playNamedMacro('foo')<cr>
```

Where `foo` is the name that you typed into the prompt, and `<leader>tm` is the keys that you want to use for your custom macro.

## Playing/Selecting Named Macros Directly

In many cases, you will have named macros that you don't use enough to justify adding an entirely new key binding.  In these cases, it's helpful to be able to play the named macro by searching through the list of named macros whenever you need it instead.  This is often easier than needing to remember a key binding for something you rarely use.  You can do this by adding the following maps or similar to your `.vimrc`:

```viml
" me = macro execute
nmap <leader>me <plug>(Mac_SearchForNamedMacroAndPlay)
```

Note that in order for these maps to work, you must either have [fzf.vim](https://github.com/junegunn/fzf.vim) or [vim-clap](https://github.com/liuchengxu/vim-clap) installed.  If you would prefer using another fuzzy list plugin, feel free to [create a github issue for it](https://github.com/svermeulen/vim-macrobatics/issues/new).

Now, you can execute `<leader>me`, to directly choose the named macro you want to play!  Note that you can also pass a count to this command.

In some cases you might want to just select a named macro rather than playing it directly.  You can do that as well with the following mapping:

```viml
" ms = macro select
nmap <leader>ms <plug>(Mac_SearchForNamedMacroAndSelect)
```

Then you can execute `<leader>ms` to set the current macro to the chosen named macro.  This is especially useful when you want to edit a named macro by appending or prepending to it (or simply overwriting it entirely).   You can do this by naming it again using the same name as <a href="#named-macros">described above</a>.

## Updating Named Macros

In many cases you'll want to update some of your saved macros.  You could do this by executing `<plug>(Mac_NameCurrentMacro)` and typing in the exact name of the macro, but this can be error prone.  As an alternative, you can use the fuzzy finder popup to select the macro that you intend to overwrite:

```viml
" mo = macro overwrite
nmap <leader>mo <plug>(Mac_SearchForNamedMacroAndOverwrite)
```

## Deleting Named Macros

Simiarly, you might want to bind a key to delete saved macros using the fuzzy finder:

```viml
" md = macro delete
nmap <leader>md <plug>(Mac_SearchForNamedMacroAndDelete)
```

Or rename the macro:

```viml
" mr = macro rename
nmap <leader>mr <plug>(Mac_SearchForNamedMacroAndRename)
```

## Recommended configuration

If you decide to adopt all the recommended bindings discussed above, you can include the following in your `.vimrc`:

```viml
" Use <nowait> to override the default bindings which wait for another key press
nmap <nowait> q <plug>(Mac_Play)
nmap <nowait> gq <plug>(Mac_RecordNew)

nmap <leader>mh :DisplayMacroHistory<cr>

nmap [m <plug>(Mac_RotateBack)
nmap ]m <plug>(Mac_RotateForward)

nmap <leader>ma <plug>(Mac_Append)
nmap <leader>mp <plug>(Mac_Prepend)

nmap <leader>mng <plug>(Mac_NameCurrentMacro)
nmap <leader>mnf <plug>(Mac_NameCurrentMacroForFileType)
nmap <leader>mns <plug>(Mac_NameCurrentMacroForCurrentSession)

nmap <leader>mo <plug>(Mac_SearchForNamedMacroAndOverwrite)
nmap <leader>mr <plug>(Mac_SearchForNamedMacroAndRename)
nmap <leader>md <plug>(Mac_SearchForNamedMacroAndDelete)
nmap <leader>me <plug>(Mac_SearchForNamedMacroAndPlay)
nmap <leader>ms <plug>(Mac_SearchForNamedMacroAndSelect)
```

## Configuration

This is the default configuration:

```viml
let g:Mac_DefaultRegister = 'm'
let g:Mac_PlayByNameRegister = 'n'
let g:Mac_MaxItems = 10
let g:Mac_SavePersistently = 0
let g:Mac_DisplayMacroMaxWidth = 80
let g:Mac_NamedMacroFileExtension = '.bin'
let g:Mac_NamedMacroFuzzySearcher = v:null
let g:Mac_NamedMacrosDirectory = "~/.config/macrobatics"
" Note that for windows, the default is actually this:
" let g:Mac_NamedMacrosDirectory = "~/AppData/Local/macrobatics"
let g:Mac_NamedMacroParameters = {}
let g:Mac_NamedMacroParametersByFileType = {}
let g:Mac_FzfOptions = {'window': {'width': 0.75, 'height': 0.6}}
" Or for vim < 8:
" let g:Mac_FzfOptions = {'down': '40%'}
```

Note that including these lines in your `.vimrc` will have zero effect, because these are already the default values.  So you'll only need to include the lines which you customize.

The values are:
* `g:Mac_DefaultRegister` - The default register that macros get stored to when an explicit register is not given.
* `g:Mac_PlayByNameRegister` - The default register that macros get stored to when triggering <a href="#named-macros">named macros</a> via either `macrobatics#playNamedMacro` or `<plug>(Mac_SearchForNamedMacroAndPlay)`.  This is a different value from `Mac_DefaultRegister` so that `macrobatics#playNamedMacro` or `<plug>(Mac_SearchForNamedMacroAndPlay)` can themselves appear inside other named macros, without clobbering the current macro register.
* `g:Mac_MaxItems` - The number of macros to store in the history buffer.  This will also control the number of rows displayed when executing the `:Macros` command
* `g:Mac_SavePersistently` - When true, the macro history will be preserved even when restarting Vim.  Note: Requires Neovim.  See <a href="#shada-support">here</a> for details. Default: `0`.  Note that this setting is only necessary for macros that are in the history buffer.  Macros that you've assigned to a specific register should be automatically restored as part of built-in Vim behaviour.
* `g:Mac_DisplayMacroMaxWidth` - When macros are displayed by executing the `:Macros` command or when navigating history, this value will control the length at which the displayed macro is truncated at to fit on the screen.
* `g:Mac_NamedMacroFileExtension` - The file extension used for the macro files stored inside directory `g:Mac_NamedMacrosDirectory`
* `g:Mac_NamedMacroFuzzySearcher` - The type of search to use when selecting or executing named macros.  Currently, valid values are 'clap' (which will use [vim-clap](https://github.com/liuchengxu/vim-clap)) and 'fzf' (which will use [fzf.vim](https://github.com/junegunn/fzf.vim))
* `g:Mac_NamedMacrosDirectory` - The directory to store the files associated with [named macros](#named-macros)
* `g:Mac_NamedMacroParameters` - The list of [named parameters](#parameterized-macros) associated with any macros that you want to be parameterized.
* `g:Mac_NamedMacroParametersByFileType` - The list of [named parameters](#parameterized-macros) associated with any filetype specific macros that you want to be parameterized.
* `g:Mac_FzfOptions` - The options used to configure the fzf window that is used to choose named macros / named parameters.

## FAQ

* ### _How do I select a specific macro from the history after executing `:DisplayMacroHistory`?_

    The easiest way to do this is to execute `x[m` where `x` is the number associated with the macro as displayed by `:DisplayMacroHistory`


* ### _The repeat button '.' doesn't work when executed immediately after undo_

    <a id="repeat-bug"></a>This is due to a [bug with tpope/vim-repeat](https://github.com/tpope/vim-repeat/pull/66).  If this issue bothers you, you can use [my fork](https://github.com/svermeulen/vim-repeat) of vim-repeat instead which contains the fix.


* ### _Can I execute a macro from within a macro?_

    Yes!  This can be quite useful.  You can do this by either triggering a named macro via a key binding, or by triggering another macro that is stored in a different register than the current macro.


* ### _Why did my macro stop working suddenly?_

    This was probably because a mapping that was used inside the macro was changed.  One of the dangers of using macros is that it uses "recursive" mappings.  In other words, macros depend heavily on the current key bindings in place at the time the macro was recorded.   If you later modify one of the bindings that was used inside the macro, the macro will break.  In this case you will need to re-record the macro.


* ### _Why should I use a named macro for a custom key map?  Why can't I just directly map to the contents of the macro register?_

    Yes, this approach usually works as well.  Assuming the macro you want to bind is stored in the `m` register, you can accomplish this by adding the following to your `.vimrc`:

    ```viml
    nmap <leader>t [MACRO CONTENTS]
    ```

    Note that we need to use nmap here in case our macro uses any non-default mappings.  To actually fill in the value for `[MACRO CONTENTS]`, you can paste from the `m` register like this:

    ```viml
    nmap <leader>t ^R^Rm
    ```

    We type `^R^Rm` to paste the raw values from the macro.  Alternatively, you could create a function for your macro instead:

    ```viml
    function s:doSomething()
        normal [MACRO CONTENTS]
    endfunction

    nnoremap <leader>t :<c-u>call <sid>doSomething()<cr>
    ```

    However, depending on your platform and the types of key presses used during the macro, it may not be possible to represent the macro correctly as text inside your `.vimrc`.  This is why it's often easier and more reliable to use [named macros instead](#named-macros) which do not suffer from this problem (because named macros are stored into binary files)

# Advanced Topics

## Temporary Named Macros

In some cases you might have a macro that is very ad-hoc and only really needed during your current Vim session.  In these cases you don't want to save it as a global macro, so you can use a binding like the following instead:

```viml
nmap <leader>mns <plug>(Mac_NameCurrentMacroForCurrentSession)
```

## File Type Macros

In many cases you will be making macros that only apply to certain file types.  You could make these named macros in the way described above, but then they would be listed for all file types.  Also, you might want to use the same name for different macros depending on the file type (eg. "rename method", "create class", etc.).  For these cases you can use file-specific macros.

First, you will need a mapping to name the macro for the specific file type:

```viml
" nmg = name macro global
nmap <leader>mng <plug>(Mac_NameCurrentMacro)
" nmf = name macro file type
nmap <leader>mnf <plug>(Mac_NameCurrentMacroForFileType)
```

Note here that we have changed the keys we used with `Mac_NameCurrentMacro` from `<leader>mn` to `<leader>mng`.

Now, when we record a named macro that is file-type-specific, we can execute `<leader>mnf` and it will save to a file-type specific directory.

We can then execute `<leader>ms` or `<leader>me` (assuming recommended mappings) and we will get both the global list of macros as well as any file-type specific macros to choose from.

## <a id="shada-support"></a>Persistent/Shared History

When `g:Mac_SavePersistently` is set to `1`, the macro history will be saved persistently by taking advantage of Neovim's "ShaDa" feature.  Note that since ShaDa support only exists in Neovim this feature is not available for Vim.

You can also use this feature to sync the macro history across multiple running instances of Vim by updating Neovim's shada file.  For example, if you execute `:wshada` in the first instance and then `:rshada` in the second instance, the second instance will be synced with the macro history in the first instance.  If this becomes a common operation you might consider using key bindings for this.

Note also that the `!` option must be added to Neovims `shada` setting for this feature to work.  For example:  `set shada=!,'100,<50,s10,h` (see `:h 'shada'` for details)

## Nested Named Macros

If you use this plugin for awhile, you might have some number of bindings that looks like this:

```viml
nnoremap <leader>tf :call macrobatics#playNamedMacro('foo')<cr>
nnoremap <leader>tb :call macrobatics#playNamedMacro('bar')<cr>
```

In some cases, you might even record macros where you trigger these bindings.  This is one way to trigger nested named macros.  Note that this should Just Work when doing it this way.

Often though, you won't have keys mapped to named macros and will rely instead on the fuzzy finder popup to select them when you need them.  You might then wonder, can you record a macro in which you trigger the fuzzy finder popup, select another macro, and execute that?   The answer is yes, with an important caveat:  You have to type in the exact name of the macro for this to work.  In other words, when recording a macro where you execute either `<plug>(Mac_SearchForNamedMacroAndSelect)` or `<plug>(Mac_SearchForNamedMacroAndPlay)`, you cannot rely on the fuzzy search selection.  You have to type in the exact name and then hit enter.   If you follow this rule, and then play back the macro, you can have as many nested macros as you like.

## Parameterized Macros

Macrobatics also has built in support for using 'named parameters' with your named macros.  How this works is that when recording the macro, you make use of certain register values as part of the macro.  Then, when the macro is named and saved, you can indicate which registers need to be filled in before the macro is played.  For example, when executing `<leader>mng` (assuming the default mappings from above), after you choose a name for your macro, it will then also prompt you with the text "Add parameters?".  If you type `Y`, you can then indicate which registers need to be filled in and also give a name for each required parameter.

Then, the next time you execute this macro, you will be prompted to fill in values for all these parameters.

## Specifying Parameterized Macros Via .vimrc

As an alternative to the approach described in the [previous section](parameterized-macros), you can also specify macro parameters in your `.vimrc` file as well.  Normally the previous approach is sufficient, however for more complex cases you might want to take the following approach instead.

For example, let's say you have a macro that renames the current method that you are in, and every time you run it, you want the user to supply the new name for the method.  You can add this macro by doing the following:

* Fill in a temporary value for the 'x' register that will represent the new name for the method (eg. by executing `"nyiw`)
* Record the macro, making use of the 'x' register to replace the current method name
* Name the current macro `rename-current-method` as [described above](#named-macros).  It is now stored persistently into the macros folder.
* Add the following to your `.vimrc`:
    ```viml
    let g:Mac_NamedMacroParameters = {
    \   'rename-current-method': [ { 'register': 'x', 'name': 'New Name' } ]
    \ }
    ```
* Restart vim, or re-source your `.vimrc`
* Play the `rename-current-method` macro
* You should then be prompted for a "New Name" value.  The 'x' register will then be set to whatever you type here, and then the macro will be executed.

Note that you can use any register in place of 'x' here, including the default `"` register.

You can also add parameter information to filetype specific macros.  For example:
```viml
let g:Mac_NamedMacroParametersByFileType = {
\   'javascript': { 
\     'rename-current-method': [ {'register': 'x', 'name': 'New Method Name'} ],
\     'create-method': [ {'register': 'x', 'name': 'Method Name'} ],
\   },
\   'python': { 
\     'rename-current-method': [ {'register': 'x', 'name': 'New Method Name'} ],
\     'create-method': [ {'register': 'x', 'name': 'Method Name'} ],
\   },
\ }
```

In many cases you will just need to assign a name to the register, and then let macrobatics prompt the user for the value, as shown above.  However, there are some cases where it is more useful to let the user choose from a list of pre-defined values, or have the value for a register come from a custom vimscript function that you define yourself.  You can refer to the following examples to learn how these kinds of parameterized macros can be defined:

```viml
" An example of using a hard-coded value
let g:Mac_NamedMacroParameters = {
    \   'my-custom-macro1': [{
    \     'register': 'x',
    \     'name': 'foo',
    \     'value': 'bar'
    \   }],
    \ }

" An example of using a list of values
" This will trigger either fzf or vim-clap to choose a value in the given list
let g:Mac_NamedMacroParameters = {
    \   'my-custom-macro2': [{
    \     'register': 'x',
    \     'name': 'foo',
    \     'choices': ['bar', 'qux', 'gorp']
    \   }],
    \ }

" An example of using a custom function to retrieve the value
function! s:getFoo(argName)
    return 'bar'
endfunction

let g:Mac_NamedMacroParameters = {
    \   'my-custom-macro3': [{
    \     'register': 'x',
    \     'name': 'foo',
    \     'valueProvider': function('s:getFoo')
    \   }],
    \ }

" An example of using a custom async function to retrieve the value
" Note that we can also just not call the sink function which will just cancel
function! s:getFoo(argName, sink)
    call a:sink('bar')
endfunction

let g:Mac_NamedMacroParameters = {
    \   'my-custom-macro3': [{
    \     'register': 'x',
    \     'name': 'foo',
    \     'is_async': 1,
    \     'valueProvider': function('s:getFoo')
    \   }],
    \ }

" An example of using a custom function to retrieve the list of choices
" This will trigger either fzf or vim-clap to choose a value in the given list
function! s:getFooChoices(argName)
    return ['foo', 'bar', 'qux']
endfunction

let g:Mac_NamedMacroParameters = {
    \   'my-custom-macro3': [{
    \     'register': 'x',
    \     'name': 'foo',
    \     'choicesProvider': function('s:getFooChoices')
    \   }],
    \ }

" An example of using a custom async function to retrieve the list of choices
" This will trigger either fzf or vim-clap to choose a value in the given list
" Note that we can also just not call the sink function which will just cancel
function! s:getFooChoices(argName, sink)
    call a:sink(['foo', 'bar', 'qux'])
endfunction

let g:Mac_NamedMacroParameters = {
    \   'my-custom-macro3': [{
    \     'register': 'x',
    \     'name': 'foo',
    \     'is_async': 1,
    \     'choicesProvider': function('s:getFooChoices')
    \   }],
    \ }
```

## Moving registers

In some cases you might find yourself making use of multiple macros at once.  In this case, it can be cumbersome to navigate the macro buffer history back and forth every time you want to swap the active macro between indexes in the history buffer.  A better way to handle this case is to save one or more of these macros to named registers and execute them that way instead.  Macrobatics provides a shortcut mapping that can do this.  For example, if you add the following to your `.vimrc`:

```viml
" mc = macro copy
nmap <leader>mc <plug>(Mac_CopyCurrentMacroToRegister)
```

Then, the next time you want to give a name to the active macro, you can execute `"x<leader>mc` where `x` is the register you want to associate with the active macro.  You can then record some number of new macros by executing `gq`, while also having access to the `x` macro (which you can replay by executing `"xq`).

Note that in addition to replaying the `x` macro with `"xq`, you can also re-record with `"xgq`, append with `"x<leader>ma`, or prepend with `"x<leader>mp`.

Note also that you might consider [naming the current macro](#named-macros) instead.  However, this can still be useful when juggling multiple temporary maps at once that you don't need to use again.

