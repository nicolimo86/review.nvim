local M = {}

local did_setup = false

---Set up user commands
function M.setup()
    if did_setup then
        return
    end
    did_setup = true

    vim.api.nvim_create_user_command("Review", function(opts)
        local args = opts.fargs
        local subcommand = args[1]

        local ui = require("review.ui")
        local state = require("review.state")
        local export = require("review.export.markdown")

        if not subcommand or subcommand == "" then
            -- Toggle review UI
            ui.toggle()
        elseif subcommand == "close" then
            ui.close()
        elseif subcommand == "export" then
            export.to_clipboard()
        elseif subcommand == "send" then
            local target = args[2] -- Optional custom target
            export.to_tmux(target)
        elseif subcommand == "commit" then
            local sha = args[2]
            if sha and not require("review.core.git").is_safe_rev(sha) then
                vim.notify("Invalid revision: " .. sha, vim.log.levels.ERROR)
            elseif sha then
                local was_open = ui.is_open()
                if was_open then
                    ui.close()
                end
                state.state.base = sha
                state.state.base_end = nil
                vim.notify("Comparing against: " .. sha, vim.log.levels.INFO)
                if was_open then
                    ui.open()
                end
            else
                vim.notify("Usage: :Review commit <sha>", vim.log.levels.WARN)
            end
        elseif subcommand == "pick" then
            local count = args[2] and tonumber(args[2]) or 20
            ui.pick_commit(count)
        elseif subcommand == "qc" then
            local quick_comments = require("review.quick_comments")
            quick_comments.add()
        elseif subcommand == "qp" then
            local quick_comments = require("review.quick_comments")
            quick_comments.toggle_panel()
        elseif subcommand == "log" then
            local log = require("review.core.log")
            vim.cmd("tabedit " .. vim.fn.fnameescape(log.get_log_path()))
        else
            vim.notify("Unknown subcommand: " .. subcommand, vim.log.levels.ERROR)
        end
    end, {
        nargs = "*",
        complete = function(arg_lead, cmdline, _)
            local parts = vim.split(cmdline, "%s+")
            if #parts == 2 then
                return vim.tbl_filter(function(item)
                    return vim.startswith(item, arg_lead)
                end, { "close", "commit", "export", "log", "pick", "qc", "qp", "send" })
            end
            return {}
        end,
        desc = "Review AI-generated code changes",
    })
end

return M
