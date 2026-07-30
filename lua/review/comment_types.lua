local M = {}

M.TYPES = {
    note = {
        label = "Note",
        icon = "󰍩",
        highlight = "ReviewCommentNote",
        border_hl = "ReviewInputBorderNote",
        title_hl = "ReviewInputTitleNote",
        border_focus_hl = "ReviewCommentBorderFocusNote",
        range_hl = "ReviewCommentRangeNote",
    },
    fix = {
        label = "Fix",
        icon = "󰁨",
        highlight = "ReviewCommentFix",
        border_hl = "ReviewInputBorderFix",
        title_hl = "ReviewInputTitleFix",
        border_focus_hl = "ReviewCommentBorderFocusFix",
        range_hl = "ReviewCommentRangeFix",
    },
    question = {
        label = "Question",
        icon = "󰋗",
        highlight = "ReviewCommentQuestion",
        border_hl = "ReviewInputBorderQuestion",
        title_hl = "ReviewInputTitleQuestion",
        border_focus_hl = "ReviewCommentBorderFocusQuestion",
        range_hl = "ReviewCommentRangeQuestion",
    },
}

M.ORDER = { "fix", "note", "question" }

return M
