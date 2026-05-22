local repos_picker = require("pigit.pickers.repos")

describe("pickers/repos", function()
	it("filters.all returns true for nil meta", function()
		assert.is_true(repos_picker.filters.all(nil))
	end)

	it("filters.all returns true for any meta", function()
		assert.is_true(repos_picker.filters.all({ unstaged = true }))
	end)

	it("filters.dirty matches unstaged", function()
		local meta = { unstaged = true, staged = false, untracked = false }
		assert.is_true(repos_picker.filters.dirty(meta))
	end)

	it("filters.dirty matches staged", function()
		local meta = { unstaged = false, staged = true, untracked = false }
		assert.is_true(repos_picker.filters.dirty(meta))
	end)

	it("filters.dirty matches untracked", function()
		local meta = { unstaged = false, staged = false, untracked = true }
		assert.is_true(repos_picker.filters.dirty(meta))
	end)

	it("filters.dirty does not match clean", function()
		local meta = { unstaged = false, staged = false, untracked = false }
		assert.is_false(repos_picker.filters.dirty(meta))
	end)

	it("filters.clean matches clean", function()
		local meta = { unstaged = false, staged = false, untracked = false }
		assert.is_true(repos_picker.filters.clean(meta))
	end)

	it("filters.clean does not match dirty", function()
		local meta = { unstaged = true, staged = false, untracked = false }
		assert.is_false(repos_picker.filters.clean(meta))
	end)

	it("filters.unpushed matches ahead > 0", function()
		local meta = { ahead = 1, behind = 0 }
		assert.is_true(repos_picker.filters.unpushed(meta))
	end)

	it("filters.unpushed does not match ahead = 0", function()
		local meta = { ahead = 0, behind = 0 }
		assert.is_false(repos_picker.filters.unpushed(meta))
	end)

	it("cycle_filter rotates through modes", function()
		local first = repos_picker.get_current_filter()
		repos_picker.cycle_filter()
		local second = repos_picker.get_current_filter()
		repos_picker.cycle_filter()
		local third = repos_picker.get_current_filter()
		repos_picker.cycle_filter()
		local fourth = repos_picker.get_current_filter()
		repos_picker.cycle_filter()
		local back_to_first = repos_picker.get_current_filter()

		assert.equals(first, back_to_first)
		assert.is_not.equals(first, second)
		assert.is_not.equals(second, third)
		assert.is_not.equals(third, fourth)
	end)

	it("format_entry returns correct structure", function()
		local config = require("pigit.config").get()
		local entry = repos_picker.format_entry("myrepo", { path = "/tmp/myrepo" }, nil, config)
		assert.equals("myrepo", entry.value.name)
		assert.equals("/tmp/myrepo", entry.value.path)
	end)
end)
