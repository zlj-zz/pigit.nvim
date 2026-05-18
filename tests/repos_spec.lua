local repos = require("pigit.repos")

describe("repos", function()
  it("resolve_path returns explicit path when given", function()
    local path = repos.resolve_path("/custom/repos.json")
    assert.equals("/custom/repos.json", path)
  end)

  it("load returns error for non-existent file", function()
    local data, err = repos.load("/nonexistent/repos.json")
    assert.is_true(#err > 0)
  end)

  it("load parses valid JSON", function()
    local tmp = os.tmpname() .. ".json"
    local f = io.open(tmp, "w")
    f:write('{"repo1": {"path": "/tmp/repo1"}, "repo2": {"path": "/tmp/repo2"}}')
    f:close()

    local data, err = repos.load(tmp)
    assert.is_nil(err)
    assert.equals("/tmp/repo1", data.repo1.path)
    assert.equals("/tmp/repo2", data.repo2.path)

    os.remove(tmp)
  end)

  it("load rejects invalid JSON", function()
    local tmp = os.tmpname() .. ".json"
    local f = io.open(tmp, "w")
    f:write("not json")
    f:close()

    local data, err = repos.load(tmp)
    assert.is_true(#err > 0)

    os.remove(tmp)
  end)

  it("load rejects non-object root", function()
    local tmp = os.tmpname() .. ".json"
    local f = io.open(tmp, "w")
    f:write('["a", "b"]')
    f:close()

    local data, err = repos.load(tmp)
    assert.is_true(#err > 0)

    os.remove(tmp)
  end)

  it("load rejects entry without path", function()
    local tmp = os.tmpname() .. ".json"
    local f = io.open(tmp, "w")
    f:write('{"repo1": {"name": "foo"}}')
    f:close()

    local data, err = repos.load(tmp)
    assert.is_true(#err > 0)

    os.remove(tmp)
  end)

  it("load_cached caches result", function()
    local tmp = os.tmpname() .. ".json"
    local f = io.open(tmp, "w")
    f:write('{"repo1": {"path": "/tmp/repo1"}}')
    f:close()

    local data1, err1 = repos.load_cached(tmp)
    local data2, err2 = repos.load_cached(tmp)
    assert.is_nil(err1)
    assert.is_nil(err2)
    assert.equals("/tmp/repo1", data1.repo1.path)
    assert.equals("/tmp/repo1", data2.repo1.path)

    repos.invalidate_cache()
    os.remove(tmp)
  end)

  it("invalidate_cache clears cache", function()
    local tmp = os.tmpname() .. ".json"
    local f = io.open(tmp, "w")
    f:write('{"repo1": {"path": "/tmp/repo1"}}')
    f:close()

    repos.load_cached(tmp)
    repos.invalidate_cache()

    local data, err = repos.load_cached(tmp)
    assert.is_nil(err)
    assert.equals("/tmp/repo1", data.repo1.path)

    os.remove(tmp)
  end)
end)
