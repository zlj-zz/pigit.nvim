local M = {}

function M.cd(repo, scope, open_on_enter)
  local config = require("pigit.config").get()

  -- Execute hooks
  config.hooks.before_cd(repo)

  -- Change directory
  vim.cmd[scope](repo.path)

  -- open_on_enter handling
  if open_on_enter == "empty" then
    vim.cmd("enew")
  elseif open_on_enter == "tree" then
    -- v0.1.0 only supports netrw; file_tree auto-detection in v0.2.0
    vim.cmd("edit " .. vim.fn.fnameescape(repo.path))
  elseif open_on_enter == "recent_file" then
    -- v0.1.0 not implemented, silently ignored
  end

  config.hooks.after_cd(repo)
end

return M
