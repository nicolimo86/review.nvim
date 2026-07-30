local config = require("review.config")
local log = require("review.core.log")

local M = {}

---@class ReviewLayoutComponent
---@field bufnr number
---@field winid number

---@class ReviewLayout
---@field branch_info ReviewLayoutComponent
---@field file_tree ReviewLayoutComponent
---@field commit_list ReviewLayoutComponent
---@field branch_list ReviewLayoutComponent
---@field comment_list ReviewLayoutComponent
---@field diff_view ReviewLayoutComponent
---@field diff_view_old ReviewLayoutComponent|nil
---@field diff_view_new ReviewLayoutComponent|nil

---@type ReviewLayout|nil
M.current = nil

---@type number|nil
M.prev_tab = nil

---@type number|nil
M.review_tab = nil

---@type number|nil
M.base_winid = nil

---@type number|nil
M.pad_winid = nil

---@type number|nil
M.pad_bufnr = nil

---@type number|nil
local resize_autocmd_id = nil

---@class SidebarPanelDef
---@field name string Key in ReviewLayout
---@field title string Display title for float border
---@field filetype string Buffer filetype
---@field is_interactive boolean Whether this panel gets cursorline/active highlight
---@field height_weight number|nil Weight for height calculation (default 1.0)

local SIDEBAR_PANELS = {
    { name = "branch_info", title = "Branch", filetype = "review-branch-info", is_interactive = false },
    { name = "file_tree", title = "Files", filetype = "review-tree", is_interactive = true },
    { name = "branch_list", title = "Branches", filetype = "review-branches", is_interactive = true },
    { name = "commit_list", title = "Commits", filetype = "review-commits", is_interactive = true },
    {
        name = "comment_list",
        title = "Comments",
        filetype = "review-comments",
        is_interactive = true,
        height_weight = 0.5,
    },
}

local PANEL_MODULES = {
    branch_list = "review.ui.branch_list",
    commit_list = "review.ui.commit_list",
    comment_list = "review.ui.comment_list",
}

local INTERACTIVE_SIDEBAR_PANELS = {}
for _, panel in ipairs(SIDEBAR_PANELS) do
    if panel.is_interactive then
        table.insert(INTERACTIVE_SIDEBAR_PANELS, panel)
    end
end

local SIDEBAR_PANEL_COUNT = #INTERACTIVE_SIDEBAR_PANELS
local BRANCH_INFO_HEIGHT = 1
local BRANCH_INFO_OUTER_HEIGHT = BRANCH_INFO_HEIGHT + 2
local SIDEBAR_BORDER_ROWS = (SIDEBAR_PANEL_COUNT + 1) * 2

---@type number|nil
local focus_autocmd_id = nil
local tab_closed_autocmd_id = nil

local INACTIVE_WINHIGHLIGHT = "NormalFloat:Normal,FloatBorder:ReviewFloatBorder,FloatTitle:ReviewFloatTitle"
local ACTIVE_SIDEBAR_WINHIGHLIGHT = "NormalFloat:Normal,FloatBorder:ReviewFloatBorderActive,"
    .. "FloatTitle:ReviewFloatTitleActive,CursorLine:ReviewSelected"
local ACTIVE_DIFF_WINHIGHLIGHT = "NormalFloat:Normal,FloatBorder:ReviewFloatBorderActive,"
    .. "FloatTitle:ReviewFloatTitleActive,CursorLine:ReviewDiffCursorLine"

