local cache = require("pigit.cache")

describe("cache", function()
  before_each(function()
    cache.invalidate()
    cache._last_picker_opened_at = 0
  end)

  it("invalidate clears all when no arg", function()
    cache._store["test"] = { data = { branch = "main" } }
    cache.invalidate()
    assert.is_nil(cache._store["test"])
  end)

  it("invalidate clears specific repo data", function()
    cache._store["a"] = { data = { branch = "main" }, fetched_at = 100 }
    cache._store["b"] = { data = { branch = "dev" }, fetched_at = 100 }
    cache.invalidate("a")
    assert.is_nil(cache._store["a"].data)
    assert.equals(0, cache._store["a"].fetched_at)
    assert.is_not_nil(cache._store["b"].data)
  end)

  it("record_picker_opened sets timestamp", function()
    cache.record_picker_opened()
    assert.is_true(cache._last_picker_opened_at > 0)
  end)

  it("is_picker_timeout returns true initially", function()
    assert.is_true(cache.is_picker_timeout(300))
  end)

  it("cancel_warmup stops timer", function()
    cache._warmup_timer = vim.defer_fn(function() end, 10000)
    cache.cancel_warmup()
    assert.is_nil(cache._warmup_timer)
  end)
end)
