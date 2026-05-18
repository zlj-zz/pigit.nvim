local pigit = require("pigit")

describe("init", function()
  it("setup function exists", function()
    assert.is_function(pigit.setup)
  end)
end)
