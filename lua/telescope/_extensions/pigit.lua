local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
	error("telescope.nvim is required for pigit extension")
end

local pigit = require("pigit")

return telescope.register_extension({
	---@param ext_config table|nil
	---@param _ table telescope global config (unused)
	setup = function(ext_config, _)
		if ext_config then
			pigit.setup(vim.tbl_deep_extend("force", {}, ext_config))
		end
	end,
	exports = {
		repos = function(opts)
			opts = opts or {}
			pigit.pickers.repos.open(opts)
		end,
		recent_files = function(opts)
			opts = opts or {}
			local repo_name = opts.repo_name
			if not repo_name then
				vim.notify("repo_name required for :Telescope pigit recent_files", vim.log.levels.ERROR)
				return
			end
			local repo = pigit.get_repo(repo_name)
			if repo then
				pigit.pickers.recent_files.open(repo, opts)
			else
				local config = require("pigit.config").get()
				vim.notify(string.format(config.messages.repo_not_found, repo_name), vim.log.levels.ERROR)
			end
		end,
	},
})
