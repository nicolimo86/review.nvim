local new_set = MiniTest.new_set
local expect = MiniTest.expect

local paths = require("review.core.paths")

local T = new_set()

T["get_relative_path"] = new_set()

T["get_relative_path"]["strips cwd prefix"] = function()
    local cwd = vim.fn.getcwd()
    local result = paths.get_relative_path(cwd .. "/src/main.lua")
    expect.equality(result, "src/main.lua")
end

T["get_relative_path"]["returns path unchanged when not under cwd"] = function()
    local result = paths.get_relative_path("/other/project/file.lua")
    expect.equality(result, "/other/project/file.lua")
end

T["get_relative_path"]["returns path unchanged when already relative"] = function()
    local result = paths.get_relative_path("src/main.lua")
    expect.equality(result, "src/main.lua")
end

T["is_test_file"] = new_set()

T["is_test_file"]["detects test_ prefix"] = function()
    expect.equality(paths.is_test_file("test_main.lua"), true)
end

T["is_test_file"]["detects .test. infix"] = function()
    expect.equality(paths.is_test_file("main.test.ts"), true)
end

T["is_test_file"]["detects .spec. infix"] = function()
    expect.equality(paths.is_test_file("main.spec.js"), true)
end

T["is_test_file"]["detects _test. infix"] = function()
    expect.equality(paths.is_test_file("main_test.go"), true)
end

T["is_test_file"]["detects _spec. infix"] = function()
    expect.equality(paths.is_test_file("main_spec.rb"), true)
end

T["is_test_file"]["detects spec_ prefix"] = function()
    expect.equality(paths.is_test_file("spec_helper.rb"), true)
end

T["is_test_file"]["rejects regular files"] = function()
    expect.equality(paths.is_test_file("main.lua"), false)
end

T["is_test_file"]["rejects files with test in directory path only"] = function()
    expect.equality(paths.is_test_file("utils.lua"), false)
end

T["get_code_fence_language"] = new_set()

T["get_code_fence_language"]["maps ts to typescript"] = function()
    expect.equality(paths.get_code_fence_language("file.ts"), "typescript")
end

T["get_code_fence_language"]["maps js to javascript"] = function()
    expect.equality(paths.get_code_fence_language("file.js"), "javascript")
end

T["get_code_fence_language"]["maps py to python"] = function()
    expect.equality(paths.get_code_fence_language("file.py"), "python")
end

T["get_code_fence_language"]["maps yml to yaml"] = function()
    expect.equality(paths.get_code_fence_language("file.yml"), "yaml")
end

T["get_code_fence_language"]["passes through lua unchanged"] = function()
    expect.equality(paths.get_code_fence_language("file.lua"), "lua")
end

T["get_code_fence_language"]["passes through unknown extensions"] = function()
    expect.equality(paths.get_code_fence_language("file.zig"), "zig")
end

T["get_relative_path"]["does not strip a sibling directory sharing a prefix"] = function()
    local cwd = vim.fn.getcwd()
    expect.equality(paths.get_relative_path(cwd .. "2/file.txt"), cwd .. "2/file.txt")
end

T["get_relative_path"]["leaves absolute paths alone outside cwd"] = function()
    expect.equality(paths.get_relative_path("/etc/hosts"), "/etc/hosts")
end

T["find_file_node_index"] = new_set()

T["find_file_node_index"]["finds a matching file node"] = function()
    local nodes = {
        { is_root = true, path = "/" },
        { is_file = true, path = "src/a.lua" },
        { is_file = true, path = "src/b.lua" },
    }
    expect.equality(paths.find_file_node_index(nodes, "src/b.lua"), 3)
end

T["find_file_node_index"]["returns the first file node when several nodes precede it"] = function()
    local nodes = {
        { is_separator = true },
        { is_directory = true, path = "src" },
        { is_file = true, path = "src/a.lua" },
    }
    expect.equality(paths.find_file_node_index(nodes, "src/a.lua"), 3)
end

T["find_file_node_index"]["skips non-file nodes sharing the path"] = function()
    local nodes = {
        { is_directory = true, path = "src/a.lua" },
        { is_file = true, path = "src/a.lua" },
    }
    expect.equality(paths.find_file_node_index(nodes, "src/a.lua"), 2)
end

T["find_file_node_index"]["returns nil when the path is absent"] = function()
    local nodes = {
        { is_file = true, path = "src/a.lua" },
    }
    expect.equality(paths.find_file_node_index(nodes, "src/missing.lua"), nil)
end

T["find_file_node_index"]["returns nil for nil nodes"] = function()
    expect.equality(paths.find_file_node_index(nil, "src/a.lua"), nil)
end

T["find_file_node_index"]["returns nil for nil target"] = function()
    local nodes = { { is_file = true, path = "src/a.lua" } }
    expect.equality(paths.find_file_node_index(nodes, nil), nil)
end

T["find_file_node_index"]["returns nil for an empty node list"] = function()
    expect.equality(paths.find_file_node_index({}, "src/a.lua"), nil)
end

return T
