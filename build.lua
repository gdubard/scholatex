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

-- Record lualatex's exit level in the baseline. Smoke tests (passing)
-- pin Compilation 1 = status 0; regression tests for deliberate failures
-- pin status != 0.
recordstatus = true

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
  topic        = { "class", "luatex", "teaching", "maths-doc" },
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

-- ────────────────────────────────────────────────────────────────────────
-- Baseline filter (whitelist)
-- ────────────────────────────────────────────────────────────────────────
--
-- l3build's normalize_log strips engine noise (dates, register numbers,
-- file paths) but happily keeps everything LaTeX prints in the preamble
-- and the begindocument hook chain -- font defaults, geometry verbose
-- output, pgfplots compat notices, etc. None of that is scholatex's
-- output; pinning it makes .tlg baselines fragile against LaTeX kernel
-- updates without buying us any actual regression coverage.
--
-- Whitelist by signature: scholatex's user-visible output has exactly
-- three shapes, all easy to grep for:
--
--   * "scholatex:" / "scholatex.cls:"        -- error / warning text
--                                              (~126 error sites in src)
--   * "./scholatex.lua:..." / "./scholatex-*.lua:..."
--                                              -- stack trace frames after
--                                              -- a Lua-level error
--   * "Class scholatex Warning:"              -- \ClassWarning output
--                                              -- (B3 truncation warn)
--
-- Everything else in the body of the .tlg becomes documentation noise
-- and is dropped. The l3build header / footer ("This is a generated
-- file..." / the recordstatus block) is preserved verbatim, as are the
-- START-TEST-LOG / END-TEST-LOG markers.
--
-- Implementation: wrap rewrite_log so it calls l3build's original
-- normalisation first, then sweeps the output file dropping lines that
-- don't match the whitelist.

local _orig_rewrite_log = rewrite_log

-- Pattern table. A line is KEPT if any pattern matches.
local _keep_patterns = {
  "^scholatex:",                  -- main error / warning prefix
  "^scholatex%.cls:",             -- cls boot errors
  "^Class scholatex Warning",     -- \ClassWarning
  "^[^:]-scholatex%.lua:",        -- stack trace from scholatex.lua
  "^[^:]-scholatex%-[%w_-]+%.lua:", -- stack trace from scholatex-*.lua
  "^PIN:",                        -- typesetting invariant lines
                                  -- (\TYPE{PIN: ...} in pin-*.lvt files)
  "^This is a generated file",    -- l3build header line 1
  "^Don't change this file",      -- l3build header line 2
  "^%*+$",                        -- the recordstatus separator (***)
  "^Compilation %d+ of test file", -- the recordstatus body line
}

local function _scholatex_filter(path)
  local f = io.open(path, "r"); if not f then return end
  local kept = {}
  for line in f:lines() do
    local keep = false
    for _, pat in ipairs(_keep_patterns) do
      if line:match(pat) then keep = true; break end
    end
    if keep then kept[#kept + 1] = line end
  end
  f:close()
  f = io.open(path, "w"); if not f then return end
  for _, l in ipairs(kept) do f:write(l, "\n") end
  f:close()
end

function rewrite_log(source, result, engine, errlevels)
  local r = _orig_rewrite_log(source, result, engine, errlevels)
  _scholatex_filter(result)
  return r
end
