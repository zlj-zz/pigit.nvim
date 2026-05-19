local M = {}

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

---@param x string staged status code
---@param y string unstaged status code
---@return number sort_key 1=staged, 2=unstaged, 3=untracked
local function get_sort_key(x, y)
  if x == "?" and y == "?" then
    return 3
  end
  if x ~= " " and x ~= "?" then
    return 1
  end
  return 2
end

---@param x string staged status code
---@param y string unstaged status code
---@param config_icons table
---@return string icons combined status icons
local function get_status_icons(x, y, config_icons)
  local icons = ""
  if x ~= " " and x ~= "?" then
    icons = icons .. config_icons.staged .. " "
  end
  if y ~= " " then
    icons = icons .. config_icons.unstaged .. " "
  end
  if x == "?" and y == "?" then
    icons = icons .. config_icons.untracked
  end
  return vim.trim(icons)
end

---@param opts table|nil
function M.open(opts)
  opts = opts or {}
  local config = require("pigit.config").get()
  local utils = require("pigit.utils")

  if not utils.ensure_telescope() then
    return
  end

  local repo, err = utils.resolve_repo(opts)
  if not repo then
    vim.notify(err or config.messages.not_in_repo, vim.log.levels.ERROR)
    return
  end

  local last_cd_path = nil

  utils.log("debug", "opening status picker: %s", repo.name)

  require("pigit.git").run_cmd(
    { "git", "status", "--porcelain" },
    repo.path,
    function(code, out, _)
      if code ~= 0 then
        vim.schedule(function()
          vim.notify(config.messages.no_status_changes, vim.log.levels.WARN)
        end)
        return
      end

      vim.schedule(function()
        local files = {}

        for line in out:gmatch("[^\r\n]+") do
          if #line >= 3 then
            local x, y = line:sub(1, 1), line:sub(2, 2)
            local file = line:sub(4)

            if x == "R" then
              file = file:match("^.*%-%>%s*(.+)$") or file
            end

            if file:sub(1, 1) == '"' and file:sub(-1) == '"' then
              file = file:sub(2, -2)
            end

            if file ~= "" then
              local abs_path = vim.fs.joinpath(repo.path, file)
              table.insert(files, {
                path = abs_path,
                rel_path = file,
                sort_key = get_sort_key(x, y),
                icons = get_status_icons(x, y, config.icons),
              })
            end
          end
        end

        if #files == 0 then
          vim.notify(config.messages.no_status_changes, vim.log.levels.INFO)
          return
        end

        table.sort(files, function(a, b)
          if a.sort_key ~= b.sort_key then
            return a.sort_key < b.sort_key
          end
          return a.rel_path < b.rel_path
        end)

        pickers.new(opts, {
          prompt_title = "Status: " .. repo.name,
          finder = finders.new_table({
            results = files,
            entry_maker = function(file)
              local display = file.icons .. " " .. file.rel_path
              return {
                value = file.path,
                display = display,
                ordinal = file.rel_path,
                filename = file.path,
              }
            end,
          }),
          sorter = conf.generic_sorter(opts),
          attach_mappings = function(prompt_bufnr, _)
            local function open_file(split)
              return function()
                local selection = action_state.get_selected_entry()
                if not selection then return end
                actions.close(prompt_bufnr)

                if last_cd_path ~= repo.path then
                  vim.cmd[config.cd_scope](repo.path)
                  last_cd_path = repo.path
                end

                if split == "vertical" then
                  require("pigit.actions").open_split(selection.value, "vertical")
                elseif split == "horizontal" then
                  require("pigit.actions").open_split(selection.value, "horizontal")
                else
                  require("pigit.actions").open_file(selection.value)
                end
              end
            end

            actions.select_default:replace(open_file())

            vim.keymap.set("i", "<C-v>", open_file("vertical"), { buffer = prompt_bufnr, nowait = true })
            vim.keymap.set("i", "<C-x>", open_file("horizontal"), { buffer = prompt_bufnr, nowait = true })

            return true
          end,
        }):find()
      end)
    end
  )
end

return M
