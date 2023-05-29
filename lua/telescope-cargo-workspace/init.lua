local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"

local M = {}

M.pick_workspace = function(opts)
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


M._call_cargo_metadata = function()
  local cmd = "cargo metadata --no-deps"
  local handle = io.popen(cmd, "r")
  local json = handle:read("*a")
  handle:close()

  return json
end

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

M._get_project_names = function(metadata_json)
  local projects = {}
  for _,v in ipairs(metadata_json) do
    table.insert(projects, v[1])
  end
end

M._extract_path_from_id = function(str)
  local _, _, path = string.find(str, "path%+file://(/.+)")
  path = string.gsub(path, "%).*$", "") 
  return path
end

return M
