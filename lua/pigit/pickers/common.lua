local M = {}

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

---@param repo {name: string, path: string}
---@param on_select fun(cmd: string)
function M.command_picker(repo, on_select)
  local config = require("pigit.config").get()
  local cmds = config.pigit_cmd_whitelist

  if #cmds == 0 then
    vim.notify(config.messages.no_commands, vim.log.levels.WARN)
    return
  end

  pickers.new({}, {
    prompt_title = "Pigit Command: " .. repo.name,
    finder = finders.new_table({
      results = cmds,
      entry_maker = function(cmd)
        return {
          value = cmd,
          display = cmd,
          ordinal = cmd,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, _)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        if not selection then
          return
        end
        actions.close(prompt_bufnr)
        on_select(selection.value)
      end)
      return true
    end,
  }):find()
end

return M
