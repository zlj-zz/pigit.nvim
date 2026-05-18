local M = {}

---@param repo {name: string, path: string}
---@param scope "cd"|"tcd"|"lcd"
---@param open_on_enter "none"|"empty"|"tree"|"recent_file"
function M.cd(repo, scope, open_on_enter)
  local config = require("pigit.config").get()
  local utils = require("pigit.utils")

  local current_dir = vim.fn.getcwd()
  local repos = require("pigit.repos")
  local path = repos.resolve_path(config.repos_json_path)
  local all_repos, _ = repos.load_cached(path)
  for name, info in pairs(all_repos or {}) do
    if utils.is_subpath(current_dir, info.path) and info.path ~= repo.path then
      utils.safe_hook_call("before_leave", config.hooks.before_leave, { name = name, path = info.path })
      break
    end
  end

  utils.safe_hook_call("before_cd", config.hooks.before_cd, repo)

  vim.cmd[scope](repo.path)

  if open_on_enter == "empty" then
    vim.cmd("enew")
  elseif open_on_enter == "tree" then
    M.open_tree(repo.path)
  elseif open_on_enter == "recent_file" then
    require("pigit.pickers.recent_files").open(repo)
  end

  utils.safe_hook_call("after_cd", config.hooks.after_cd, repo)
end

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

---@param file_path string
function M.open_file(file_path)
  vim.cmd("edit " .. vim.fn.fnameescape(file_path))
end

---Run a whitelisted pigit command asynchronously
---@param repo {name: string, path: string}
---@param cmd string one of "fetch", "pull", "push", "status"
function M.run_pigit_cmd(repo, cmd)
  local config = require("pigit.config").get()
  local utils = require("pigit.utils")

  if not vim.tbl_contains(config.pigit_cmd_whitelist, cmd) then
    vim.notify(string.format(config.messages.command_not_allowed, cmd), vim.log.levels.ERROR)
    return
  end

  vim.notify(string.format(config.messages.running_cmd, cmd, repo.name), vim.log.levels.INFO)
  utils.log("debug", "running pigit cmd: %s on %s", cmd, repo.name)

  local function handle_result(code, out, err)
    if code ~= 0 then
      vim.notify(
        string.format(config.messages.cmd_failed, cmd, repo.name, err or ""),
        vim.log.levels.ERROR
      )
    else
      vim.notify(string.format(config.messages.cmd_completed, cmd, repo.name), vim.log.levels.INFO)
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
