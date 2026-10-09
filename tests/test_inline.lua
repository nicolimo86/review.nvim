local new_set = MiniTest.new_set
local expect = MiniTest.expect

local diff = require("review.core.diff")
local inline = require("review.core.inline")

local T = new_set()

local function parse(lines)
    return diff.parse(table.concat(lines, "\n") .. "\n")
end

local HEADER = { "diff --git a/f.lua b/f.lua", "--- a/f.lua", "+++ b/f.lua" }

local function make(hunk_lines)
    local lines = vim.list_extend(vim.deepcopy(HEADER), hunk_lines)
    return parse(lines)
end

T["compute"] = new_set()

T["compute"]["maps added lines onto file rows"] = function()
    local parsed = make({ "@@ -1,2 +1,3 @@", " a", "+b", " c" })
    local layout = inline.compute(parsed, 3)
    expect.equality(layout.added[2] ~= nil, true)
    expect.equality(layout.added[1], nil)
    expect.equality(layout.change_rows, { 2 })
    expect.equality(#layout.deletions, 0)
end

T["compute"]["attaches deleted lines above the next surviving row"] = function()
    local parsed = make({ "@@ -1,3 +1,2 @@", " a", "-b", " c" })
    local layout = inline.compute(parsed, 2)
    expect.equality(#layout.deletions, 1)
    expect.equality(layout.deletions[1].row, 2)
    expect.equality(layout.deletions[1].above, true)
    expect.equality(layout.deletions[1].lines[1].content, "b")
    expect.equality(layout.deletions[1].lines[1].old_line, 2)
    expect.equality(layout.change_rows, { 2 })
end

T["compute"]["pairs a replacement for word-level highlights"] = function()
    local parsed = make({ "@@ -1,3 +1,3 @@", " a", "-old", "+new", " c" })
    local layout = inline.compute(parsed, 3)
    expect.equality(layout.added[2].pair, "old")
    expect.equality(layout.deletions[1].lines[1].pair, "new")
    expect.equality(layout.deletions[1].row, 2)
    -- deletion block and replacement share one change row
    expect.equality(layout.change_rows, { 2 })
end

T["compute"]["leaves surplus adds unpaired"] = function()
    local parsed = make({ "@@ -1,2 +1,3 @@", " a", "-old", "+new1", "+new2" })
    local layout = inline.compute(parsed, 3)
    expect.equality(layout.added[2].pair, "old")
    expect.equality(layout.added[3].pair, nil)
end

T["compute"]["draws trailing deletions below the last row"] = function()
    local parsed = make({ "@@ -1,3 +1,1 @@", " a", "-b", "-c" })
    local layout = inline.compute(parsed, 1)
    expect.equality(layout.deletions[1].row, 1)
    expect.equality(layout.deletions[1].above, false)
    expect.equality(#layout.deletions[1].lines, 2)
    expect.equality(layout.change_rows, { 1 })
end

T["compute"]["handles a pure deletion hunk with zero new count"] = function()
    -- git reports new_start as the line before the gap for -U0 style hunks
    local parsed = make({ "@@ -3,2 +2,0 @@", "-x", "-y" })
    local layout = inline.compute(parsed, 5)
    expect.equality(layout.deletions[1].row, 3)
    expect.equality(layout.deletions[1].above, true)
end

T["compute"]["keeps hunks separate and change rows sorted"] = function()
    local parsed = make({
        "@@ -1,2 +1,3 @@",
        " a",
        "+b",
        " c",
        "@@ -10,2 +11,2 @@",
        " x",
        "-y",
        "+z",
    })
    local layout = inline.compute(parsed, 12)
    expect.equality(layout.change_rows, { 2, 12 })
end

T["compute"]["returns an empty layout for an empty diff"] = function()
    local layout = inline.compute(diff.parse(""), 3)
    expect.equality(layout.change_rows, {})
    expect.equality(layout.deletions, {})
end

T["build_render_lines"] = new_set()

T["build_render_lines"]["has one entry per row typed by change"] = function()
    local parsed = make({ "@@ -1,2 +1,3 @@", " a", "+b", " c" })
    local layout = inline.compute(parsed, 3)
    local lines = inline.build_render_lines(layout, { "a", "b", "c" })
    expect.equality(#lines, 3)
    expect.equality(lines[1].type, "context")
    expect.equality(lines[2].type, "add")
    expect.equality(lines[2].new_line, 2)
    expect.equality(lines[2].content, "b")
end

T["build_render_lines"]["anchors comments through get_source_line"] = function()
    local parsed = make({ "@@ -1,2 +1,3 @@", " a", "+b", " c" })
    local layout = inline.compute(parsed, 3)
    local lines = inline.build_render_lines(layout, { "a", "b", "c" })
    local line, side = diff.get_source_line(3, lines)
    expect.equality(line, 3)
    expect.equality(side, "new")
end

T["next_change"] = new_set()

T["next_change"]["moves forward and wraps"] = function()
    expect.equality(inline.next_change({ 2, 10 }, 1, 1), 2)
    expect.equality(inline.next_change({ 2, 10 }, 2, 1), 10)
    expect.equality(inline.next_change({ 2, 10 }, 10, 1), 2)
end

T["next_change"]["moves backward and wraps"] = function()
    expect.equality(inline.next_change({ 2, 10 }, 12, -1), 10)
    expect.equality(inline.next_change({ 2, 10 }, 10, -1), 2)
    expect.equality(inline.next_change({ 2, 10 }, 2, -1), 10)
end

T["next_change"]["returns nil without changes"] = function()
    expect.equality(inline.next_change({}, 1, 1), nil)
end

T["supports"] = new_set()

T["supports"]["accepts a working-tree diff"] = function()
    local parsed = make({ "@@ -1 +1 @@", "-a", "+b" })
    expect.equality(inline.supports(parsed, nil), true)
end

T["supports"]["rejects a fixed range"] = function()
    local parsed = make({ "@@ -1 +1 @@", "-a", "+b" })
    expect.equality(inline.supports(parsed, "abc123"), false)
end

T["supports"]["rejects a deleted file"] = function()
    local parsed = diff.parse("diff --git a/f b/f\n--- a/f\n+++ /dev/null\n@@ -1 +0,0 @@\n-a\n")
    expect.equality(inline.supports(parsed, nil), false)
end

return T
