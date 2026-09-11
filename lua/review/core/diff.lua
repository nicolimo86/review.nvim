---@class DiffHunk
---@field header string The @@ header line
---@field old_start number Starting line in old file
---@field old_count number Number of lines in old file
---@field new_start number Starting line in new file
---@field new_count number Number of lines in new file
---@field lines DiffLine[]

---@class DiffLine
---@field type "context"|"add"|"delete"|"header"
---@field content string The line content (without +/- prefix)
---@field raw string The raw line with prefix
---@field old_line number|nil Line number in old file
---@field new_line number|nil Line number in new file

---@class ParsedDiff
---@field file_old string|nil Old file path
---@field file_new string|nil New file path
---@field binary boolean Whether git reported the file as binary
---@field hunks DiffHunk[]

local M = {}

---Parse the @@ header to extract line numbers
---@param header string
---@return number old_start, number old_count, number new_start, number new_count
local function parse_hunk_header(header)
    -- Format: @@ -old_start,old_count +new_start,new_count @@
    local old_start, old_count, new_start, new_count = header:match("@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")

    old_start = tonumber(old_start) or 1
    old_count = tonumber(old_count) or 1
    new_start = tonumber(new_start) or 1
    new_count = tonumber(new_count) or 1

    return old_start, old_count, new_start, new_count
end

---Parse a unified diff string into structured format
---@param diff_text string Raw unified diff output
---@return ParsedDiff
function M.parse(diff_text)
    local result = {
        file_old = nil,
        file_new = nil,
        binary = false,
        hunks = {},
    }

    if not diff_text or diff_text == "" then
        return result
    end

    if diff_text:match("^Binary files ") or diff_text:match("\nBinary files ") then
        result.binary = true
    end

    local lines = vim.split((diff_text:gsub("\r\n", "\n")), "\n", { plain = true })
    local current_hunk = nil
    local old_line = 0
    local new_line = 0

    for _, line in ipairs(lines) do
        -- Parse file headers
        if line:match("^diff %-%-git ") then
            current_hunk = nil
        elseif current_hunk == nil and line:match("^%-%-%- ") then
            result.file_old = line:match("^%-%-%- a/(.+)$") or line:match("^%-%-%- (.+)$")
        elseif current_hunk == nil and line:match("^%+%+%+ ") then
            result.file_new = line:match("^%+%+%+ b/(.+)$") or line:match("^%+%+%+ (.+)$")
        elseif line:match("^@@ ") then
            -- Start new hunk
            local old_start, old_count, new_start, new_count = parse_hunk_header(line)
            current_hunk = {
                header = line,
                old_start = old_start,
                old_count = old_count,
                new_start = new_start,
                new_count = new_count,
                lines = {},
            }
            table.insert(result.hunks, current_hunk)
            old_line = old_start
            new_line = new_start
        elseif current_hunk then
            -- Parse diff lines
            local prefix = line:sub(1, 1)
            local content = line:sub(2)

            if prefix == "+" then
                table.insert(current_hunk.lines, {
                    type = "add",
                    content = content,
                    raw = line,
                    old_line = nil,
                    new_line = new_line,
                })
                new_line = new_line + 1
            elseif prefix == "-" then
                table.insert(current_hunk.lines, {
                    type = "delete",
                    content = content,
                    raw = line,
                    old_line = old_line,
                    new_line = nil,
                })
                old_line = old_line + 1
            elseif prefix == " " then
                table.insert(current_hunk.lines, {
                    type = "context",
                    content = content,
                    raw = line,
                    old_line = old_line,
                    new_line = new_line,
                })
                old_line = old_line + 1
                new_line = new_line + 1
            end
        end
    end

    return result
end

---Get all lines for rendering (flattened from hunks)
---@param parsed_diff ParsedDiff
---@return DiffLine[]
function M.get_render_lines(parsed_diff)
    local render_lines = {}

    for _, hunk in ipairs(parsed_diff.hunks) do
        -- Add hunk header as special line
        table.insert(render_lines, {
            type = "header",
            content = hunk.header,
            raw = hunk.header,
            old_line = nil,
            new_line = nil,
        })

        -- Add all lines from hunk
        for _, line in ipairs(hunk.lines) do
            table.insert(render_lines, line)
        end
    end

    return render_lines
end

---@class SplitLine
---@field type "context"|"add"|"delete"|"padding"|"filepath"
---@field content string
---@field source_line number|nil
---@field pair_content string|nil

