local bit       = require "bit"

local sub       = string.sub
local byte      = string.byte
local tonumber  = tonumber
local tostring  = tostring

local _M = {}

function _M.parse_small_int(data, anchor)
    return byte(data, anchor, anchor), anchor + 1
end


function _M.parse_int(data, anchor)
    local ans = 0
    for i = 0, 3 do
        ans = bit.bor(bit.lshift(ans, 8), byte(data, anchor + i, anchor + i))
    end
    return ans, anchor + 4
end


function _M.parse_nil(data, anchor)
    return {}, anchor
end


-- See also: http://erlang.org/doc/apps/erts/erl_ext_dist.html#LIST_EXT
function _M.parse_list(data, anchor)
    local length, new_anchor = _M.parse_int(data, anchor)
    local list = {}
    local term
    for i = 1, length do
        term, new_anchor = _M.parse(data, new_anchor)
        list[i] = term
    end

    term, new_anchor = _M.parse(data, new_anchor)
    if type(term) == "table" and #term == 0 then
        -- proper list
        return list, new_anchor
    else
        -- improper list
        list[length + 1] = term
        return list, new_anchor
    end
end


function _M.parse_small_big_integer(data, anchor)
    local length, sign, new_anchor
    length, new_anchor = _M.parse_small_int(data, anchor)
    sign, new_anchor = _M.parse_small_int(data, new_anchor)
    local ans = 0
    for i = length, 1, -1 do
        ans = ans * 256 + byte(data, new_anchor + i - 1, new_anchor + i - 1)
    end

    if sign == 1 then
        ans = -ans
    end

    return ans, new_anchor + length
end


function _M.parse_small_atom_utf8(data, anchor)
    local length, new_anchor = _M.parse_small_int(data, anchor)
    return sub(data, new_anchor, new_anchor + length - 1), new_anchor + length
end


function _M.parse_atom(data, anchor)
    local length = bit.bor(bit.lshift(byte(data, anchor, anchor), 8),
                           byte(data, anchor + 1, anchor + 1))
    local new_anchor = anchor + 2
    return sub(data, new_anchor, new_anchor + length - 1), new_anchor + length
end


function _M.parse_binary(data, anchor)
    local length, new_anchor = _M.parse_int(data, anchor)
    return sub(data, new_anchor, new_anchor + length - 1), new_anchor + length
end


-- NOTE: Parse Erlang's tuple into Lua's table
function _M.parse_small_tuple(data, anchor)
    local arity, new_anchor = _M.parse_small_int(data, anchor)
    local tuple = {}
    local term
    for i = 1, arity do
        term, new_anchor = _M.parse(data, new_anchor)
        tuple[i] = term
    end
    return tuple, new_anchor
end


-- NOTE: Parse Erlang's tuple into Lua's table
function _M.parse_large_tuple(data, anchor)
    local arity, new_anchor = _M.parse_int(data, anchor)
    local tuple = {}
    local term
    for i = 1, arity do
        term, new_anchor = _M.parse(data, new_anchor)
        tuple[i] = term
    end
    return tuple, new_anchor
end


function _M.parse_map(data, anchor)
    local arity, new_anchor = _M.parse_int(data, anchor)
    local map = {}
    local key, val
    for i = 1, arity do
        key, new_anchor = _M.parse(data, new_anchor)
        val, new_anchor = _M.parse(data, new_anchor)
        map[tostring(key)] = val
    end
    return map, new_anchor
end


-- Erlang's string does not have a corresponding Erlang representation, but is an
-- optimization for sending lists of bytes (integer in the range 0-255) more
-- efficiently over the distribution. As field Length is an unsigned 2 byte
-- integer (big-endian), implementations must ensure that lists longer than
-- 65535 elements are encoded as LIST_EXT.
function _M.parse_string(data, anchor)
    local length = bit.bor(bit.lshift(byte(data, anchor, anchor), 8),
                           byte(data, anchor + 1, anchor + 1))
    local new_anchor = anchor + 2
    return sub(data, new_anchor, new_anchor + length - 1), new_anchor + length
end


-- Term format:
--   <tag> <data>
--
-- Reference: http://erlang.org/doc/apps/erts/erl_ext_dist.html
--
function _M.parse(data, anchor)
    local tag = byte(data, anchor, anchor)
    local new_anchor = anchor + 1

    if tag == 97 then        -- small integer
        return _M.parse_small_int(data, new_anchor)
    elseif tag == 98  then   -- integer
        return _M.parse_int(data, new_anchor)
    elseif tag == 99  then   -- float
    elseif tag == 101 then   -- reference (would not occur)
    elseif tag == 102 then   -- port (would not occur)
    elseif tag == 103 then   -- pid (would not occur)
    elseif tag == 104 then   -- small tuple
        return _M.parse_small_tuple(data, new_anchor)
    elseif tag == 105 then   -- large tuple
        return _M.parse_large_tuple(data, new_anchor)
    elseif tag == 116 then   -- map
        return _M.parse_map(data, new_anchor)
    elseif tag == 106 then   -- empty list [], or so-called nil
        return _M.parse_nil(data, new_anchor)
    elseif tag == 107 then   -- string
        return _M.parse_string(data, new_anchor)
    elseif tag == 108 then   -- list
        return _M.parse_list(data, new_anchor)
    elseif tag == 109 then   -- binary
        return _M.parse_binary(data, new_anchor)
    elseif tag == 110 then   -- small big number
        return _M.parse_small_big_integer(data, new_anchor)
    elseif tag == 111 then   -- large big number ... exceed Lua integer scope
    elseif tag == 114 then   -- new reference (would not occur)
    elseif tag == 117 then   -- function (would not occur)
    elseif tag == 112 then   -- new function (would not occur)
    elseif tag == 113 then   -- export (would not occur)
    elseif tag == 77  then   -- bit binary (would not occur)
    elseif tag == 70  then   -- new float
    elseif tag == 118 then   -- atom utf8
    elseif tag == 119 then   -- small atom utf8
        return _M.parse_small_atom_utf8(data, new_anchor)
    elseif tag == 100 then   -- atom
        return _M.parse_atom(data, new_anchor)
    elseif tag == 115 then   -- small atom
    elseif tag == 70  then   -- new float
    end
end


function _M.binary_to_term(bin)
    -- bin[1] is version, just ignore it
    return _M.parse(bin, 2)
end


return _M
