# telescope-cargo-workspace.nvim

[Telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) extension for switching between cargo workspaces in Rust projects.  Useful for navigating rust monorepos with many crates.

## Install

This plugin requires [nvim-telescope](https://github.com/nvim-telescope/telescope.nvim) and [Cargo](https://www.rust-lang.org/) to be installed.

Using [vim-plug](https://github.com/junegunn/vim-plug):

```lua
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'
Plug 'mattcairns/telescope-cargo-workspace'
```

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
'nvim-telescope/telescope.nvim', tag = '0.1.1',
  dependencies = { 'nvim-lua/plenary.nvim' }
}
{ 'mattcairns/telescope-cargo-workspace' }
```

## Configuration

To use this extension, add the following code to your `init.vim` file:

```lua
require("telescope").load_extension("telescope-cargo-workspace")
```

## Usage

The following commands are provided:

Show all the crates in the current Cargo workspace and allows you to switch Neovims current working directory to the chosen crate.
```vimscript
:Telescope telescope-cargo-workspace switch
```

<!-- This command shows all the cargo workspaces in the current Rust project and opens the selected one without changing the current workspace. -->
<!-- ```vimscript -->
<!-- :Telescope telescope-cargo-workspace oneshot -->
<!-- ``` -->

## License

MIT License. See [LICENSE](./LICENSE) file for details.


