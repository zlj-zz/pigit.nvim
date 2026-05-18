local M = {}

-- Cache storage
-- { [repo_name] = { data = GitMetadata, fetched_at = number, fetching = boolean, pending_callbacks = function[] } }
M._store = {}
M._last_picker_opened_at = 0

function M.get(repo_name, repo_path, ttl, callback)
  local entry = M._store[repo_name]
  local now = vim.loop.now() / 1000 -- convert to seconds

  -- Hit and not expired
  if entry and entry.data and (now - entry.fetched_at) < ttl then
    callback(nil, entry.data)
    return
  end

  -- Currently fetching, add to pending queue
  if entry and entry.fetching then
    table.insert(entry.pending_callbacks, callback)
    return
  end

  -- Need to re-fetch
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
    -- Execute in vim.schedule to ensure atomic state updates
    vim.schedule(function()
      if not err and meta then
        entry.data = meta
        entry.fetched_at = vim.loop.now() / 1000
      end
      entry.fetching = false

      -- Notify all waiters
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

return M
