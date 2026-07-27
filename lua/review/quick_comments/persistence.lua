local json_persistence = require("review.core.json_persistence")
local log = require("review.core.log")
local qc_state = require("review.quick_comments.state")

local M = {}

local FILENAME = "review-comments.json"

local loaded_path = nil

---Get the path to the persistence file
---@return string|nil
function M.get_path()
    return json_persistence.get_git_path(FILENAME)
end

---Load comments from disk
---@return boolean success
function M.load()
    local path = M.get_path()
    if not path then
        return false
    end

    loaded_path = path

    local ok, data = json_persistence.read_json_file(path)
    if not ok then
        vim.notify("Failed to parse quick comments file", vim.log.levels.WARN)
        return false
    end

    if not data then
        return true
    end

    if data.version ~= 1 then
        vim.notify("Unsupported quick comments file version", vim.log.levels.WARN)
        return false
    end

    qc_state.load({
        comments = data.comments or {},
        comment_id_counter = data.comment_id_counter or 0,
    })

    log.info("quick comments: loaded", #(data.comments or {}), "from", path)

    return true
end

---Save comments to disk
---@return boolean success
function M.save()
    if not require("review.config").get().persistence.enabled then
        return false
    end

    local path = M.get_path()
    if not path then
        return false
    end

    if loaded_path and loaded_path ~= path then
        log.warn("quick comments: refusing to save into", path, "loaded from", loaded_path)
        return false
    end

    local state_data = qc_state.export()

    if qc_state.count() == 0 then
        os.remove(path)
        return true
    end

    local data = {
        version = 1,
        comments = state_data.comments,
        comment_id_counter = state_data.comment_id_counter,
    }

    if not json_persistence.write_json_file(path, data) then
        vim.notify("Failed to write quick comments file", vim.log.levels.ERROR)
        log.error("quick comments: write failed", path)
        return false
    end

    log.info("quick comments: saved", qc_state.count(), "to", path)
    return true
end

---Set up autosave on VimLeavePre
function M.setup_autosave()
    vim.api.nvim_create_autocmd("VimLeavePre", {
        group = vim.api.nvim_create_augroup("ReviewQuickCommentsPersist", { clear = true }),
        callback = function()
            M.save()
        end,
    })
end

return M
