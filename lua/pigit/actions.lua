local M = {}

function M.cd(repo, scope, open_on_enter)
  local config = require("pigit.config").get()

  config.hooks.before_cd(repo)
  vim.cmd[scope](repo.path)

  if open_on_enter == "empty" then
    vim.cmd("enew")
  elseif open_on_enter == "tree" then
    M.open_tree(repo.path)
  elseif open_on_enter == "recent_file" then
    require("pigit.pickers.recent_files").open(repo)
  end

  config.hooks.after_cd(repo)
end

---Open file tree at repo root
---@param repo_path string
---@param tree_type string|nil "netrw"|"nvim-tree"|"neo-tree"|"mini.files"
function M.open_tree(repo_path, tree_type)
  tree_type = tree_type or require("pigit.utils").detect_file_tree()
  if tree_type == "netrw" then
    vim.cmd("edit " .. vim.fn.fnameescape(repo_path))
  elseif tree_type == "nvim-tree" then
    vim.cmd("NvimTreeOpen " .. vim.fn.fnameescape(repo_path))
  elseif tree_type == "neo-tree" then
    vim.cmd("Neotree reveal " .. vim.fn.fnameescape(repo_path))
  elseif tree_type == "mini.files" then
    require("mini.files").open(repo_path)
  end
end

---Open file in split
---@param file_path string
---@param split "vertical"|"horizontal"|"tab"
function M.open_split(file_path, split)
  local cmd = ({
    vertical = "vsplit",
    horizontal = "split",
    tab = "tabedit",
  })[split] or "edit"
  vim.cmd(cmd .. " " .. vim.fn.fnameescape(file_path))
end

---Open file directly
---@param file_path string
function M.open_file(file_path)
  vim.cmd("edit " .. vim.fn.fnameescape(file_path))
end

---Run a whitelisted pigit command asynchronously
---@param repo {name: string, path: string}
---@param cmd string one of "fetch", "pull", "push", "status"
function M.run_pigit_cmd(repo, cmd)
  local config = require("pigit.config").get()

  if not vim.tbl_contains(config.pigit_cmd_whitelist, cmd) then
    vim.notify("pigit: command not allowed: " .. cmd, vim.log.levels.ERROR)
    return
  end

  vim.notify("pigit: running " .. cmd .. " on " .. repo.name .. " ...", vim.log.levels.INFO)

  local function handle_result(code, out, err)
    if code ~= 0 then
      vim.notify(
        "pigit: " .. cmd .. " failed on " .. repo.name .. ": " .. (err or ""),
        vim.log.levels.ERROR
      )
    else
      vim.notify("pigit: " .. cmd .. " completed on " .. repo.name, vim.log.levels.INFO)
      require("pigit.cache").invalidate(repo.name)
    end
  end

  require("pigit.git").run_cmd(
    { "pigit", "repo", cmd, repo.name },
    repo.path,
    handle_result
  )
end

return M
