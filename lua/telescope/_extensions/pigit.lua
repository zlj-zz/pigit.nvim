local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
  error("telescope.nvim is required for pigit extension")
end

local pigit = require("pigit")

return telescope.register_extension({
  setup = function(ext_config, _)
    -- ext_config 允许用户传入选项
    -- _ 是 telescope 的全局配置（保留参数位置，不使用）
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
