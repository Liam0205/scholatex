local U = require("scholatex-util")

local function extract_align(optstr)
  local rest, aligns = {}, {}
  for _, w in ipairs(U.split_opts(optstr or "")) do
    local v, h = U.place_code(w)
    if v then
      aligns[#aligns + 1] = "valign=" .. v
      aligns[#aligns + 1] = "halign=" .. h
    else
      rest[#rest + 1] = w
    end
  end
  return table.concat(rest, " "), aligns
end

local function parse_grid_opts(s)
  local opts = U.parse_attrs(s, {
    tag      = "grid",
    brackets = true,
    hint     = "expects key:value options (template:[...], gap:N)",
  })
  local rows = {}
  if opts.template then
    for row in opts.template:gmatch('"([^"]*)"') do rows[#rows + 1] = row end
    opts.template = nil
  end
  if opts.gap == nil then opts.gap = "4" end
  return rows, opts
end

local function compute_areas(rows)
  local grid, ncols = {}, 0
  for r, row in ipairs(rows) do
    grid[r] = {}
    local c = 0
    for word in row:gmatch("%S+") do
      c = c + 1
      grid[r][c] = word
    end
    if c > ncols then ncols = c end
  end
  local nrows = #rows

  local bb = {}
  for r = 1, nrows do
    for c = 1, ncols do
      local nm = grid[r] and grid[r][c]
      if nm and nm ~= "." then
        local b = bb[nm]
        if not b then
          bb[nm] = {cmin = c, cmax = c, rmin = r, rmax = r}
        else
          if c < b.cmin then b.cmin = c end
          if c > b.cmax then b.cmax = c end
          if r < b.rmin then b.rmin = r end
          if r > b.rmax then b.rmax = r end
        end
      end
    end
  end

  local areas, order = {}, {}
  for r = 1, nrows do
    for c = 1, ncols do
      local nm = grid[r] and grid[r][c]
      if nm and nm ~= "." and not areas[nm] then
        local b = bb[nm]
        for rr = b.rmin, b.rmax do
          for cc = b.cmin, b.cmax do
            if not (grid[rr] and grid[rr][cc] == nm) then
              error("scholatex: <grid> area '" .. nm .. "' is not rectangular; "
                  .. "every cell of its span must carry the same name")
            end
          end
        end
        areas[nm] = {
          col     = b.cmin,
          row     = b.rmin,
          span    = b.cmax - b.cmin + 1,
          rowspan = b.rmax - b.rmin + 1,
        }
        order[#order + 1] = nm
      end
    end
  end
  return ncols, nrows, areas, order
end

local function split_areas(inner)
  local list, byname = {}, {}
  local i, n = 1, #inner
  while i <= n do
    local l = inner[i]
    local iname, iopts, icontent
    if type(l) == "string" then
      iname, iopts, icontent =
        l:match("^%s*<area%s+([%a_][%w_]*)%s*(.-)>%s*{(.*)}%s*$")
    end
    if iname then
      byname[iname] = {lines = { icontent }, opts = U.trim(iopts or "")}
      list[#list+1] = iname
      i = i + 1
      goto continue
    end
    local name, mopts
    if type(l) == "string" then
      name, mopts = l:match("^%s*<area%s+([%a_][%w_]*)%s*(.-)>%s*{%s*$")
    end
    if name then
      local sub
      sub, i = U.collect_block(inner, i + 1)
      byname[name] = {lines = sub, opts = U.trim(mopts or "")}
      list[#list+1] = name
    else
      if type(l) == "string" and l:match("%S") then
        error("scholatex: <grid> body only holds <area NAME>{...} blocks; "
            .. "stray content: '" .. U.trim(l) .. "'")
      end
      i = i + 1
    end
    ::continue::
  end
  return list, byname
end

local function register(sl)
  sl.register_block("grid", function(api, words_str, inner)
    local ws = words_str or ""
    local bracket = ws:match("%b[]") or ""
    local SENT = "\1TEMPLATE\1"
    local outside = bracket ~= "" and ws:gsub("%b[]", SENT, 1) or ws
    local gridrest_out, gridaligns = extract_align(outside)
    local gridrest = (bracket ~= "")
                     and gridrest_out:gsub(SENT, function() return bracket end)
                     or gridrest_out
    local default_align = (#gridaligns > 0) and table.concat(gridaligns, ", ")
                          or "valign=top, halign=left"
    local rows, opts = parse_grid_opts(gridrest)
    if #rows == 0 then
      error('sl: <grid> needs a template:[ "..." "..." ] option')
    end
    local ncols, nrows, areas, order = compute_areas(rows)
    local placed, content = split_areas(inner)

    for _, nm in ipairs(placed) do
      if not areas[nm] then
        error("scholatex: <grid> has <area " .. nm .. "> but '" .. nm
            .. "' is not in the template")
      end
    end

    local widthspec
    if opts.width then
      local pct = opts.width:match("^(%d+%.?%d*)%%$")
      if pct then
        local f = string.format("%.4f", tonumber(pct) / 100):gsub("0+$", ""):gsub("%.$", "")
        widthspec = "\\\\dimexpr " .. f .. "\\\\linewidth\\\\relax"
      else
        widthspec = opts.width .. "mm"
      end
    else
      widthspec = "\\\\linewidth"
    end

    local heightkey, needspace = "", ""
    if opts.height then
      heightkey = ", height=" .. opts.height .. "mm"
      needspace = "\\\\Needspace*{" .. string.format("%g", tonumber(opts.height) + 12) .. "mm}"
    end

    local pad = (sl.config and sl.config.padding) or "2"
    local pad_reset = "boxsep=" .. pad .. "mm, left=0mm, right=0mm, top=0mm, bottom=0mm"

    api.raw('emit("' .. needspace .. '\\\\par\\\\nobreak\\\\noindent")\n')
    api.raw('emit("\\\\begin{minipage}{' .. widthspec .. '}")\n')
    api.raw('emit("\\\\begin{tcbposter}[poster={columns=' .. ncols
            .. ', rows=' .. nrows .. ', spacing=' .. (opts.gap or "4")
            .. 'mm' .. heightkey .. '}, boxes={enhanced, frame empty, '
            .. 'colback=White, sharp corners, ' .. default_align .. ', '
            .. pad_reset .. '}]")\n')

    for _, nm in ipairs(order) do
      local a    = areas[nm]
      local spec = "name=" .. nm .. ", column=" .. a.col .. ", row=" .. a.row
      if a.span > 1    then spec = spec .. ", span=" .. a.span end
      if a.rowspan > 1 then spec = spec .. ", rowspan=" .. a.rowspan end

      local area = content[nm]
      local styleopts, aligns = "", {}
      if area then styleopts, aligns = extract_align(area.opts) end
      local alignspec = (#aligns > 0) and table.concat(aligns, ", ") or ""

      local boxwords, textwords = {}, {}
      for _, w in ipairs(U.split_opts(styleopts)) do
        if w:match("^[%a_]+:") then boxwords[#boxwords+1] = w
        else textwords[#textwords+1] = w end
      end
      local boxstr = table.concat(boxwords, " ")

      if boxstr ~= "" and sl.box_parse_opts then
        local bopts   = sl.box_parse_opts(boxstr)
        local boxspec = sl.box_build_options(bopts)
        local title   = bopts.title and ("adjusted title={" .. bopts.title .. "}, ") or ""
        local extra   = (alignspec ~= "") and (", " .. alignspec) or ""
        api.raw('emit("\\\\posterbox[' .. title .. boxspec .. extra
                .. ']{' .. spec .. '}{")\n')
      elseif alignspec ~= "" then
        api.raw('emit("\\\\posterbox[' .. alignspec .. ', ' .. pad_reset
                .. ']{' .. spec .. '}{")\n')
      else
        api.raw('emit("\\\\posterbox[' .. pad_reset .. ']{' .. spec .. '}{")\n')
      end

      local topen, tclose = "", ""
      for _, w in ipairs(textwords) do
        local cmd = sl.style.ALIGN[w]
        if cmd then topen = topen .. "{" .. cmd .. " "; tclose = "\\par}" .. tclose
        else error("scholatex: <area " .. nm .. "> got '" .. w
                 .. "'; cell placement uses two-letter codes (tl, mc, br...), "
                 .. "text uses l/c/r/j") end
      end
      if topen ~= "" then api.raw('emit(' .. string.format("%q", topen) .. ")\n") end
      if area then api.process_block(area.lines) end
      if tclose ~= "" then api.raw('emit(' .. string.format("%q", tclose) .. ")\n") end
      api.raw('emit("}")\n')
    end

    api.raw('emit("\\\\end{tcbposter}")\n')
    api.raw('emit("\\\\end{minipage}\\\\par")\n')
  end)
end

return register