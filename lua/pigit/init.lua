local M = {}

function M.setup(opts)
  require("pigit.config").resolve(opts)

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
      vim.notify("pigit: repo name required", vim.log.levels.ERROR)
      return
    end
    local info = all_repos[repo_name]
    if not info then
      vim.notify("pigit: repo not found: " .. repo_name, vim.log.levels.ERROR)
      return
    end
    require("pigit.pickers.recent_files").open({ name = repo_name, path = info.path })
  end, { nargs = 1, desc = "Open recent files picker for a repo" })

  vim.api.nvim_create_user_command("PigitRefresh", function()
    require("pigit.cache").invalidate()
    require("pigit.repos").invalidate_cache()
    vim.notify("pigit cache refreshed", vim.log.levels.INFO)
  end, { desc = "Invalidate pigit cache" })
end

return M
