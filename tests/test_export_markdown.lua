local new_set = MiniTest.new_set
local expect = MiniTest.expect

local config = require("review.config")
local markdown = require("review.export.markdown")
local state = require("review.state")

local T = new_set({
    hooks = {
        pre_case = function()
            config.setup()
            state.reset()
        end,
    },
})

T["no comments returns no comments message"] = function()
    local result = markdown.generate()
    expect.equality(result:find("_No comments._") ~= nil, true)
end

T["single comment has correct markdown structure"] = function()
    state.add_comment("src/main.lua", 5, "note", "Looks good")
    local file_state = state.get_file_state("src/main.lua")
    file_state.render_lines = {
        { type = "context", content = "line 1" },
        { type = "context", content = "line 2" },
        { type = "context", content = "line 3" },
        { type = "context", content = "line 4" },
        { type = "add", content = "line 5" },
    }
    local result = markdown.generate()
    expect.equality(result:find("# Code Review Comments") ~= nil, true)
    expect.equality(result:find("## src/main.lua") ~= nil, true)
    expect.equality(result:find("%[NOTE%]") ~= nil, true)
    expect.equality(result:find("Looks good") ~= nil, true)
end

T["fix type shows FIX label"] = function()
    state.add_comment("test.lua", 1, "fix", "Fix this")
    state.get_file_state("test.lua").render_lines = { { type = "add", content = "x" } }
    local result = markdown.generate()
    expect.equality(result:find("%[FIX%]") ~= nil, true)
end

T["question type shows QUESTION label"] = function()
    state.add_comment("test.lua", 1, "question", "Why?")
    state.get_file_state("test.lua").render_lines = { { type = "add", content = "x" } }
    local result = markdown.generate()
    expect.equality(result:find("%[QUESTION%]") ~= nil, true)
end

T["files sorted alphabetically"] = function()
    state.add_comment("z_file.lua", 1, "note", "z comment")
    state.get_file_state("z_file.lua").render_lines = { { type = "add", content = "z" } }
    state.add_comment("a_file.lua", 1, "note", "a comment")
    state.get_file_state("a_file.lua").render_lines = { { type = "add", content = "a" } }
    local result = markdown.generate()
    local a_position = result:find("## a_file.lua")
    local z_position = result:find("## z_file.lua")
    expect.equality(a_position < z_position, true)
end

T["original_line used when present"] = function()
    state.add_comment("test.lua", 5, "note", "hello", 42)
    state.get_file_state("test.lua").render_lines = {
        { type = "context", content = "1" },
        { type = "context", content = "2" },
        { type = "context", content = "3" },
        { type = "context", content = "4" },
        { type = "add", content = "5" },
    }
    local result = markdown.generate()
    expect.equality(result:find("test.lua:42") ~= nil, true)
end

T["falls back to diff line when no original_line"] = function()
    state.add_comment("test.lua", 5, "note", "hello")
    state.get_file_state("test.lua").render_lines = {
        { type = "context", content = "1" },
        { type = "context", content = "2" },
        { type = "context", content = "3" },
        { type = "context", content = "4" },
        { type = "add", content = "5" },
    }
    local result = markdown.generate()
    expect.equality(result:find("test.lua:5") ~= nil, true)
end

T["language mapping for .ts files"] = function()
    state.add_comment("app.ts", 1, "note", "hello")
    local file_state = state.get_file_state("app.ts")
    file_state.render_lines = {
        { type = "context", content = "const x = 1" },
    }
    local result = markdown.generate()
    expect.equality(result:find("```typescript") ~= nil, true)
end

T["language mapping for .lua files"] = function()
    state.add_comment("init.lua", 1, "note", "hello")
    local file_state = state.get_file_state("init.lua")
    file_state.render_lines = {
        { type = "context", content = "local M = {}" },
    }
    local result = markdown.generate()
    expect.equality(result:find("```lua") ~= nil, true)
end

T["context lines from render_lines"] = function()
    state.add_comment("test.lua", 2, "note", "check this")
    local file_state = state.get_file_state("test.lua")
    file_state.render_lines = {
        { type = "context", content = "line one" },
        { type = "add", content = "line two" },
        { type = "context", content = "line three" },
    }
    local result = markdown.generate()
    expect.equality(result:find("%+line two") ~= nil, true)
end

T["to_clipboard sets both registers"] = function()
    state.add_comment("test.lua", 1, "note", "clipboard test")
    state.get_file_state("test.lua").render_lines = { { type = "add", content = "x" } }
    markdown.to_clipboard()
    local plus_content = vim.fn.getreg("+")
    local star_content = vim.fn.getreg("*")
    expect.equality(plus_content:find("clipboard test") ~= nil, true)
    expect.equality(star_content:find("clipboard test") ~= nil, true)
end

T["context boundary handling at start of render_lines"] = function()
    config.setup({ export = { context_lines = 3 } })
    state.add_comment("test.lua", 1, "note", "first line comment")
    local file_state = state.get_file_state("test.lua")
    file_state.render_lines = {
        { type = "add", content = "only line" },
    }
    local result = markdown.generate()
    expect.equality(result:find("%+only line") ~= nil, true)
end

T["range comment shows start-end in header"] = function()
    state.add_comment("test.lua", 5, "fix", "Fix range", 10, "new", 15, "new")
    local file_state = state.get_file_state("test.lua")
    file_state.render_lines = {
        { type = "context", content = "line 1", new_line = 8 },
        { type = "context", content = "line 2", new_line = 9 },
        { type = "add", content = "line 3", new_line = 10 },
        { type = "add", content = "line 4", new_line = 11 },
        { type = "add", content = "line 5", new_line = 12 },
    }
    local result = markdown.generate()
    expect.equality(result:find("%[FIX%] test.lua:10%-15") ~= nil, true)
end

T["range comment includes full range context"] = function()
    config.setup({ export = { context_lines = 1 } })
    state.add_comment("test.lua", 5, "note", "Range note", 2, "new", 4, "new")
    local file_state = state.get_file_state("test.lua")
    file_state.render_lines = {
        { type = "context", content = "before", new_line = 1 },
        { type = "add", content = "start", new_line = 2 },
        { type = "add", content = "middle", new_line = 3 },
        { type = "add", content = "end", new_line = 4 },
        { type = "context", content = "after", new_line = 5 },
    }
    local result = markdown.generate()
    -- Should include from start-1 to end+1 (context_lines=1)
    expect.equality(result:find("before") ~= nil, true)
    expect.equality(result:find("%+start") ~= nil, true)
    expect.equality(result:find("%+middle") ~= nil, true)
    expect.equality(result:find("%+end") ~= nil, true)
    expect.equality(result:find("after") ~= nil, true)
end

T["single-line comment still shows single line in header"] = function()
    state.add_comment("test.lua", 3, "note", "Single", 42, "new")
    local file_state = state.get_file_state("test.lua")
    file_state.render_lines = {
        { type = "context", content = "a", new_line = 40 },
        { type = "context", content = "b", new_line = 41 },
        { type = "add", content = "c", new_line = 42 },
    }
    local result = markdown.generate()
    expect.equality(result:find("%[NOTE%] test.lua:42") ~= nil, true)
    -- Should NOT have a range dash
    expect.equality(result:find("test.lua:42%-") == nil, true)
end

return T