---Update border highlights based on the currently focused window
local function update_border_highlights()
    if not M.current then
        return
    end
    local current_win = vim.api.nvim_get_current_win()
    for _, panel_def in ipairs(INTERACTIVE_SIDEBAR_PANELS) do
        local component = M.current[panel_def.name]
        if component and vim.api.nvim_win_is_valid(component.winid) then
            if component.winid == current_win then
                vim.api.nvim_set_option_value("winhighlight", ACTIVE_SIDEBAR_WINHIGHLIGHT, { win = component.winid })
                vim.api.nvim_set_option_value("cursorline", true, { win = component.winid })
            else
                local base = INACTIVE_WINHIGHLIGHT .. ",CursorLine:ReviewSelected"
                vim.api.nvim_set_option_value("winhighlight", base, { win = component.winid })
                vim.api.nvim_set_option_value("cursorline", false, { win = component.winid })
            end
        end
    end
    local branch_info = M.current.branch_info
    if branch_info and vim.api.nvim_win_is_valid(branch_info.winid) then
        vim.api.nvim_set_option_value("winhighlight", INACTIVE_WINHIGHLIGHT, { win = branch_info.winid })
        vim.api.nvim_set_option_value("cursorline", false, { win = branch_info.winid })
    end
    local diff_panels = { M.current.diff_view, M.current.diff_view_old, M.current.diff_view_new }
    for _, component in ipairs(diff_panels) do
        if component and vim.api.nvim_win_is_valid(component.winid) then
            if component.winid == current_win then
                vim.api.nvim_set_option_value("winhighlight", ACTIVE_DIFF_WINHIGHLIGHT, { win = component.winid })
            else
                vim.api.nvim_set_option_value("winhighlight", INACTIVE_WINHIGHLIGHT, { win = component.winid })
                vim.api.nvim_set_option_value("cursorline", false, { win = component.winid })
            end
        end
    end
end

---Calculate floating window positions for all panes
---@param sidebar_visible boolean
---@return table positions
local function calculate_positions(sidebar_visible)
    local columns = vim.o.columns
    local lines = vim.o.lines
    local total_height = lines - 2

    local opts = config.get()
    local sidebar_content_width = math.floor(columns * opts.ui.file_tree_width / 100)

    local positions = {}

    if sidebar_visible then
        local sidebar_outer_width = sidebar_content_width + 2
        local diff_content_width = columns - sidebar_outer_width - 2
        local diff_col = sidebar_outer_width

        local available_content = total_height - SIDEBAR_BORDER_ROWS - BRANCH_INFO_HEIGHT

        local total_weight = 0
        for _, panel in ipairs(INTERACTIVE_SIDEBAR_PANELS) do
            total_weight = total_weight + (panel.height_weight or 1.0)
        end

        local panel_heights = {}
        local allocated = 0
        for panel_index, panel in ipairs(INTERACTIVE_SIDEBAR_PANELS) do
            local weight = panel.height_weight or 1.0
            local height
            if panel_index == 1 then
                local base = math.floor(available_content * weight / total_weight)
                height = base
            else
                height = math.floor(available_content * weight / total_weight)
            end
            panel_heights[panel.name] = height
            allocated = allocated + height
        end

        local remainder = available_content - allocated
        if remainder > 0 then
            panel_heights[INTERACTIVE_SIDEBAR_PANELS[1].name] = panel_heights[INTERACTIVE_SIDEBAR_PANELS[1].name]
                + remainder
        end

        positions.branch_info = {
            row = 0,
            col = 0,
            width = sidebar_content_width,
            height = BRANCH_INFO_HEIGHT,
        }

        local current_row = BRANCH_INFO_OUTER_HEIGHT
        for _, panel in ipairs(INTERACTIVE_SIDEBAR_PANELS) do
            local height = panel_heights[panel.name]
            positions[panel.name] = {
                row = current_row,
                col = 0,
                width = sidebar_content_width,
                height = height,
            }
            current_row = current_row + height + 2
        end

        positions.diff_view = {
            row = 0,
            col = diff_col,
            width = diff_content_width,
            height = total_height - 2,
        }
    else
        positions.diff_view = {
            row = 0,
            col = 0,
            width = columns - 2,
            height = total_height - 2,
        }
    end

    return positions
end

---Apply file tree window options
---@param winid number
local function apply_tree_win_options(winid)
    vim.api.nvim_set_option_value("number", false, { win = winid })
    vim.api.nvim_set_option_value("relativenumber", false, { win = winid })
    vim.api.nvim_set_option_value("cursorline", true, { win = winid })
    vim.api.nvim_set_option_value("signcolumn", "no", { win = winid })
    vim.api.nvim_set_option_value("wrap", false, { win = winid })
    vim.api.nvim_set_option_value("scrollbind", false, { win = winid })
    vim.api.nvim_set_option_value("cursorbind", false, { win = winid })
    vim.api.nvim_set_option_value(
        "winhighlight",
        INACTIVE_WINHIGHLIGHT .. ",CursorLine:ReviewSelected",
        { win = winid }
    )
