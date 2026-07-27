local new_set = MiniTest.new_set
local expect = MiniTest.expect

local git = require("review.core.git")

local T = new_set()

T["name-status: modified file"] = function()
    local entry = git.parse_name_status_line("M\tlua/init.lua")
    expect.equality(entry.status, "modified")
    expect.equality(entry.path, "lua/init.lua")
    expect.equality(entry.rename_from, nil)
end

T["name-status: added and deleted"] = function()
    expect.equality(git.parse_name_status_line("A\tnew.txt").status, "added")
    expect.equality(git.parse_name_status_line("D\tgone.txt").status, "deleted")
end

T["name-status: conflicted file"] = function()
    local entry = git.parse_name_status_line("U\tconflict.txt")
    expect.equality(entry.status, "conflicted")
    expect.equality(entry.path, "conflict.txt")
end

T["name-status: rename with spaces in both paths"] = function()
    local entry = git.parse_name_status_line("R100\told name.txt\tnew name.txt")
    expect.equality(entry.status, "renamed")
    expect.equality(entry.path, "new name.txt")
    expect.equality(entry.rename_from, "old name.txt")
end

T["name-status: copy is not treated as modified"] = function()
    local entry = git.parse_name_status_line("C75\tsrc.txt\tdst.txt")
    expect.equality(entry.status, "copied")
    expect.equality(entry.path, "dst.txt")
    expect.equality(entry.rename_from, "src.txt")
end

T["name-status: path containing spaces stays intact"] = function()
    local entry = git.parse_name_status_line("M\tfile with spaces.txt")
    expect.equality(entry.path, "file with spaces.txt")
end

T["name-status: non-ascii path"] = function()
    local entry = git.parse_name_status_line("M\tä-ünïcode.txt")
    expect.equality(entry.path, "ä-ünïcode.txt")
end

T["name-status: empty and malformed input"] = function()
    expect.equality(git.parse_name_status_line(""), nil)
    expect.equality(git.parse_name_status_line("garbage"), nil)
end

local UNIT = "\31"

local function commit_line(fields)
    return table.concat(fields, UNIT)
end

T["commit line: basic fields"] = function()
    local commit = git.parse_commit_line(commit_line({
        "abc123def",
        "abc123d",
        "fix: something",
        "Ada Lovelace",
        "2 days ago",
        "parent1",
    }))
    expect.equality(commit.hash, "abc123def")
    expect.equality(commit.short_hash, "abc123d")
    expect.equality(commit.subject, "fix: something")
    expect.equality(commit.author, "Ada Lovelace")
    expect.equality(commit.date, "2 days ago")
    expect.equality(commit.parent_count, 1)
    expect.equality(commit.is_merge, false)
end

T["commit line: subject containing a pipe does not shift fields"] = function()
    local commit = git.parse_commit_line(commit_line({
        "abc123",
        "abc",
        "fix: a | b",
        "Ada Lovelace",
        "2 days ago",
        "parent1",
    }))
    expect.equality(commit.subject, "fix: a | b")
    expect.equality(commit.author, "Ada Lovelace")
    expect.equality(commit.date, "2 days ago")
    expect.equality(commit.parent_count, 1)
    expect.equality(commit.is_merge, false)
end

T["commit line: merge commit"] = function()
    local commit = git.parse_commit_line(commit_line({
        "h",
        "s",
        "Merge branch 'x'",
        "Ada",
        "now",
        "parent1 parent2",
    }))
    expect.equality(commit.parent_count, 2)
    expect.equality(commit.is_merge, true)
end

T["commit line: root commit has no parents"] = function()
    local commit = git.parse_commit_line(commit_line({ "h", "s", "init", "Ada", "now", "" }))
    expect.equality(commit.parent_count, 0)
    expect.equality(commit.is_merge, false)
end

T["commit line: empty and malformed input"] = function()
    expect.equality(git.parse_commit_line(""), nil)
    expect.equality(git.parse_commit_line("no separators here"), nil)
end

return T
