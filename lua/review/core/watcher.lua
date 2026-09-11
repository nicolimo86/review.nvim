local log = require("review.core.log")

local M = {}

local MAX_WATCHED_DIRS = 2000

local IGNORED_DIRS = {
    [".git"] = true,
    ["node_modules"] = true,
    ["target"] = true,
    ["dist"] = true,
    ["build"] = true,
    [".venv"] = true,
    ["vendor"] = true,
}

---@type uv.uv_fs_event_t[]
local fs_events = {}

---@type uv.uv_timer_t|nil
local debounce_timer = nil

---@type uv.uv_timer_t|nil
local git_debounce_timer = nil

---Collect directories to watch, skipping ignored trees
---@param root string
---@return string[]
local function collect_directories(root)
    local dirs = { root }
    local queue = { root }
    local truncated = false

    while #queue > 0 and not truncated do
        local current = table.remove(queue)
        local ok, iterator = pcall(vim.fs.dir, current)
        if ok then
            for name, kind in iterator do
                if kind == "directory" and not IGNORED_DIRS[name] then
                    if #dirs >= MAX_WATCHED_DIRS then
                        truncated = true
                        break
                    end
                    local path = vim.fs.joinpath(current, name)
                    table.insert(dirs, path)
                    table.insert(queue, path)
                end
            end
        end
    end

    if truncated then
        log.warn("watcher: hit the", MAX_WATCHED_DIRS, "directory limit, some changes will not auto-refresh")
    end

    return dirs
end

---Resolve the absolute git directory for a working tree
---@param git_root string
---@return string|nil
local function resolve_git_dir(git_root)
    local result = vim.system({ "git", "rev-parse", "--absolute-git-dir" }, { text = true, cwd = git_root }):wait()
    if result.code ~= 0 then
        return nil
    end
    return vim.trim(result.stdout)
end

---Git-dir paths whose changes mean the history/refs moved (commits, branches, checkouts)
---@param git_dir string
---@return string[]
local function git_metadata_dirs(git_dir)
    local dirs = { git_dir, vim.fs.joinpath(git_dir, "refs") }
    local queue = { vim.fs.joinpath(git_dir, "refs") }

    -- refs/ nests (heads, remotes, tags, remotes/<remote>/...); watch each subdirectory.
    while #queue > 0 do
        local current = table.remove(queue)
        local ok, iterator = pcall(vim.fs.dir, current)
        if ok then
            for name, kind in iterator do
                if kind == "directory" then
                    local path = vim.fs.joinpath(current, name)
                    table.insert(dirs, path)
                    table.insert(queue, path)
                end
            end
        end
    end

    local logs = vim.fs.joinpath(git_dir, "logs")
    if vim.uv.fs_stat(logs) then
        table.insert(dirs, logs)
    end

    return dirs
end

---Start watching a repository for file changes
---@param git_root string Path to watch
---@param callback fun() Called when working-tree changes are detected (debounced)
---@param on_git_change? fun() Called when git metadata (commits, refs) changes (debounced)
function M.start(git_root, callback, on_git_change)
    M.stop()

    local config = require("review.config").get()
    if not config.auto_refresh.enabled then
        log.debug("watcher: disabled by config")
        return
    end

    local debounce_ms = config.auto_refresh.debounce_ms
    debounce_timer = vim.uv.new_timer()
    git_debounce_timer = vim.uv.new_timer()

    local function on_change(error)
        if error or not debounce_timer then
            return
        end
        debounce_timer:stop()
        debounce_timer:start(debounce_ms, 0, function()
            vim.schedule(callback)
        end)
    end

    local function on_git_meta_change(error)
        if error or not git_debounce_timer then
            return
        end
        git_debounce_timer:stop()
        git_debounce_timer:start(debounce_ms, 0, function()
            if on_git_change then
                vim.schedule(on_git_change)
            end
        end)
    end

    local function watch(dir, handler)
        local handle = vim.uv.new_fs_event()
        if handle then
            local ok = pcall(function()
                handle:start(dir, {}, handler)
            end)
            if ok then
                table.insert(fs_events, handle)
            else
                handle:close()
            end
        end
    end

    for _, dir in ipairs(collect_directories(git_root)) do
        watch(dir, on_change)
    end

    local work_tree_count = #fs_events

    if on_git_change then
        local git_dir = resolve_git_dir(git_root)
        if git_dir then
            for _, dir in ipairs(git_metadata_dirs(git_dir)) do
                watch(dir, on_git_meta_change)
            end
        end
    end

    log.info(
        "watcher: watching",
        work_tree_count,
        "work-tree dirs and",
        #fs_events - work_tree_count,
        "git-metadata dirs debounce=",
        debounce_ms
    )
end

---Stop watching for file changes
function M.stop()
    if debounce_timer then
        debounce_timer:stop()
        debounce_timer:close()
        debounce_timer = nil
    end

    if git_debounce_timer then
        git_debounce_timer:stop()
        git_debounce_timer:close()
        git_debounce_timer = nil
    end

    for _, handle in ipairs(fs_events) do
        handle:stop()
        handle:close()
    end
    fs_events = {}
end

return M
