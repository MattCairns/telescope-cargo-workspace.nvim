local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
local entry_display = require "telescope.pickers.entry_display"

local M = {}

---
-- Displays a list of Cargo workspaces found in the current Rust project and sets the active workspace to the user's selection.
-- @param opts (table) Optional configuration options for the picker.
M.pick_cargo_workspace = function(opts)
  M._ensure_highlights()
  local workspace = M._get_cargo_workspaces()
  opts = opts or {}
  local first_column_width = M._max_display_path_crate_width(workspace)
  local displayer = entry_display.create {
    separator = "   ",
    items = {
      { width = first_column_width },
      { remaining = true },
    },
  }

  pickers.new(opts, {
    prompt_title = "Cargo Workspaces",
    previewer = conf.file_previewer(opts),
    finder = finders.new_table {
      results = workspace,
      entry_maker = function(entry)
        local display_path_crate, path_prefix_len = M._format_path_crate(entry.parent_display, entry.name)
        return {
          value = entry.path,
          display = function()
            return displayer {
              {
                display_path_crate,
                function()
                  local highlights = {}
                  local full_len = #display_path_crate
                  local path_len = math.min(path_prefix_len, full_len)

                  if path_len > 0 then
                    table.insert(highlights, { { 0, path_len }, "TelescopeCargoWorkspacePath" })
                  end

                  if path_len < full_len then
                    table.insert(highlights, { { path_len, full_len }, "Identifier" })
                  end

                  return highlights
                end,
              },
              { tostring(entry.version or ""), "Number" },
            }
          end,
          filename = entry.path .. "/Cargo.toml",
          ordinal = table.concat({
            tostring(entry.parent_display or ""),
            tostring(entry.name or ""),
            tostring(entry.version or ""),
            tostring(entry.path or ""),
          }, " "),
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

M._format_path_crate = function(parent_display, crate_name)
  local prefix = parent_display or ""

  if prefix ~= "" and prefix ~= "." then
    prefix = prefix .. "/"
  elseif prefix == "." then
    prefix = "./"
  else
    prefix = ""
  end

  local name = tostring(crate_name or "")
  return prefix .. name, #prefix
end

M._max_display_path_crate_width = function(workspace)
  local max_width = 0

  for _, entry in ipairs(workspace) do
    local display_path_crate = M._format_path_crate(entry.parent_display, entry.name)
    local width = vim.fn.strdisplaywidth(display_path_crate)
    if width > max_width then
      max_width = width
    end
  end

  if max_width == 0 then
    return 1
  end

  return max_width
end

M._ensure_highlights = function()
  if M._highlights_initialized then
    return
  end

  local ok = pcall(vim.api.nvim_set_hl, 0, "TelescopeCargoWorkspacePath", {
    link = "Comment",
    default = true,
  })

  if ok then
    M._highlights_initialized = true
  end
end

---
-- TODO @mattcairns: This function should display files in the cargo workspace sorted by workspace, with workspace names displayed next to the filename.
-- @param opts (table) Optional configuration options for the picker.
M.find_files_in_workspace = function(opts)
  local cargo_workspaces = M._get_cargo_workspaces()
  opts = opts or {}
  local file_list = {}

  for _, workspace in ipairs(cargo_workspaces) do
    local workspace_name = workspace.name
    local workspace_path = workspace.path
    local workspace_prefix = workspace_path .. "/"
    local files_in_workspace = vim.fn.glob(workspace_path .. "/**/*", true, true)
    
    for _, file in ipairs(files_in_workspace) do
      local relative_file = file
      if vim.startswith(file, workspace_prefix) then
        relative_file = string.sub(file, #workspace_prefix + 1)
      end

      table.insert(file_list, { workspace_name, file, relative_file })
    end
  end

  pickers.new(opts, {
    prompt_title = "Cargo Workspaces Files",
    previewer = conf.file_previewer(opts),
    finder = finders.new_table {
      results = file_list,
      entry_maker = function(entry)
        return {
          value = entry[2],
          display = entry[3] .. " (" .. entry[1] .. ")",
          filename = entry[2],
          ordinal = entry[3] .. " " .. entry[1] .. " " .. entry[2],
        }
      end
    },
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        local save_dir = vim.fn.chdir(vim.fn.fnamemodify(selection.value, ":h"))
      end)
      return true
    end,
  }):find()
end

---
-- Calls the `cargo metadata` command to retrieve metadata for the current Rust project.
-- @return string The metadata in JSON format.
M._call_cargo_metadata = function()
  -- perform preliminary checks to ensure that cargo is installed 
  local is_cargo_installed = os.execute("which cargo >/dev/null 2>&1")
  if is_cargo_installed ~= 0 then
    error("Cargo is not installed")
  end

  local cmd = "cargo metadata --no-deps 2> /dev/null"
  local handle = io.popen(cmd, "r")
  local json = handle:read("*a")
  handle:close()
  return json
end

---
-- Parses the cargo workspaces from a JSON input string.
-- @param string json_input The JSON input string to parse.
-- @return table An array of package metadata tables containing
--         name, version, path, and parent display path.
M._parse_cargo_workspaces_from_json = function(json_input)
  local cargo_workspaces = {}

  local decoded_input = vim.json.decode(json_input)

  for _, package in ipairs(decoded_input.packages) do
    local path = M._extract_path_from_id(package.id) 
    -- Remove the version part from the path if it exists
    path = path:match("([^#]+)")
    table.insert(cargo_workspaces, {
      name = package.name,
      version = package.version,
      path = path,
      parent_display = M._parent_path_for_display(path),
    })
  end

  return cargo_workspaces
end


M._get_cargo_workspaces = function()
  local json_input = M._call_cargo_metadata()
  local cargo_workspaces = M._parse_cargo_workspaces_from_json(json_input)
  table.sort(cargo_workspaces, function(a, b)
    local a_path = string.lower(a.parent_display)
    local b_path = string.lower(b.parent_display)
    if a_path ~= b_path then
      return a_path < b_path
    end

    local a_name = string.lower(a.name)
    local b_name = string.lower(b.name)
    if a_name ~= b_name then
      return a_name < b_name
    end

    if a.version ~= b.version then
      return a.version < b.version
    end

    if a.path == b.path then
      return a.name < b.name
    else
      return a.path < b.path
    end
  end)

  return cargo_workspaces
end

---
-- Retrieves the project names from metadata JSON.
-- @param metadata_json The metadata in JSON format.
-- @return A table containing the project names.
M._get_project_names = function(metadata_json)
  local projects = {}
  for _,v in ipairs(metadata_json) do
    table.insert(projects, v.name)
  end
end

M._parent_path_for_display = function(path)
  local parent_path = vim.fn.fnamemodify(path, ":h")
  local relative_parent_path = vim.fn.fnamemodify(parent_path, ":.")
  return relative_parent_path
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