end

---Apply diff view window options
---@param winid number
local function apply_diff_win_options(winid)
    vim.api.nvim_set_option_value("number", true, { win = winid })
    vim.api.nvim_set_option_value("relativenumber", false, { win = winid })
    vim.api.nvim_set_option_value("cursorline", false, { win = winid })
    vim.api.nvim_set_option_value("signcolumn", "yes", { win = winid })
    vim.api.nvim_set_option_value("wrap", false, { win = winid })
    vim.api.nvim_set_option_value("scrollbind", false, { win = winid })
    vim.api.nvim_set_option_value("cursorbind", false, { win = winid })
    vim.api.nvim_set_option_value(
        "winhighlight",
        INACTIVE_WINHIGHLIGHT .. ",WinSeparator:Normal",
        { win = winid }
    )
end

---Create a scratch buffer with the given filetype
---@param filetype string
---@return number bufnr
local function create_panel_buffer(filetype)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
    vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
    vim.api.nvim_set_option_value("filetype", filetype, { buf = bufnr })
    vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
    vim.api.nvim_set_option_value("readonly", false, { buf = bufnr })
    return bufnr
end

---Open a floating window
---@param bufnr number
---@param pos table {row, col, width, height}
---@param title string|nil
---@return number winid
local function open_float(bufnr, pos, title)
    local float_opts = {
        relative = "editor",
        row = pos.row,
        col = pos.col,
        width = math.max(pos.width, 1),
        height = math.max(pos.height, 1),
        border = "rounded",
        style = "minimal",
        focusable = true,
    }
    if title then
        float_opts.title = " " .. title .. " "
        float_opts.title_pos = "left"
    end
    return vim.api.nvim_open_win(bufnr, false, float_opts)
end

---Create the main layout with floating windows in a new tab
---@return ReviewLayout
function M.create()
    log.info("layout: creating")
    M.prev_tab = vim.api.nvim_get_current_tabpage()

    vim.cmd("tabnew")
    M.review_tab = vim.api.nvim_get_current_tabpage()

    -- The base window becomes the diff pane (a normal window, no compositor overhead).
    -- We create a left padding split that the sidebar floats sit on top of.
    local diff_buf = create_panel_buffer("review-diff")
    local base_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(base_win, diff_buf)

    local opts = config.get()
    local sidebar_content_width = math.floor(vim.o.columns * opts.ui.file_tree_width / 100)
    local sidebar_outer_width = sidebar_content_width + 2

    -- Create a left padding split for the sidebar to float over
    vim.cmd("topleft " .. sidebar_outer_width .. "vsplit")
    local pad_win = vim.api.nvim_get_current_win()
    local pad_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(pad_win, pad_buf)
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = pad_buf })
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = pad_buf })
    vim.api.nvim_set_option_value("buflisted", false, { buf = pad_buf })
    vim.api.nvim_set_option_value("swapfile", false, { buf = pad_buf })
    vim.api.nvim_set_option_value("number", false, { win = pad_win })
    vim.api.nvim_set_option_value("relativenumber", false, { win = pad_win })
    vim.api.nvim_set_option_value("signcolumn", "no", { win = pad_win })
    vim.api.nvim_set_option_value("cursorline", false, { win = pad_win })
    vim.api.nvim_set_option_value("winfixwidth", true, { win = pad_win })
    vim.api.nvim_set_option_value("winhighlight", "Normal:Normal,EndOfBuffer:Normal,WinSeparator:Normal", { win = pad_win })
    vim.api.nvim_set_option_value("fillchars", "eob: ,vert: ", { win = pad_win })

    -- Focus back on the diff (right) window
    vim.api.nvim_set_current_win(base_win)
    M.base_winid = base_win
    M.pad_winid = pad_win
    M.pad_bufnr = pad_buf

    apply_diff_win_options(base_win)

    -- Set window-local cwd to git root so plugins calling getcwd(winid) work
    local git = require("review.core.git")
    local git_root = git.get_root()
    if git_root then
        vim.api.nvim_win_call(base_win, function()
            vim.cmd("lcd " .. vim.fn.fnameescape(git_root))
        end)
    end

    -- Ensure this window is recognized as most-recently-visited by sidekick.nvim
    vim.w[base_win].sidekick_visit = vim.uv.hrtime()

    local positions = calculate_positions(true)

    M.current = {}

    for _, panel_def in ipairs(SIDEBAR_PANELS) do
        local bufnr = create_panel_buffer(panel_def.filetype)
        local winid = open_float(bufnr, positions[panel_def.name], " " .. panel_def.title)
        apply_tree_win_options(winid)
        if not panel_def.is_interactive then
            vim.api.nvim_set_option_value("cursorline", false, { win = winid })
        end
        M.current[panel_def.name] = { bufnr = bufnr, winid = winid }
    end

    M.current.diff_view = { bufnr = diff_buf, winid = base_win }

    resize_autocmd_id = vim.api.nvim_create_autocmd("VimResized", {
        callback = function()
            M.reposition()
        end,
    })

    tab_closed_autocmd_id = vim.api.nvim_create_autocmd("TabClosed", {
        callback = function()
            if not M.current then
                return
            end
            if M.base_winid and vim.api.nvim_win_is_valid(M.base_winid) then
                return
            end
            log.info("layout: review tab closed externally, tearing down")
            vim.schedule(function()
                require("review.ui").close()
            end)
        end,
    })

    focus_autocmd_id = vim.api.nvim_create_autocmd("WinEnter", {
        callback = function()
            M.bounce_from_passive_window()
            if M.current and M.is_layout_window(vim.api.nvim_get_current_win()) then
                update_border_highlights()
            end
        end,
    })

    return M.current
