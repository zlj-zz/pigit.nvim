local M = {}

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

function M.format_entry(repo_name, repo_info, meta, config)
  local icons = config.icons
  local display_parts = { repo_name }

  if meta then
    table.insert(display_parts, icons.branch .. meta.branch)
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

  local ok, _ = pcall(require, "telescope")
  if not ok then
    vim.notify("pigit: telescope.nvim not found. Install: nvim-telescope/telescope.nvim", vim.log.levels.ERROR)
    return
  end

  config.hooks.before_open("repos")

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

  local repo_list = {}
  for name, info in pairs(all_repos) do
    table.insert(repo_list, { name = name, path = info.path })
  end
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

  -- Background warmup for remaining repos
  local remaining = {}
  for i = config.cache.initial_batch + 1, #repo_list do
    table.insert(remaining, repo_list[i])
  end
  if #remaining > 0 then
    cache.start_warmup(remaining, config)
  end

  pickers.new(opts, {
    prompt_title = "Managed Repos",
    finder = finders.new_table({
      results = repo_list,
      entry_maker = function(repo)
        local cached = cache._store[repo.name]
        local meta = cached and cached.data or nil
        return M.format_entry(repo.name, repo, meta, config)
      end,
    }),
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

      vim.keymap.set("i", "<C-r>", with_selection(function(value)
        require("pigit.pickers.recent_files").open(value)
      end), { buffer = prompt_bufnr, nowait = true })

      vim.keymap.set("i", "<C-t>", with_selection(function(value)
        actions_module.open_tree(value.path)
      end), { buffer = prompt_bufnr, nowait = true })

      vim.keymap.set("i", "<C-v>", with_selection(function(value)
        actions_module.open_split(value.path, "vertical")
      end), { buffer = prompt_bufnr, nowait = true })

      vim.keymap.set("i", "<C-x>", with_selection(function(value)
        actions_module.open_split(value.path, "horizontal")
      end), { buffer = prompt_bufnr, nowait = true })

      return true
    end,
    on_complete = {
      function()
        cache.cancel_warmup()
      end,
    },
  }):find()
end

function M.make_previewer()
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
      if cached and cached.data then
        local meta = cached.data
        table.insert(lines, "Branch:    " .. meta.branch)
        table.insert(lines, "Status:    " .. (meta.staged and "+" or "") .. (meta.unstaged and "*" or "") .. (meta.untracked and "?" or ""))
        table.insert(lines, "")
        table.insert(lines, "Last Commit:")
        table.insert(lines, "  " .. meta.last_commit_msg)
        table.insert(lines, "  by " .. meta.last_commit_author .. " · " .. meta.last_commit_time)
        table.insert(lines, "")
        table.insert(lines, "Recent Files:")
        table.insert(lines, "  (loading...)")
        loading_line = #lines - 1
      else
        table.insert(lines, "Loading...")
      end

      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)

      if loading_line then
        require("pigit.git").run_cmd(
          { "git", "log", "--diff-filter=d", "--name-only", "-n", "5", "--pretty=format:" },
          repo.path,
          function(code, out, _)
            if code ~= 0 then return end
            vim.schedule(function()
              if my_id ~= preview_id then return end
              local bufnr = self.state.bufnr
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
                table.insert(file_lines, "  (no recent files)")
              end
              vim.api.nvim_buf_set_lines(bufnr, loading_line, loading_line + 1, false, file_lines)
            end)
          end
        )
      end
    end,
  })
end

return M
