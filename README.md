# sven.nvim

A minimal Neovim plugin that opens the [`sven`](https://github.com/yourname/sven) CLI inside a terminal window — no temporary files, no external dependencies, no fuss.

<p align="center">
  <img src="https://img.shields.io/badge/Neovim-0.7%2B-green?logo=neovim" alt="Neovim 0.7+">
  <img src="https://img.shields.io/badge/Lua-blue?logo=lua" alt="Lua">
  <img src="https://img.shields.io/badge/License-MIT-yellow" alt="MIT License">
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

| Command            | Description                                  |
|--------------------|----------------------------------------------|
| `:Sven`            | Open `sven` in the default window            |
| `:Sven vsplit`     | Open `sven` in a vertical split              |
| `:Sven float`      | Open `sven` in a floating window             |
| `:SvenVsplit`      | Convenience command for vertical split       |
| `:SvenFloat`       | Convenience command for floating window      |

Default keymap: `<leader>sv`

## Configuration

```lua
require('sven').setup({
  -- 'vsplit' or 'float'
  default_window = 'vsplit',

  -- Keymap to open sven. Set to false to disable.
  keymap = '<leader>sv',

  -- Floating window options (only used when default_window = 'float')
  float = {
    width = 0.8,
    height = 0.8,
    border = 'rounded', -- 'single', 'double', 'shadow', 'none', etc.
  },
})
```

## Window controls

Inside the terminal window:

- **Terminal mode** — all keys are sent directly to `sven`
- **`<Esc>`** — enter normal mode
- **`q`** in normal mode — close the window
- **`<Esc><Esc>`** in a floating window — close the floating window

## Why no temp file?

`sven` is an interactive tool. This plugin runs it directly in a Neovim `:terminal` buffer via `termopen('sven', ...)`. There is no need to capture output to a temporary file because the terminal itself is the interface.
