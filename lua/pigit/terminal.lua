local M = {}

---Open a floating terminal window
---@param opts table|nil
---  - cwd: string|nil working directory
---  - cmd: string|nil command to run (default: shell)
function M.open(opts)
  opts = opts or {}
  local config = require("pigit.config").get()
  local term_config = config.terminal

  local width = math.floor(vim.o.columns * term_config.width_ratio)
  local height = math.floor(vim.o.lines * term_config.height_ratio)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  if not buf or buf == 0 then
    require("pigit.utils").log("error", "failed to create terminal buffer")
    return
  end

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = term_config.border,
  })

  if not win or win == 0 then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
    require("pigit.utils").log("error", "failed to open terminal window")
    return
  end

  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })

  local cmd = opts.cmd or vim.o.shell
  local cwd = opts.cwd or vim.fn.getcwd()

  require("pigit.utils").log("debug", "terminal open: cmd=%s cwd=%s", cmd, cwd)

  local done = false
  local function cleanup()
    if done then
      return
    end
    done = true
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
    if vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end

  local ok = pcall(vim.fn.termopen, cmd, {
    cwd = cwd,
    on_exit = function(_, code, _)
      require("pigit.utils").log("debug", "terminal exited: code=%d", code)
      if term_config.auto_close then
        vim.schedule(cleanup)
      end
    end,
  })

  if not ok then
    cleanup()
    return
  end

  vim.api.nvim_win_call(win, function()
    vim.cmd("startinsert")
  end)

  vim.keymap.set("t", "<Esc><Esc>", function()
    cleanup()
  end, { buffer = buf, nowait = true, silent = true })
end

return M
