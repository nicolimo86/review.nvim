local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
vim.opt.rtp:prepend(root)
vim.opt.rtp:prepend(root .. "/.deps/mini.nvim")

local clipboard_store = { ["+"] = { { "" }, "v" }, ["*"] = { { "" }, "v" } }
local function clipboard_copy(name)
    return function(lines, regtype)
        clipboard_store[name] = { lines, regtype }
    end
end
local function clipboard_paste(name)
    return function()
        return clipboard_store[name][1], clipboard_store[name][2]
    end
end

vim.g.clipboard = {
    name = "test-clipboard",
    copy = { ["+"] = clipboard_copy("+"), ["*"] = clipboard_copy("*") },
    paste = { ["+"] = clipboard_paste("+"), ["*"] = clipboard_paste("*") },
    cache_enabled = 0,
}

require("mini.test").setup()
