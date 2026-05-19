local M = {}

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local branches_picker = require("pigit.pickers.branches")
local status_picker = require("pigit.pickers.status")

M._filter_modes = { "all", "dirty", "clean", "unpushed" }
M._current_filter_idx = 1

---Filter predicate functions
---@type table<string, fun(meta: GitMetadata|nil): boolean|nil>
M.filters = {
  all = function() return true end,
  dirty = function(meta)
    return meta and (meta.unstaged or meta.staged or meta.untracked)
  end,
  clean = function(meta)
    return meta and not (meta.unstaged or meta.staged or meta.untracked)
  end,
  unpushed = function(meta)
    return meta and meta.ahead > 0
  end,
}

---@return string
function M.get_current_filter()
  return M._filter_modes[M._current_filter_idx] or "all"
end

---@return string
function M.cycle_filter()
  M._current_filter_idx = M._current_filter_idx + 1
  if M._current_filter_idx > #M._filter_modes then
    M._current_filter_idx = 1
  end
  return M.get_current_filter()
end

---@param repo_name string
---@param repo_info {path: string}
---@param meta GitMetadata|nil
---@param config table
---@return table
function M.format_entry(repo_name, repo_info, meta, config)
  local icons = config.icons
  local display_parts = { repo_name }

  if meta then
    table.insert(display_parts, icons.branch .. meta.branch)
    local indicators = {}
    if meta.ahead > 0 then
      table.insert(indicators, icons.ahead .. meta.ahead)
    end
    if meta.behind > 0 then
      table.insert(indicators, icons.behind .. meta.behind)
    end
    if meta.unstaged then
      table.insert(indicators, icons.unstaged)
    end
    if meta.staged then
      table.insert(indicators, icons.staged)
    end
    if meta.untracked then
      table.insert(indicators, icons.untracked)
    end
    if #indicators == 0 then
      table.insert(indicators, icons.clean)
    end
    table.insert(display_parts, table.concat(indicators, ""))
  else
    table.insert(display_parts, "")
    table.insert(display_parts, "")
  end

  local short_path = vim.fn.fnamemodify(repo_info.path, ":~")
  table.insert(display_parts, short_path)

  return {
    value = { name = repo_name, path = repo_info.path },
    ordinal = repo_name .. " " .. (meta and meta.branch or "") .. " " .. repo_info.path,
    display = table.concat(display_parts, "  "),
    filename = repo_info.path,
    text = repo_name,
  }
end

