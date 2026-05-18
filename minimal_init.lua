-- Minimal Neovim config for testing pigit.nvim
-- Usage: nvim -u minimal_init.lua

vim.opt.rtp:prepend(vim.fn.stdpath("config"))

-- Add pigit.nvim to runtime path (local development)
vim.opt.rtp:prepend(vim.fn.getcwd())

-- Ensure telescope is available (lazy.nvim style bootstrap for minimal testing)
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  { "nvim-lua/plenary.nvim", lazy = true },
  { "nvim-telescope/telescope.nvim", dependencies = { "nvim-lua/plenary.nvim" } },
  {
    "pigit.nvim",
    dir = vim.fn.getcwd(),
    config = function()
      require("pigit").setup({
        -- Test configuration
        cd_scope = "tcd",
        open_on_enter = "none",
      })
    end,
  },
}, {
  root = vim.fn.stdpath("data") .. "/lazy",
})

-- Optional: create a sample repos.json for testing
vim.api.nvim_create_user_command("PigitSetupTest", function()
  local test_repos = vim.fn.stdpath("config") .. "/pigit"
  vim.fn.mkdir(test_repos, "p")
  local f = io.open(test_repos .. "/repos.json", "w")
  if f then
    f:write('{}')
    f:close()
    vim.notify("Created empty test repos.json at " .. test_repos .. "/repos.json")
  end
end, {})
