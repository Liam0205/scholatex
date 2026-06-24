local U = require("scholatex-util")
local Math = require("scholatex-math")

local ENV = {
  matrix  = { env = "pmatrix", left = "(",        right = ")",        bar = true  },
  det     = { env = "vmatrix", left = "\\lvert",   right = "\\rvert",   bar = false },
  bmatrix = { env = "bmatrix", left = "[",         right = "]",        bar = true  },
}

local REL = { "<=", ">=", "!=", "=", "<", ">" }

local function split_row(line)
  local cells, buf, i, n, inmath = {}, {}, 1, #line, false
  local bar = nil
  local function flush()
    cells[#cells+1] = U.trim(table.concat(buf)); buf = {}
  end
  while i <= n do
    local c = line:sub(i, i)
    if c == "\\" then
      buf[#buf+1] = line:sub(i, i+1); i = i + 2
    elseif c == "$" then
      inmath = not inmath; buf[#buf+1] = c; i = i + 1
    elseif c == ";" and not inmath then
      flush(); i = i + 1
    elseif c == "|" and not inmath then
      if bar then return cells, bar, "twice" end
      flush(); bar = #cells; i = i + 1
    else
      buf[#buf+1] = c; i = i + 1
    end
  end
  flush()
  return cells, bar, nil
end

local function body_lines(inner)
  local out = {}
  for _, l in ipairs(inner) do
    if type(l) == "string" and l:match("%S") then out[#out+1] = U.trim(l) end
  end
  return out
end

local function split_relation(eq)
  local depth, i, n = 0, 1, #eq
  while i <= n do
    local c = eq:sub(i, i)
    if c == "\\" then i = i + 2
    elseif c == "(" or c == "{" then depth = depth + 1; i = i + 1
    elseif c == ")" or c == "}" then depth = depth - 1; i = i + 1
    elseif depth == 0 then
      for _, r in ipairs(REL) do
        if eq:sub(i, i + #r - 1) == r then
          return eq:sub(1, i - 1), r, eq:sub(i + #r)
        end
      end
      i = i + 1
    else
      i = i + 1
    end
  end
  return eq, nil, nil
end

return function(sl)
  for name, spec in pairs(ENV) do
    sl.register_block(name, function(api, words_str, inner)
      if U.trim(words_str or "") ~= "" then
        error("scholatex: <" .. name .. "> takes no options; put the rows in the body, "
            .. "one row per line, cells separated by ';'")
      end
      local lines = body_lines(inner)
      if #lines == 0 then
        error("scholatex: <" .. name .. "> is empty; give one row per line")
      end

      local ncols, barpos
      local rows = {}
      for k, l in ipairs(lines) do
        local cells, bar, flag = split_row(l)
        if flag == "twice" then
          error("scholatex: <" .. name .. "> row " .. k .. " has two '|'; a single "
              .. "separation bar is allowed")
        end
        if bar then
          if not spec.bar then
            error("scholatex: <" .. name .. "> cannot take a '|' separation bar; "
                .. "it is meaningful only on matrix and bmatrix")
          end
          if bar == 0 or bar == #cells
             or cells[bar] == "" or cells[bar + 1] == "" then
            error("scholatex: <" .. name .. "> row " .. k .. " has a '|' at the edge "
                .. "or next to an empty cell; it must sit between two cells")
          end
        end
        if not ncols then
          ncols, barpos = #cells, bar
        else
          if #cells ~= ncols then
            error("scholatex: <" .. name .. "> row " .. k .. " has " .. #cells
                .. " cells, " .. ncols .. " expected")
          end
          if bar ~= barpos then
            error("scholatex: <" .. name .. "> row " .. k .. " puts the '|' bar in a "
                .. "different place; it must sit at the same column on every row")
          end
        end
        local cooked = {}
        for _, cell in ipairs(cells) do cooked[#cooked+1] = Math.mathlite(cell) end
        rows[#rows+1] = table.concat(cooked, " & ")
      end

      if barpos then
        local pre = string.rep("c", barpos) .. "|" .. string.rep("c", ncols - barpos)
        api.lit("\\[\\left" .. spec.left .. "\\begin{array}{" .. pre .. "}")
        api.lit(table.concat(rows, " \\\\ "))
        api.lit("\\end{array}\\right" .. spec.right .. "\\]")
      else
        api.lit("\\[\\begin{" .. spec.env .. "}")
        api.lit(table.concat(rows, " \\\\ "))
        api.lit("\\end{" .. spec.env .. "}\\]")
      end
    end)
  end

  sl.register_block("system", function(api, words_str, inner)
    if U.trim(words_str or "") ~= "" then
      error("scholatex: <system> takes no options; put one equation per line")
    end
    local lines = body_lines(inner)
    if #lines == 0 then
      error("scholatex: <system> is empty; give one equation per line")
    end

    local rows = {}
    for _, l in ipairs(lines) do
      local lhs, rel, rhs = split_relation(l)
      if rel then
        rows[#rows+1] = Math.mathlite(lhs) .. " &" .. Math.mathlite(rel .. rhs)
      else
        rows[#rows+1] = Math.mathlite(lhs) .. " &"
      end
    end

    api.lit("\\[\\left\\{\\begin{aligned}")
    api.lit(table.concat(rows, " \\\\ "))
    api.lit("\\end{aligned}\\right.\\]")
  end)
end
