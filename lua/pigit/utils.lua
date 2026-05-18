local M = {}

local _detected_tree = nil

---Detect available file tree plugin (memoized after first call)
---@return string tree_type
function M.detect_file_tree()
  if _detected_tree then
    return _detected_tree
  end
  local config = require("pigit.config").get()
  if config.file_tree then
    _detected_tree = config.file_tree
    return _detected_tree
  end
  local ok, _ = pcall(require, "nvim-tree")
  if ok then
    _detected_tree = "nvim-tree"
    return _detected_tree
  end
  local ok2, _ = pcall(require, "neo-tree.command")
  if ok2 then
    _detected_tree = "neo-tree"
    return _detected_tree
  end
  local ok3, _ = pcall(require, "mini.files")
  if ok3 then
    _detected_tree = "mini.files"
    return _detected_tree
  end
  _detected_tree = "netrw"
  return _detected_tree
end

---Get basename of a path
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

return M
