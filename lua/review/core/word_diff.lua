local M = {}

---Split string into tokens (words, punctuation, whitespace)
---@param str string
---@return table[] tokens with {text, start, finish}
local function tokenize(str)
    local tokens = {}
    local i = 1
    local len = #str

    while i <= len do
        local start = i
        local char = str:sub(i, i)

        if char:match("%s") then
            -- Whitespace
            while i <= len and str:sub(i, i):match("%s") do
                i = i + 1
            end
        elseif char:match("[%w_]") then
            -- Word (alphanumeric + underscore)
            while i <= len and str:sub(i, i):match("[%w_]") do
                i = i + 1
            end
        else
            -- Punctuation/symbol - single char
            i = i + 1
        end

        table.insert(tokens, {
            text = str:sub(start, i - 1),
            start = start - 1, -- 0-indexed for nvim
            finish = i - 1, -- 0-indexed for nvim
        })
    end

    return tokens
end

---Compute word-level diff between two strings
---Returns list of {start, end} ranges that are different in new_str
---@param old_str string
---@param new_str string
---@return table[] ranges of changed characters in new_str
function M.compute(old_str, new_str)
    if not old_str or not new_str then
        return {}
    end

    local old_tokens = tokenize(old_str)
    local new_tokens = tokenize(new_str)

    -- Find common prefix tokens
    local prefix_count = 0
    while prefix_count < #old_tokens and prefix_count < #new_tokens do
        if old_tokens[prefix_count + 1].text == new_tokens[prefix_count + 1].text then
            prefix_count = prefix_count + 1
        else
            break
        end
    end

    -- Find common suffix tokens (don't overlap with prefix)
    local suffix_count = 0
    while suffix_count < (#old_tokens - prefix_count) and suffix_count < (#new_tokens - prefix_count) do
        local old_idx = #old_tokens - suffix_count
        local new_idx = #new_tokens - suffix_count
        if old_tokens[old_idx].text == new_tokens[new_idx].text then
            suffix_count = suffix_count + 1
        else
            break
        end
    end

    -- The changed tokens in new_str
    local first_changed = prefix_count + 1
    local last_changed = #new_tokens - suffix_count

    if first_changed <= last_changed then
        local start_pos = new_tokens[first_changed].start
        local end_pos = new_tokens[last_changed].finish
        return { { start_pos, end_pos } }
    end

    return {}
end

return M
