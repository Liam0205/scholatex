local U = require("scholatex-util")

-- =====================================================================
-- <plot> --- tracé d'une fonction via pgfplots.
--
--   <plot k samples:200 x:{-2, 4} y:{-15, 15}>
--
-- Lit l'objet fonction k (défini par  let k = <fn ... expr:{...} ...>) :
--   * expr  : l'expression à tracer (mini-langage maths)
--   * name  : pour les libellés des axes (variable et fonction)
--   * x     : à défaut de x:{a,b} ici, l'intervalle vient des abscisses
--             finies du tableau.
--
-- Options du tag :
--   x:{a, b}    fenêtre horizontale (défaut : intervalle du tableau)
--   y:{c, d}    fenêtre verticale (obligatoire si la fonction diverge)
--   samples:N   nombre de points calculés (défaut 100)
--
-- La fonction est traduite vers la syntaxe pgfplots ; les pôles sont
-- gérés (restrict y + unbounded coords=jump) pour éviter le trait
-- vertical parasite à une asymptote.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Parse les options key:{...} ou key:val du tag.
-- ---------------------------------------------------------------------
local function parse_attrs(s)
  return U.parse_attrs(s, {
    tag  = "plot",
    hint = "expects a function object name then key:{...} options",
    on_bare = function(word, attrs)
      if not attrs._ref then attrs._ref = word; return true end
      return false
    end,
  })
end

