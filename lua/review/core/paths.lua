local M = {}

---Get relative path from cwd
---@param path string
---@return string
function M.get_relative_path(path)
    local cwd = vim.fn.getcwd()
    if cwd ~= "/" and path:sub(1, #cwd + 1) == cwd .. "/" then
        return path:sub(#cwd + 2)
    end
    return path
end

---Check if a filename is a test or spec file
---@param filename string
---@return boolean
function M.is_test_file(filename)
    local basename = vim.fn.fnamemodify(filename, ":t")
    if
        basename:match("^test[_.]")
        or basename:match("[_.]test%.")
        or basename:match("[_.]spec%.")
        or basename:match("^spec[_.]")
        or basename:match("_test%.")
        or basename:match("_spec%.")
    then
        return true
    end
    return false
end

---Find the index of the file node whose path matches the target.
---Skips non-file nodes (directories, separators, roots). Pure over the node list.
---@param nodes table[]|nil List of nodes, each with `is_file` and `path` fields
---@param target_path string|nil Path to match
---@return number|nil index 1-based index of the matching file node, or nil
function M.find_file_node_index(nodes, target_path)
    if not nodes or not target_path then
        return nil
    end
    for index, node in ipairs(nodes) do
        if node.is_file and node.path == target_path then
            return index
        end
    end
    return nil
end

---Get file extension for fenced code block language
---@param file string
---@return string
function M.get_code_fence_language(file)
    local extension = vim.fn.fnamemodify(file, ":e")
    local language_map = {
        ts = "typescript",
        js = "javascript",
        py = "python",
        rb = "ruby",
        rs = "rust",
        yml = "yaml",
        md = "markdown",
    }
    return language_map[extension] or extension
end

return M
