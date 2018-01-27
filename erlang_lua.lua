local bit       = require "bit"

local sub       = string.sub
local byte      = string.byte
local tonumber  = tonumber
local tostring  = tostring

local _M = {}

function _M.parse_small_int(data)
    local term = sub(data, 1, 1)
    local rest = sub(data, 2)
    return byte(term, 1, 1), rest
end


function _M.parse_int(data)
    local term = sub(data, 1, 4)
    local rest = sub(data, 5)
    local ans = 0
    for i = 1, #term do
        ans = bit.bor(bit.lshift(ans, 8), byte(term, i, i))
    end
    return ans, rest
end


function _M.parse_nil(data)
    local rest = sub(data, 2)
    return {}, rest
end


function _M.parse_list(data)
    local length = _M.parse_int(sub(data, 1, 4))
    local rest = sub(data, 5)
    local list = {}
    local term

    -- Assume it is proper list, so we only parse only `length` terms. See
    -- also: http://erlang.org/doc/apps/erts/erl_ext_dist.html#LIST_EXT
    for i = 1, length do
        term, rest = _M.parse(rest)
        list[i] = term
    end
    return list, rest
end


function _M.parse_small_big_integer(data)
    local length = _M.parse_small_int(sub(data, 1, 1))
    local sign = _M.parse_small_int(sub(data, 2, 2))
    local term = sub(data, 3, 3 + length)
    local rest = sub(data, 4 + length)
    local ans = 0
    for i = length, 1, -1 do
        ans = ans * 256 + byte(term, i, i)
    end

    if sign == 1 then
        ans = -ans
    end
    return ans, rest
end


function _M.parse_small_atom_utf8(data)
    local length, rest = _M.parse_small_int(data)
    local term = sub(rest, 1, length)
    rest = sub(rest, length + 1)
    return term, rest
end


function _M.parse_atom(data)
    local length = bit.bor(bit.lshift(byte(data, 1, 1), 8), byte(data, 2, 2))
    data = sub(data, 3)
    local term = sub(data, 1, length)
    local rest = sub(data, length + 1)
    return term, rest
end


function _M.parse_binary(data)
    local length, rest = _M.parse_int(data)
    local term = sub(rest, 1, length)
    rest = sub(rest, length + 1)
    return term, rest
end


-- NOTE: Parse Erlang's tuple into Lua's table
function _M.parse_small_tuple(data)
    local arity, rest = _M.parse_small_int(data)
    local tuple = {}
    local term
    for i = 1, arity do
        term, rest = _M.parse(rest)
        tuple[i] = term
    end
    return tuple, rest
end


-- NOTE: Parse Erlang's tuple into Lua's table
function _M.parse_large_tuple(data)
    local arity, rest = _M.parse_int(data)
    local tuple = {}
    local term
    for i = 1, arity do
        term, rest = _M.parse(rest)
        tuple[i] = term
    end
    return tuple, rest
end


function _M.parse_map(data)
    local arity, rest = _M.parse_int(data)
    local map = {}
    local key, val
    for i = 1, arity do
        key, rest = _M.parse(rest)
        val, rest = _M.parse(rest)
        map[tostring(key)] = val
    end
    return map, rest
end


-- NOTE: Parse Erlang's string to Lua's table
function _M.parse_string(data)
    local length = bit.bor(bit.lshift(byte(data, 1, 1), 8), byte(data, 2, 2))
    local rest = sub(data, 3)
    local list = {}
    for i = 1, length do
        list[i] = byte(rest, i, i)
    end
    rest = sub(rest, length + 1)
    return list, rest
end


-- Term format:
--   <tag> <data>
--
-- Reference: http://erlang.org/doc/apps/erts/erl_ext_dist.html
--
function _M.parse(bin)
    local tag = byte(bin, 1, 1)
    local data = sub(bin, 2, #bin)

    if tag == 97 then        -- small integer
        return _M.parse_small_int(data)
    elseif tag == 98  then   -- integer
        return _M.parse_int(data)
    elseif tag == 99  then   -- float
    elseif tag == 101 then   -- reference (would not occur)
    elseif tag == 102 then   -- port (would not occur)
    elseif tag == 103 then   -- pid (would not occur)
    elseif tag == 104 then   -- small tuple
        return _M.parse_small_tuple(data)
    elseif tag == 105 then   -- large tuple
        return _M.parse_large_tuple(data)
    elseif tag == 116 then   -- map
        return _M.parse_map(data)
    elseif tag == 106 then   -- empty list [], or so-called nil
        return _M.parse_nil(data)
    elseif tag == 107 then   -- string
        return _M.parse_string(data)
    elseif tag == 108 then   -- list
        return _M.parse_list(data)
    elseif tag == 109 then   -- binary
        return _M.parse_binary(data)
    elseif tag == 110 then   -- small big number
        return _M.parse_small_big_integer(data)
    elseif tag == 111 then   -- large big number ... exceed Lua integer scope
    elseif tag == 114 then   -- new reference (would not occur)
    elseif tag == 117 then   -- function (would not occur)
    elseif tag == 112 then   -- new function (would not occur)
    elseif tag == 113 then   -- export (would not occur)
    elseif tag == 77  then   -- bit binary (would not occur)
    elseif tag == 70  then   -- new float (TODO)
    elseif tag == 118 then   -- atom utf8
    elseif tag == 119 then   -- small atom utf8
        return parse_small_atom_utf8(data)
    elseif tag == 100 then   -- atom
        return _M.parse_atom(data)
    elseif tag == 115 then   -- small atom
    elseif tag == 70  then   -- new float
    end
end


return _M
