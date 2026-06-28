local U = require("scholatex-util")

-- Section blocks: a heading that also contains its body.
--
--   <subsection title:{My title}>{
--   Body text under the heading.
--   }
--
-- The heading level is the block name (section / subsection / subsubsection).
-- `title:{...}` is the heading text; the braces hold the body, processed as
-- normal (nestable) block content. Optional colour/style words wrap the title
-- text. Layout attributes (tab, lines, alignment) are text attributes and go
-- on the body paragraphs, not on the heading.
--
-- The lightweight attribute form <section>Title (heading only, no body
-- braces) also works, unchanged.

local LEVEL = {
  section       = "\\section",
  subsection    = "\\subsection",
  subsubsection = "\\subsubsection",
}

-- Pulls title:{...} out of the option string and returns it plus the
-- remaining bare words (layout / style attributes).
local function split_title(s)
  local title, rest = nil, {}
  local i, n = 1, #s
  while i <= n do
    while i <= n and s:sub(i, i):match("%s") do i = i + 1 end
    if i > n then break end
    local key = s:match("^title:", i)
    if key and s:sub(i + 6, i + 6) == "{" then
      local value, after = U.read_group(s, i + 6)
      title = value
      i = after
    else
      local word = s:match("^(%S+)", i)
      rest[#rest + 1] = word
      i = i + #word
    end
  end
  return title, rest
end

local function register(sl)
  for name, cmd in pairs(LEVEL) do
    sl.register_block(name, function(api, words_str, inner)
      local title, words = split_title(words_str or "")
      if not title then
        error("scholatex: <" .. name .. "> block needs a title:{...} option")
      end

      -- The title takes colour/style words (which wrap its text) and a
      -- line skip (line/Nlines), emitted as vertical space BEFORE the
      -- heading -- exactly as in the attribute form, so the same alias works
      -- both ways. Other layout words (tab, alignment) have no meaning on a
      -- heading and are rejected; put them on the body paragraphs instead.
      -- Counter-style words set the numbering format of THIS level, on its
      -- own (no inherited prefix): <section ROMAN> -> I, II ; <subsection
      -- roman> -> i, ii (not I.ii). Recognised via resolve as kind "counter":
      -- num, roman, ROMAN, alpha, ALPHA. Default keeps LaTeX's hierarchical
      -- numbering.
      local counter_cmd = nil

      local style_open, style_close = {}, {}
      local before = {}
      for _, w in ipairs(words) do
        local r = sl.style.resolve(w)
        if r and r.kind == "counter" then
          counter_cmd = r.cmd
        elseif r and (r.kind == "style" or r.kind == "color") then
          style_open[#style_open + 1] = r.open
          style_close[#style_close + 1] = r.close
        elseif r and r.kind == "size" then
          local lead = string.format("%.1f", tonumber(r.pt) * 1.2)
          style_open[#style_open + 1] =
            "{\\fontsize{" .. r.pt .. "}{" .. lead .. "}\\selectfont "
          style_close[#style_close + 1] = "}"
        elseif r and r.kind == "lines" then
          before[#before + 1] = "\\vspace*{" .. r.n .. "\\scholatexline}"
        else
          error("scholatex: <" .. name .. "> only accepts colour/style words, a "
              .. "line skip, or a counter style (num/roman/ROMAN/alpha/ALPHA) "
              .. "on the title (got '" .. w .. "'); put layout like tab on the "
              .. "body paragraphs instead")
        end
      end

      -- If a counter style was given, redefine \the<level> for this level,
      -- autonomously (no prefix from the parent level).
      if counter_cmd then
        local the = "\\the" .. name
        api.raw('emit(' .. string.format("%q",
          "\\renewcommand{" .. the .. "}{" .. counter_cmd .. "{" .. name .. "}}")
          .. ")\n")
      end

      -- Vertical skip before the heading, if any.
      for _, b in ipairs(before) do
        api.raw('emit(' .. string.format("%q", b) .. ")\n")
      end

      -- Emit the heading, with optional colour/style wrapping the title text.
      api.raw('emit("' .. cmd:gsub("\\", "\\\\") .. '{")\n')
      for _, o in ipairs(style_open) do
        api.raw('emit(' .. string.format("%q", o) .. ")\n")
      end
      api.forward_text(title)
      for j = #style_close, 1, -1 do
        api.raw('emit(' .. string.format("%q", style_close[j]) .. ")\n")
      end
      api.raw('emit("}")\n')

      -- Emit the body, processed as normal block content (nestable).
      api.process_block(inner)
    end)
  end
end

return register