end

---Reposition diff windows (unified or split) to fill the given area.
---The diff pane is a normal window; resizing is done via the padding split width.
---@param diff_pos table {row, col, width, height}
local function reposition_diff_windows(diff_pos)
    -- Resize the padding window to match the sidebar width
    if M.pad_winid and vim.api.nvim_win_is_valid(M.pad_winid) then
        vim.api.nvim_win_set_width(M.pad_winid, math.max(diff_pos.col, 1))
    end

    if M.is_split_mode() then
        local old_component = M.current.diff_view_old
        local new_component = M.current.diff_view_new
        -- In split mode, old and new are real vsplits; just balance widths
        if old_component and vim.api.nvim_win_is_valid(old_component.winid) then
            local half_width = math.floor(diff_pos.width / 2)
            vim.api.nvim_win_set_width(old_component.winid, math.max(half_width, 1))
        end
        -- The new component gets the remainder automatically
    end
end

---Reposition all layout windows after a resize
function M.reposition()
    if not M.current then
        return
    end

    local sidebar_visible = M.is_file_tree_visible()
    local positions = calculate_positions(sidebar_visible)
    log.debug("layout: reposition", vim.o.columns .. "x" .. vim.o.lines, "sidebar=" .. tostring(sidebar_visible))

    if sidebar_visible then
        for _, panel_def in ipairs(SIDEBAR_PANELS) do
            local component = M.current[panel_def.name]
            local pos = positions[panel_def.name]
            if component and pos and vim.api.nvim_win_is_valid(component.winid) then
                vim.api.nvim_win_set_config(component.winid, {
                    relative = "editor",
                    row = pos.row,
                    col = pos.col,
                    width = math.max(pos.width, 1),
                    height = math.max(pos.height, 1),
                    title = " " .. panel_def.title .. " ",
                    title_pos = "left",
                })
            end
        end
    end

    reposition_diff_windows(positions.diff_view)
end

---Check if a window is part of the layout but has no keymaps to escape from
---@param winid number
---@return boolean
function M.is_passive_window(winid)
    if winid == M.pad_winid then
        return true
    end
    local branch_info = M.current and M.current.branch_info
    return branch_info ~= nil and branch_info.winid == winid
