local palette = require("review.ui.palette")

local M = {}

local LINKS = {
    ReviewDiffAdd = "DiffAdd",
    ReviewDiffDelete = "DiffDelete",
    ReviewDiffChange = "DiffChange",
    ReviewDiffText = "DiffText",
    ReviewDiffPadding = "NonText",
    ReviewSelected = "Visual",
    ReviewActiveRow = "CursorLine",
    ReviewDiffCursorLine = "CursorLine",
    ReviewCommentNote = "DiagnosticInfo",
    ReviewCommentFix = "DiagnosticError",
    ReviewCommentQuestion = "DiagnosticWarn",
    ReviewCommentText = "Normal",
    ReviewGitAdded = "Added",
    ReviewGitModified = "Changed",
    ReviewGitDeleted = "Removed",
    ReviewFloatBorder = "FloatBorder",
    ReviewFloatTitle = "FloatTitle",
    ReviewWinSeparator = "WinSeparator",
    ReviewTitle = "Title",
    ReviewFilePath = "Normal",
    ReviewFilePathFaded = "Comment",
    ReviewFileFaded = "Comment",
    ReviewTreeDirectory = "Directory",
    ReviewCommentListEmpty = "Comment",
    ReviewQCPanelContext = "Comment",
}

function M.setup()
    local highlights = {

        ReviewDiffAddInline = { bg = palette.diff_add_emphasis },
        ReviewDiffDeleteInline = { bg = palette.diff_delete_emphasis },

        ReviewDiffSignAdd = { fg = palette.positive, bold = true },
        ReviewDiffSignDelete = { fg = palette.negative, bold = true },
        ReviewDiffSignContext = { fg = palette.border },

        ReviewDiffFilePath = { fg = palette.text, bold = true },
        ReviewDiffFileHeaderBg = { bg = palette.header },
        ReviewDiffFileDivider = { fg = palette.text, bg = palette.header, bold = true },
        ReviewDiffFileDividerBorderTop = { fg = palette.border_accent },
        ReviewDiffFileDividerBorderBottom = { fg = palette.border_accent },

        ReviewDiffHeader = { fg = palette.special, bg = palette.tint, bold = true },
        ReviewDiffHunkHeader = { fg = palette.accent, bg = palette.header, italic = true },

        ReviewCommentBorder = { fg = palette.muted },
        ReviewCommentBorderFocusNote = { fg = palette.accent },
        ReviewCommentBorderFocusFix = { fg = palette.negative },
        ReviewCommentBorderFocusQuestion = { fg = palette.highlight },

        ReviewFileReviewed = { fg = palette.positive },
        ReviewFileModified = { fg = palette.caution },
        ReviewFilePending = { fg = palette.text },
        ReviewTreeIndent = { fg = palette.border },
        ReviewLogo = { fg = palette.accent, bold = true },

        ReviewInputBorder = { fg = palette.text },
        ReviewInputTitle = { fg = palette.text, bold = true },
        ReviewInputFooter = { fg = palette.muted },

        ReviewInputBorderFix = { fg = palette.negative },
        ReviewInputTitleFix = { fg = palette.negative, bold = true },
        ReviewInputBorderNote = { fg = palette.accent },
        ReviewInputTitleNote = { fg = palette.accent, bold = true },
        ReviewInputBorderQuestion = { fg = palette.highlight },
        ReviewInputTitleQuestion = { fg = palette.highlight, bold = true },

        ReviewGitRenamed = { fg = palette.special },

        ReviewBranchAhead = { fg = palette.caution },
        ReviewBranchBehind = { fg = palette.caution },
        ReviewBranchSpinner = { fg = palette.caution, bg = palette.selected },

        ReviewFloatBorderActive = { fg = palette.positive },
        ReviewFloatTitleActive = { fg = palette.positive, bold = true },

        ReviewBorder = { fg = palette.border },
        ReviewWinBar = { fg = palette.text, bold = true, bg = "NONE" },
        ReviewWinBarCount = { fg = palette.faded, bg = "NONE" },
        ReviewHelpGroup = { fg = palette.text, bg = palette.surface, bold = true },
        ReviewHelpKey = { fg = palette.highlight },

        ReviewLineNrAdd = { fg = palette.positive },
        ReviewLineNrDelete = { fg = palette.negative },
        ReviewLineNrContext = { fg = palette.muted },

        ReviewFooterText = { fg = palette.muted },
        ReviewFooterCount = { fg = palette.accent },

        ReviewQCPanelHeader = { fg = palette.accent, bold = true },
        ReviewQCPanelBorder = { fg = palette.border },
        ReviewQCPanelFile = { fg = palette.text, bold = true },
        ReviewQCPanelLineNr = { fg = palette.muted },

        ReviewCommentListFile = { fg = palette.text },

        ReviewTemplateKey = { fg = palette.highlight, bold = true },
        ReviewTemplateLabel = { fg = palette.text },
        ReviewTemplateBorder = { fg = palette.muted },
        ReviewTemplateTitle = { fg = palette.accent, bold = true },

        ReviewSelectItem = { fg = palette.accent, bold = true },
        ReviewSelectHint = { fg = palette.muted },

        ReviewCommitHash = { fg = palette.highlight },
        ReviewCommitAuthor = { fg = palette.accent },
        ReviewCommitAuthor1 = { fg = palette.author1 },
        ReviewCommitAuthor2 = { fg = palette.author2 },
        ReviewCommitAuthor3 = { fg = palette.author3 },
        ReviewCommitAuthor4 = { fg = palette.author4 },
        ReviewCommitAuthor5 = { fg = palette.author5 },
        ReviewCommitAuthor6 = { fg = palette.author6 },
        ReviewCommitDate = { fg = palette.faded },
        ReviewCommitActive = { fg = palette.positive, bold = true },
        ReviewCommitSeparator = { fg = palette.border },
        ReviewCommitGraph = { fg = palette.special },
        ReviewCommitGraphActive = { fg = palette.positive, bold = true },
        ReviewCommitPushed = { fg = palette.positive },
        ReviewCommitUnpushed = { fg = palette.negative },
        ReviewCommitIconRegular = { fg = palette.text },
        ReviewCommitIconMerge = { fg = palette.special },
        ReviewCommitIconRoot = { fg = palette.highlight },

        ReviewBranchName = { fg = palette.text },
        ReviewBranchMain = { fg = palette.positive },
        ReviewBranchHead = { fg = palette.accent },
        ReviewBranchActive = { fg = palette.positive, bold = true },
        ReviewBranchCurrent = { fg = palette.special },
        ReviewBranchCurrentRow = { bg = palette.tint },
        ReviewBranchSeparator = { fg = palette.border },
        ReviewHeadLabel = { fg = palette.highlight, bold = true },
    }

    for name, opts in pairs(highlights) do
        opts.default = true
        vim.api.nvim_set_hl(0, name, opts)
    end

    for name, target in pairs(LINKS) do
        vim.api.nvim_set_hl(0, name, { link = target, default = true })
    end
end

vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("ReviewHighlights", { clear = true }),
    callback = function()
        M.setup()
    end,
})

return M
