local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"

local M = {}

---
-- Displays a list of Cargo workspaces found in the current Rust project and sets the active workspace to the user's selection.
-- @param opts (table) Optional configuration options for the picker.
M.pick_cargo_workspace = function(opts)
  local workspace = M._get_cargo_workspaces()
  opts = opts or {}
  pickers.new(opts, {
    prompt_title = "Cargo Workspaces",
    finder = finders.new_table {
      results = workspace,
      entry_maker = function(entry)
        return {
          value = entry[2],
          display = entry[1],
          ordinal = entry[1],
        }
      end
    },
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        local save_dir = vim.fn.chdir(selection.value)
      end)
      return true
    end,
  }):find()
end

---
-- Calls the `cargo metadata` command to retrieve metadata for the current Rust project.
-- @return string The metadata in JSON format.
M._call_cargo_metadata = function()
  local cmd = "cargo metadata --no-deps"
  local handle = io.popen(cmd, "r")
  local json = handle:read("*a")
  handle:close()
  return json
end

---
-- Parses the cargo workspaces from a JSON input string.
-- @param string json_input The JSON input string to parse.
-- @return table An array of tables, where each table has two elements:
--         the name of the package and the path to its directory.
M._parse_cargo_workspaces_from_json = function(json_input)
  local cargo_workspaces = {}

  local decoded_input = vim.json.decode(json_input)

  for _, package in ipairs(decoded_input.packages) do
    local path = M._extract_path_from_id(package.id) 
    table.insert(cargo_workspaces, {package.name, path})
  end

  return cargo_workspaces
end


M._get_cargo_workspaces = function()
  local json_input = M._call_cargo_metadata()
  local cargo_workspaces = M._parse_cargo_workspaces_from_json(json_input)

  return cargo_workspaces
end

---
-- Retrieves the project names from metadata JSON.
-- @param metadata_json The metadata in JSON format.
-- @return A table containing the project names.
M._get_project_names = function(metadata_json)
  local projects = {}
  for _,v in ipairs(metadata_json) do
    table.insert(projects, v[1])
  end
end

---
-- Extracts the file path from a given id string, which is in the format of "path+file://(/absolute/path/to/file)".
-- @param str (string) The id string to extract the file path from.
-- @return (string) The absolute path of the file extracted from the given id string.
M._extract_path_from_id = function(str)
  local _, _, path = string.find(str, "path%+file://(/.+)")
  path = string.gsub(path, "%).*$", "") 
  return path
end

return M
