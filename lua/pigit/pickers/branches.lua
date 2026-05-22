local M = {}

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

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

	utils.log("debug", "opening branch picker: %s", repo.name)

	require("pigit.git").run_cmd(
		{ "git", "branch", "--format=%(refname:short)|%(HEAD)" },
		repo.path,
		function(code, out, _)
			if code ~= 0 then
				vim.schedule(function()
					vim.notify(config.messages.no_branches, vim.log.levels.WARN)
				end)
				return
			end

			vim.schedule(function()
				local branches = {}
				local current_branch = nil

				for line in out:gmatch("[^\r\n]+") do
					local name, head = line:match("^([^|]+)|(.*)$")
					local is_head = head == "*"
					if name then
						if is_head then
							current_branch = name
						end
						table.insert(branches, { name = name, is_head = is_head })
					end
				end

				table.sort(branches, function(a, b)
					if a.is_head and not b.is_head then
						return true
					end
					if b.is_head and not a.is_head then
						return false
					end
					return a.name < b.name
				end)

				pickers
					.new(opts, {
						prompt_title = "Branches: " .. repo.name,
						finder = finders.new_table({
							results = branches,
							entry_maker = function(branch)
								local display = branch.name
								if branch.is_head then
									display = "* " .. display
								end
								return {
									value = branch.name,
									display = display,
									ordinal = branch.name,
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

								local branch_name = selection.value
								if branch_name == current_branch then
									utils.log("debug", "branch %s is already checked out", branch_name)
									return
								end
								if branch_name == "HEAD" then
									utils.log("debug", "cannot checkout detached HEAD")
									return
								end

								require("pigit.git").run_cmd(
									{ "git", "checkout", branch_name },
									repo.path,
									function(exit_code, _, stderr)
										vim.schedule(function()
											if exit_code == 0 then
												vim.notify(
													string.format(config.messages.branch_checkout_success, branch_name),
													vim.log.levels.INFO
												)
												require("pigit.cache").invalidate(repo.name)
											else
												vim.notify(
													string.format(config.messages.branch_checkout_failed, stderr or ""),
													vim.log.levels.ERROR
												)
											end
										end)
									end
								)
							end)
							return true
						end,
					})
					:find()
			end)
		end
	)
end

return M
