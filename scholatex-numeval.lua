-- scholatex-numeval --- the single source of truth for the mathematical
-- functions available when scholatex COMPUTES a number, and for how that
-- number is rounded on the page.
--
-- Two surfaces need these functions and they must agree exactly:
--   * the #{...} interpolation, whose expression is Lua run in the body
--     environment (scholatex.lua injects the names listed here);
--   * the plot / cobweb numeric compiler (scholatex-plot.lua maps the
--     same words to the same Lua).
-- Defining them once here is what keeps  #{sin(pi/6)}  and a plotted
-- sin(x) referring to the very same function.
--
-- Angle convention: RADIANS by default -- the universal mathematical
-- convention, what Lua and pgfplots already use, and what the
-- trigonometric circle reasons in (fractions of pi). The degree variants
-- sind/cosd/... are there for the occasions (lower secondary school) when
-- an angle is naturally written in degrees.

local N = {}

-- ---------------------------------------------------------------------
-- The function library. Each entry maps a scholatex name to the Lua
-- expression that implements it. Lua 5.3 gives us sin/cos/tan/asin/acos/
-- atan/sinh/cosh/tanh/exp/log/sqrt/abs/floor/ceil directly; the rest are
-- composed from them. atan takes two arguments in Lua (atan(y, x)), which
-- also serves the one-argument case.
-- ---------------------------------------------------------------------
local D = "(math.pi/180)"   -- degree->radian factor, spelled once (parenthesised
                            -- so  x/D  and  x*D  keep the intended grouping)

N.FUNCS = {
  -- circular, radians
  sin = "math.sin", cos = "math.cos", tan = "math.tan",
  cot = "(function(t) return math.cos(t)/math.sin(t) end)",
  sec = "(function(t) return 1/math.cos(t) end)",
  csc = "(function(t) return 1/math.sin(t) end)",
  -- circular, degrees (sind(30) = 0.5)
  sind = "(function(t) return math.sin(t*" .. D .. ") end)",
  cosd = "(function(t) return math.cos(t*" .. D .. ") end)",
  tand = "(function(t) return math.tan(t*" .. D .. ") end)",
  -- inverse circular; the d-suffixed return degrees
  arcsin = "math.asin", arccos = "math.acos", arctan = "math.atan",
  asin = "math.asin", acos = "math.acos", atan = "math.atan",
  arcsind = "(function(t) return math.asin(t)/" .. D .. " end)",
  arccosd = "(function(t) return math.acos(t)/" .. D .. " end)",
  arctand = "(function(t) return math.atan(t)/" .. D .. " end)",
  -- hyperbolic
  sinh = "math.sinh", cosh = "math.cosh", tanh = "math.tanh",
  coth = "(function(t) return math.cosh(t)/math.sinh(t) end)",
  sech = "(function(t) return 1/math.cosh(t) end)",
  csch = "(function(t) return 1/math.sinh(t) end)",
  -- inverse hyperbolic, from their closed forms
  arcsinh = "(function(t) return math.log(t+math.sqrt(t*t+1)) end)",
  arccosh = "(function(t) return math.log(t+math.sqrt(t*t-1)) end)",
  arctanh = "(function(t) return 0.5*math.log((1+t)/(1-t)) end)",
  asinh = "(function(t) return math.log(t+math.sqrt(t*t+1)) end)",
  acosh = "(function(t) return math.log(t+math.sqrt(t*t-1)) end)",
  atanh = "(function(t) return 0.5*math.log((1+t)/(1-t)) end)",
  -- exponential and logarithms
  exp = "math.exp",
  ln  = "math.log",
  log = "(function(v) return math.log(v)/math.log(10) end)",     -- base 10
  log2 = "(function(v) return math.log(v)/math.log(2) end)",
  logb = "(function(v, b) return math.log(v)/math.log(b) end)",  -- log_b(v)
  -- algebraic / rounding
  sqrt = "math.sqrt", cbrt = "(function(v) return (v<0 and -1 or 1)*math.abs(v)^(1/3) end)",
  abs = "math.abs", sign = "(function(v) return v>0 and 1 or v<0 and -1 or 0 end)",
  floor = "math.floor", ceil = "math.ceil",
  round = "__round",   -- round(x) or round(x, d): see __round below
  min = "math.min", max = "math.max",
}

