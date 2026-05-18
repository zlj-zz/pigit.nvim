local M = {}

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

---@class RecentFileEntry
---@field path string relative path from repo root
---@field filename string

---Fetch recent files via git log
---@param repo_path string
---@param depth number
---@param unique boolean
---@param callback fun(err: string|nil, files: RecentFileEntry[]|nil)
function M.fetch_git_files(repo_path, depth, unique, callback)
  require("pigit.git").run_cmd(
    { "git", "log", "--diff-filter=d", "--name-only", "-n", tostring(depth), "--pretty=format:" },
    repo_path,
    function(code, out, _)
      if code ~= 0 then
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
        })
        ::continue::
      end

      callback(nil, files)
    end
  )
end

---Open recent files picker for a repo
---@param repo {name: string, path: string}
---@param opts table|nil Telescope picker opts
function M.open(repo, opts)
  opts = opts or {}
  local config = require("pigit.config").get()

  local ok, _ = pcall(require, "telescope")
  if not ok then
    vim.notify("pigit: telescope.nvim not found", vim.log.levels.ERROR)
    return
  end

  config.hooks.before_open("recent_files")

  local depth = config.recent_files_git_depth
  local unique = config.recent_files_git_unique

  M.fetch_git_files(repo.path, depth, unique, function(err, files)
    if err then
      vim.notify("pigit: " .. err, vim.log.levels.ERROR)
      return
    end

    vim.schedule(function()
      pickers.new(opts, {
        prompt_title = "Recent Files: " .. repo.name,
        finder = finders.new_table({
          results = files or {},
          entry_maker = function(file)
            local display = file.filename
            local icon = ""
            if config.devicons then
              icon, _ = require("pigit.utils").get_file_icon(file.path)
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
  end)
end

return M
