local json_persistence = require("review.core.json_persistence")
local log = require("review.core.log")
local state = require("review.state")

local M = {}

local FILENAME = "review-session.json"

local loaded_path = nil
local unreadable_path = nil

---Get the path to the persistence file
---@return string|nil
function M.get_path()
    return json_persistence.get_git_path(FILENAME)
end

---Check if a saved session exists
---@return boolean
function M.exists()
    local path = M.get_path()
    if not path then
        return false
    end

    local file = io.open(path, "r")
    if not file then
        return false
    end
    file:close()
    return true
end

---Load session from disk into state
---@return boolean success
function M.load()
    local path = M.get_path()
    if not path then
        return false
    end

    local ok, data = json_persistence.read_json_file(path)
    if not ok then
        unreadable_path = path
        vim.notify("Failed to parse review session file, leaving it untouched", vim.log.levels.WARN)
        log.warn("persistence: parse failed, will not overwrite or delete", path)
        return false
    end

    if data and data.version ~= 1 then
        unreadable_path = path
        vim.notify("Unsupported review session file version, leaving it untouched", vim.log.levels.WARN)
        log.warn("persistence: version", tostring(data.version), "unsupported, will not overwrite or delete", path)
        return false
    end

    loaded_path = path
    unreadable_path = nil

    if not data then
        return true
    end

    if data.files then
        for file_path, file_data in pairs(data.files) do
            local file_state = state.get_file_state(file_path)
            if file_data.comments then
                file_state.comments = file_data.comments
            end
        end
    end

    if data.base and not state.is_history_mode() then
        state.state.base = data.base
        state.state.base_end = data.base_end
    end

    if data.diff_mode then
        state.state.diff_mode = data.diff_mode
    end

    if data.comment_id_counter then
        state.state.comment_id_counter = data.comment_id_counter
    end

    return true
end

---Save session to disk
---@return boolean success
function M.save()
    local config = require("review.config").get()
    if not config.persistence.enabled then
        return true
    end

    local path = M.get_path()
    if not path then
        return false
    end

    if loaded_path and loaded_path ~= path then
        log.warn("persistence: refusing to save into", path, "loaded from", loaded_path)
        return false
    end

    if unreadable_path == path then
        log.warn("persistence: refusing to overwrite", path, "-- it exists but could not be read")
        return false
    end

    local all_comments = state.get_all_comments()
    if #all_comments == 0 then
        os.remove(path)
        return true
    end

    local files_data = {}
    for file_path, file_state in pairs(state.state.files) do
        if #file_state.comments > 0 then
            local comments = {}
            for _, comment in ipairs(file_state.comments) do
                table.insert(comments, {
                    id = comment.id,
                    file = comment.file,
                    line = comment.line,
                    original_line = comment.original_line,
                    side = comment.side,
                    type = comment.type,
                    text = comment.text,
                    created_at = comment.created_at,
                })
            end
            files_data[file_path] = { comments = comments }
        end
    end

    local data = {
        version = 1,
        files = files_data,
        base = state.state.base,
        base_end = state.state.base_end,
        diff_mode = state.state.diff_mode,
        comment_id_counter = state.state.comment_id_counter,
    }

    if not json_persistence.write_json_file(path, data) then
        vim.notify("Failed to write review session file", vim.log.levels.ERROR)
        log.error("persistence: write failed", path)
        return false
    end

    log.info("persistence: saved", #all_comments, "comment(s) to", path)
    return true
end

---Delete the session file
---@return boolean success
function M.delete()
    local path = M.get_path()
    if not path then
        return false
    end

    if unreadable_path == path then
        log.warn("persistence: refusing to delete", path, "-- it exists but could not be read")
        return false
    end

    os.remove(path)
    return true
end

---Set up autosave on VimLeavePre
function M.setup_autosave()
    vim.api.nvim_create_autocmd("VimLeavePre", {
        group = vim.api.nvim_create_augroup("ReviewSessionPersist", { clear = true }),
        callback = function()
            if state.state.is_open then
                M.save()
            end
        end,
    })
end

return M
