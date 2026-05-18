local M = {}

function M.check()
  vim.health.start("pigit.nvim")

  -- 1. Neovim version
  local version = vim.version()
  if version.major > 0 or version.minor >= 10 then
    vim.health.ok("Neovim " .. tostring(vim.version()))
  else
    vim.health.error("Neovim >= 0.10 required, found " .. tostring(vim.version()))
    return
  end

  -- 2. pigit CLI
  if vim.fn.executable("pigit") == 1 then
    vim.health.ok("pigit CLI found")
  else
    vim.health.error("pigit CLI not found. Install: pip install pigit")
    return
  end

  -- 3. repos.json
  local config = require("pigit.config").get()
  local repos = require("pigit.repos")
  local path = repos.resolve_path(config.repos_json_path)
  vim.health.info("repos.json path: " .. path)

  local all_repos, err = repos.load(path)
  if err then
    vim.health.error("repos.json: " .. err)
    return
  end

  local count = vim.tbl_count(all_repos)
  vim.health.ok("repos.json valid, " .. count .. " repo(s) managed")

  -- 4. Sample check first 5 repos
  if count > 0 then
    local sorted = {}
    for name, info in pairs(all_repos) do
      table.insert(sorted, { name = name, path = info.path })
    end
    table.sort(sorted, function(a, b)
      return a.name < b.name
    end)

    local invalid = {}
    for i = 1, math.min(5, #sorted) do
      local r = sorted[i]
      local git_dir = vim.fs.joinpath(r.path, ".git")
      if vim.fn.isdirectory(r.path) ~= 1 or vim.fn.isdirectory(git_dir) ~= 1 then
        table.insert(invalid, r.name)
      end
    end

    if #invalid > 0 then
      vim.health.warn("Invalid repos (sampled): " .. table.concat(invalid, ", "))
    else
      vim.health.ok("All sampled repos valid")
    end
  end

  -- 5. Telescope
  local ok, _ = pcall(require, "telescope")
  if ok then
    vim.health.ok("telescope.nvim installed")
  else
    vim.health.error("telescope.nvim not found. Install: nvim-telescope/telescope.nvim")
  end

  -- 6. devicons (optional)
  local ok2, _ = pcall(require, "nvim-web-devicons")
  if ok2 then
    vim.health.ok("nvim-web-devicons installed")
  else
    vim.health.info("nvim-web-devicons not installed (icons will not show)")
  end
end

return M
