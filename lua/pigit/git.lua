local M = {}

---@class GitMetadata
---@field branch string
---@field ahead number
---@field behind number
---@field unstaged boolean
---@field staged boolean
---@field untracked boolean
---@field last_commit_msg string
---@field last_commit_author string
---@field last_commit_time string

local function run_cmd(cmd, cwd, callback)
  if vim.system then
    vim.system(cmd, { cwd = cwd, text = true }, function(obj)
      vim.schedule(function()
        callback(obj.code, obj.stdout or "", obj.stderr or "")
      end)
    end)
  else
    -- Fallback to vim.loop.spawn
    local stdout_data = {}
    local stderr_data = {}
    local handle
    handle = vim.loop.spawn(cmd[1], {
      args = vim.list_slice(cmd, 2),
      cwd = cwd,
      stdio = { nil, vim.loop.new_pipe(), vim.loop.new_pipe() },
    }, function(code)
      vim.schedule(function()
        callback(code, table.concat(stdout_data), table.concat(stderr_data))
      end)
      if handle then
        handle:close()
      end
    end)

    -- Read stdout
    vim.loop.read_start(handle:get_stdio(2), function(err, data)
      if data then
        table.insert(stdout_data, data)
      end
    end)
    -- Read stderr
    vim.loop.read_start(handle:get_stdio(3), function(err, data)
      if data then
        table.insert(stderr_data, data)
      end
    end)
  end
end

function M.fetch_metadata(repo_path, callback)
  local meta = {}
  local pending = 3
  local has_error = false

  local function done()
    pending = pending - 1
    if pending == 0 then
      callback(has_error and "git command failed" or nil, has_error and nil or meta)
    end
  end

  -- 1. branch
  run_cmd({ "git", "symbolic-ref", "--short", "HEAD" }, repo_path, function(code, out, err)
    if code == 0 then
      meta.branch = vim.trim(out)
    else
      meta.branch = "?"
      has_error = true
    end
    done()
  end)

  -- 2. status
  run_cmd({ "git", "status", "--porcelain" }, repo_path, function(code, out, err)
    meta.unstaged = false
    meta.staged = false
    meta.untracked = false
    if code == 0 then
      for line in out:gmatch("[^\r\n]+") do
        if #line >= 2 then
          local x, y = line:sub(1, 1), line:sub(2, 2)
          if x ~= " " and x ~= "?" then
            meta.staged = true
          end
          if y ~= " " then
            meta.unstaged = true
          end
          if x == "?" and y == "?" then
            meta.untracked = true
          end
        end
      end
    else
      has_error = true
    end
    done()
  end)

  -- 3. last commit
  run_cmd(
    { "git", "log", "-1", "--format=%s|%an|%ar" },
    repo_path,
    function(code, out, err)
      if code == 0 then
        local parts = vim.split(vim.trim(out), "|")
        meta.last_commit_msg = parts[1] or ""
        meta.last_commit_author = parts[2] or ""
        meta.last_commit_time = parts[3] or ""
      else
        meta.last_commit_msg = ""
        meta.last_commit_author = ""
        meta.last_commit_time = ""
        has_error = true
      end
      done()
    end
  )
end

return M
