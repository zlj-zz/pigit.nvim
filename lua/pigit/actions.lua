local M = {}

---@param repo {name: string, path: string}
---@param scope "cd"|"tcd"|"lcd"
---@param open_on_enter "none"|"empty"|"tree"|"recent_file"
function M.cd(repo, scope, open_on_enter)
	local config = require("pigit.config").get()
	local utils = require("pigit.utils")
	utils.log("info", "cd to repo: %s (%s)", repo.name, repo.path)

	local current_dir = vim.fn.getcwd()
	if current_dir == repo.path then
		return
	end

	local current_repo, _ = utils.resolve_current_repo()
	if current_repo and current_repo.path ~= repo.path then
		utils.safe_hook_call("before_leave", config.hooks.before_leave, current_repo)
	end

	if config.close_buffers_on_leave then
		M.close_buffers()
	end

	utils.safe_hook_call("before_cd", config.hooks.before_cd, repo)

	vim.cmd[scope](repo.path)

	if open_on_enter == "empty" then
		vim.cmd("enew")
	elseif open_on_enter == "tree" then
		M.open_tree(repo.path)
	elseif open_on_enter == "recent_file" then
		require("pigit.pickers.recent_files").open(repo)
	end

	utils.safe_hook_call("after_cd", config.hooks.after_cd, repo)
end

---@param repo_path string
---@param tree_type string|nil "netrw"|"nvim-tree"|"neo-tree"|"mini.files"
function M.open_tree(repo_path, tree_type)
	tree_type = tree_type or require("pigit.utils").detect_file_tree()
	require("pigit.utils").log("debug", "open tree: %s (%s)", tree_type, repo_path)
	if tree_type == "netrw" then
		vim.cmd("edit " .. vim.fn.fnameescape(repo_path))
	elseif tree_type == "nvim-tree" then
		vim.cmd("NvimTreeOpen " .. vim.fn.fnameescape(repo_path))
	elseif tree_type == "neo-tree" then
		vim.cmd("Neotree reveal " .. vim.fn.fnameescape(repo_path))
	elseif tree_type == "mini.files" then
		require("mini.files").open(repo_path)
	end
end

---@param file_path string
---@param split "vertical"|"horizontal"|"tab"
function M.open_split(file_path, split)
	local cmd = ({
		vertical = "vsplit",
		horizontal = "split",
		tab = "tabedit",
	})[split] or "edit"
	vim.cmd(cmd .. " " .. vim.fn.fnameescape(file_path))
end

---@param file_path string
function M.open_file(file_path)
	vim.cmd("edit " .. vim.fn.fnameescape(file_path))
end

---Run a whitelisted pigit command asynchronously
---@param repo {name: string, path: string}
---@param cmd string one of "fetch", "pull", "push", "status"
function M.run_pigit_cmd(repo, cmd)
	local config = require("pigit.config").get()
	local utils = require("pigit.utils")

	if not vim.tbl_contains(config.pigit_cmd_whitelist, cmd) then
		utils.log("warn", "command not in whitelist: %s", cmd)
		vim.notify(string.format(config.messages.command_not_allowed, cmd), vim.log.levels.ERROR)
		return
	end

	vim.notify(string.format(config.messages.running_cmd, cmd, repo.name), vim.log.levels.INFO)
	utils.log("debug", "running pigit cmd: %s on %s", cmd, repo.name)

	local function handle_result(code, out, err)
		if code ~= 0 then
			utils.log("error", "pigit cmd failed: %s on %s: %s", cmd, repo.name, err or "")
			vim.notify(string.format(config.messages.cmd_failed, cmd, repo.name, err or ""), vim.log.levels.ERROR)
		else
			utils.log("info", "pigit cmd completed: %s on %s", cmd, repo.name)
			vim.notify(string.format(config.messages.cmd_completed, cmd, repo.name), vim.log.levels.INFO)
			require("pigit.cache").invalidate(repo.name)
		end
	end

	require("pigit.git").run_cmd({ "pigit", "repo", cmd, repo.name }, repo.path, handle_result)
end

---Close all normal (non-special) file buffers that have no unsaved changes.
-- Collects targets first to avoid mutating the list while iterating (ipairs
-- skips elements when the underlying buffer list changes). Switches away
-- from the current buffer before deleting it so that window layout stays
-- stable and BufEnter autocmds fire on a surviving buffer rather than on
-- a scratch buffer. name ~= "" excludes scratch buffers created by plugins.
function M.close_buffers()
	local to_close = {}
	for _, buf in ipairs(vim.fn.getbufinfo({ bufloaded = 1 })) do
		local buftype = vim.fn.getbufvar(buf.bufnr, "&buftype")
		local name = vim.api.nvim_buf_get_name(buf.bufnr)
		if buftype == "" and buf.changed == 0 and name ~= "" then
			to_close[buf.bufnr] = true
		end
	end

	-- Switch to a buffer that will survive so the window does not collapse
	-- or land on a scratch buffer, which can trigger heavy autocmd chains.
	local current = vim.api.nvim_get_current_buf()
	if to_close[current] then
		for _, buf in ipairs(vim.fn.getbufinfo({ bufloaded = 1 })) do
			if not to_close[buf.bufnr] then
				vim.api.nvim_set_current_buf(buf.bufnr)
				break
			end
		end
	end

	for bufnr, _ in pairs(to_close) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
		end
	end
end

return M
