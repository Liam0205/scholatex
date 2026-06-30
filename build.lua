-- build.lua -- l3build configuration for scholatex.
--
-- scholatex is a single-package, LuaLaTeX-only document class with no .dtx
-- source. Build inputs are the .cls + 15 .lua modules already at the repo
-- root; install layout mirrors the manual-install instructions in
-- README.md ("~/texmf/tex/luatex/latex/scholatex/").
--
-- l3build verbs we wire up:
--   l3build doc      -- rebuild scholatex.pdf from scholatex.tex
--   l3build check    -- run the .lvt corpus under luatex
--   l3build save     -- regenerate .tlg baselines after a deliberate change
--   l3build ctan     -- assemble the CTAN zip
--   l3build install  -- copy installfiles into local TDS for ad-hoc testing
--   l3build upload   -- POST to ctan.org's upload form (used by CTAN workflow)

module = "scholatex"

-- Package and TDS layout ------------------------------------------------
packtdszip = true
tdsroot    = "luatex"

-- No .dtx; sources are .cls and .lua already at the root.
unpackfiles  = { }
sourcefiles  = { "scholatex.cls", "scholatex.lua", "scholatex-*.lua" }
installfiles = sourcefiles

-- Documentation -------------------------------------------------------------
typesetfiles = { "scholatex.tex" }
typesetexe   = "lualatex"

docfiles = {
  "README.md",
  "CHANGELOG.md",
  "LICENSE",
}

-- Testing -----------------------------------------------------------------
testfiledir  = "./testfiles"
stdengine    = "luatex"
checkengines = { "luatex" }
checkformat  = "latex"

-- The class itself reads its own source via tex.jobname during
-- \AtBeginDocument, so every test must be invoked with -jobname matching
-- the .lvt's basename. l3build already does that by default.
checkruns    = 1

-- CTAN upload metadata ----------------------------------------------------
--
-- Consumed by `l3build ctan` (builds the zip) and `l3build upload` (POSTs
-- to ctan.org's web form). The uploader / email / note come from the
-- environment so they can be supplied via the CTAN workflow without
-- baking real names into git history.
uploadconfig = {
  pkg         = "scholatex",
  author      = "Gérard Dubard",
  uploader    = os.getenv("CTAN_UPLOADER") or "",
  email       = os.getenv("CTAN_EMAIL")    or "",
  license     = "gpl3+",
  summary     = "A tag-based language for print-ready teaching worksheets",
  description = [[scholatex is a LuaLaTeX document class that exposes a
small tag-based language for writing teaching worksheets — exams, drills,
problem sheets — without learning the LaTeX core. It ships a styling
vocabulary, a math mini-language, a declarative geometry block (<draw>),
and renderers for boxes, tables, function studies and grids.]],
  topic        = { "class", "luatex", "education", "maths-doc" },
  ctanPath     = "/macros/luatex/latex/scholatex",
  repository   = "https://github.com/gdubard/scholatex",
  bugtracker   = "https://github.com/gdubard/scholatex/issues",
  note         = os.getenv("CTAN_NOTE") or "",
  update       = true,
}

-- Version surfacing -----------------------------------------------------
-- Read `\ProvidesClass{scholatex}[<date> v<X.Y> ...]` from scholatex.cls
-- to populate uploadconfig.version automatically. Failing that, fall back
-- to "dev" so unconfigured local runs don't crash.
local function read_version()
  local f = io.open("scholatex.cls", "r")
  if not f then return "dev" end
  local body = f:read("*a"); f:close()
  return body:match("ProvidesClass{scholatex}%[[%d-]+%s+v([%w.+-]+)") or "dev"
end
uploadconfig.version = "v" .. read_version()
