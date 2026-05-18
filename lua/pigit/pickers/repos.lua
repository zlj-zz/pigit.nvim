local M = {}

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

-- Entry formatting
function M.format_entry(repo_name, repo_info, meta, config)
  local icons = config.icons
  local display_parts = { repo_name }

  if meta then
    -- branch
    table.insert(display_parts, icons.branch .. meta.branch)

    -- status indicators
    local indicators = {}
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

  -- path (shortened)
  local short_path = vim.fn.fnamemodify(repo_info.path, ":~")
  table.insert(display_parts, short_path)

  return {
    value = { name = repo_name, path = repo_info.path },
    ordinal = repo_name .. " " .. (meta and meta.branch or "") .. " " .. repo_info.path,
    display = table.concat(display_parts, "  "),
  }
end

function M.open(opts)
  opts = opts or {}
  local config = require("pigit.config").get()
  local repos = require("pigit.repos")
  local cache = require("pigit.cache")
  local actions_module = require("pigit.actions")

  -- Check telescope is available
  local ok, _ = pcall(require, "telescope")
  if not ok then
    vim.notify("pigit: telescope.nvim not found. Install: nvim-telescope/telescope.nvim", vim.log.levels.ERROR)
    return
  end

  -- Resolve path
  local path, err = repos.resolve_path(config.repos_json_path)
  if err then
    vim.notify("pigit: " .. err, vim.log.levels.ERROR)
    return
  end

  -- Load repos
  local all_repos, load_err = repos.load(path)
  if load_err then
    vim.notify("pigit: " .. load_err, vim.log.levels.ERROR)
    return
  end

  -- Check picker timeout, invalidate cache if expired
  if cache.is_picker_timeout(300) then
    cache.invalidate()
  end
  cache.record_picker_opened()

  -- Build repo list
  local repo_list = {}
  for name, info in pairs(all_repos) do
    table.insert(repo_list, { name = name, path = info.path })
  end

  -- Sort by repo_name alphabetically
  table.sort(repo_list, function(a, b)
    return a.name < b.name
  end)

  -- Preload first initial_batch repos
  local batch_count = 0
  for _, repo in ipairs(repo_list) do
    if batch_count >= config.cache.initial_batch then
      break
    end
    cache.get(repo.name, repo.path, config.cache.ttl, function() end)
    batch_count = batch_count + 1
  end

  -- Telescope picker
  pickers.new(opts, {
    prompt_title = "Managed Repos",
    finder = finders.new_table({
      results = repo_list,
      entry_maker = function(repo)
        local entry = M.format_entry(repo.name, repo, nil, config)
        -- Try to get from cache (may be warmed up)
        local cached = cache._store[repo.name]
        if cached and cached.data then
          entry = M.format_entry(repo.name, repo, cached.data, config)
        end
        return entry
      end,
    }),
    sorter = conf.generic_sorter(opts),
    previewer = config.picker.previewer and M.make_previewer() or nil,
    attach_mappings = function(prompt_bufnr, _)
      -- Default <CR>: cd
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        if not selection then
          return
        end
        actions.close(prompt_bufnr)
        actions_module.cd(selection.value, config.cd_scope, config.open_on_enter)
      end)

      return true
    end,
  }):find()
end

-- Simple previewer (v0.1.0 basic version)
function M.make_previewer()
  local previewers = require("telescope.previewers")

  return previewers.new_buffer_previewer({
    title = "Repo Info",
    define_preview = function(self, entry, _)
      local repo = entry.value
      local lines = {
        "Repo:      " .. repo.name,
        "Path:      " .. repo.path,
      }

      -- Try to get metadata from cache
      local cache = require("pigit.cache")
      local cached = cache._store[repo.name]
      if cached and cached.data then
        local meta = cached.data
        table.insert(lines, "Branch:    " .. meta.branch)
        table.insert(lines, "Status:    " .. (meta.staged and "+" or "") .. (meta.unstaged and "*" or "") .. (meta.untracked and "?" or ""))
        table.insert(lines, "")
        table.insert(lines, "Last Commit:")
        table.insert(lines, "  " .. meta.last_commit_msg)
        table.insert(lines, "  by " .. meta.last_commit_author .. " · " .. meta.last_commit_time)
      else
        table.insert(lines, "Loading...")
      end

      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
    end,
  })
end

return M
