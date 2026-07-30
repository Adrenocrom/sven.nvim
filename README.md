# sven.nvim

A minimal Neovim plugin that opens the `sven` CLI in a dedicated `nofile` buffer and streams its output inline. It allows you to chat with your AI agent or ask questions about your current code without leaving the editor.

<p align="center">
  <img src="https://img.shields.io/badge/Neovim-0.7%2B-green?logo=neovim" alt="Neovim 0.7+">
  <img src="https://img.shields.io/badge/Lua-blue?logo=lua" alt="Lua">
</p>

## Features

- 🪟 **Flexible Windows**: Open `sven` in a vertical split or a floating window.
- 💬 **Interactive Chat**: Send messages to `sven` via `vim.ui.input` prompts.
- 🔍 **Context Awareness**: Ask questions about the current buffer or a specific visual selection.
- 🧹 **Clean Exit**: Close the window and stop the background job instantly with `q` or `<Esc>`.
- 📦 **Zero Dependencies**: No temporary files or external plugins required—just Neovim and the `sven` binary.
- 📝 **Markdown Integration**: Output is streamed into a buffer with markdown highlighting.

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

## Usage

The primary entry point is the `:Sven` command. When executed, it will prompt you to choose between **Ask** (send current buffer context) or **Chat** (start a fresh conversation).

### Commands

| Command | Description |
| :--- | :--- |
| `:Sven` | Open the selection menu (Ask vs Chat) |
| `:Sven [mode]` | Open the selection menu, defaulting the window to `vsplit` or `float` |

**Pro Tip:** If you have a visual selection active, `:Sven` will automatically detect it and offer to send only the selected text to the agent.

### Window Controls (Inside the Sven Buffer)

- **`<CR>`** (Enter): Open an input prompt to send a new message to `sven`.
- **`q`** or **`<Esc>`**: Close the window and terminate the `sven` process.

## Configuration

```lua
require('sven').setup({
  -- Default window mode: 'vsplit' or 'float'
  default_window = 'vsplit',

  -- Floating window options (used when default_window = 'float')
  float = {
    width = 0.8,
    height = 0.8,
    border = 'rounded', -- 'single', 'double', 'shadow', 'none', etc.
  },

  -- Template used to build the prompt for "Ask" mode.
  -- Placeholders: {{filetype}}, {{filepath}}, {{content}}, {{prompt}}
  prompt_template = "Regarding the following file, {{prompt}}:\n```{{filetype}}\n{{content}}\n```",

  -- Filetype assigned to the output buffer (default: 'markdown')
  terminal_filetype = 'markdown',
})
```

## How it Works

`sven.nvim` runs the `sven` binary as a background job using `jobstart()`. 
1. It sets the environment variable `SVEN_PLUGIN_MODE=1` to signal the CLI.
2. It streams `stdout` directly into a Neovim buffer, stripping ANSI escape codes for a clean look.
3. It handles user input by appending the prompt to the buffer and sending it to the process with a specific end-of-input marker (`###END_OF_INPUT###`).
