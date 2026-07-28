# sven.nvim

A minimal Neovim plugin that opens the [`sven`](https://github.com/yourname/sven) CLI inside a terminal window — no temporary files, no external dependencies, no fuss.

<p align="center">
  <img src="https://img.shields.io/badge/Neovim-0.7%2B-green?logo=neovim" alt="Neovim 0.7+">
  <img src="https://img.shields.io/badge/Lua-blue?logo=lua" alt="Lua">
</p>

## Features

- 🪟 Open `sven` in a **vertical split** or a **floating window**
- ⌨️ Starts in insert mode automatically so `sven` receives your keystrokes right away
- 🧹 Closes the window automatically when `sven` exits
- 📦 Zero dependencies beyond Neovim and `sven`
- ⚙️ Simple, configurable Lua setup

## Installation

### With [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'yourname/sven.nvim',
  config = function()
    require('sven').setup()
  end,
}
```

### With [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'yourname/sven.nvim',
  config = function()
    require('sven').setup()
  end,
}
```

### Manual

Clone the repo into your Neovim runtime path, e.g.:

```bash
git clone https://github.com/yourname/sven.nvim.git \
  ~/.local/share/nvim/site/pack/plugins/start/sven.nvim
```

Then restart Neovim.

## Usage

| Command            | Description                                                   |
|--------------------|---------------------------------------------------------------|
| `:Sven`            | Open `sven` in the default window                             |
| `:Sven vsplit`     | Open `sven` in a vertical split                               |
| `:Sven float`      | Open `sven` in a floating window                              |
| `:SvenVsplit`      | Convenience command for vertical split                        |
| `:SvenFloat`       | Convenience command for floating window                         |
| `:SvenAsk`         | Ask `sven` about the current buffer (uses prepared prompt)    |
| `:SvenAsk vsplit`  | Same as `:SvenAsk` but in a vertical split                    |
| `:SvenAsk float`   | Same as `:SvenAsk` but in a floating window                   |
| `:SvenAskVsplit`   | Convenience command for `:SvenAsk` in a vertical split        |
| `:SvenAskFloat`    | Convenience command for `:SvenAsk` in a floating window       |
| `:SvenPreviewPrompt` | Preview the prepared prompt without opening `sven`          |

Default keymaps: `<leader>sv` (open), `<leader>sa` (ask)

## Configuration

```lua
require('sven').setup({
  -- 'vsplit' or 'float'
  default_window = 'vsplit',

  -- Keymap to open sven. Set to false to disable.
  keymap = '<leader>sv',

  -- Keymap to ask sven about the current buffer. Set to false to disable.
  keymap_ask = '<leader>sa',

  -- Floating window options (only used when default_window = 'float')
  float = {
    width = 0.8,
    height = 0.8,
    border = 'rounded', -- 'single', 'double', 'shadow', 'none', etc.
  },

  -- Template used to build the prepared prompt for :SvenAsk.
  -- Available placeholders: {{filetype}}, {{content}}, {{prompt}}
  prompt_template = "Filetype: {{filetype}}\n\nContent:\n{{content}}\n\nRequest:\n{{prompt}}",

  -- Filetype assigned to the terminal buffer. Use 'markdown' for Markdown
  -- highlighting/conceal, or any other filetype you prefer.
  terminal_filetype = 'sven',
})
```

## Window controls

Inside the terminal window:

- **Terminal mode** — all keys are sent directly to `sven`
- **`<Esc>`** — enter normal mode
- **`q`** in normal mode — close the window
- **`<Esc><Esc>`** in a floating window — close the floating window

## Terminal filetype

The terminal buffer is assigned a filetype (default: `sven`). You can set it
to `markdown` in your config to get Markdown syntax highlighting and
conceal in the terminal window:

```lua
require('sven').setup({
  terminal_filetype = 'markdown',
})
```

Note: terminal buffers render raw process output, so Markdown highlighting
only applies to the buffer text (for example, after pressing `<Esc>` to enter
normal mode). For clean Markdown rendering of `sven` output, capture it to a
normal buffer instead of a terminal.

## Why no temp file?

`sven` is an interactive tool. This plugin runs it directly in a Neovim `:terminal` buffer via `termopen('sven', ...)`. There is no need to capture output to a temporary file because the terminal itself is the interface.