---@param opts table|nil
function M.open(opts)
  opts = opts or {}
  require("pigit.utils").log("debug", "opening repo picker")
  local config = require("pigit.config").get()
  local repos = require("pigit.repos")
  local cache = require("pigit.cache")
  local actions_module = require("pigit.actions")
  local utils = require("pigit.utils")

  local ok, _ = pcall(require, "telescope")
  if not ok then
    vim.notify(config.messages.telescope_not_found, vim.log.levels.ERROR)
    return
  end

  utils.safe_hook_call("before_open", config.hooks.before_open, "repos")

  local path, err = repos.resolve_path(config.repos_json_path)
  if err then
    vim.notify("pigit: " .. err, vim.log.levels.ERROR)
    return
  end

  local all_repos, load_err = repos.load_cached(path)
  if load_err then
    vim.notify("pigit: " .. load_err, vim.log.levels.ERROR)
    return
  end

  if cache.is_picker_timeout(300) then
    cache.invalidate()
  end
  cache.record_picker_opened()

  local default_filter = config.default_filter or "all"
  for i, mode in ipairs(M._filter_modes) do
    if mode == default_filter then
      M._current_filter_idx = i
      break
    end
  end

  local repo_list = {}
  for name, info in pairs(all_repos) do
    table.insert(repo_list, { name = name, path = info.path })
  end
  table.sort(repo_list, function(a, b)
    return a.name < b.name
  end)

  local batch_count = 0
  for _, repo in ipairs(repo_list) do
    if batch_count >= config.cache.initial_batch then
      break
    end
    cache.get(repo.name, repo.path, config.cache.ttl, function() end)
    batch_count = batch_count + 1
  end

  local remaining = {}
  for i = config.cache.initial_batch + 1, #repo_list do
    table.insert(remaining, repo_list[i])
  end
  if #remaining > 0 then
    cache.start_warmup(remaining, config)
  end

  local current_picker = nil

  local function make_finder()
    local filter_fn = M.filters[M.get_current_filter()]
    return finders.new_table({
      results = repo_list,
      entry_maker = function(repo)
        local cached = cache._store[repo.name]
        local meta = cached and cached.data or nil

        -- Unloaded entries are kept to avoid list flicker while metadata warms up.
        if meta and not filter_fn(meta) then
          return nil
        end

        return M.format_entry(repo.name, repo, meta, config)
      end,
    })
  end

  local function refresh_picker()
    if current_picker then
      local new_finder = make_finder()
      current_picker:refresh(new_finder, { reset = true })
    end
  end

  pickers.new(opts, {
    prompt_title = "Managed Repos [" .. utils.get_filter_label(M.get_current_filter()) .. "]",
    finder = make_finder(),
    sorter = conf.generic_sorter(opts),
    previewer = config.picker.previewer and M.make_previewer() or nil,
    attach_mappings = function(prompt_bufnr, _)
      local function with_selection(fn)
        return function()
          local selection = action_state.get_selected_entry()
          if not selection then return end
          actions.close(prompt_bufnr)
          fn(selection.value)
        end
      end

      actions.select_default:replace(with_selection(function(value)
        actions_module.cd(value, config.cd_scope, config.open_on_enter)
      end))

      vim.keymap.set("i", "<C-d>", function()
        require("pigit.utils").log("debug", "filter cycled to: %s", M.get_current_filter())
        local new_mode = M.cycle_filter()
        if current_picker then
          current_picker.prompt_border.prompt_title = "Managed Repos [" .. utils.get_filter_label(new_mode) .. "]"
          refresh_picker()
        end
      end, { buffer = prompt_bufnr, nowait = true })

      vim.keymap.set("i", "<C-g>", function()
        local selection = action_state.get_selected_entry()
        if not selection then
          return
        end
        require("pigit.utils").log("debug", "command picker opened for: %s", selection.value.name)
        require("pigit.pickers.common").command_picker(selection.value, function(cmd)
          actions_module.run_pigit_cmd(selection.value, cmd)
        end)
      end, { buffer = prompt_bufnr, nowait = true })

      vim.keymap.set("i", "<C-r>", with_selection(function(value)
        require("pigit.utils").log("debug", "recent files picker opened for: %s", value.name)
        require("pigit.pickers.recent_files").open(value)
      end), { buffer = prompt_bufnr, nowait = true })

      vim.keymap.set("i", "<C-t>", with_selection(function(value)
        require("pigit.utils").log("debug", "open tree for: %s", value.name)
        actions_module.open_tree(value.path)
      end), { buffer = prompt_bufnr, nowait = true })

      vim.keymap.set("i", "<C-v>", with_selection(function(value)
        actions_module.open_split(value.path, "vertical")
      end), { buffer = prompt_bufnr, nowait = true })

      vim.keymap.set("i", "<C-x>", with_selection(function(value)
        actions_module.open_split(value.path, "horizontal")
      end), { buffer = prompt_bufnr, nowait = true })

      vim.keymap.set("i", "<C-b>", with_selection(function(value)
        require("pigit.utils").log("debug", "branch picker opened for: %s", value.name)
        branches_picker.open({ repo = value })
      end), { buffer = prompt_bufnr, nowait = true })

      vim.keymap.set("i", "<C-s>", with_selection(function(value)
        require("pigit.utils").log("debug", "status picker opened for: %s", value.name)
        status_picker.open({ repo = value })
      end), { buffer = prompt_bufnr, nowait = true })

      return true
    end,
    on_complete = {
      function(picker)
        current_picker = picker
        for _, repo in ipairs(repo_list) do
          local entry = cache._store[repo.name]
          if entry and entry.fetching then
            entry.on_refresh = refresh_picker
          end
        end
      end,
      function()
        cache.cancel_warmup()
        for _, repo in ipairs(repo_list) do
          local entry = cache._store[repo.name]
          if entry then
            entry.on_refresh = nil
          end
        end
      end,
    },
  }):find()
end

local _preview_ns = vim.api.nvim_create_namespace("pigit_preview")

local function hl(bufnr, line, col_start, col_end, group)
  vim.api.nvim_buf_add_highlight(bufnr, _preview_ns, group, line, col_start, col_end)
end

