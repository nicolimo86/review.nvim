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
        elseif subcommand == "diff" then
            local git = require("review.core.git")
            if ui.is_open() then
                vim.notify("Review is already open. Close it first.", vim.log.levels.WARN)
                return
            end
            local branch = args[2]
            if branch then
                if not git.is_safe_rev(branch) then
                    vim.notify("Invalid ref: " .. branch, vim.log.levels.ERROR)
                    return
                end
                if not git.ref_exists(branch) then
                    vim.notify("Unknown ref: " .. branch, vim.log.levels.ERROR)
                    return
                end
                state.state.base = "HEAD"
                state.state.base_end = branch
                state.state.locked = true
                ui.open()
            else
                ui.pick_branch_and_open()
            end
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
                end, { "close", "commit", "diff", "export", "log", "pick", "qc", "qp", "send" })
            end
            -- Branch completion for :Review diff <branch>
            if #parts == 3 and parts[2] == "diff" then
                local git = require("review.core.git")
                local git_root = git.get_root()
                if not git_root then
                    return {}
                end
                local result = vim.system(
                    { "git", "-c", "core.quotepath=false", "branch", "-a", "--format=%(refname:short)" },
                    { text = true, cwd = git_root }
                ):wait()
                if result.code ~= 0 then
                    return {}
                end
                local branches = {}
                for line in result.stdout:gmatch("[^\r\n]+") do
                    if line ~= "" and not line:match("/HEAD$") then
                        if vim.startswith(line, arg_lead) then
                            table.insert(branches, line)
                        end
                    end
                end
                table.sort(branches)
                return branches
            end
            return {}
        end,
        desc = "Review AI-generated code changes",
    })
end

return M
