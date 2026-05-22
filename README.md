# pigit.nvim

A Neovim plugin that bridges the [`pigit`](https://github.com/zlj-zz/pigit) Python CLI with [`telescope.nvim`](https://github.com/nvim-telescope/telescope.nvim), giving you fuzzy-searchable repo management, one-key directory switching, and recent-file access across all your projects.

## Features

- **Repo picker** — Fuzzy-find across all repos registered in `pigit`'s `repos.json`
- **Smart filters** — Toggle between All / Dirty / Clean / Unpushed repos without restarting the picker
- **Recent files picker** — Open recently changed files per repo via `git log`, MRU (`vim.v.oldfiles`), or a hybrid merge of both
- **Branch picker** — List and checkout branches for the current (or specified) repo
- **Status picker** — Browse changed files in the current repo and open them with `<CR>`, `<C-v>`, or `<C-x>`
- **Floating terminal** — Launch `pigit` TUI directly from the repo picker or via `:PigitTerm`
- **One-key workflows** — `<CR>` to cd, `<C-r>` for recent files, `<C-t>` for file tree, `<C-v>`/`<C-x>` for splits
- **Auto-cd on open** — Automatically switch to the repo root when opening a file from outside Neovim
- **Close buffers on leave** — Clean up file buffers when switching to a different repo
- **Async metadata** — Git status, branch, ahead/behind, and last commit info loads in the background with TTL caching
- **L2 persistent cache** — Leverages `repos.json` metadata to avoid redundant git commands on first open
- **Pigit commands** — Run whitelisted `pigit` commands (`fetch`, `pull`, `push`, `status`) directly from the repo picker
- **Hooks** — Lifecycle callbacks (`before_open`, `before_cd`, `after_cd`, `before_leave`, `after_refresh`) for integration with session managers
- **File watcher** — Auto-invalidates cache when `repos.json` changes on disk
- **Telescope extension** — Register as `:Telescope pigit repos` and `:Telescope pigit recent_files`

## Requirements

- Neovim >= 0.10
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [pigit](https://github.com/zlj-zz/pigit) CLI (`pip3 install pigit`)
- (Optional) [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons) for file icons

## Installation

### lazy.nvim

```lua
{
  "zevr/pigit.nvim",
  dependencies = { "nvim-telescope/telescope.nvim" },
  config = function()
    require("pigit").setup({
      -- your configuration (see below)
    })
  end,
}
```

### Telescope extension

```lua
require("telescope").load_extension("pigit")
```

Then use:
- `:Telescope pigit repos`
- `:Telescope pigit recent_files repo_name=myproject`

## Configuration

Default options with all available fields:

```lua
require("pigit").setup({
  repos_json_path = nil,          -- nil = auto-detect ($PIGIT_HOME, $XDG_CONFIG_HOME, stdpath)
  cd_scope = "tcd",               -- "cd" | "tcd" | "lcd"
  open_on_enter = "none",         -- "none" | "empty" | "tree" | "recent_file"
  close_buffers_on_leave = true,  -- close normal file buffers when switching repos
  auto_cd_on_open = true,         -- auto-cd to repo root when opening a file from outside nvim
  picker = {
    theme = "dropdown",
    layout_config = {},
    previewer = true,
  },
  cache = {
    ttl = 30,                     -- seconds
    max_workers = 4,
    initial_batch = 50,
    batch_size = 50,
    batch_interval_ms = 200,
  },
  recent_files_git_depth = 50,
  recent_files_git_unique = true,
  recent_files_mode = "git",      -- "git" | "hybrid" | "mru"
  file_tree = nil,                -- nil = auto-detect; or "netrw" | "nvim-tree" | "neo-tree" | "mini.files"
  icons = {
    branch = "",
    ahead = "↑",
    behind = "↓",
    unstaged = "*",
    staged = "+",
    untracked = "?",
    clean = "✓",
  },
  devicons = true,
  pigit_cmd_whitelist = { "fetch", "pull", "push", "status" },
  default_filter = "all",         -- "all" | "dirty" | "clean" | "unpushed"
  log_level = "warn",             -- "debug" | "info" | "warn" | "error"
  terminal = {
    width_ratio = 0.9,
    height_ratio = 0.9,
    border = "rounded",
    auto_close = true,
  },
  messages = {
    -- override any default message string
  },
  mappings = {
    repos = {},
    recent_files = {},
  },
  hooks = {
    before_open = function() end,
    before_cd = function(repo) end,
    after_cd = function(repo) end,
    before_leave = function(repo) end,
    after_refresh = function() end,
  },
})
```

### Environment variables

| Variable | Description |
|----------|-------------|
| `PIGIT_HOME` | Base directory for `repos.json` |
| `PIGIT_DEBUG=1` | Forces `log_level = "debug"` |

## Commands

| Command | Args | Description |
|---------|------|-------------|
| `:PigitRepos` | `[query]` | Open the repo picker (optionally pre-filled with search text) |
| `:PigitRecentFiles` | `<repo_name>` | Open recent files picker for a specific repo |
| `:PigitBranches` | `[repo_name]` | Open branch picker for current repo (or specified repo) |
| `:PigitStatus` | `[repo_name]` | Open git status picker for current repo (or specified repo) |
| `:PigitTerm` | `[repo_name]` | Run `pigit` TUI in a floating terminal for current repo (or specified repo) |
| `:PigitRefresh` | — | Invalidate all caches and reload `repos.json` |

## Repo picker keymaps

| Key | Action |
|-----|--------|
| `<CR>` | Change directory to repo (`cd_scope`) |
| `<C-r>` | Open recent files picker for selected repo |
| `<C-t>` | Open file tree for selected repo |
| `<C-v>` | Open repo in vertical split |
| `<C-x>` | Open repo in horizontal split |
| `<C-d>` | Cycle filter (All → Dirty → Clean → Unpushed) |
| `<C-g>` | Run a whitelisted pigit command on selected repo |
| `<C-b>` | Open branch picker for selected repo |
| `<C-s>` | Open git status picker for selected repo |
| `<C-\>` | Run `pigit` TUI in a floating terminal for selected repo |

## Branch picker keymaps

| Key | Action |
|-----|--------|
| `<CR>` | Checkout the selected branch |

## Status picker keymaps

| Key | Action |
|-----|--------|
| `<CR>` | Open file (`cd_scope` to repo first) |
| `<C-v>` | Open file in vertical split |
| `<C-x>` | Open file in horizontal split |

## Hooks

Hooks receive repo tables (`{ name: string, path: string }`) where applicable.

```lua
require("pigit").setup({
  hooks = {
    before_open = function(picker_name)
      -- picker_name: "repos" or "recent_files"
    end,
    before_cd = function(repo)
      -- called before changing directory
    end,
    after_cd = function(repo)
      -- called after changing directory
    end,
    before_leave = function(repo)
      -- called when leaving one repo's directory for another
    end,
    after_refresh = function()
      -- called after :PigitRefresh completes
    end,
  },
})
```

### Integration examples

Save and restore sessions when switching repos with [possession.nvim](https://github.com/jedrzejboczar/possession.nvim):

```lua
hooks = {
  before_leave = function(repo)
    require("possession").save(repo.name)
  end,
  after_cd = function(repo)
    require("possession").load(repo.name)
  end,
}
```

## Health check

Run `:checkhealth pigit` to verify:

- Neovim version >= 0.10
- `pigit` CLI availability
- `repos.json` validity and repo count
- `telescope.nvim` installation
- `nvim-web-devicons` (optional)

## License

[MIT](LICENSE)