-- Lua 5.3 dropped math.sinh/cosh/tanh; provide them so the crate works on
-- 5.3 and 5.4 alike. LuaTeX ships 5.3.
N.PREAMBLE = table.concat({
  "local __mabs, __mexp, __mlog = math.abs, math.exp, math.log",
  "if not math.sinh then",
  "  math.sinh = function(x) return (__mexp(x)-__mexp(-x))/2 end",
  "  math.cosh = function(x) return (__mexp(x)+__mexp(-x))/2 end",
  "  math.tanh = function(x) local a,b=__mexp(x),__mexp(-x) return (a-b)/(a+b) end",
  "end",
  -- round(x, d): rounds to d decimals AND fixes the display precision to d,
  -- overriding the document-wide `precision`. It returns a tagged table so
  -- _show can honour the local choice; used bare in arithmetic it still
  -- behaves as the number (metatable __tonumber-like access via .v, and the
  -- numeric metamethods below).
  "local __roundmt",
  "local function __round(x, d)",
  "  d = d or 0",
  "  local m = 10 ^ d",
  "  local r = (x >= 0) and math.floor(x*m + 0.5)/m or -math.floor(-x*m + 0.5)/m",
  "  return setmetatable({v = r, d = d}, __roundmt)",
  "end",
  -- arithmetic on a rounded value unwraps to its number (so round(x,2)+1
  -- works); the result is a plain number, precision applies again.
  "local function __u(a) return type(a)=='table' and a.v or a end",
  "__roundmt = {",
  "  __add=function(a,b) return __u(a)+__u(b) end,",
  "  __sub=function(a,b) return __u(a)-__u(b) end,",
  "  __mul=function(a,b) return __u(a)*__u(b) end,",
  "  __div=function(a,b) return __u(a)/__u(b) end,",
  "  __pow=function(a,b) return __u(a)^__u(b) end,",
  "  __unm=function(a) return -__u(a) end,",
  "  __eq=function(a,b) return __u(a)==__u(b) end,",
  "  __lt=function(a,b) return __u(a)<__u(b) end,",
  "  __le=function(a,b) return __u(a)<=__u(b) end,",
  "  __tostring=function(a) return tostring(a.v) end,",
  "}",
  "local pi = math.pi; local e = math.exp(1)",
}, "\n") .. "\n"

-- Names bound to *values* (not functions) that #{...} may reference bare.
N.CONSTS = { pi = "math.pi", e = "math.exp(1)" }

-- ---------------------------------------------------------------------
-- Injection string for the #{...} body environment. Produces
--   local sin = math.sin; local cot = (function ...) ; ... local round = __round
-- so every function name resolves inside a user expression. Emitted once,
-- after N.PREAMBLE, by scholatex.lua's build_lua.
-- ---------------------------------------------------------------------
function N.inject_locals()
  local out = {}
  -- deterministic order keeps the generated code stable (easier to debug)
  local names = {}
  for k in pairs(N.FUNCS) do names[#names+1] = k end
  table.sort(names)
  for _, k in ipairs(names) do
    out[#out+1] = "local " .. k .. " = " .. N.FUNCS[k]
  end
  return N.PREAMBLE .. table.concat(out, "\n") .. "\n"
end

-- ---------------------------------------------------------------------
-- Display formatting for numbers the READER sees (measure labels, trig
-- projections, percentages...), as opposed to internal TikZ coordinates
-- which must keep full precision. This is the single place the document
-- `precision` is honoured across every module.
--
--   N.display(v [, sep [, fallback_dec]])
--
-- * v          the number (non-numbers pass through as tostring).
-- * sep        decimal separator to use (defaults to "."); modules that
--              know the lang pass "," / "{,}" as appropriate.
-- * fallback_dec  decimals to use when no document precision is set
--              (precision = -1). A module with a natural default (the pie
--              wanted 2, a measure wants 2) passes it; omitted means "print
--              as computed".
-- Trailing zeros are always dropped: 3.50 -> 3.5, 4.0 -> 4.
-- The active precision is read from N.doc_precision, set once per run by
-- scholatex.lua from sl.config.precision.
-- ---------------------------------------------------------------------
N.doc_precision = -1

function N.set_precision(p)
  N.doc_precision = (type(p) == "number") and p or -1
end

function N.display(v, sep, fallback_dec)
  sep = sep or "."
  if type(v) ~= "number" then
    if v == nil then return "" end
    return tostring(v)
  end
  local p = N.doc_precision
  if not p or p < 0 then p = fallback_dec end   -- may still be nil
  local s
  if p and p >= 0 then
    s = string.format("%." .. p .. "f", v)
    if s:find("%.") then s = s:gsub("0+$", ""):gsub("%.$", "") end
  else
    s = tostring(v)
  end
  return (s:gsub("%.", sep, 1))
end


return N