end

---Move focus off a passive layout window onto the next usable one
function M.bounce_from_passive_window()
    if not M.current then
        return
    end

    local current = vim.api.nvim_get_current_win()
    if not M.is_passive_window(current) then
        return
    end

    local wins = vim.api.nvim_tabpage_list_wins(0)
    local start_index = 1
    for index, winid in ipairs(wins) do
        if winid == current then
            start_index = index
            break
        end
    end

    for offset = 1, #wins do
        local candidate = wins[((start_index - 1 + offset) % #wins) + 1]
        if
            not M.is_passive_window(candidate)
            and vim.api.nvim_win_is_valid(candidate)
            and M.is_layout_window(candidate)
        then
            log.debug("layout: bouncing focus off passive window", current, "to", candidate)
            vim.api.nvim_set_current_win(candidate)
            return
        end
    end
end

---Check if a window belongs to the layout
---@param winid number
---@return boolean
function M.is_layout_window(winid)
    if winid == M.base_winid then
        return true
    end
    if winid == M.pad_winid then
        return true
    end
    if not M.current then
        return false
    end
    local component_names = { "diff_view", "diff_view_old", "diff_view_new" }
    for _, panel_def in ipairs(SIDEBAR_PANELS) do
        table.insert(component_names, panel_def.name)
    end
    for _, name in ipairs(component_names) do
        local component = M.current[name]
        if component and component.winid == winid then
            return true
        end
    end
    return false
end

---Check if file tree is currently visible
---@return boolean
function M.is_file_tree_visible()
    if not M.current then
        return false
    end
    return vim.api.nvim_win_is_valid(M.current.file_tree.winid)
end

---Hide the file tree panel (and commit list and branch list)
function M.hide_file_tree()
    if not M.current then
        return
    end

    local focus_win = M.current.diff_view.winid
    if M.is_split_mode() then
        local new_component = M.current.diff_view_new
        if new_component and vim.api.nvim_win_is_valid(new_component.winid) then
            focus_win = new_component.winid
        end
    end
    if vim.api.nvim_win_is_valid(focus_win) then
        vim.api.nvim_set_current_win(focus_win)
    end

    for _, panel_def in ipairs(SIDEBAR_PANELS) do
        local name = panel_def.name
        local component = M.current[name]
        if component and vim.api.nvim_win_is_valid(component.winid) then
            vim.api.nvim_win_close(component.winid, true)
        end
    end

    -- Hide the padding window (set width to 1, minimum)
    if M.pad_winid and vim.api.nvim_win_is_valid(M.pad_winid) then
        vim.api.nvim_win_set_width(M.pad_winid, 1)
    end
end

---Show the file tree panel (re-open the windows with existing buffers)
function M.show_file_tree()
    if not M.current then
        return
    end

    local tree = M.current.file_tree
    if vim.api.nvim_win_is_valid(tree.winid) then
        return
    end

    local positions = calculate_positions(true)

    -- Restore padding window width for sidebar
    if M.pad_winid and vim.api.nvim_win_is_valid(M.pad_winid) then
        local opts = config.get()
        local sidebar_content_width = math.floor(vim.o.columns * opts.ui.file_tree_width / 100)
        local sidebar_outer_width = sidebar_content_width + 2
        vim.api.nvim_win_set_width(M.pad_winid, sidebar_outer_width)
    end

    for _, panel_def in ipairs(SIDEBAR_PANELS) do
        local component = M.current[panel_def.name]
        local pos = positions[panel_def.name]
        if component and pos then
            local winid = open_float(component.bufnr, pos, " " .. panel_def.title)
            apply_tree_win_options(winid)
            if not panel_def.is_interactive then
                vim.api.nvim_set_option_value("cursorline", false, { win = winid })
            end
            component.winid = winid
            if panel_def.name == "file_tree" then
                require("review.ui.file_tree").set_winid(winid)
            elseif PANEL_MODULES[panel_def.name] then
                local panel_module = require(PANEL_MODULES[panel_def.name])
                if panel_module.current then
                    panel_module.current.winid = winid
                end
            end
        end
    end

    reposition_diff_windows(positions.diff_view)
end

---Toggle the file tree panel visibility
function M.toggle_file_tree()
    if M.is_file_tree_visible() then
        M.hide_file_tree()
    else
        M.show_file_tree()
    end
end

---Enter split (side-by-side) diff mode
function M.enter_split_mode()
    if not M.current then
        return
    end

    if M.is_split_mode() then
        return
    end

    local stale_old = M.current.diff_view_old
    if stale_old then
        M.current.diff_view_old = nil
        M.current.diff_view_new = nil
        vim.schedule(function()
            if vim.api.nvim_buf_is_valid(stale_old.bufnr) then
                vim.api.nvim_buf_delete(stale_old.bufnr, { force = true })
            end
        end)
    end

    -- The base window (diff_view) becomes the "new" pane.
    -- Create a vertical split to the left of it for the "old" pane.
    local diff_win = M.current.diff_view.winid
    local prev_win = vim.api.nvim_get_current_win()

    -- Focus the diff window and split left for the old pane
    vim.api.nvim_set_current_win(diff_win)

    local old_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = old_buf })
    vim.api.nvim_set_option_value("swapfile", false, { buf = old_buf })
    vim.api.nvim_set_option_value("modifiable", true, { buf = old_buf })
    vim.api.nvim_set_option_value("readonly", false, { buf = old_buf })

    vim.cmd("leftabove vsplit")
    local old_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(old_win, old_buf)
    apply_diff_win_options(old_win)

    -- The original diff_win is now the "new" pane (right side)
    local new_win = diff_win
    apply_diff_win_options(new_win)

    -- Balance the widths
    local sidebar_visible = M.is_file_tree_visible()
    local positions = calculate_positions(sidebar_visible)
    local diff_pos = positions.diff_view
    local half_width = math.floor(diff_pos.width / 2)
    vim.api.nvim_win_set_width(old_win, math.max(half_width, 1))

    vim.api.nvim_set_option_value("scrollbind", true, { win = old_win })
    vim.api.nvim_set_option_value("cursorbind", true, { win = old_win })
    vim.api.nvim_set_option_value("scrollbind", true, { win = new_win })
    vim.api.nvim_set_option_value("cursorbind", true, { win = new_win })

    M.current.diff_view.winid = new_win
    M.current.diff_view_old = { bufnr = old_buf, winid = old_win }
    M.current.diff_view_new = { bufnr = M.current.diff_view.bufnr, winid = new_win }

    if vim.api.nvim_win_is_valid(prev_win) and prev_win ~= diff_win then
        vim.api.nvim_set_current_win(prev_win)
    else
        vim.api.nvim_set_current_win(new_win)
    end
