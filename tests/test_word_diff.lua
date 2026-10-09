local new_set = MiniTest.new_set
local expect = MiniTest.expect

local word_diff = require("review.core.word_diff")

local T = new_set()

T["compute"] = new_set()

T["compute"]["returns the changed span in the new string"] = function()
    expect.equality(word_diff.compute("local x = 1", "local x = 22"), { { 10, 12 } })
end

T["compute"]["returns empty for identical strings"] = function()
    expect.equality(word_diff.compute("same", "same"), {})
end

T["compute"]["handles nil input"] = function()
    expect.equality(word_diff.compute(nil, "x"), {})
    expect.equality(word_diff.compute("x", nil), {})
end

T["compute"]["covers an insertion in the middle"] = function()
    expect.equality(word_diff.compute("foo(a)", "foo(a, b)"), { { 5, 8 } })
end

return T
