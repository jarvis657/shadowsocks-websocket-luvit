local table = require("table")
local math = require("math")
local merge
merge = function(left, right, cmp)
  local result = { }
  while (#left > 0) and (#right > 0) do
    if cmp(left[1], right[1]) then
      table.insert(result, table.remove(left, 1))
    else
      table.insert(result, table.remove(right, 1))
    end
  end
  while #left > 0 do
    table.insert(result, table.remove(left, 1))
  end
  while #right > 0 do
    table.insert(result, table.remove(right, 1))
  end
  return result
end
local merge_sort
merge_sort = function(tbl, cmp)
  if #tbl < 2 then
    return tbl
  end
  local middle = math.ceil(#tbl / 2)
  return merge(merge_sort((function()
    local _accum_0 = { }
    local _len_0 = 1
    for i = 1, middle do
      _accum_0[_len_0] = tbl[i]
      _len_0 = _len_0 + 1
    end
    return _accum_0
  end)(), cmp), merge_sort((function()
    local _accum_0 = { }
    local _len_0 = 1
    for i = middle + 1, #tbl do
      _accum_0[_len_0] = tbl[i]
      _len_0 = _len_0 + 1
    end
    return _accum_0
  end)(), cmp), cmp)
end
return {
  merge_sort = merge_sort
}