end

---Exit split (side-by-side) diff mode
function M.exit_split_mode()
    if not M.current then
        return
    end

    if not M.is_split_mode() then
        return
    end

    local old_component = M.current.diff_view_old
    local new_component = M.current.diff_view_new

    local prev_win = vim.api.nvim_get_current_win()
    local was_focused = (old_component and prev_win == old_component.winid)
        or (new_component and prev_win == new_component.winid)

    -- Unbind scrolling on the new (base) window
    if new_component and vim.api.nvim_win_is_valid(new_component.winid) then
        vim.api.nvim_set_option_value("scrollbind", false, { win = new_component.winid })
        vim.api.nvim_set_option_value("cursorbind", false, { win = new_component.winid })
    end

    -- Close the old split window
    if old_component then
        if vim.api.nvim_win_is_valid(old_component.winid) then
            vim.api.nvim_win_close(old_component.winid, true)
        end
        vim.schedule(function()
            if vim.api.nvim_buf_is_valid(old_component.bufnr) then
                vim.api.nvim_buf_delete(old_component.bufnr, { force = true })
            end
        end)
    end

    -- The base window (M.base_winid) is still the diff view
    local diff_win = M.base_winid
    M.current.diff_view.winid = diff_win
    M.current.diff_view_old = nil
    M.current.diff_view_new = nil

    if was_focused or not vim.api.nvim_win_is_valid(prev_win) then
        vim.api.nvim_set_current_win(diff_win)
    end
