local M = {}

---Telescope extension entry points
M.pickers = {
  repos = require("pigit.pickers.repos"),
  recent_files = require("pigit.pickers.recent_files"),
}

---Get repo by name (for extension usage)
---@param name string
---@return {name: string, path: string}|nil
function M.get_repo(name)
  return require("pigit.repos").get_by_name(name)
end

function M.setup(opts)
  require("pigit.config").resolve(opts)

  require("pigit.utils").register_highlights()

  vim.api.nvim_create_user_command("PigitRepos", function(cmd_opts)
    require("pigit.pickers.repos").open({ default_text = cmd_opts.args })
  end, { nargs = "?", desc = "Open pigit repo picker" })

  vim.api.nvim_create_user_command("PigitRecentFiles", function(cmd_opts)
    local repos = require("pigit.repos")
    local config = require("pigit.config").get()
    local path = repos.resolve_path(config.repos_json_path)
    local all_repos, err = repos.load_cached(path)
    if err then
      vim.notify("pigit: " .. err, vim.log.levels.ERROR)
      return
    end
    local repo_name = cmd_opts.args
    if repo_name == "" then
      vim.notify(config.messages.repo_name_required, vim.log.levels.ERROR)
      return
    end
    local info = all_repos[repo_name]
    if not info then
      vim.notify(string.format(config.messages.repo_not_found, repo_name), vim.log.levels.ERROR)
      return
    end
    require("pigit.pickers.recent_files").open({ name = repo_name, path = info.path })
  end, { nargs = 1, desc = "Open recent files picker for a repo" })

  vim.api.nvim_create_user_command("PigitRefresh", function()
    require("pigit.cache").invalidate()
    require("pigit.repos").invalidate_cache()
    local config = require("pigit.config").get()
    require("pigit.utils").safe_hook_call("after_refresh", config.hooks.after_refresh)
    vim.notify(config.messages.cache_refreshed, vim.log.levels.INFO)
  end, { desc = "Invalidate pigit cache" })

  local config = require("pigit.config").get()
  local path = require("pigit.repos").resolve_path(config.repos_json_path)
  local stop_watcher = require("pigit.repos").watch(path, function()
    require("pigit.cache").invalidate()
    require("pigit.repos").invalidate_cache()
    vim.notify(config.messages.repos_changed, vim.log.levels.INFO)
  end)

  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      stop_watcher()
    end,
  })
end

return M
