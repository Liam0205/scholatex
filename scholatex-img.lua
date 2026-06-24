local U = require("scholatex-util")

return function(sl)
  sl.register_tag("img", function(api, words, content)
    local opt = "width=\\linewidth"
    local w = words[2]
    if w then
      local wd, ht = w:match("^(%d+%.?%d*)x(%d+%.?%d*)$")
      if wd then
        opt = "width=" .. wd .. "mm,height=" .. ht .. "mm,keepaspectratio"
      elseif w:match("^%d+%.?%d*$") then
        opt = "width=" .. w .. "mm"
      else
        error("scholatex: invalid image dimension: '" .. w
            .. "' (expected N or NxM in mm)")
      end
    end
    local fname = U.trim(content)
    api.lit("\\includegraphics[" .. opt .. "]{")
    local p = 1
    while true do
      local h = fname:find("#", p, true)
      if not h then api.lit(fname:sub(p)); break end
      api.lit(fname:sub(p, h - 1))
      local expr, after
      if fname:sub(h + 1, h + 1) == "{" then
        expr, after = U.read_group(fname, h + 1)
      else
        expr = fname:match("^#([%a_][%w_]*)", h)
        after = h + 1 + #expr
      end
      api.raw("emit(tostring(" .. expr .. "))\n")
      p = after
    end
    api.lit("}")
  end)
end
