# lite-modal-vim
Replicates vi(m)-like modal editing in Lite-XL

## Features
This plugin adds various features from the vim text editor, such as modes, and it's infamous vim motions.

## Known limitations
* can't use numbers as motions, example: the `0` keybind which would send you to the start of the line. (however, you may still use numbers for doing a certain motion multiple times, such as `5k`)

## TODO
* implement vim-like command mode instead of using lite-xl's (allow access to lite-xl's commands using lx command)
* Text Objects (such as brackets, methods, comments, etc)
* Marks
* registers
* Visual block mode
* Others (Use https://github.com/VSCodeVim/Vim/blob/HEAD/ROADMAP.md as reference)

## Credits
[Lite-XL-Vibe](https://github.com/eugenpt/lite-xl-vibe) - First modal-editing plugin that I personally used
[Vim](https://vim.org) & [Neovim](https://neovim.io) - For being great text editors
[lite-modal](https://codeberg.org/Mandarancio/lite-modal) - Uses the lite-modal plugin under the hood
