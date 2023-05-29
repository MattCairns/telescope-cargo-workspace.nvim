local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values

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
          value = entry,
          display = entry[1],
          ordinal = entry[1],
        }
      end
    },
    sorter = conf.generic_sorter(opts),
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
      table.insert(cargo_workspaces, {package.name, package.id})
  end

  return cargo_workspaces
end

M._get_cargo_workspaces = function()
  local json_input = M._call_cargo_metadata()
  local cargo_workspaces = M._parse_cargo_workspaces_from_json(json_input)

  print(vim.inspect(cargo_workspaces))
  return cargo_workspaces
end

M._get_project_names = function(metadata_json)
  local projects = {}
  for _,v in ipairs(metadata_json) do
    print(v[1])
    table.insert(projects, v[1])
  end
  print(vim.inspect(projects))
  -- return projects
end




return M
