-- Lightweight Launch Argument Parser for Lua (lwlap.lua)
--[[Copyright 2026 Alexander Osipov

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy,
modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software
is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

local lwlap = {}

-- Metamethod to access parser methods defined below
function lwlap.__index(t, k)
    return lwlap[k]
end

-- Make a parser table/object
-- parser = lwlap.parser()
function lwlap.parser(argc_min, argc_max)
    local t = {
        options = {},  -- Long option keys
        key_bindings = {}, -- Short key bindings
        positional = {} -- Positional argument parameters
    }
    lwlap.setnpos(t, argc_min or 0, argc_max)  -- Default positional argument number to (argc_min, argc_max)
    return setmetatable(t, lwlap)
end

-- Add an option key
-- parser:option(long_key, short_key = nil, argc_min = 0, argc_max = nil)
--
-- long_key is required, but it might be substituted with short_key unless it is nil too. Both long_key
-- and short_key may not contain the prefix hyphens ('-' or '--') in the function arguments, but long_key
-- may contain separating hyphens in place of spaces.
-- Option value type:
-- * argc_max = 0 - boolean (defaults to true);
-- * argc_max = 1 - string;
-- * argc_max > 1 - table of strings.
-- Both argc_min and argc_max must be non-negative integers. argc_max may not be less
-- than argc_min. If argc_max is omitted, it equals to argc_min.
--
-- Throws an error, if the expression `long_key or short_key` equals to nil or 'n' (reserved index for
-- the number of positional arguments).
--
-- Returns the parser object itself to enable chaining calls. For example:
-- parser:option('foo', nil, 1):option('bar')
function lwlap:option(long_key, short_key, argc_min, argc_max)
    -- Processing option keys
    local opt_k = long_key or short_key
    if opt_k == nil or opt_k == 'n' then
        error('invalid option key')
    elseif short_key then
        self.key_bindings[short_key] = opt_k
    end
    -- Range of numbers of the option values
    argc_min = argc_min or 0
    self.options[opt_k] = {
        key = opt_k, short_only = (long_key == nil),
        min = argc_min, max = math.max(argc_max or argc_min, argc_min)
    }
end

-- Set min and max number of positional arguments
-- parser:setnpos(min = 0, max = nil)
--
-- Both min and max must be non-negative integers. max may not be less than min.
-- If max is omitted, it equals to min. 
function lwlap:setnpos(min, max)
    min = min or 0
    self.positional = {min = min, max = math.max(max or min, min)}
end

-- Local function to count the argument values
local function num_args(args)
        if type(args) == 'table' then
            return  #args
        else
            return (prev_v ~= nil and 1 or 0)
        end
end

-- Local function to write argument values into the result table
local function write_arg_values(opt, val, res, final)
    local prev_val_n = res.n  -- Number of previously added arguments
    if opt.key then
        prev_val_n = num_args(res[opt.key])
    end
    -- Argument number check
    if not final and not opt.key and #val == 0 then
        -- Skip the check for now
    elseif #val + prev_val_n < opt.min then
        if opt.key then
            return false, string.format("not enough of values for option --%s (expected %d, got %d)", opt.key, opt.min, #val + prev_val_n)
        else
            return false, string.format("not enough of positional arguments (expected %d, got %d)", opt.min, #val + prev_val_n)
        end
    elseif #val + prev_val_n > opt.max then
        if opt.key then
            return false, string.format("too many values for option --%s (expected %d, got %d)", opt.key, opt.max, #val + prev_val_n)
        else
            return false, string.format("too many positional arguments (expected %d, got %d)", opt.max, #val + prev_val_n)
        end
    elseif opt.key then
        if opt.max > 1 then
            if res[opt.key] == nil then
                res[opt.key] = {}
            end
            table.move(val, 1, #val, #res[opt.key] + 1, res[opt.key])
        elseif opt.max == 1 then
            res[opt.key] = val[1]
        else
            res[opt.key] = true
        end
    else
        for i = 1, #val do
            res[res.n + i] = val[i]
        end
        res.n = res.n + #val
    end
    return true, nil
end

-- Parse the provided arg table
-- parser:parse(args)
--
-- On success, it returns true and a table with the argument values. Positional arguments have ordinal integer
-- indices, and their number is stored in field 'n'. Options have incides of their long keys without the '--' prefix.
-- You can use the standard Lua tools to convert the argument values into the required type, check option presence or
-- copy the positional arguments into another table to make a proper array of them.
-- Beware that Lua treats number strings as different values than the numbers they might be converted into (i.e. '42' ~= 42),
-- so options with number-like keys should not conflict with the positional arguments at all.
--
-- On fail, it returns false and a string with an input error message. It detects only unknown option keys and argument
-- count mismatches, so any further error detection (e.g. type mismatches or out-of-range values) must be implemented
-- by the library user.
function lwlap:parse(args)
    local opt, val = nil, {} -- Current option and value buffer
    local res = {n = 0} -- result table
    for i, arg in ipairs(args) do
        if arg == '--' then
            -- Close the option scope (usually before positional arguments)
            local ok, err = write_arg_values(opt and self.options[opt] or self.positional, val, res)
            if ok then
                opt, val = nil, {}
            else
                return false, err
            end
        elseif arg:sub(1, 2) == '--' then
            local ok, err = write_arg_values(opt and self.options[opt] or self.positional, val, res)
            if ok then
                opt, val = arg:sub(3), {}  -- Enter a long-key option scope
                if not self.options[opt] then
                    return false, "unknown option key: --" .. opt
                end
            else
                return false, err
            end
        elseif arg:sub(1, 1) == '-' then
            -- Sub-loop to process multiple short keys
            local opts, n_opts = arg:sub(2), #arg - 1
            for i = 1, n_opts do
                local ok, err = write_arg_values(opt and self.options[opt] or self.positional, val, res)
                if ok then
                    opt, val = opts:sub(i, i), {}
                    if not self.key_bindings[opt] then
                        return false, "unknown option key: -" .. opt
                    else
                        opt = self.key_bindings[opt]
                    end
                else
                    return false, err
                end
            end
        else
            if opt and num_args(res[opt]) + num_args(val) >= self.options[opt].max then
                -- Close the option scope
                local ok, err = write_arg_values(opt and self.options[opt] or self.positional, val, res)
                if ok then
                    opt, val = nil, {}
                else
                    return false, err
                end
            end
            -- Write an argument value to the buffer
            table.insert(val, arg)
        end
    end
    -- Final argument parsing
    local ok, err = write_arg_values(opt and self.options[opt] or self.positional, val, res, true)
    if ok then
        if res.n < self.positional.min then
            return false, string.format("not enough of positional arguments (expected %d, got %d)", self.positional.min, res.n)
        end
        return true, res
    else
        return false, err
    end
end

-- Debug function to display the parsed data
function lwlap.print(ok, res)
    print("Parsing succeed:", ok)
    if ok then
        print("Parsed arguments:")
        for k, v in pairs(res) do
            if type(v) == 'table' then
                v = '{' .. table.concat(v, ', ') .. '} (' .. #v .. ' values)'
            end
            if type(k) == 'string' then
                print(string.format("%s = %s", k, v))
            else
                print(string.format("[%d] = %s", k, v))
            end
        end
    else
        print("Reason:", res)
    end
end

return lwlap
