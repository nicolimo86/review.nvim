local git = require("review.core.git")

local M = {}

local git_dir_cache = {}

---Get the path to a file inside the resolved git directory
---@param filename string
---@return string|nil
function M.get_git_path(filename)
    local git_root = git.get_root()
    if not git_root then
        return nil
    end

    local git_dir = git_dir_cache[git_root]
    if not git_dir then
        local result = vim.system({ "git", "rev-parse", "--absolute-git-dir" }, { text = true, cwd = git_root }):wait()
        if result.code ~= 0 then
            return nil
        end
        git_dir = vim.trim(result.stdout)
        git_dir_cache[git_root] = git_dir
    end

    return git_dir .. "/" .. filename
end

---Read and decode a JSON file
---@param path string
---@return boolean ok
---@return table|nil data
function M.read_json_file(path)
    local file = io.open(path, "r")
    if not file then
        return true, nil
    end

    local content = file:read("*all")
    file:close()

    if not content or content == "" then
        return true, nil
    end

    local ok, data = pcall(vim.json.decode, content)
    if not ok or type(data) ~= "table" then
        return false, nil
    end

    return true, data
end

---Encode and write data to a JSON file
---@param path string
---@param data table
---@return boolean ok
function M.write_json_file(path, data)
    local encode_ok, json = pcall(vim.json.encode, data)
    if not encode_ok then
        return false
    end

    local tmp_path = path .. ".tmp"
    local file = io.open(tmp_path, "w")
    if not file then
        return false
    end

    local written = file:write(json)
    file:close()

    if not written then
        os.remove(tmp_path)
        return false
    end

    if not os.rename(tmp_path, path) then
        os.remove(tmp_path)
        return false
    end

    return true
end

return M
