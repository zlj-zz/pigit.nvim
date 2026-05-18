local recent = require("pigit.pickers.recent_files")

describe("recent_files", function()
  it("fetch_mru_files filters by repo path", function()
    local original_oldfiles = vim.v.oldfiles
    vim.v.oldfiles = { "/home/user/proj/a.txt", "/home/user/other/b.txt", "/home/user/proj/c.lua" }

    local files = recent.fetch_mru_files("/home/user/proj", 10)
    assert.equals(2, #files)
    assert.equals("a.txt", files[1].filename)
    assert.equals("c.lua", files[2].filename)

    vim.v.oldfiles = original_oldfiles
  end)

  it("merge_hybrid deduplicates git-first", function()
    local git = { { path = "a.lua", source = "git" }, { path = "b.lua", source = "git" } }
    local mru = { { path = "b.lua", source = "mru" }, { path = "c.lua", source = "mru" } }
    local merged = recent.merge_hybrid(git, mru)
    assert.equals(3, #merged)
    assert.equals("a.lua", merged[1].path)
    assert.equals("b.lua", merged[2].path)
    assert.equals("c.lua", merged[3].path)
  end)

  it("fetch_mru_files respects max limit", function()
    local original_oldfiles = vim.v.oldfiles
    vim.v.oldfiles = { "/home/user/proj/a.txt", "/home/user/proj/b.txt", "/home/user/proj/c.txt" }

    local files = recent.fetch_mru_files("/home/user/proj", 2)
    assert.equals(2, #files)

    vim.v.oldfiles = original_oldfiles
  end)
end)
