local U = require("scholatex-util")

local function split_cells(line)
  local cells, buf, i, n, inmath = {}, {}, 1, #line, false
  while i <= n do
    local c = line:sub(i, i)
    if c == "\\" then
      buf[#buf+1] = line:sub(i, i+1); i = i + 2
    elseif c == "$" then
      inmath = not inmath; buf[#buf+1] = c; i = i + 1
    elseif c == "|" and not inmath then
      cells[#cells+1] = U.trim(table.concat(buf))
      buf = {}; i = i + 1
    else
      buf[#buf+1] = c; i = i + 1
    end
  end
  cells[#cells+1] = U.trim(table.concat(buf))
  return cells
end

local function parse_cell(cell)
  if cell == "." then return { absorbed = true, width = 1 } end
  if not cell:match("^<%s*[cr][%a]*span:") then
    return { text = cell, width = 1 }
  end
  local words, content = cell:match("^<%s*(.-)%s*>%s*{(.*)}%s*$")
  if not words then return { text = cell, width = 1 } end
  local c = { width = 1, text = content }
  for w in words:gmatch("%S+") do
    local cs = w:match("^colspan:(%d+)$")
    local rs = w:match("^rowspan:(%d+)$")
    if cs then
      if tonumber(cs) < 2 then error("scholatex: colspan must be 2 or more (got " .. cs .. ")") end
      c.colspan = tonumber(cs); c.width = c.colspan
    elseif rs then
      if tonumber(rs) < 2 then error("scholatex: rowspan must be 2 or more (got " .. rs .. ")") end
      c.rowspan = tonumber(rs)
    elseif #w == 2 and U.place_code(w) then
      local v, h = U.place_code(w)
      c.align  = ({left="l", center="c", right="r"})[h]
      c.valign = ({top="t", center="m", bottom="b"})[v]
    else
      error("scholatex: unknown table cell tag: '" .. w .. "'; use colspan:N, "
          .. "rowspan:N, or a two-letter placement code like tl, mc, br")
    end
  end
  return c
end

local function row_cells(line)
  local out = {}
  for _, raw in ipairs(split_cells(line)) do out[#out+1] = parse_cell(raw) end
  return out
end

local function row_width(cells)
  local w = 0
  for _, c in ipairs(cells) do w = w + c.width end
  return w
end

local function parse_table_opts(words_str)
  local o = { cols = nil, borders = false, header = false, gap = nil }

  local spec = words_str:match("%[(.-)%]")
  if spec then
    o.cols = {}
    for rawfield in (spec .. ","):gmatch("(.-),") do
      local field = U.trim(rawfield)
      if field ~= "" then
        local width, code = field:match("^(%d+):(%a+)$")
        if not width then
          code = field:match("^(%a+)$")
          width = nil
        end
        local align, valign
        if code and #code == 2 then
          local v, h = U.place_code(code)
          if v then
            valign = ({top="t", center="m", bottom="b"})[v]
            align  = ({left="l", center="c", right="r"})[h]
          end
        end
        if not align then
          error("scholatex: invalid table column '" .. field
              .. "'; every column needs a two-letter placement code "
              .. "(vertical t/m/b, then horizontal l/c/r) such as tl, mc or "
              .. "br, optionally prefixed with a width: 30:mc")
        end
        o.cols[#o.cols+1] = { width = width, align = align, valign = valign }
      end
    end
    words_str = words_str:gsub("%[.-%]", " ")
  end

  for w in words_str:gmatch("%S+") do
    if w == "borders" then o.borders = true
    elseif w == "header" or w == "headers" then o.header = true
    else
      local key, val = w:match("^([%a_]+):(.+)$")
      if key == "gap" then o.gap = val
      elseif key == "fill" then o.fill = val
      elseif key == "line" then o.line = val
      elseif key == "text" then o.text = val
      elseif key == "headerfill" then o.headerfill = val
      elseif key == "headertext" then o.headertext = val
      elseif key == "radius" or key == "title" or key == "width" then
        error("scholatex: <table> has no '" .. key .. "' option; it applies to a "
            .. "box, not table cells. Wrap the table in a <box " .. key
            .. ":...> to frame it.")
      elseif key then
        error("scholatex: unknown <table> option: '" .. w .. "'")
      else
        error("scholatex: unknown <table> option: '" .. w .. "'")
      end
    end
  end
  return o
end

local VMAP = {t = "h", m = "m", b = "f"}

local function colspec(o, ncols)
  local parts = {}
  for ci = 1, ncols do
    local col = o.cols and o.cols[ci]
    local align = (col and col.align) or "c"
    local valign = VMAP[(col and col.valign) or "t"] or "h"
    local width = col and col.width
    if width then
      parts[ci] = "Q[" .. align .. "," .. valign .. "," .. width .. "mm]"
    else
      parts[ci] = "X[" .. align .. "," .. valign .. "]"
    end
  end
  return table.concat(parts)
end

return function(sl)
  sl.register_block("table", function(api, words_str, inner)
    local opts = parse_table_opts(words_str or "")

    local ncols = 1
    for _, l in ipairs(inner) do
      if type(l) == "string" and not l:match("^%s*for%s")
         and not l:match("^%s*if%s") and not l:match("^%s*}")
         and not l:match("^%s*else") and l:match("%S") then
        ncols = row_width(row_cells(l)); break
      end
    end

    local cs = colspec(opts, ncols)

    local cn = sl.box_color_name
    local rulecolor   = opts.line       and cn(opts.line)
    local fillcolor   = opts.fill       and cn(opts.fill)
    local textcolor   = opts.text       and cn(opts.text)
    local hfillcolor  = opts.headerfill and cn(opts.headerfill)
    local htextcolor  = opts.headertext and cn(opts.headertext)

    local width = "\\dimexpr\\linewidth-" .. (2 * ncols) .. "\\tabcolsep\\relax"
    local settings = { "colspec={" .. cs .. "}", "width=" .. width }
    if opts.gap then settings[#settings+1] = "colsep=" .. opts.gap .. "mm" end
    if opts.borders then
      if rulecolor then
        settings[#settings+1] = "hlines={" .. rulecolor .. "}"
        settings[#settings+1] = "vlines={" .. rulecolor .. "}"
      else
        settings[#settings+1] = "hlines"
        settings[#settings+1] = "vlines"
      end
    end
    if fillcolor or textcolor then
      local c = {}
      if fillcolor then c[#c+1] = "bg=" .. fillcolor end
      if textcolor then c[#c+1] = "fg=" .. textcolor end
      settings[#settings+1] = "cells={" .. table.concat(c, ",") .. "}"
    end
    if opts.header then
      local h = { "font=\\bfseries" }
      if hfillcolor then h[#h+1] = "bg=" .. hfillcolor end
      if htextcolor then h[#h+1] = "fg=" .. htextcolor end
      settings[#settings+1] = "row{1}={" .. table.concat(h, ",") .. "}"
    end

    local preamble_esc = table.concat(settings, ", "):gsub("\\", "\\\\")
    api.raw('emit("\\\\begin{tblr}{' .. preamble_esc .. '}")\n')

    local function emit_cell_text(cellt)
      api.forward_text(cellt)
    end

    local rownum = 0
    local depth = 0
    local held = {}
    for c = 1, ncols do held[c] = 0 end

    local ri, rtotal = 1, #inner
    while ri <= rtotal do
      local l = inner[ri]
      if type(l) == "string" and l:match("^%s*}%s*$") then
        api.raw("end\n"); depth = depth - 1; ri = ri + 1
      elseif type(l) == "string" and api.is_control_open(l) then
        api.raw(api.lua_control(l) .. "\n"); depth = depth + 1; ri = ri + 1
      elseif type(l) == "string" and l:match("%S") then
        rownum = rownum + 1
        local cells = row_cells(l)
        local rw = row_width(cells)
        if rw ~= ncols then
          error("scholatex: table row covers " .. rw .. " columns, " .. ncols .. " expected")
        end
        local colidx = 1
        for ci, cell in ipairs(cells) do
          if ci > 1 then api.raw('emit(" & ")\n') end
          if cell.absorbed then
          elseif cell.colspan then
            local h = cell.align or "c"
            api.raw('emit("\\\\SetCell[c=' .. cell.colspan .. ']{' .. h .. '} ")\n')
            emit_cell_text((cell.text or ""):gsub("\\\\", "\\newline "))
            for _ = 2, cell.colspan do api.raw('emit(" &")\n') end
          elseif cell.rowspan then
            local v = VMAP[cell.valign or "t"] or "h"
            api.raw('emit("\\\\SetCell[r=' .. cell.rowspan .. ']{' .. v .. '} ")\n')
            emit_cell_text((cell.text or ""):gsub("\\\\", "\\newline "))
            held[colidx] = cell.rowspan
          else
            emit_cell_text((cell.text or ""):gsub("\\\\", "\\newline "))
          end
          colidx = colidx + cell.width
        end
        api.raw('emit(" \\\\\\\\ ")\n')
        for c = 1, ncols do if held[c] > 0 then held[c] = held[c] - 1 end end
        ri = ri + 1
      else
        ri = ri + 1
      end
    end

    while depth > 0 do api.raw("end\n"); depth = depth - 1 end

    api.raw('emit("\\\\end{tblr}")\n')
  end)
end
