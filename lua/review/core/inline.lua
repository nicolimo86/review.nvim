---Pure layout for the inline diff mode: maps parsed hunks onto the rows of the
---working-tree file. Added lines are rows of the file itself; deleted lines
---have no row, so they are grouped into blocks attached to the row they sat above.
local M = {}

---@class InlineAdded
---@field pair string|nil Content of the deleted line this one replaced (for word-level highlights)

---@class InlineDeletedLine
---@field content string
---@field old_line number
---@field pair string|nil Content of the added line that replaced it

---@class InlineDeletion
---@field row number 1-based file row the block is attached to
---@field above boolean true: draw above `row`; false: draw below it (deletion at end of file)
---@field lines InlineDeletedLine[]

---@class InlineLayout
---@field added table<number, InlineAdded> Added rows, keyed by 1-based file row
---@field deletions InlineDeletion[] Deleted blocks, in file order
---@field change_rows number[] Sorted, unique 1-based rows where a change block starts

---Compute where each hunk change lands in the working-tree file
---@param parsed ParsedDiff
---@param line_count number Number of lines in the working-tree file
---@return InlineLayout
function M.compute(parsed, line_count)
    local layout = { added = {}, deletions = {}, change_rows = {} }
    local seen = {}

    local function mark(row)
        if not seen[row] then
            seen[row] = true
            table.insert(layout.change_rows, row)
        end
    end

    for _, hunk in ipairs(parsed.hunks) do
        -- For a pure deletion git reports new_start as the line *before* the gap
        local next_new = hunk.new_count == 0 and hunk.new_start + 1 or hunk.new_start
        local block = nil -- deletion block still collecting lines
        local paired = nil -- closed block that the following adds pair against
        local paired_idx = 0
        local in_change = false

        -- Attach the pending block to `row`, the first new-side row after it
        local function close(row)
            if not block then
                return
            end
            if row > line_count then
                block.row = math.max(line_count, 1)
                block.above = false
            else
                block.row = row
                block.above = true
            end
            table.insert(layout.deletions, block)
            mark(block.row)
            in_change = true
            paired, paired_idx, block = block, 0, nil
        end

        for _, line in ipairs(hunk.lines) do
            if line.type == "delete" then
                paired = nil
                in_change = false
                block = block or { lines = {} }
                table.insert(block.lines, { content = line.content, old_line = line.old_line })
            else
                close(next_new)
                if line.type == "add" then
                    local row = line.new_line or next_new
                    local entry = {}
                    layout.added[row] = entry
                    if not in_change then
                        mark(row)
                    end
                    in_change = true
                    paired_idx = paired_idx + 1
                    local deleted = paired and paired.lines[paired_idx]
                    if deleted then
                        entry.pair = deleted.content
                        deleted.pair = line.content
                    end
                else
                    paired = nil
                    in_change = false
                end
                next_new = next_new + 1
            end
        end
        close(next_new)
    end

    return layout
end

---Build render_lines for the working-tree file. One entry per file row, so a
---display row is also the source line, and the helpers that anchor comments
---(`get_source_line`, `display_row_for`) work unchanged on the new side.
---@param layout InlineLayout
---@param contents string[]
---@return DiffLine[]
function M.build_render_lines(layout, contents)
    local render_lines = {}
    for row, text in ipairs(contents) do
        render_lines[row] = {
            type = layout.added[row] and "add" or "context",
            content = text,
            new_line = row,
        }
    end
    return render_lines
end

---Find the next or previous change row, wrapping around the ends
---@param rows number[] Sorted change rows
---@param cursor number 1-based cursor row
---@param direction 1|-1
---@return number|nil row
function M.next_change(rows, cursor, direction)
    if #rows == 0 then
        return nil
    end
    if direction > 0 then
        for _, row in ipairs(rows) do
            if row > cursor then
                return row
            end
        end
        return rows[1]
    end
    for i = #rows, 1, -1 do
        if rows[i] < cursor then
            return rows[i]
        end
    end
    return rows[#rows]
end

---Whether a diff can be drawn on the working-tree file. Needs a working-tree
---comparison (the file on disk is the new side) and a file that still exists.
---@param parsed ParsedDiff
---@param base_end string|nil
---@return boolean
function M.supports(parsed, base_end)
    if base_end ~= nil or parsed.binary then
        return false
    end
    return parsed.file_new ~= "/dev/null"
end

return M