end

---Check if currently in split mode
---@return boolean
function M.is_split_mode()
    if not M.current or not M.current.diff_view_old then
        return false
    end
    return vim.api.nvim_win_is_valid(M.current.diff_view_old.winid)
end

---Get the old-side diff view component
---@return ReviewLayoutComponent|nil
function M.get_diff_view_old()
    return M.current and M.current.diff_view_old
end

---Get the new-side diff view component
---@return ReviewLayoutComponent|nil
function M.get_diff_view_new()
    return M.current and M.current.diff_view_new
end

---Mount the layout (no-op, create() does everything)
function M.mount() end

---Unmount the layout
function M.unmount()
    log.info("layout: unmounting")
    if M.current then
        if M.is_split_mode() then
            M.exit_split_mode()
        end

        if resize_autocmd_id then
            vim.api.nvim_del_autocmd(resize_autocmd_id)
            resize_autocmd_id = nil
        end

        if focus_autocmd_id then
            vim.api.nvim_del_autocmd(focus_autocmd_id)
            focus_autocmd_id = nil
        end

        if tab_closed_autocmd_id then
            pcall(vim.api.nvim_del_autocmd, tab_closed_autocmd_id)
            tab_closed_autocmd_id = nil
        end

        local prev_tab = M.prev_tab
        local review_tab = M.review_tab

        -- Close sidebar float windows
        local float_wins = {}
        local panel_buffers = {}
        for _, panel_def in ipairs(SIDEBAR_PANELS) do
            local component = M.current[panel_def.name]
            if component then
                if vim.api.nvim_win_is_valid(component.winid) then
                    table.insert(float_wins, component.winid)
                end
                table.insert(panel_buffers, component.bufnr)
            end
        end

        -- Collect the diff buffer for cleanup (the window is the base_win, closed with the tab)
        local diff_component = M.current.diff_view
        if diff_component then
            table.insert(panel_buffers, diff_component.bufnr)
        end

        -- Collect the pad buffer for cleanup
        if M.pad_bufnr then
            table.insert(panel_buffers, M.pad_bufnr)
        end

        M.current = nil
        M.prev_tab = nil
        M.review_tab = nil

        for _, winid in ipairs(float_wins) do
            pcall(vim.api.nvim_win_close, winid, true)
        end

        if review_tab and vim.api.nvim_tabpage_is_valid(review_tab) then
            pcall(vim.cmd.tabclose, vim.api.nvim_tabpage_get_number(review_tab))
        end

        if prev_tab and vim.api.nvim_tabpage_is_valid(prev_tab) then
            vim.api.nvim_set_current_tabpage(prev_tab)
        end

        M.base_winid = nil
        M.pad_winid = nil
        M.pad_bufnr = nil

        vim.schedule(function()
            for _, bufnr in ipairs(panel_buffers) do
                pcall(function()
                    if vim.api.nvim_buf_is_valid(bufnr) then
                        vim.api.nvim_buf_delete(bufnr, { force = true })
                    end
                end)
            end
        end)
    end
end

---Check if layout is mounted
---@return boolean
function M.is_mounted()
    return M.current ~= nil
end

---Get a layout component by name
---@param name string
---@return ReviewLayoutComponent|nil
function M.get_component(name)
    return M.current and M.current[name]
end

---@return ReviewLayoutComponent|nil
function M.get_branch_info()
    return M.get_component("branch_info")
end

---@return ReviewLayoutComponent|nil
function M.get_file_tree()
    return M.get_component("file_tree")
end

---@return ReviewLayoutComponent|nil
function M.get_commit_list()
    return M.get_component("commit_list")
end

---@return ReviewLayoutComponent|nil
function M.get_branch_list()
    return M.get_component("branch_list")
end

---@return ReviewLayoutComponent|nil
function M.get_comment_list()
    return M.get_component("comment_list")
end

---@return ReviewLayoutComponent|nil
function M.get_diff_view()
    return M.get_component("diff_view")
end

return M
