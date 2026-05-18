local M = {}

local _cache = { path = nil, data = nil }

---@param path string
---@return table|nil data, string|nil err
function M.load_cached(path)
  if _cache.path == path and _cache.data then
    return _cache.data, nil
  end
  local data, err = M.load(path)
  if not err then
    _cache.path = path
    _cache.data = data
  end
  return data, err
end

function M.invalidate_cache()
  _cache.path = nil
  _cache.data = nil
end

function M.resolve_path(explicit_path)
  if explicit_path then
    return vim.fn.expand(explicit_path)
  end

  -- $PIGIT_HOME
  local pigit_home = vim.env.PIGIT_HOME
  if pigit_home then
    return vim.fs.joinpath(pigit_home, "repos.json")
  end

  -- $XDG_CONFIG_HOME
  local xdg = vim.env.XDG_CONFIG_HOME
  if xdg then
    return vim.fs.joinpath(xdg, "pigit", "repos.json")
  end

  -- stdpath("config")
  local stdpath = vim.fn.stdpath("config")
  if stdpath then
    return vim.fs.joinpath(stdpath, "pigit", "repos.json")
  end

  -- Platform default
  if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
    return vim.fs.joinpath(vim.env.LOCALAPPDATA or "~/AppData/Local", "pigit", "repos.json")
  else
    return "~/.config/pigit/repos.json"
  end
end

function M.load(path)
  path = vim.fn.expand(path)
  local f = io.open(path, "r")
  if not f then
    return {}, "repos.json not found: " .. path
  end
  local content = f:read("*a")
  f:close()

  local ok, data = pcall(vim.json.decode, content)
  if not ok then
    return {}, "invalid JSON in repos.json: " .. tostring(data)
  end

  if type(data) ~= "table" then
    return {}, "repos.json must be a JSON object"
  end

  -- Validate each entry has a path field
  for name, info in pairs(data) do
    if type(info) ~= "table" or type(info.path) ~= "string" then
      return {}, "invalid entry in repos.json: " .. tostring(name)
    end
  end

  return data, nil
end

---Watch repos.json for changes and trigger callback
---@param path string
---@param on_change fun()
---@return function stop_watcher
function M.watch(path, on_change)
  path = vim.fn.expand(path)
  local uv = vim.uv or vim.loop
  local watcher = uv.new_fs_event()

  if not watcher then
    vim.notify("pigit: fs_event not available", vim.log.levels.WARN)
    return function() end
  end

  watcher:start(path, {}, function(err, fname, events)
    if err then
      return
    end
    vim.schedule(function()
      local data, load_err = M.load(path)
      if not load_err then
        _cache.path = path
        _cache.data = data
        on_change()
      end
    end)
  end)

  return function()
    if watcher then
      local ok, _ = pcall(watcher.stop, watcher)
      if ok then
        watcher:close()
      end
    end
  end
end

return M
