local M = {}

---@type string|nil
local _detected_tree = nil

---Detect available file tree plugin (memoized after first call)
---@return string tree_type
function M.detect_file_tree()
  if _detected_tree then
    return _detected_tree
  end
  local config = require("pigit.config").get()
  ---@type string
  local tree
  local file_tree = config.file_tree
  if file_tree then
    tree = file_tree
  elseif pcall(require, "nvim-tree") then
    tree = "nvim-tree"
  elseif pcall(require, "neo-tree.command") then
    tree = "neo-tree"
  elseif pcall(require, "mini.files") then
    tree = "mini.files"
  else
    tree = "netrw"
  end
  _detected_tree = tree
  return tree
end

---@param path string
---@return string
function M.basename(path)
  return vim.fn.fnamemodify(path, ":t")
end

---Get icon for file path (via nvim-web-devicons)
---@param file_path string
---@return string icon, string hl_group
function M.get_file_icon(file_path)
  local ok, devicons = pcall(require, "nvim-web-devicons")
  if not ok then
    return "", ""
  end
  local name = M.basename(file_path)
  local ext = vim.fn.fnamemodify(file_path, ":e")
  local icon, hl = devicons.get_icon(name, ext, { default = true })
  return icon or "", hl or ""
end

---Register default highlight groups for pigit
function M.register_highlights()
  local highlights = {
    PigitRepoName = { default = true, link = "TelescopeResultsIdentifier" },
    PigitBranch = { default = true, link = "TelescopeResultsConstant" },
    PigitDirty = { default = true, link = "DiagnosticWarn" },
    PigitClean = { default = true, link = "DiagnosticOk" },
    PigitInvalid = { default = true, link = "DiagnosticError" },
    PigitPath = { default = true, link = "TelescopeResultsComment" },
  }
  for name, hl in pairs(highlights) do
    vim.api.nvim_set_hl(0, name, hl)
  end
end

---@param mode string
---@return string
function M.get_filter_label(mode)
  local labels = {
    all = "All",
    dirty = "Dirty",
    clean = "Clean",
    unpushed = "Unpushed",
  }
  return labels[mode] or "All"
end

local _log_levels = { debug = 0, info = 1, warn = 2, error = 3 }

---Debug logging with configurable level
---@param level "debug"|"info"|"warn"|"error"
---@param fmt string
function M.log(level, fmt, ...)
  local config = require("pigit.config").get()
  local config_level = _log_levels[config.log_level] or 2
  if _log_levels[level] >= config_level then
    vim.notify(string.format("[pigit] " .. fmt, ...), vim.log.levels[level:upper()])
  end
end

---Call a hook function safely, logging errors without propagating them
---@param name string hook name for error messages
---@param fn function hook function to call
---@param ... any arguments to pass to the hook
function M.safe_hook_call(name, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then
    M.log("error", "%s hook error: %s", name, err)
  end
end

---Check if child path is a subpath of parent (handles trailing slashes)
---@param child string
---@param parent string
---@return boolean
function M.is_subpath(child, parent)
  if #child < #parent then
    return false
  end
  if child:sub(1, #parent) ~= parent then
    return false
  end
  local next_char = child:sub(#parent + 1, #parent + 1)
  return next_char == "" or next_char == "/" or next_char == "\\"
end

return M