-- ---------------------------------------------------------------------
-- Traduit une borne (a du mini-langage) en valeur numérique pgfplots.
-- Gère -pi, pi/2, -inf (interdit comme borne d'affichage), nombres.
-- ---------------------------------------------------------------------
local function num_bound(tok, what)
  tok = U.trim(tok)
  if tok:match("inf") then
    error("scholatex: <plot> " .. what .. " bound cannot be infinite ('"
        .. tok .. "'); give a finite display window, e.g. x:{-3, 3}")
  end
  -- remplace pi par sa valeur, gère a/b et -a
  local expr = tok:gsub("pi", "(pi)")
  -- pgfplots comprend pi, /, -, donc on renvoie tel quel (évalué par lui)
  return tok
end

-- ---------------------------------------------------------------------
-- Traduit l'expression du mini-langage vers la syntaxe pgfplots.
-- Sous-ensemble supporté : + - * / ^ ( ) , les fonctions
-- sin cos tan exp ln log sqrt abs, les constantes pi e, et la variable
-- (remplacée par x). Les fonctions trigonométriques reçoivent deg(...)
-- car pgfplots travaille en degrés.
-- ---------------------------------------------------------------------
local TRIG = { sin=true, cos=true, tan=true }
local FUNC = { sin=true, cos=true, tan=true, exp=true, ln=true, log=true,
               sqrt=true, abs=true }

local function translate(expr, var)
  -- 1. variable -> x  (mot entier seulement)
  if var ~= "x" then
    expr = expr:gsub("([%a_]?)(" .. var .. ")([%w_]?)", function(a, m, b)
      if a == "" and b == "" then return "x" else return a .. m .. b end
    end)
  end

  -- 2. ln -> ln, log -> log10 (pgfplots), e reste e, pi reste pi
  -- 3. fonctions trigo : f( ... ) -> f(deg( ... ))
  -- On parcourt et on enveloppe les arguments des fonctions trigo.
  local out, i, n = {}, 1, #expr
  while i <= n do
    local word = expr:match("^(%a+)", i)
    if word then
      i = i + #word
      if expr:sub(i, i) == "(" then
        -- lire le groupe ( ... )
        local depth, j = 0, i
        while j <= n do
          local c = expr:sub(j, j)
          if c == "(" then depth = depth + 1
          elseif c == ")" then depth = depth - 1; if depth == 0 then break end end
          j = j + 1
        end
        local arg = expr:sub(i + 1, j - 1)
        local targ = translate(arg, "x")   -- déjà en x
        if TRIG[word] then
          out[#out+1] = word .. "(deg(" .. targ .. "))"
        elseif word == "ln" then
          out[#out+1] = "ln(" .. targ .. ")"
        elseif word == "log" then
          out[#out+1] = "log10(" .. targ .. ")"
        elseif FUNC[word] then
          out[#out+1] = word .. "(" .. targ .. ")"
        else
          -- mot inconnu suivi de ( : on le laisse mais c'est suspect
          out[#out+1] = word .. "(" .. targ .. ")"
        end
        i = j + 1
      else
        -- mot sans parenthèse : pi, e, ou variable résiduelle
        out[#out+1] = word
      end
    else
      out[#out+1] = expr:sub(i, i)
      i = i + 1
    end
  end
  local result = table.concat(out)

  -- Multiplication implicite -> explicite, pour pgfplots qui l'exige :
  --   chiffre suivi d'une lettre ou '(' :  2x -> 2*x,  2( -> 2*(
  --   ')' suivi d'un chiffre, lettre ou '(' :  )x -> )*x,  )( -> )*(
  -- Les noms de fonctions (cos, sqrt...) ne sont pas touchés : on n'insère
  -- jamais de '*' entre deux lettres.
  result = result:gsub("(%d)([%a%(])", "%1*%2")
  result = result:gsub("(%))([%w%(])", "%1*%2")
  return result
end

-- ---------------------------------------------------------------------
-- Détermine la fenêtre horizontale : x:{a,b} explicite, sinon les
-- abscisses finies extrêmes du tableau (champ x de l'objet).
-- ---------------------------------------------------------------------
local function hwindow(attrs, obj)
  if attrs.x then
    local a, b = attrs.x:match("^%s*(.-)%s*,%s*(.-)%s*$")
    if not a then
      error("scholatex: <plot> x:{a, b} needs two bounds separated by a comma")
    end
    return num_bound(a, "x"), num_bound(b, "x")
  end
  -- déduire des abscisses du tableau : premières/dernières finies
  if not (obj and obj.x) then
    error("scholatex: <plot> needs an x:{a, b} window (or a referenced "
        .. "object carrying abscissas)")
  end
  local cells = {}
  for c in (obj.x .. "|"):gmatch("(.-)|") do
    c = U.trim(c)
    if c ~= "" then cells[#cells+1] = c end
  end
  -- première et dernière abscisse finies
  local lo, hi
  for _, c in ipairs(cells) do
    if not c:match("inf") then lo = lo or c; hi = c end
  end
  if not lo then
    error("scholatex: <plot> cannot infer a finite x window from the table; "
        .. "give x:{a, b} explicitly")
  end
  return num_bound(lo, "x"), num_bound(hi, "x")
end

-- ---------------------------------------------------------------------
return function(sl)
  sl.register_tag("plot", function(api, words, content)
    local parts = {}
    for k = 2, #words do parts[#parts+1] = words[k] end
    local attrs = parse_attrs(U.trim(table.concat(parts, " ")))

    -- résoudre l'objet référencé
    local ref = attrs._ref
    if not ref then
      error("scholatex: <plot> needs a function object, e.g. <plot k ...> "
          .. "after  let k = <fn ...>")
    end
    local obj = sl._objects and sl._objects[ref]
    if not obj then
      error("scholatex: <plot " .. ref .. "> refers to an object that is not "
          .. "defined; write  let " .. ref .. " = <fn ... expr:{...} ...>  first")
    end
    if not obj.expr then
      error("scholatex: <plot " .. ref .. "> needs the object to carry an "
          .. "expr:{...} (the formula to plot)")
    end

    -- nom de fonction et variable, pour les libellés et la traduction
    local fn, var = "f", "x"
    if obj.name then
      local f, v = obj.name:match("^%s*([%a]%w*)%s*%(%s*([%a]%w*)%s*%)%s*$")
      if f then fn, var = f, v
      else fn = obj.name:match("^%s*([%a]%w*)%s*$") or "f" end
    end

    local body = translate(U.trim(obj.expr), var)

    local xa, xb = hwindow(attrs, obj)
    local samples = attrs.samples or "100"

    local yclip = ""
    local axisopts = {}
    axisopts[#axisopts+1] = "width=10cm, height=7cm"
    axisopts[#axisopts+1] = "axis lines=middle"
    -- A curve crossing an axis would otherwise run straight over the tick
    -- numbers sitting on that axis (visible on a function with a pole, where
    -- a branch sweeps past x=-2 and blots out the label). A thin white
    -- backing plate behind each tick label keeps the number readable without
    -- moving the axes off centre.
    axisopts[#axisopts+1] = "every tick label/.append style={"
                         .. "fill=white, inner sep=1pt, font=\\footnotesize}"
    -- Run each axis line a touch past its last graduation so the arrow tip
    -- clears the final tick number, the way a textbook axis does, instead of
    -- the arrow sitting right on top of it. shorten >=-6pt lengthens the
    -- arrowed end of the line by 6pt; it touches neither the plot domain, the
    -- ticks, nor the window, so it is safe even when the bounds are pi-based
    -- expressions rather than plain numbers.
    axisopts[#axisopts+1] = "axis line style={shorten >=-6pt}"
    axisopts[#axisopts+1] = "xlabel=$" .. var .. "$"
    axisopts[#axisopts+1] = "ylabel=$" .. fn .. "(" .. var .. ")$"
    axisopts[#axisopts+1] = "xmin=" .. xa .. ", xmax=" .. xb
    if attrs.y then
      local c, d = attrs.y:match("^%s*(.-)%s*,%s*(.-)%s*$")
      if not c then
        error("scholatex: <plot> y:{c, d} needs two bounds separated by a comma")
      end
      local ct, dt = U.trim(c), U.trim(d)
      axisopts[#axisopts+1] = "ymin=" .. ct .. ", ymax=" .. dt
      -- restreindre Y au-delà de la fenêtre pour couper aux pôles, seulement
      -- si les deux bornes sont numériques (sinon pi/2 ou une expression
      -- ferait planter la multiplication ; pgfplots clippe alors à ymin/ymax)
      local cn, dn = tonumber(ct), tonumber(dt)
      if cn and dn then
        axisopts[#axisopts+1] = "restrict y to domain=" .. (cn * 3) .. ":" .. (dn * 3)
      end
    end
    axisopts[#axisopts+1] = "samples=" .. samples
    axisopts[#axisopts+1] = "unbounded coords=jump"

    local opt = table.concat(axisopts, ", ")

    local out = {}
    out[#out+1] = "\\begin{center}\\begin{tikzpicture}"
    out[#out+1] = "\\begin{axis}[" .. opt .. "]"
    out[#out+1] = "\\addplot[Blue, thick, domain=" .. xa .. ":" .. xb
              .. "] {" .. body .. "};"
    out[#out+1] = "\\end{axis}"
    out[#out+1] = "\\end{tikzpicture}\\end{center}"

    api.raw('emit(' .. string.format("%q", table.concat(out)) .. ")\n")
  end)
end
