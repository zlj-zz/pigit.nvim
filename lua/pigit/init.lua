local M = {}

---Telescope extension entry points
M.pickers = {
  repos = require("pigit.pickers.repos"),
  recent_files = require("pigit.pickers.recent_files"),
  branches = require("pigit.pickers.branches"),
  status = require("pigit.pickers.status"),
}

---Get repo by name (for extension usage)
---@param name string
---@return {name: string, path: string}|nil
function M.get_repo(name)
  return require("pigit.repos").get_by_name(name)
end

---@param opts table|nil
function M.setup(opts)
  require("pigit.config").resolve(opts)
  local utils = require("pigit.utils")
  utils.register_highlights()
  utils.log("info", "pigit setup complete")

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

  vim.api.nvim_create_user_command("PigitBranches", function(cmd_opts)
    local args = cmd_opts.args
    require("pigit.pickers.branches").open({
      repo_name = args ~= "" and args or nil,
    })
  end, { nargs = "?", desc = "Open branch picker for current or specified repo" })

  vim.api.nvim_create_user_command("PigitStatus", function(cmd_opts)
    local args = cmd_opts.args
    require("pigit.pickers.status").open({
      repo_name = args ~= "" and args or nil,
    })
  end, { nargs = "?", desc = "Open git status picker for current or specified repo" })

  vim.api.nvim_create_user_command("PigitTerm", function(cmd_opts)
    local repo, err = require("pigit.utils").resolve_repo({ repo_name = cmd_opts.args ~= "" and cmd_opts.args or nil })
    if not repo then
      vim.notify(err or "pigit: unknown repo", vim.log.levels.ERROR)
      return
    end
    require("pigit.terminal").open({ cwd = repo.path, cmd = "pigit" })
  end, { nargs = "?", desc = "Run pigit TUI in floating terminal for current or specified repo" })

  local config = require("pigit.config").get()

  if config.auto_cd_on_open then
    vim.api.nvim_create_autocmd("BufReadPost", {
      group = vim.api.nvim_create_augroup("PigitAutoCd", { clear = true }),
      callback = function()
        local buf = vim.api.nvim_get_current_buf()
        local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })
        if buftype ~= "" then
          return
        end
        local filepath = vim.api.nvim_buf_get_name(buf)
        if filepath == "" then
          return
        end
        local repos = require("pigit.repos")
        local repos_path = repos.resolve_path(config.repos_json_path)
        local all_repos, _ = repos.load_cached(repos_path)
        if not all_repos then
          return
        end
        for name, info in pairs(all_repos) do
          if require("pigit.utils").is_subpath(filepath, info.path) then
            local cwd = vim.fn.getcwd()
            if cwd ~= info.path then
              vim.cmd[config.cd_scope](info.path)
            end
            break
          end
        end
      end,
    })
  end

  local path = require("pigit.repos").resolve_path(config.repos_json_path)
  local stop_watcher = require("pigit.repos").watch(path, function()
    utils.log("debug", "repos.json changed on disk, invalidating cache")
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