local function apply_highlights(bufnr, lines, meta)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  hl(bufnr, 0, 0, 5, "PigitLabel")
  hl(bufnr, 0, 11, -1, "PigitRepoName")

  hl(bufnr, 1, 0, 5, "PigitLabel")
  hl(bufnr, 1, 11, -1, "PigitPath")

  if not meta then
    return
  end

  hl(bufnr, 2, 0, 7, "PigitLabel")
  hl(bufnr, 2, 11, -1, "PigitBranch")

  hl(bufnr, 3, 0, 7, "PigitLabel")
  local status_pos = 11
  if meta.staged then
    hl(bufnr, 3, status_pos, status_pos + 1, "PigitStaged")
    status_pos = status_pos + 1
  end
  if meta.unstaged then
    hl(bufnr, 3, status_pos, status_pos + 1, "PigitUnstaged")
    status_pos = status_pos + 1
  end
  if meta.untracked then
    hl(bufnr, 3, status_pos, status_pos + 1, "PigitUntracked")
  end

  hl(bufnr, 4, 0, 6, "PigitLabel")
  local ahead_len = #tostring(meta.ahead)
  local behind_len = #tostring(meta.behind)
  hl(bufnr, 4, 11, 11 + ahead_len, "PigitAhead")
  hl(bufnr, 4, 13 + ahead_len, 20 + ahead_len, "PigitLabel")
  hl(bufnr, 4, 21 + ahead_len, 21 + ahead_len + behind_len, "PigitBehind")

  hl(bufnr, 6, 0, -1, "PigitSection")
  hl(bufnr, 7, 0, -1, "PigitCommit")
  hl(bufnr, 8, 0, -1, "PigitCommit")
  hl(bufnr, 10, 0, -1, "PigitSection")

  for i = 12, #lines do
    hl(bufnr, i - 1, 0, -1, "PigitPath")
  end
end

---@return table previewer
function M.make_previewer()
  local config = require("pigit.config").get()
  local previewers = require("telescope.previewers")
  local preview_id = 0

  return previewers.new_buffer_previewer({
    title = "Repo Info",
    define_preview = function(self, entry, _)
      preview_id = preview_id + 1
      local my_id = preview_id
      local repo = entry.value
      local lines = {
        "Repo:      " .. repo.name,
        "Path:      " .. repo.path,
      }

      local cache = require("pigit.cache")
      local cached = cache._store[repo.name]
      local loading_line = nil
      local meta = nil
      if cached and cached.data then
        meta = cached.data
        table.insert(lines, "Branch:    " .. meta.branch)
        table.insert(lines, "Status:    " .. (meta.staged and "+" or "") .. (meta.unstaged and "*" or "") .. (meta.untracked and "?" or ""))
        table.insert(lines, "Ahead:     " .. meta.ahead .. "  Behind: " .. meta.behind)
        table.insert(lines, "")
        table.insert(lines, "Last Commit:")
        table.insert(lines, "  " .. meta.last_commit_msg)
        table.insert(lines, "  by " .. meta.last_commit_author .. " · " .. meta.last_commit_time)
        table.insert(lines, "")
        table.insert(lines, "Recent Files:")
        table.insert(lines, "  " .. config.messages.recent_files_loading)
        loading_line = #lines - 1
      else
        table.insert(lines, config.messages.loading)
      end

      local bufnr = self.state.bufnr
      vim.api.nvim_buf_clear_namespace(bufnr, _preview_ns, 0, -1)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      apply_highlights(bufnr, lines, meta)

      if loading_line then
        require("pigit.git").run_cmd(
          { "git", "log", "--diff-filter=d", "--name-only", "-n", "5", "--pretty=format:" },
          repo.path,
          function(code, out, _)
            if code ~= 0 then return end
            vim.schedule(function()
              if my_id ~= preview_id then return end
              if not vim.api.nvim_buf_is_valid(bufnr) then return end
              local file_lines = {}
              local count = 0
              for line in out:gmatch("[^\r\n]+") do
                if line ~= "" and count < 5 then
                  table.insert(file_lines, "  " .. line)
                  count = count + 1
                end
              end
              if count == 0 then
                table.insert(file_lines, "  " .. config.messages.no_recent_files)
              end
              vim.api.nvim_buf_clear_namespace(bufnr, _preview_ns, loading_line, loading_line + 1)
              vim.api.nvim_buf_set_lines(bufnr, loading_line, loading_line + 1, false, file_lines)
              for i = 1, #file_lines do
                hl(bufnr, loading_line + i - 1, 0, -1, "PigitPath")
              end
            end)
          end
        )
      end
    end,
  })
end

return M
