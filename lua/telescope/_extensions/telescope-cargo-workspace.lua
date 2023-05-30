-- local has_telescope, telescope = pcall(require, 'telescope')
-- if not has_telescope then
--   error('This plugins requires nvim-telescope/telescope.nvim')
-- end
--
-- local picker = require("telescope-cargo-workspace")
return require("telescope").register_extension {
  exports = {
    switch = require("telescope-cargo-workspace").pick_cargo_workspace,
    -- cargo_workspace_oneshot = require("telescope-cargo-workspace").pick_cargo_workspace
  }
}
