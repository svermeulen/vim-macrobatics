
<img align="right" width="300" height="300" src="https://i.imgur.com/4BdGxV8.png">

# Macrobatics.vim

Macrobatics is a plugin for vim/neovim with the goal of making vim macros easier to use.

## Features

* Provides a history of macros, which can be navigated to play previously recorded ones.
* Makes macros repeatable with the `.` operator.
* Supports editting existing macros by appending or prepending content to it.
* Supports nested macros (create macros that play other macros).
* Supports giving macros a name and then saving them persistently
* Written in pure vim-script.

## Installation

Install into vim using your preferred plugin manager (eg. [vim-plug](https://github.com/junegunn/vim-plug)).

Note that in order for macros to be repeatable with the `.` key, you will need to also install [tpope/vim-repeat](https://github.com/tpope/vim-repeat) (you might also consider using [my fork](https://github.com/svermeulen/vim-repeat) of vim-repeat instead as discussed <a href="#repeat-bug">here</a>).

Note also that this plugin contains no default mappings and will have no effect until you add your own maps to one of the `<plug>` bindings below:

For example, to add just the most basic functionality:

```viml
nmap gp <plug>(Mac_Play)
nmap gr <plug>(Mac_RecordNew)
```

## Recording

With the above mappings, you can then press `gr` in Vim to begin recording a new macro.

However - Note that this mapping works differently than Vim's default way of recording a macro with the `q` key.  Unlike `q`, which is immediately followed by the register you want to record the macro to, `gr` will always record to the same register unless a register is explicitly given (eg. `"xgr` to record the macro to the `x` register).  By default this register is `m` however this is [configurable](#configuration).

It works this way just because specifying the register this way is more consistent with other actions in Vim like delete, yank, etc.

You can then stop recording by pressing the same keys again (`gr`)

## Playback and repeat

Again assuming the above plug mappings, you can replay the current macro by pressing `gp`.  Similar to `gr`, you can also pass a register to use using the standard Vim convention (eg. `"xgp` to execute the macro stored in the `x` register).   And when a register is not specified, it will play whatever macro is stored in the default macro register (`m`  by default but also [configurable](#configuration))

Assuming [vim-repeat](https://github.com/tpope/vim-repeat) is installed, after playback or recording, you can use the standard repeat operator `.` to replay the same macro again in a different spot.  Or, you can also execute `gp` / `"xgp` again for the same effect.

You can also pass a count to the play command to immediately repeat the macro a given number of times.

## Navigating history

To view the current history of macros, you can execute `:DisplayMacroHistory`.  By default the history contains a maximum of 10 items, however this is [configurable](#configuration).  You might also consider adding a binding for this:

```viml
nmap <leader>dm :DisplayMacroHistory<cr>
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
nmap ggp <plug>(Mac_Append)
nmap ggr <plug>(Mac_Prepend)
```

Then, you can append behaviour to the current macro by pressing `ggp`.  This will play the given macro and then immediately enter record mode to record any new content to the end of it.

The prepend `ggr` command works similarly except that it will enter record mode immediately, and then play the previous macro immediately after the recording is stopped.

Then in both cases, the macro will be updated to contain the new change.

The suggested values are `ggp` and `ggr` because they work similarly to `gp` and `gr` (`gp` and `gpp` play immediately, `gr` and `grr` record immediately)

## Named Macros

If you find yourself re-using a macro quite often, then you might consider giving it a name, and maybe even adding a direct key mapping for it.  You can do this by first adding the following mapping or similar to your `.vimrc`:

```viml
nmap <leader>nm <plug>(Mac_NameCurrentMacro)
```

Now, every time you create a new macro that you want to name, you can execute `<leader>nm`, and you will then be prompted to type in a name for it.  Then, to add a mapping for it, you can add the following to your `.vimrc`:

```viml
nnoremap <leader>tm :call macrobatics#playNamedMacro('foo')<cr>
```

Where `foo` is the name that you typed into the prompt, and `<leader>tm` is the keys that you want to use for your custom macro.

## Playing/Selecting Named Macros Directly

In many cases, you will have named macros that you don't use enough to justify adding an entirely new key binding.  In these cases, it's helpful to be able to play the named macro by searching through the list of named macros whenever you need it instead.  This is often easier than needing to remember a key binding for something you rarely use.  You can do this by adding the following maps or similar to your `.vimrc`:

```viml
nmap <leader>gp <plug>(Mac_SearchForNamedMacroAndPlay)
```

Note that in order for these maps to work, you must either have [fzf.vim](https://github.com/junegunn/fzf.vim) or [vim-clap](https://github.com/liuchengxu/vim-clap) installed.  If you would prefer using another fuzzy list plugin, feel free to [create a github issue for it](https://github.com/svermeulen/vim-macrobatics/issues/new).

Now, you can execute `<leader>gp`, to directly choose the named macro you want to play!  Note that you can also pass a count to this command.

In some cases you might want to just select a named macro rather than playing it directly.  You can do that as well with the following mapping:

```viml
nmap <leader>sm <plug>(Mac_SearchForNamedMacroAndSelect)
```

Then you can execute `<leader>sm` to set the current macro to the chosen named macro.  This is especially useful when you want to edit a named macro by appending or prepending to it (or simply overwriting it entirely).   You can do this by naming it again using the same name after executing the `<leader>nm` keys (or using whichver keys you use for that).

## Re-mapping `q`

If you find yourself using this plugin and no longer have a need for Vim's built-in way of recording registers, then you might want to re-use the `q` key for something else.  An easy way to achieve this is to use the `<nowait>` setting when adding a new binding. For example:

```viml
nnoremap <nowait> q :echo 'my new binding'<cr>
```

Without the `<nowait>` setting here, after hitting `q`, vim will always wait for another keypress for the built-in macro mapping, even if you add a mapping for `q` by itself.

## Configuration

This is the default configuration:

```viml
let g:Mac_DefaultRegister = 'm'
let g:Mac_MaxItems = 10
let g:Mac_SavePersistently = 0
let g:Mac_DisplayMacroMaxWidth = 80
let g:Mac_NamedMacroFileExtension = '.bin'
let g:Mac_NamedMacroFuzzySearcher = v:null
let g:Mac_NamedMacrosDirectory = "~/.config/macrobatics"
" Note that for windows, the default is actually this:
" let g:Mac_NamedMacrosDirectory = "~/AppData/Local/macrobatics"
```

Note that including these lines in your `.vimrc` will have zero effect, because these are already the default values.  So you'll only need to include the lines which you customize.

The values are:
* `g:Mac_DefaultRegister` - The default register that macros get stored to when an explicit register is not given.
* `g:Mac_MaxItems` - The number of macros to store in the history buffer.  This will also control the number of rows displayed when executing the `:Macros` command
* `g:Mac_SavePersistently` - When true, the macro history will be preserved even when restarting Vim.  Note: Requires Neovim.  See <a href="#shada-support">here</a> for details. Default: `0`.  Note that this setting is only necessary for macros that are in the history buffer.  Macros that you've assigned to a specific register should be automatically restored as part of built-in Vim behaviour.
* `g:Mac_DisplayMacroMaxWidth` - When macros are displayed by executing the `:Macros` command or when navigating history, this value will control the length at which the displayed macro is truncated at to fit on the screen.
* `g:Mac_NamedMacroFileExtension` - The file extension used for the macro files stored inside directory `g:Mac_NamedMacrosDirectory`
* `g:Mac_NamedMacroFuzzySearcher` - The type of search to use when selecting or executing named macros.  Currently, valid values are 'clap' (which will use [vim-clap](https://github.com/liuchengxu/vim-clap)) and 'fzf' (which will use [fzf.vim](https://github.com/junegunn/fzf.vim))
* `g:Mac_NamedMacrosDirectory` - The directory to store the files associated with [named macros](#named-macros)

# Advanced Topics

## <a id="shada-support"></a>Persistent/Shared History

When `g:Mac_SavePersistently` is set to `1`, the macro history will be saved persistently by taking advantage of Neovim's "ShaDa" feature.  Note that since ShaDa support only exists in Neovim this feature is not available for Vim.

You can also use this feature to sync the macro history across multiple running instances of Vim by updating Neovim's shada file.  For example, if you execute `:wshada` in the first instance and then `:rshada` in the second instance, the second instance will be synced with the macro history in the first instance.  If this becomes a common operation you might consider using key bindings for this.

Note also that the `!` option must be added to Neovims `shada` setting for this feature to work.  For example:  `set shada=!,'100,<50,s10,h` (see `:h 'shada'` for details)

## Moving registers

In some cases you might find yourself making use of multiple macros at once.  In this case, it is cumbersome to need to navigate the macro buffer history back and forth every time you want to swap the active macro between indexes in the history buffer.  A better way to handle this case is to save one or more of these macros to named registers and execute them that way instead.  Macrobatics provides a shortcut mapping that can do this.  For example, if you add the following to your `.vimrc`:

```viml
nmap gs <plug>(Mac_CopyCurrentMacroToRegister)
```

Then, the next time you want to give a name to the active macro, you can execute `"xgs` where `x` is the register you want to associate with the active macro.  You can then record some number of new macros by executing `gr`, while also having access to the `x` macro (which you can replay by executing `"xgp`).

Note that in addition to replaying the `x` macro with `"xgp`, you can also re-record with `"xgr`, append with `"xggr`, or prepend with `"xggp`.

Note also that you might consider [naming the current macro](#named-macros) instead.  However, this can still be useful when juggling multiple temporary maps at once that you don't need to use again.

## FAQ

* ### _How do I select a specific macro from the history after executing `:DisplayMacroHistory`?_

    The easiest way to do this is to execute `x[m` where `x` is the number associated with the macro as displayed by `:DisplayMacroHistory`


* ### _The repeat button '.' doesn't work when executed immediately after undo_

    <a id="repeat-bug"></a>This is due to a [bug with tpope/vim-repeat](https://github.com/tpope/vim-repeat/pull/66).  You can use [my fork](https://github.com/svermeulen/vim-repeat) instead which contains the fix.


* ### _Can I execute a macro from within a macro?_

    Yes!  This can be quite useful.  You can do this by either triggering a named macro via a key binding, or by triggering another macro that is stored in a different register than the current macro.


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

    However, dependending on your platform and the types of key presses used during the macro, it may not be possible to represent the macro correctly as text inside your `.vimrc`.  This is why it's often easier and more reliable to use [named macros instead](#named-macros) which do not suffer from this problem (because named macros are stored into binary files)
