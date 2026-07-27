local comment_types_module = require("review.comment_types")
local paths = require("review.core.paths")

local comment_types = comment_types_module.TYPES

local M = {}

---Build markdown content from quick comments
---@param comments QuickComment[]
---@return string
function M.build(comments)
    local lines = { "# Quick Comments" }
    local current_file = nil

    for _, comment in ipairs(comments) do
        if comment.file ~= current_file then
            current_file = comment.file
            table.insert(lines, "")
            table.insert(lines, "## " .. paths.get_relative_path(comment.file))
        end

        local type_info = comment_types[comment.type] or comment_types.note
        local line_number = tonumber(comment.line) or 0
        table.insert(lines, "")
        table.insert(lines, string.format("**Line %d** - %s %s", line_number, type_info.icon, type_info.label))
        if comment.context then
            local fence = string.rep("`", math.max(3, #(comment.context:match("`+") or "") + 1))
            table.insert(lines, fence)
            table.insert(lines, comment.context)
            table.insert(lines, fence)
        end
        table.insert(lines, comment.text or "")
    end

    return table.concat(lines, "\n")
end

return M
