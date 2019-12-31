
<img align="right" width="300" height="300" src="https://i.imgur.com/4BdGxV8.png">

# Macrobatics.vim

Macrobatics is a plugin for vim/neovim with the goal of making macros easier to use.  It adds the following functionality to Vim's built-in support for macros:

* A history of macros, which can be navigated to play previously recorded ones.
* Repeatability.  Vim's repeat operator `.` can be used to play the most recently recorded/played macro.
* Edit existing macros by appending or prepending content to it.
* Nested macros (create macros that play other macros).

# Installation

Note that this plugin contains no default mappings and will have no effect until you add your own maps to one of the `<plug>` bindings below:

For example, to add just the most basic functionality:

```viml
nmap gp <plug>(Mac_Play)
nmap gr <plug>(Mac_RecordNew)
```

# Recording

With the above mappings, you can then press `gr` in Vim to begin recording a new macro.

However - Note that this mapping works differently than Vim's default way of recording a macro with the `q` key.  Unlike `q`, which is immediately followed by the register you want to record the macro to, `gr` will always record to the same register unless a register is explicitly given (eg. `"xgr` to record the macro to the `x` register).  By default this register is `m` however this is [configurable](#configuration).

It works this way just because specifying the register this way is more consistent with other actions in Vim like delete, yank, etc.

You can then stop recording by pressing the same keys again (`gr`)

# Playback and repeat

Again assuming the above plug mappings, you can replay the current macro by pressing `gp`.  Similar to `gr`, you can also pass a register to use using the standard Vim convention (eg. `"xgp` to execute the macro stored in the `x` register).   And when a register is not specified, it will play whatever macro is stored in the default register (`m`  by default but also [configurable](#configuration))

After playback, you can use the standard repeat operator `.` to replay the same macro again in a different spot.  Or, you can also execute `gp` / `"xgp` again for the same effect.

# Navigating history

To view the current history of macros, you can execute `:Macros`.  By default the history contains a maximum of 10 items, however this is [configurable](#configuration).

You will notice that the current macro is displayed alongside the `m` letter (the default value for `g:Mac_DefaultRegister`) and the rest are displayed as indexes into the history buffer.

To navigate the history, you can add bindings similar to the following to your `.vimrc`:

```viml
nmap [m <plug>(Mac_RotateBack)
nmap ]m <plug>(Mac_RotateForward)
```

Then if you execute `[m` or `]m` you should see a preview of the newly selected macro in status bar.

# Editing Macros

In many cases, after recording a macro, you realize that you would like to tweak it slightly, usually by either adding something to the beginning or adding something to the end.  Macrobatics provides two bindings to make this process very easy.  For example, you could add the following bindings to your `.vimrc`:

```viml
nmap ggp <plug>(Mac_Append)
nmap ggr <plug>(Mac_Prepend)
```

Then, you can add content to the current macro by pressing `ggp`.  This will play the given macro and then immediately enter record mode to record any new content to the end of it.

The prepend `ggr` command works similarly except that it will enter record mode immediately, and then play the previous macro immediately after the recording is stopped.

Then in both cases, the macro will be updated to contain the change.

The suggested values are `ggp` and `ggr` because they work similarly to `gp` and `gr` (`gp` and `gpp` play immediately, `gr` and `grr` record immediately)

# Moving registers

In some cases you might find yourself making use of multiple macros at once.  In this case, it is cumbersome to need to navigate the macro buffer history back and forth every time you want to swap the active macro between indexes in the history buffer.  A better way to handle this case is to save one or more of these macros to named registers and execute them that way instead.  Macrobatics provides a shortcut mapping that can do this.  For example, if you add the following to your `.vimrc`:

```viml
nmap gs <plug>(Mac_StoreCurrent)
```

Then, the next time you want to give a name to the active macro, you can execute `"xgs` where `x` is the register you want to associate with the active macro.  You can then record some number of new macros by executing `gr`, while also having access to the `x` macro (which you can replay by executing `"xgp`).

Note that in addition to replaying the `x` macro with `"xgp`, you can also re-record with `"xgr`, append with `"xggr`, or prepend with `"xggp`.

# Configuration

This is the default configuration:

```viml
let g:Mac_DefaultRegister = 'm'
let g:Mac_MaxItems = 10
let g:Mac_SavePersistently = 0
let g:Mac_DisplayMacroMaxWidth = 80
```

Note that including these lines in your `.vimrc` will have zero effect, because these are already the default values.  So you'll only need to include the lines which you customize.

The values are:
* `g:Mac_DefaultRegister` - The default register that macros get stored to when an explicit register is not given.
* `g:Mac_MaxItems` - The number of macros to store in the history buffer.  This will also control the number of rows displayed when executing the `:Macros` command
* `g:Mac_SavePersistently` - When true, the macro history will be preserved even when restarting Vim.  Note: Requires Neovim.  See <a href="#shada-support">here</a> for details. Default: `0`
* `g:Mac_DisplayMacroMaxWidth` - When macros are displayed by executing the `:Macros` command or when navigating history, this value will control the length at which the displayed macro is truncated at to fit on the screen.

# Advanced

## Nested macros

In some cases you might want to execute a macro from within another macro.  For example, you might have a macro (stored in register `x`) that applies some change to the word under the cursor, and you might instead want a macro that applies the same change to the first word in the current sentence.  One way to do this would be pre-pend the `x` register with a key to move to the beginning of the sentence.  However, you might not want to modify the `x` macro to achieve this, since it might be useful on its own as well.  So instead you could record a new macro (stored in register `y`) that goes to the beginning of the sentence and then executes the `x` macro by pressing `"xgp`.  This way, you could even edit the `x` macro and have those changes included in the `y` macro as well.

## Re-mapping `q`

If you find yourself using this plugin and no longer have a need for Vim's built-in way of recording registers, then you might want to re-use the `q` key for something else.  An easy way to achieve this is to use the `<nowait>` setting when adding a new binding. For example:

```viml
nnoremap <nowait> q :echo 'my new binding'<cr>
```

Without the `<nowait>` setting here, after hitting `q`, vim will always wait for another keypress for the built-in macro mapping, even if you add a mapping for `q` by itself.

## <a id="shada-support"></a>Persistent/Shared History

When `g:Mac_SavePersistently` is set to 1, the macro history will be saved persistently by taking advantage of Neovim's "ShaDa" feature.  Note that since ShaDa support only exists in Neovim this feature is not available for Vim.

You can also use this feature to sync the macro history across multiple running instances of Vim by updating Neovim's shada file.  For example, if you execute `:wshada` in the first instance and then `:rshada` in the second instance, the second instance will be synced with the macro history in the first instance.  If this becomes a common operation you might consider using key bindings for this.

Note also that the `!` option must be added to Neovims `shada` setting for this feature to work.  For example:  `set shada=!,'100,<50,s10,h` (see `:h 'shada'` for details)

