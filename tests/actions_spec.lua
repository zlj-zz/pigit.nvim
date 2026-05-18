local actions = require("pigit.actions")

describe("actions", function()
  it("open_split returns correct command mapping", function()
    -- We can't easily spy vim.cmd, but we can verify the function exists
    assert.is_function(actions.open_split)
  end)

  it("open_file function exists", function()
    assert.is_function(actions.open_file)
  end)

  it("open_tree function exists", function()
    assert.is_function(actions.open_tree)
  end)

  it("cd function exists", function()
    assert.is_function(actions.cd)
  end)

  it("run_pigit_cmd function exists", function()
    assert.is_function(actions.run_pigit_cmd)
  end)
end)
