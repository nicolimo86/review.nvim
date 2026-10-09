---Inline diff mode: shows the working-tree file itself in the diff pane and
---decorates it. Added lines get line highlights and signs; deleted lines are
---drawn as virtual lines above the row they were removed from.
local git = require("review.core.git")
local inline = require("review.core.inline")
local word_diff = require("review.core.word_diff")

local M = {}

---Buffers that currently hold inline content, with the syntax value to restore
---@type table<number, string>
local active = {}

---Read the working-tree file
---@param file string Path relative to the git root
---@return string[]|nil contents nil when the file cannot be read
function M.read_file(file)
    local root = git.get_root()
    if not root then
        return nil
    end
    local path = root .. "/" .. file
    if vim.fn.filereadable(path) ~= 1 then
        return nil
    end
    local ok, lines = pcall(vim.fn.readfile, path)
    if not ok then
        return nil
    end
    return lines
end

---Highlight the buffer. Treesitter when a parser exists, regex syntax otherwise.
---No FileType event is fired so user autocmds (LSP attach, ftplugins) never see this scratch buffer.
---@param bufnr number
---@param file string
local function attach_highlighting(bufnr, file)
    local ft = vim.filetype.match({ filename = file })
    if not ft or ft == "" then
        return
    end
    local lang = vim.treesitter.language.get_lang(ft) or ft
    if not pcall(vim.treesitter.start, bufnr, lang) then
        vim.bo[bufnr].syntax = ft
    end
end

---Undo attach_highlighting when the buffer goes back to unified rendering
---@param bufnr number
function M.release(bufnr)
    local saved_syntax = active[bufnr]
    if saved_syntax == nil then
        return
    end
    active[bufnr] = nil
    if vim.api.nvim_buf_is_valid(bufnr) then
        pcall(vim.treesitter.stop, bufnr)
        vim.bo[bufnr].syntax = saved_syntax
    end
end

---Build the virtual lines for one deleted block
---@param deletion InlineDeletion
---@param width number Window width, so the line background spans the pane
---@param gutter number Width of the sign + number columns
---@return table[] virt_lines
local function deletion_virt_lines(deletion, width, gutter)
    local virt_lines = {}
    local tab = string.rep(" ", vim.o.tabstop)
    for _, deleted in ipairs(deletion.lines) do
        local text = deleted.content:gsub("\t", tab)
        local chunks = {
            { "▌", "ReviewDiffSignDelete" },
            { string.rep(" ", math.max(gutter - 1, 0)), "ReviewDiffDelete" },
        }

        -- Emphasise the changed span; ranges are byte offsets into the original content
        local ranges = deleted.pair and word_diff.compute(deleted.pair, deleted.content) or {}
        if #ranges > 0 and text == deleted.content then
            local range = ranges[1]
            table.insert(chunks, { text:sub(1, range[1]), "ReviewDiffDelete" })
            table.insert(chunks, { text:sub(range[1] + 1, range[2]), "ReviewDiffDeleteInline" })
            table.insert(chunks, { text:sub(range[2] + 1), "ReviewDiffDelete" })
        else
            table.insert(chunks, { text, "ReviewDiffDelete" })
        end

        local pad = width - gutter - vim.fn.strdisplaywidth(text)
        if pad > 0 then
            table.insert(chunks, { string.rep(" ", pad), "ReviewDiffDelete" })
        end
        table.insert(virt_lines, chunks)
    end
    return virt_lines
end

---Fill the buffer with the working-tree file and decorate it
---@param bufnr number
---@param winid number|nil
---@param file string
---@param parsed ParsedDiff
---@param contents string[]
---@param ns number Namespace for the decorations
---@return DiffLine[] render_lines
---@return InlineLayout layout
function M.render(bufnr, winid, file, parsed, contents, ns)
    if #contents == 0 then
        contents = { "" }
    end
    local layout = inline.compute(parsed, #contents)

    vim.api.nvim_set_option_value("readonly", false, { buf = bufnr })
    vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, contents)
    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
    vim.api.nvim_set_option_value("readonly", true, { buf = bufnr })

    if active[bufnr] == nil then
        active[bufnr] = vim.bo[bufnr].syntax
        attach_highlighting(bufnr, file)
    end

    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

    -- A new file is all additions; a full-width green wall is noise, so keep the signs only
    local whole_file_added = parsed.file_old == "/dev/null"

    for row, entry in pairs(layout.added) do
        vim.api.nvim_buf_set_extmark(bufnr, ns, row - 1, 0, {
            sign_text = "▌",
            sign_hl_group = "ReviewDiffSignAdd",
            line_hl_group = not whole_file_added and "ReviewDiffAdd" or nil,
        })
        local text = contents[row] or ""
        local ranges = entry.pair and word_diff.compute(entry.pair, text) or {}
        for _, range in ipairs(ranges) do
            if range[1] < range[2] then
                vim.api.nvim_buf_set_extmark(bufnr, ns, row - 1, range[1], {
                    end_col = math.min(range[2], #text),
                    hl_group = "ReviewDiffAddInline",
                    priority = 4200,
                })
            end
        end
    end

    local valid_win = winid and vim.api.nvim_win_is_valid(winid)
    local width = valid_win and vim.api.nvim_win_get_width(winid) or 80
    local gutter = valid_win and vim.fn.getwininfo(winid)[1].textoff or 0

    for _, deletion in ipairs(layout.deletions) do
        vim.api.nvim_buf_set_extmark(bufnr, ns, deletion.row - 1, 0, {
            virt_lines = deletion_virt_lines(deletion, width, gutter),
            virt_lines_above = deletion.above,
            virt_lines_leftcol = true,
        })
    end

    return inline.build_render_lines(layout, contents), layout
end

return M
