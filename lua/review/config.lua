---@class ReviewConfig
---@field keymaps ReviewKeymaps
---@field diff ReviewDiffConfig
---@field ui ReviewUIConfig
---@field navigation ReviewNavigationConfig
---@field tmux ReviewTmuxConfig
---@field quick_comments ReviewQuickCommentsConfig
---@field export ReviewExportConfig
---@field auto_refresh ReviewAutoRefreshConfig
---@field persistence ReviewPersistenceConfig
---@field gitlab ReviewGitlabConfig
---@field templates ReviewTemplate[]
---@field log_level string Log level: DEBUG, INFO, WARN, ERROR
---@field log_file string|nil Override the log file path (defaults to a file under the system temp dir)

---@class ReviewKeymaps
---@field toggle string

---@class ReviewDiffConfig
---@field base string Default base for diff comparison

---@class ReviewUIConfig
---@field file_tree_width number Width of file tree panel (percentage)
---@field diff_view_mode "unified"|"split" Default diff view mode

---@class ReviewNavigationConfig
---@field passthrough boolean When true, boundary C-h/j/k/l keys are not captured, letting global keymaps (e.g. vim-tmux-navigator) handle them

---@class ReviewTmuxConfig
---@field target string Target window/pane (e.g., "!" for last active pane, or a window name)
---@field auto_enter boolean Whether to send Enter key after pasting

---@class ReviewQuickCommentsConfig
---@field keymaps ReviewQuickCommentsKeymaps
---@field panel ReviewQuickCommentsPanelConfig
---@field signs ReviewQuickCommentsSignsConfig

---@class ReviewQuickCommentsKeymaps
---@field add string|nil Keymap to add a quick comment
---@field toggle_panel string|nil Keymap to toggle the quick comments panel

---@class ReviewQuickCommentsPanelConfig
---@field width number Panel width in columns
---@field position "left"|"right" Panel position

---@class ReviewQuickCommentsSignsConfig
---@field enabled boolean Whether to show gutter signs

---@class ReviewExportConfig
---@field context_lines number Number of context lines to include around commented line

---@class ReviewAutoRefreshConfig
---@field enabled boolean Whether to auto-refresh on file changes
---@field debounce_ms number Debounce interval in milliseconds

---@class ReviewPersistenceConfig
---@field enabled boolean Whether to persist review sessions

---@class ReviewGitlabConfig
---@field preamble string Preamble template prepended to comments in gitlab mode. {branch} is replaced with the target branch name.

---@class ReviewTemplate
---@field key string Single character shortcut key
---@field label string Display label
---@field text string Template text to insert

local M = {}

---@type ReviewConfig
M.defaults = {
    keymaps = {
        toggle = nil,
    },
    diff = {
        base = "HEAD", -- Compare against HEAD (unstaged changes)
    },
    ui = {
        file_tree_width = 33,
        diff_view_mode = "unified",
    },
    navigation = {
        passthrough = true,
    },
    tmux = {
        target = "!",
        auto_enter = false,
    },
    quick_comments = {
        keymaps = {
            add = nil,
            toggle_panel = nil,
        },
        panel = {
            width = 65,
            position = "right",
        },
        signs = {
            enabled = true,
        },
    },
    export = {
        context_lines = 3,
    },
    auto_refresh = {
        enabled = true,
        debounce_ms = 500,
    },
    persistence = {
        enabled = true,
    },
    gitlab = {
        preamble = "Post the following comments as discussions on the GitLab MR for branch `{branch}`. Each ### section is a separate discussion thread positioned on the file and line from its heading.\n\n",
    },
    log_level = "WARN",
    log_file = nil,
    templates = {
        { key = "e", label = "Extract", text = "Extract this into a separate function/component" },
        { key = "r", label = "Rename", text = "Rename to: " },
        { key = "m", label = "Move", text = "Move this to a separate file" },
        { key = "t", label = "Types", text = "Add proper types" },
        { key = "h", label = "Error handling", text = "Add error handling" },
        { key = "p", label = "Performance", text = "Performance concern: " },
        { key = "s", label = "Simplify", text = "Simplify this" },
        { key = "d", label = "Delete", text = "Remove this" },
    },
}

---@type ReviewConfig
M.options = vim.deepcopy(M.defaults)

M.did_setup = false

---@param opts? ReviewConfig
function M.setup(opts)
    if opts ~= nil and type(opts) ~= "table" then
        vim.notify("review.nvim: setup() expects a table, got " .. type(opts), vim.log.levels.ERROR)
        opts = nil
    end
    M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
    M.did_setup = true
end

---@return ReviewConfig
function M.get()
    return M.options
end

return M
