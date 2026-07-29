# sven.nvim

A minimal Neovim plugin that opens the [`sven`](https://github.com/yourname/sven) CLI in a dedicated `nofile` buffer and streams its output inline — no temporary files, no `:terminal`, no external dependencies beyond Neovim and `sven`.

<p align="center">
  <img src="https://img.shields.io/badge/Neovim-0.7%2B-green?logo=neovim" alt="Neovim 0.7+">
  <img src="https://img.shields.io/badge/Lua-blue?logo=lua" alt="Lua">
</p>

## Features

- 🪟 Open `sven` in a **vertical split** or a **floating window**
- 💬 Send messages to `sven` via `vim.ui.input` prompts
- 🧹 Close the window with `q` or `<Esc>` when you're done
- 📦 Zero dependencies beyond Neovim and `sven`
- ⚙️ Simple, configurable Lua setup
- 📝 Output buffer uses your chosen `filetype` (default: `markdown`)

## Requirements

- Neovim 0.7 or later
- The `sven` binary available in your `$PATH`

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

| Command              | Description                                                    |
|----------------------|----------------------------------------------------------------|
| `:Sven`              | Open `sven` in the default window                              |
| `:Sven vsplit`       | Open `sven` in a vertical split                                |
| `:Sven float`        | Open `sven` in a floating window                               |
| `:SvenVsplit`        | Convenience command for vertical split                         |
| `:SvenFloat`         | Convenience command for floating window                        |
| `:SvenAsk`           | Ask `sven` about the current buffer (uses prepared prompt)     |
| `:SvenAsk vsplit`    | Same as `:SvenAsk` but in a vertical split                     |
| `:SvenAsk float`     | Same as `:SvenAsk` but in a floating window                    |
| `:SvenAskVsplit`     | Convenience command for `:SvenAsk` in a vertical split         |
| `:SvenAskFloat`      | Convenience command for `:SvenAsk` in a floating window        |
| `:SvenPreviewPrompt` | Preview the prepared prompt without opening `sven`             |

Default keymaps:

- `<leader>sv` — open `sven`
- `<leader>sa` — ask `sven` about the current buffer

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
  -- Available placeholders: {{filetype}}, {{filepath}}, {{content}}, {{prompt}}
  prompt_template = "Regarding the following file, {{prompt}}:\n```{{filetype}}\n{{content}}\n```",

  -- Filetype assigned to the sven output buffer. Use 'markdown' for Markdown
  -- highlighting/conceal, or any other filetype you prefer.
  terminal_filetype = 'markdown',
})
```

## Window controls

Inside the sven buffer:

- **`<CR>`** in normal mode — open an input prompt to send a message to `sven`
- **`q`** in normal mode — close the window and stop the job
- **`<Esc>`** in normal mode — close the window and stop the job

## Output buffer

`sven` runs as a background job via `jobstart()`. Its stdout is streamed into a
regular `nofile` buffer, with ANSI escape sequences and carriage returns
stripped. The buffer is assigned the configured `terminal_filetype` (default:
`markdown`) so you get syntax highlighting when viewing it in normal mode.

User input is rendered manually as a markdown section. The plugin communicates
with `sven` using the `SVEN_PLUGIN_MODE=1` environment variable and sends each
prompt followed by an end-of-input marker (`###END_OF_INPUT###`).

## Why no temp file?

`sven` is an interactive tool. This plugin runs it as a background job and streams
its output directly into a Neovim buffer. There is no need to capture output to a
temporary file because the buffer itself is the interface.
