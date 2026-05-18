local M = {}

-- Deep copy to prevent user modifications from affecting defaults
local function deep_copy(t)
  local result = {}
  for k, v in pairs(t) do
    if type(v) == "table" then
      result[k] = deep_copy(v)
    else
      result[k] = v
    end
  end
  return result
end

M.defaults = {
  repos_json_path = nil,
  cd_scope = "tcd",
  open_on_enter = "none",
  picker = {
    theme = "dropdown",
    layout_config = {},
    previewer = true,
  },
  cache = {
    ttl = 30,
    max_workers = 4,
    initial_batch = 50,
    batch_size = 50,
    batch_interval_ms = 200,
  },
  recent_files_git_depth = 50,
  recent_files_git_unique = true,
  recent_files_mode = "git",     -- "git" | "hybrid" | "mru"
  file_tree = nil,
  icons = {
    branch = "",
    ahead = "↑",
    behind = "↓",
    unstaged = "*",
    staged = "+",
    untracked = "?",
    clean = "✓",
  },
  devicons = true,
  pigit_cmd_whitelist = { "fetch", "pull", "push", "status" },
  default_filter = "all",
  log_level = "warn",            -- "debug" | "info" | "warn" | "error"
  messages = {
    no_repos = "No managed repos. Run: pigit repo add <path>",
    repo_not_found = "Repo not found: %s",
    invalid_repo = "[invalid]",
    no_commands = "pigit: no commands in whitelist",
    command_not_allowed = "pigit: command not allowed: %s",
    running_cmd = "pigit: running %s on %s ...",
    cmd_failed = "pigit: %s failed on %s: %s",
    cmd_completed = "pigit: %s completed on %s",
    cache_refreshed = "pigit cache refreshed",
    repos_changed = "pigit: repos.json changed, cache invalidated",
    telescope_not_found = "pigit: telescope.nvim not found. Install: nvim-telescope/telescope.nvim",
    repo_name_required = "pigit: repo name required",
    fs_event_unavailable = "pigit: fs_event not available",
    no_recent_files = "(no recent files)",
    loading = "Loading...",
    recent_files_loading = "(loading...)",
  },
  mappings = {
    repos = {},
    recent_files = {},
  },
  hooks = {
    before_open = function() end,
    before_cd = function() end,
    after_cd = function() end,
    before_leave = function() end,
    after_refresh = function() end,
  },
}

M._current = nil

-- Resolve user options against defaults
function M.resolve(user_opts)
  user_opts = user_opts or {}
  local config = deep_copy(M.defaults)

  -- Top-level field override
  for k, v in pairs(user_opts) do
    if type(v) == "table" and type(config[k]) == "table" and k ~= "hooks" then
      -- Sub-table shallow override (one level only)
      for sk, sv in pairs(v) do
        config[k][sk] = sv
      end
    else
      config[k] = v
    end
  end

  -- Validate cd_scope
  local valid_scopes = { tcd = true, cd = true, lcd = true }
  if not valid_scopes[config.cd_scope] then
    error("invalid cd_scope: " .. tostring(config.cd_scope))
  end

  -- Validate open_on_enter
  local valid_open = { none = true, empty = true, tree = true, recent_file = true }
  if not valid_open[config.open_on_enter] then
    error("invalid open_on_enter: " .. tostring(config.open_on_enter))
  end

  -- Validate log_level
  local valid_log = { debug = true, info = true, warn = true, error = true }
  if not valid_log[config.log_level] then
    error("invalid log_level: " .. tostring(config.log_level))
  end

  -- Validate recent_files_mode
  local valid_modes = { git = true, hybrid = true, mru = true }
  if not valid_modes[config.recent_files_mode] then
    error("invalid recent_files_mode: " .. tostring(config.recent_files_mode))
  end

  -- Messages shallow override
  if user_opts.messages then
    for k, v in pairs(user_opts.messages) do
      if type(v) == "string" then
        config.messages[k] = v
      end
    end
  end

  -- Hooks need shallow copy to avoid modifying default empty functions
  if user_opts.hooks then
    for k, v in pairs(user_opts.hooks) do
      if type(v) == "function" then
        config.hooks[k] = v
      end
    end
  end

  -- PIGIT_DEBUG=1 forces debug log level
  if vim.env.PIGIT_DEBUG == "1" then
    config.log_level = "debug"
  end

  M._current = config
  return config
end

function M.get()
  if not M._current then
    M.resolve()
  end
  return M._current
end

return M
