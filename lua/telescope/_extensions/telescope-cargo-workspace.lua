local has_telescope, telescope = pcall(require, 'telescope')
if not has_telescope then
  error('This plugins requires nvim-telescope/telescope.nvim')
end

local picker = require("telescope-cargo-workspace")
return require("telescope").register_extension {
  exports = {
    telescope-cargo-workspace = picker.pick_cargo_workspace 
  }
}
