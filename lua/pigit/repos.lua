local M = {}

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

return M
