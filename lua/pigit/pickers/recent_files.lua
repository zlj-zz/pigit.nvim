local M = {}

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

---@param repo_path string
---@param depth number
---@param unique boolean
---@param callback fun(err: string|nil, files: table[]|nil)
function M.fetch_git_files(repo_path, depth, unique, callback)
  require("pigit.utils").log("debug", "fetching git files: depth=%d, unique=%s", depth, tostring(unique))
  require("pigit.git").run_cmd(
    { "git", "log", "--diff-filter=d", "--name-only", "-n", tostring(depth), "--pretty=format:" },
    repo_path,
    function(code, out, _)
      if code ~= 0 then
        require("pigit.utils").log("warn", "git log failed for %s", repo_path)
        callback("git log failed", nil)
        return
      end

      local files = {}
      local seen = {}

      for line in out:gmatch("[^\r\n]+") do
        if line == "" then
          goto continue
        end
        if unique then
          if seen[line] then
            goto continue
          end
          seen[line] = true
        end
        table.insert(files, {
          path = line,
          filename = require("pigit.utils").basename(line),
          source = "git",
        })
        ::continue::
      end

      callback(nil, files)
    end
  )
end

---@param repo_path string
---@param max number
---@return table[]
function M.fetch_mru_files(repo_path, max)
  local files = {}
  local seen = {}
  local count = 0

  for _, f in ipairs(vim.v.oldfiles) do
    if count >= max then
      break
    end
    -- Pre-filter with Lua string match before expensive vim.fn.expand
    if not vim.startswith(f, repo_path) then
      goto continue
    end
    local full = vim.fn.expand(f)
    if vim.startswith(full, repo_path) then
      local rel = full:sub(#repo_path + 2)
      if rel ~= "" and not seen[rel] then
        seen[rel] = true
        table.insert(files, {
          path = rel,
          filename = require("pigit.utils").basename(rel),
          source = "mru",
        })
        count = count + 1
      end
    end
    ::continue::
  end

  return files
end

---Merge git and mru files, deduplicate, git-first order
---@param git_files table[]
---@param mru_files table[]
---@return table[]
function M.merge_hybrid(git_files, mru_files)
  local merged = {}
  local seen = {}

  -- git_files is already deduplicated; copy directly
  for _, f in ipairs(git_files) do
    seen[f.path] = true
    table.insert(merged, f)
  end

  for _, f in ipairs(mru_files) do
    if not seen[f.path] then
      seen[f.path] = true
      table.insert(merged, f)
    end
  end

  return merged
end

---@param repo {name: string, path: string}
---@param opts table|nil
function M.open(repo, opts)
  opts = opts or {}
  require("pigit.utils").log("debug", "opening recent files picker: %s (mode=%s)", repo.name, require("pigit.config").get().recent_files_mode)
  local config = require("pigit.config").get()
  local utils = require("pigit.utils")

  local ok, _ = pcall(require, "telescope")
  if not ok then
    vim.notify(config.messages.telescope_not_found, vim.log.levels.ERROR)
    return
  end

  utils.safe_hook_call("before_open", config.hooks.before_open, "recent_files")

  local mode = config.recent_files_mode
  local depth = config.recent_files_git_depth
  local unique = config.recent_files_git_unique

  local function open_picker(files)
    vim.schedule(function()
      local get_file_icon = utils.get_file_icon
      pickers.new(opts, {
        prompt_title = "Recent Files: " .. repo.name,
        finder = finders.new_table({
          results = files or {},
          entry_maker = function(file)
            local display = file.filename
            local icon = ""
            if config.devicons then
              icon, _ = get_file_icon(file.path)
              if icon ~= "" then
                display = icon .. " " .. display
              end
            end
            return {
              value = vim.fs.joinpath(repo.path, file.path),
              ordinal = file.path,
              display = display,
            }
          end,
        }),
        sorter = conf.generic_sorter(opts),
        attach_mappings = function(prompt_bufnr, _)
          actions.select_default:replace(function()
            local selection = action_state.get_selected_entry()
            if not selection then
              return
            end
            actions.close(prompt_bufnr)
            require("pigit.actions").open_file(selection.value)
          end)
          return true
        end,
      }):find()
    end)
  end

  if mode == "mru" then
    local files = M.fetch_mru_files(repo.path, depth)
    open_picker(files)
    return
  end

  M.fetch_git_files(repo.path, depth, unique, function(err, git_files)
    if err then
      require("pigit.utils").log("error", "fetch_git_files failed: %s", err)
      vim.notify("pigit: " .. err, vim.log.levels.ERROR)
      return
    end

    if mode == "hybrid" then
      local mru_files = M.fetch_mru_files(repo.path, depth)
      local merged = M.merge_hybrid(git_files or {}, mru_files)
      open_picker(merged)
    else
      open_picker(git_files or {})
    end
  end)
end

return M
