local git = require("pigit.git")

describe("git", function()
	it("fetch_metadata calls callback with meta", function()
		-- This test requires a real git repo; skip if not available
		local tmpdir = vim.fn.systemlist("mktemp -d")[1]
		if not tmpdir or tmpdir == "" then
			return
		end
		vim.fn.mkdir(tmpdir, "p")

		git.run_cmd({ "git", "init" }, tmpdir, function(code)
			if code ~= 0 then
				return
			end
			git.fetch_metadata(tmpdir, function(err, meta)
				assert.is_nil(err)
				assert.is_not_nil(meta)
				assert.is_string(meta.branch)
				assert.is_boolean(meta.staged)
				assert.is_boolean(meta.unstaged)
				assert.is_boolean(meta.untracked)
				assert.is_number(meta.ahead)
				assert.is_number(meta.behind)
			end)
		end)

		vim.fn.delete(tmpdir, "rf")
	end)
end)
