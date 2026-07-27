local M = {}

local LEVELS = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
}

local LEVEL_NAMES = { "DEBUG", "INFO", "WARN", "ERROR" }

local MAX_LOG_BYTES = 1024 * 1024

local current_level = LEVELS.WARN

local default_dir = vim.fs.joinpath(vim.uv.os_tmpdir() or "/tmp", "review.nvim")
local log_path = vim.fs.joinpath(default_dir, "review.log")
local dir_ready = false

---@return string
function M.get_log_path()
    return log_path
end

---Configure the logger
---@param level string|nil Log level name (DEBUG, INFO, WARN, ERROR)
---@param path string|nil Override the log file path
function M.setup(level, path)
    if level and LEVELS[level:upper()] then
        current_level = LEVELS[level:upper()]
    end
    if path and path ~= "" then
        log_path = path
        dir_ready = false
    end
end

---Truncate the log file when it grows past the size cap
local function rotate_if_needed()
    local stat = vim.uv.fs_stat(log_path)
    if stat and stat.size > MAX_LOG_BYTES then
        os.remove(log_path .. ".old")
        os.rename(log_path, log_path .. ".old")
    end
end

---Write a log entry at the given level
---@param level number
---@param ... any
local function write(level, ...)
    if level < current_level then
        return
    end

    local parts = {}
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        table.insert(parts, tostring(value))
    end
    local message = table.concat(parts, " ")

    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local level_name = LEVEL_NAMES[level] or "UNKNOWN"
    local line = string.format("[%s] [%s] %s\n", timestamp, level_name, message)

    if not dir_ready then
        vim.fn.mkdir(vim.fs.dirname(log_path), "p")
        dir_ready = true
    end

    rotate_if_needed()

    local file = io.open(log_path, "a")
    if file then
        file:write(line)
        file:close()
    end
end

---@param ... any
function M.debug(...)
    write(LEVELS.DEBUG, ...)
end

---@param ... any
function M.info(...)
    write(LEVELS.INFO, ...)
end

---@param ... any
function M.warn(...)
    write(LEVELS.WARN, ...)
end

---@param ... any
function M.error(...)
    write(LEVELS.ERROR, ...)
end

return M
