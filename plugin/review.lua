-- Prevent loading twice
if vim.g.loaded_review then
    return
end
vim.g.loaded_review = true

-- Check Neovim version
if vim.fn.has("nvim-0.10") ~= 1 then
    vim.notify("review.nvim requires Neovim 0.10 or later", vim.log.levels.ERROR)
    return
end

require("review.commands").setup()

require("review.core.persistence").setup_autosave()
