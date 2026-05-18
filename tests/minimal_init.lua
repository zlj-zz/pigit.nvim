vim.opt.rtp:prepend(vim.fn.getcwd())
vim.opt.rtp:prepend(vim.fn.stdpath("data") .. "/lazy/plenary.nvim")
vim.opt.rtp:prepend(vim.fn.stdpath("data") .. "/lazy/telescope.nvim")

require("plenary.busted")
