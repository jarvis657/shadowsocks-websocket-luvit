table = require "table"
math = require "math"

merge = (left, right, cmp) ->
  result = {}
  while (#left > 0) and (#right > 0)
    if cmp(left[1], right[1])
      table.insert result, table.remove left, 1
    else
      table.insert result, table.remove right, 1
  while #left > 0 do table.insert result, table.remove left, 1
  while #right > 0 do table.insert result, table.remove right, 1
  result

merge_sort = (tbl, cmp) ->
  return tbl if #tbl < 2
  middle = math.ceil(#tbl / 2)
  merge merge_sort([tbl[i] for i = 1, middle], cmp), merge_sort([tbl[i] for i = middle + 1, #tbl], cmp), cmp

{:merge_sort}
