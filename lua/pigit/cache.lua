local M = {}

M._store = {}
M._last_picker_opened_at = 0
M._warmup_timer = nil

function M.get(repo_name, repo_path, ttl, callback)
  local entry = M._store[repo_name]
  local now = vim.loop.now() / 1000

  if entry and entry.data and (now - entry.fetched_at) < ttl then
    callback(nil, entry.data)
    return
  end

  if entry and entry.fetching then
    table.insert(entry.pending_callbacks, callback)
    return
  end

  if not entry then
    entry = {
      data = nil,
      fetched_at = 0,
      fetching = false,
      pending_callbacks = {},
    }
    M._store[repo_name] = entry
  end

  entry.fetching = true
  entry.pending_callbacks = { callback }

  require("pigit.git").fetch_metadata(repo_path, function(err, meta)
    vim.schedule(function()
      if not err and meta then
        entry.data = meta
        entry.fetched_at = vim.loop.now() / 1000
      end
      entry.fetching = false
      for _, cb in ipairs(entry.pending_callbacks) do
        cb(err, meta)
      end
      entry.pending_callbacks = {}
    end)
  end)
end

function M.invalidate(repo_name)
  if repo_name then
    local entry = M._store[repo_name]
    if entry then
      entry.data = nil
      entry.fetched_at = 0
    end
  else
    M._store = {}
  end
end

function M.record_picker_opened()
  M._last_picker_opened_at = vim.loop.now() / 1000
end

function M.is_picker_timeout(timeout_sec)
  if M._last_picker_opened_at == 0 then
    return true
  end
  local now = vim.loop.now() / 1000
  return (now - M._last_picker_opened_at) > timeout_sec
end

---Start background batch warmup after picker opens
---@param repos table[] array of {name: string, path: string}
---@param config table
function M.start_warmup(repos, config)
  M.cancel_warmup()

  local total = #repos
  if total == 0 then
    return
  end

  local batch_size = config.cache.batch_size
  local interval = config.cache.batch_interval_ms
  local index = 1

  local function process_batch()
    if index > total then
      return
    end
    if M._warmup_timer == nil then
      return -- cancelled
    end

    local end_idx = math.min(index + batch_size - 1, total)
    for i = index, end_idx do
      local repo = repos[i]
      M.get(repo.name, repo.path, config.cache.ttl, function() end)
    end

    index = end_idx + 1
    if index <= total then
      M._warmup_timer = vim.defer_fn(process_batch, interval)
    else
      M._warmup_timer = nil
    end
  end

  M._warmup_timer = vim.defer_fn(process_batch, interval)
end

---Cancel warmup if picker is closed
function M.cancel_warmup()
  if M._warmup_timer then
    pcall(vim.fn.timer_stop, M._warmup_timer)
    M._warmup_timer = nil
  end
end

return M
