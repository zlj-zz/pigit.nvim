local M = {}

function M.setup(opts)
  require("pigit.config").resolve(opts)

  -- Register highlight groups
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

  -- Register commands
  vim.api.nvim_create_user_command("PigitRepos", function(cmd_opts)
    require("pigit.pickers.repos").open({ default_text = cmd_opts.args })
  end, { nargs = "?", desc = "Open pigit repo picker" })

  vim.api.nvim_create_user_command("PigitRefresh", function()
    require("pigit.cache").invalidate()
    vim.notify("pigit cache refreshed", vim.log.levels.INFO)
  end, { desc = "Invalidate pigit cache" })
end

return M