---Get aligned split render lines for side-by-side diff
---@param parsed_diff ParsedDiff
---@return SplitLine[] old_lines, SplitLine[] new_lines
function M.get_split_render_lines(parsed_diff)
    local old_lines = {}
    local new_lines = {}

    local file_path = parsed_diff.file_new or parsed_diff.file_old or ""

    table.insert(old_lines, { type = "filepath", content = file_path, source_line = nil, pair_content = nil })
    table.insert(new_lines, { type = "filepath", content = file_path, source_line = nil, pair_content = nil })
    table.insert(old_lines, { type = "filepath", content = "", source_line = nil, pair_content = nil })
    table.insert(new_lines, { type = "filepath", content = "", source_line = nil, pair_content = nil })

    for _, hunk in ipairs(parsed_diff.hunks) do
        local line_idx = 1
        local lines = hunk.lines

        while line_idx <= #lines do
            local line = lines[line_idx]

            if line.type == "context" then
                table.insert(old_lines, {
                    type = "context",
                    content = line.content,
                    source_line = line.old_line,
                    pair_content = nil,
                })
                table.insert(new_lines, {
                    type = "context",
                    content = line.content,
                    source_line = line.new_line,
                    pair_content = nil,
                })
                line_idx = line_idx + 1
            elseif line.type == "delete" then
                local deletes = {}
                local scan = line_idx
                while scan <= #lines and lines[scan].type == "delete" do
                    table.insert(deletes, lines[scan])
                    scan = scan + 1
                end

                local adds = {}
                while scan <= #lines and lines[scan].type == "add" do
                    table.insert(adds, lines[scan])
                    scan = scan + 1
                end

                local max_count = math.max(#deletes, #adds)
                for pair_idx = 1, max_count do
                    local delete_line = deletes[pair_idx]
                    local add_line = adds[pair_idx]

                    if delete_line and add_line then
                        table.insert(old_lines, {
                            type = "delete",
                            content = delete_line.content,
                            source_line = delete_line.old_line,
                            pair_content = add_line.content,
                        })
                        table.insert(new_lines, {
                            type = "add",
                            content = add_line.content,
                            source_line = add_line.new_line,
                            pair_content = delete_line.content,
                        })
                    elseif delete_line then
                        table.insert(old_lines, {
                            type = "delete",
                            content = delete_line.content,
                            source_line = delete_line.old_line,
                            pair_content = nil,
                        })
                        table.insert(new_lines, {
                            type = "padding",
                            content = "",
                            source_line = nil,
                            pair_content = nil,
                        })
                    elseif add_line then
                        table.insert(old_lines, {
                            type = "padding",
                            content = "",
                            source_line = nil,
                            pair_content = nil,
                        })
                        table.insert(new_lines, {
                            type = "add",
                            content = add_line.content,
                            source_line = add_line.new_line,
                            pair_content = nil,
                        })
                    end
                end

                line_idx = scan
            elseif line.type == "add" then
                table.insert(old_lines, {
                    type = "padding",
                    content = "",
                    source_line = nil,
                    pair_content = nil,
                })
                table.insert(new_lines, {
                    type = "add",
                    content = line.content,
                    source_line = line.new_line,
                    pair_content = nil,
                })
                line_idx = line_idx + 1
            else
                line_idx = line_idx + 1
            end
        end
    end

    return old_lines, new_lines
end

---Get the source line number for a rendered line
---@param rendered_line_num number 1-based line number in rendered buffer
---@param render_lines DiffLine[]|SplitLine[]
---@return number|nil original_line, "old"|"new"|nil side
function M.get_source_line(rendered_line_num, render_lines)
    local line = render_lines[rendered_line_num]
    if not line then
        return nil, nil
    end

    if line.type ~= "add" and line.type ~= "delete" and line.type ~= "context" then
        return nil, nil
    end

    local side = line.type == "delete" and "old" or "new"

    if line.source_line then
        return line.source_line, side
    end

    if line.type == "delete" then
        return line.old_line, "old"
    end

    return line.new_line, "new"
end

---Resolve the new-side (working file) line to jump to for a given cursor row.
---
---When the cursor sits on an add or context line, its `new_line` is used directly.
---When it sits on a delete line (which has no new-side counterpart), the render
---lines are scanned outward from the cursor in both directions, nearest first,
---for the closest entry that carries a `new_line`. If nothing has a `new_line`
---(e.g. an all-deletion hunk), it falls back to line 1.
---@param render_lines DiffLine[]|SplitLine[]
---@param cursor_row number 1-based line number in the rendered buffer
---@return number target new-side line number (>= 1)
function M.resolve_new_side_line(render_lines, cursor_row)
    if type(render_lines) ~= "table" then
        return 1
    end

    local current = render_lines[cursor_row]
    if current and current.new_line then
        return current.new_line
    end

    -- Scan outward from the cursor, nearest first, for a line with a new_line.
    local max_offset = #render_lines
    for offset = 1, max_offset do
        local below = render_lines[cursor_row + offset]
        if below and below.new_line then
            return below.new_line
        end
        local above = render_lines[cursor_row - offset]
        if above and above.new_line then
            return above.new_line
        end
    end

    return 1
end

return M
