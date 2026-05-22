local M = {}

---@type string|nil
local _detected_tree = nil

---Detect available file tree plugin (memoized after first call)
---@return string tree_type
function M.detect_file_tree()
	if _detected_tree then
		return _detected_tree
	end
	local config = require("pigit.config").get()
	---@type string
	local tree
	local file_tree = config.file_tree
	if file_tree then
		tree = file_tree
	elseif pcall(require, "nvim-tree") then
		tree = "nvim-tree"
	elseif pcall(require, "neo-tree.command") then
		tree = "neo-tree"
	elseif pcall(require, "mini.files") then
		tree = "mini.files"
	else
		tree = "netrw"
	end
	_detected_tree = tree
	return tree
end

---@param path string
---@return string
function M.basename(path)
	return vim.fn.fnamemodify(path, ":t")
end

---Get icon for file path (via nvim-web-devicons)
---@param file_path string
---@return string icon, string hl_group
function M.get_file_icon(file_path)
	local ok, devicons = pcall(require, "nvim-web-devicons")
	if not ok then
		return "", ""
	end
	local name = M.basename(file_path)
	local ext = vim.fn.fnamemodify(file_path, ":e")
	local icon, hl = devicons.get_icon(name, ext, { default = true })
	return icon or "", hl or ""
end

---Register default highlight groups for pigit
function M.register_highlights()
	local highlights = {
		PigitRepoName = { default = true, link = "TelescopeResultsIdentifier" },
		PigitBranch = { default = true, link = "TelescopeResultsConstant" },
		PigitDirty = { default = true, link = "DiagnosticWarn" },
		PigitClean = { default = true, link = "DiagnosticOk" },
		PigitInvalid = { default = true, link = "DiagnosticError" },
		PigitPath = { default = true, link = "TelescopeResultsComment" },
		PigitLabel = { default = true, link = "TelescopeResultsField" },
		PigitSection = { default = true, link = "TelescopeResultsTitle" },
		PigitCommit = { default = true, link = "TelescopeResultsComment" },
		PigitAhead = { default = true, link = "DiagnosticOk" },
		PigitBehind = { default = true, link = "DiagnosticWarn" },
		PigitStaged = { default = true, link = "DiagnosticOk" },
		PigitUnstaged = { default = true, link = "DiagnosticWarn" },
		PigitUntracked = { default = true, link = "DiagnosticInfo" },
	}
	for name, hl in pairs(highlights) do
		vim.api.nvim_set_hl(0, name, hl)
	end
end

---@param mode string
---@return string
function M.get_filter_label(mode)
	local labels = {
		all = "All",
		dirty = "Dirty",
		clean = "Clean",
		unpushed = "Unpushed",
	}
	return labels[mode] or "All"
end

local _log_levels = { debug = 0, info = 1, warn = 2, error = 3 }
local uv = vim.uv or vim.loop

-- Cached log directory (resolved once per session)
local _log_dir = nil

local function get_log_dir()
	if _log_dir then
		return _log_dir
	end
	local pigit_home = vim.env.PIGIT_HOME
	if pigit_home then
		_log_dir = vim.fs.joinpath(pigit_home, "nvim")
	else
		local xdg = vim.env.XDG_CONFIG_HOME
		if xdg then
			_log_dir = vim.fs.joinpath(xdg, "pigit", "nvim")
		else
			local stdpath = vim.fn.stdpath("config")
			if stdpath then
				_log_dir = vim.fs.joinpath(stdpath, "pigit", "nvim")
			else
				_log_dir = vim.fs.joinpath(vim.fn.expand("~"), ".config", "pigit", "nvim")
			end
		end
	end
	vim.fn.mkdir(_log_dir, "p")
	return _log_dir
end

---Delete log files older than 7 days
local function cleanup_old_logs()
	local dir = get_log_dir()
	local ok, iter = pcall(uv.fs_scandir, dir)
	if not ok or not iter then
		return
	end
	local now = os.time()
	local max_age = 7 * 24 * 60 * 60
	while true do
		local name, t = uv.fs_scandir_next(iter)
		if not name then
			break
		end
		if t == "file" and name:match("^pigit%-nvim%-%d%d%d%d%-%d%d%-%d%d%.log$") then
			local path = vim.fs.joinpath(dir, name)
			local stat = uv.fs_stat(path)
			if stat and stat.mtime and (now - stat.mtime.sec) > max_age then
				pcall(uv.fs_unlink, path)
			end
		end
	end
end

---Append a log line to today's log file
---@param level string
---@param msg string
local function write_log_file(level, msg)
	local dir = get_log_dir()
	local now = os.time()
	local date = os.date("%Y-%m-%d", now)
	local time = os.date("%H:%M:%S", now)
	local path = vim.fs.joinpath(dir, "pigit-nvim-" .. date .. ".log")
	local f = io.open(path, "a")
	if not f then
		return
	end
	f:write(string.format("[%s %s] [%s] %s\n", date, time, level:upper(), msg))
	f:close()
end

-- Run cleanup once at module load to avoid blocking first log caller
pcall(cleanup_old_logs)

---Debug logging with configurable level
---@param level "debug"|"info"|"warn"|"error"
---@param fmt string
function M.log(level, fmt, ...)
	local config = require("pigit.config").get()
	local config_level = _log_levels[config.log_level] or 2
	if _log_levels[level] >= config_level then
		local msg = string.format(fmt, ...)
		vim.notify("[pigit] " .. msg, vim.log.levels[level:upper()])
		pcall(write_log_file, level, msg)
	end
end

---Call a hook function safely, logging errors without propagating them
---@param name string hook name for error messages
---@param fn function hook function to call
---@param ... any arguments to pass to the hook
function M.safe_hook_call(name, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		M.log("error", "%s hook error: %s", name, err)
	end
end

---Check if child path is a subpath of parent (handles trailing slashes)
---@param child string
---@param parent string
---@return boolean
function M.is_subpath(child, parent)
	if #child < #parent then
		return false
	end
	if child:sub(1, #parent) ~= parent then
		return false
	end
	local next_char = child:sub(#parent + 1, #parent + 1)
	return next_char == "" or next_char == "/" or next_char == "\\"
end

---Detect which managed repo the current cwd belongs to
---@return {name: string, path: string}|nil repo, string|nil err
function M.resolve_current_repo()
	local config = require("pigit.config").get()
	local repos = require("pigit.repos")
	local path = repos.resolve_path(config.repos_json_path)
	local all_repos, err = repos.load_cached(path)
	if err then
		return nil, err
	end
	local cwd = vim.fn.getcwd()
	for name, info in pairs(all_repos) do
		if M.is_subpath(cwd, info.path) then
			return { name = name, path = info.path }, nil
		end
	end
	return nil, config.messages.not_in_repo
end

---Resolve target repo from picker opts
---@param opts table
---@return {name: string, path: string}|nil repo, string|nil err
function M.resolve_repo(opts)
	if opts.repo then
		return opts.repo, nil
	end
	if opts.repo_name then
		local repo = require("pigit.repos").get_by_name(opts.repo_name)
		if not repo then
			return nil, string.format(require("pigit.config").get().messages.repo_not_found, opts.repo_name)
		end
		return repo, nil
	end
	return M.resolve_current_repo()
end

---Ensure telescope.nvim is installed
---@return boolean
function M.ensure_telescope()
	local ok, _ = pcall(require, "telescope")
	if not ok then
		vim.notify(require("pigit.config").get().messages.telescope_not_found, vim.log.levels.ERROR)
		return false
	end
	return true
end

return M
