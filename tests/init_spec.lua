local pigit = require("pigit")

describe("init", function()
	it("setup function exists", function()
		assert.is_function(pigit.setup)
	end)

	it("exposes pickers for extension usage", function()
		assert.is_not_nil(pigit.pickers.repos)
		assert.is_not_nil(pigit.pickers.recent_files)
		assert.is_function(pigit.pickers.repos.open)
		assert.is_function(pigit.pickers.recent_files.open)
	end)

	it("get_repo function exists", function()
		assert.is_function(pigit.get_repo)
	end)
end)
