local M = {}

local GREEK = {
  alpha=true, beta=true, gamma=true, delta=true, epsilon=true, zeta=true,
  eta=true, theta=true, iota=true, kappa=true, lambda=true, mu=true, nu=true,
  xi=true, pi=true, rho=true, sigma=true, tau=true, phi=true, chi=true,
  psi=true, omega=true, Gamma=true, Delta=true, Theta=true, Lambda=true,
  Xi=true, Pi=true, Sigma=true, Phi=true, Psi=true, Omega=true,
  varepsilon=true, vartheta=true, varphi=true, varpi=true, varrho=true,
  varsigma=true, ell=true, hbar=true,
  partial=true, nabla=true,
}
local BIGOP = { sum="\\sum", prod="\\prod", int="\\int" }
local UNDEROP = { lim="\\lim" }
local FUNC = {
  sin=true, cos=true, tan=true, cot=true, sec=true, csc=true,
  arcsin=true, arccos=true, arctan=true,
  sinh=true, cosh=true, tanh=true, coth=true,
  ln=true, log=true, exp=true, det=true, dim=true, gcd=true,
  deg=true, ker=true, arg=true, hom=true, max=true, min=true, sup=true,
}
local INTOP = {
  int        = { pre="",                multi=true,  contour=false },
  contourint = { pre="\\oint",          multi=false, contour=true  },
  pvint      = { pre="\\mathrm{p.v.}\\!\\int", multi=false, contour=false },
  meanint    = { pre="\\fint",          multi=false, contour=false },
}

-- Number sets (blackboard bold). Doubled keyword -> \mathbb{Letter}, the
-- ASCIIMath convention: NN, ZZ, DD, QQ, RR, CC and a few advanced ones.
-- Doubling avoids any clash with a one-letter variable named N, R, ...
local BBSET = {
  NN = "\\mathbb{N}", ZZ = "\\mathbb{Z}", DD = "\\mathbb{D}",
  QQ = "\\mathbb{Q}", RR = "\\mathbb{R}", CC = "\\mathbb{C}",
  PP = "\\mathbb{P}", KK = "\\mathbb{K}", HH = "\\mathbb{H}",
  FF = "\\mathbb{F}", EE = "\\mathbb{E}", UU = "\\mathbb{U}",
}

-- Word-keyword symbols: quantifiers, logical connectives, set relations,
-- common dots and miscellaneous notation. One canonical word per symbol.
-- These are bare words (no parentheses); a trailing space keeps spacing
-- correct when the next atom follows immediately.
local SYM = {
  -- Quantifiers (negation is written !exists, not a separate word)
  forall   = "\\forall ",   exists  = "\\exists ",
  -- Logical connectives
  ["and"]  = "\\land ",      ["or"]  = "\\lor ",
  land     = "\\land ",      lor     = "\\lor ",      lnot    = "\\lnot ",
  neg      = "\\neg ",       xorsym  = "\\oplus ",
  implies  = "\\implies ",   iff     = "\\iff ",      impliedby = "\\impliedby ",
  -- Set membership / relations (negation is written !in, !subset, ...)
  ["in"]   = "\\in ",        ni      = "\\ni ",
  subset   = "\\subset ",    supset  = "\\supset ",
  subseteq = "\\subseteq ",  supseteq= "\\supseteq ",
  cup      = "\\cup ",       cap     = "\\cap ",
  setminus = "\\setminus ",  emptyset= "\\varnothing ",
  union    = "\\cup ",       inter   = "\\cap ",       mid     = "\\mid ",
  -- Arrows (as words; symbolic forms -> => <=> also exist)
  to       = "\\to ",        mapsto  = "\\mapsto ",
  -- Relations & misc
  approx   = "\\approx ",    equiv   = "\\equiv ",    propto  = "\\propto ",
  sim      = "\\sim ",       cong    = "\\cong ",
  similar  = "\\sim ",       congruent = "\\cong ",
  times    = "\\times ",     cdot    = "\\cdot ",     ddiv    = "\\div ",
  pm       = "\\pm ",        mp      = "\\mp ",       ast     = "\\ast ",
  circop   = "\\circ ",      star    = "\\star ",     bullet  = "\\bullet ",
  ldots    = "\\ldots ",     cdots   = "\\cdots ",    vdots   = "\\vdots ",
  ddots    = "\\ddots ",     dots    = "\\dots ",
  perp     = "\\perp ",      parallel= "\\mathbin{/\\!/}",
  perpendicular = "\\perp ",
  rightangle = "\\rightangle ", parallelogram = "\\scholatexparallelogram ",
  nparallel = "\\mathbin{/\\!/\\mkern-12.5mu\\backslash}",
  Real     = "\\Re ",        Imag    = "\\Im ",
  aleph    = "\\aleph ",     wp      = "\\wp ",
  Top      = "\\top ",       Bot     = "\\bot ",      models  = "\\models ",
  vdash    = "\\vdash ",     thus    = "\\therefore ", because = "\\because ",
}

-- Negation prefix !word. Native amssymb negated glyphs where they exist
-- (they render far better than a struck-through \not), else \not<symbol>.
-- !=  is handled earlier as \neq in the main loop, before this fires.
local NEG = {
  ["in"]   = "\\notin ",     exists  = "\\nexists ",
  subset   = "\\not\\subset ", supset = "\\not\\supset ",
  subseteq = "\\nsubseteq ", supseteq= "\\nsupseteq ",
  equiv    = "\\not\\equiv ", sim    = "\\nsim ",      cong = "\\ncong ",
  parallel = "\\mathbin{/\\!/\\mkern-12.5mu\\backslash}", models  = "\\nvDash ",    vdash = "\\nvdash ",
  approx   = "\\not\\approx ",
}

-- Functions taking one parenthesised atom and wrapping it with a fence or
-- accent (modelled on abs/norm/vec). name -> { open, close }.
local FENCE = {
  abs   = { "\\left|",         "\\right|"        },
  norm  = { "\\left\\|",       "\\right\\|"      },
  floor = { "\\left\\lfloor ", "\\right\\rfloor" },
  ceil  = { "\\left\\lceil ",  "\\right\\rceil"  },
  round = { "\\left\\lfloor ", "\\right\\rceil"  },
  set   = { "\\left\\{",       "\\right\\}"      },
  abr   = { "\\left\\langle ", "\\right\\rangle" },  -- angle brackets / inner product
}

-- Accents over one parenthesised atom. bar/not give the SAME overline rule,
-- named by intention: bar = generic (conjugate, mean, segment, closure),
-- not = logical negation. hat/tilde/dot/ddot complete the usual set.
local ACCENT = {
  bar      = "\\overline",         -- conjugate / mean / closure
  ["not"]  = "\\overline",         -- logical negation: not(A cup B)
  conj     = "\\overline",         -- explicit synonym for the complex conjugate
  vec      = "\\overrightarrow",
  hat      = "\\widehat",
  tilde    = "\\widetilde",
  dotacc   = "\\dot",
  ddotacc  = "\\ddot",
  underbar = "\\underline",
}

-- Named operators set upright, taking their argument as ordinary maths:
-- name -> \operatorname{...}. Modelled on the built-in gcd/det/dim that LaTeX
-- already provides. The argument is whatever parenthesised group follows, run
-- back through the mini-language, so card(abs(x)) and ker(f) both behave.
local NAMED = {
  -- arithmetic & sets
  lcm  = "lcm",   sign = "sgn",   card = "card",
  -- linear algebra
  tr   = "tr",    rank = "rg",    ker  = "Ker",   im   = "Im",
  span = "Span",  com  = "com",   eigen= "Sp",    adj  = "adj",
  -- analysis / differential operators (named-operator convention)
  grad = "grad",  div  = "div",   curl = "rot",
}

-- Symbol operators applied WITHOUT parentheses: the Laplacian Delta f reads
-- like nabla f, not Delta(f). name -> symbol; the following atom is its
-- operand. lap(f) and lap f both work; the parentheses, if present, are the
-- operand's own grouping, not a function call.
local SYMOP = {
  lap = "\\Delta ",
}

-- Operators whose result is a fixed wrapper around one argument, but with a
-- non-operatorname rendering: powerset, expectations, etc. name -> function
-- that, given the already-cooked inner maths, returns the full string.
local WRAP1 = {
  powerset = function(a) return "\\mathcal{P}(" .. a .. ")" end,
  laplace  = function(a) return "\\mathcal{L}\\left\\{" .. a .. "\\right\\}" end,
  fourier  = function(a) return "\\mathcal{F}\\left\\{" .. a .. "\\right\\}" end,
  ilaplace = function(a) return "\\mathcal{L}^{-1}\\left\\{" .. a .. "\\right\\}" end,
  ifourier = function(a) return "\\mathcal{F}^{-1}\\left\\{" .. a .. "\\right\\}" end,
  transpose= function(a) return a .. "^{\\top}" end,
  inv      = function(a) return a .. "^{-1}" end,
  euler    = function(a) return "\\varphi(" .. a .. ")" end,
  mobius   = function(a) return "\\mu(" .. a .. ")" end,
  var      = function(a) return "\\operatorname{Var}(" .. a .. ")" end,
  std      = function(a) return "\\sigma(" .. a .. ")" end,
  factorial= function(a) return a .. "!" end,
  poisson  = function(a) return "\\mathcal{P}\\left(" .. a .. "\\right)" end,
  -- Landau notation. o/O on their own stay variables; the asymptotic forms
  -- are the explicit words litO / bigO so nothing legitimate is captured.
  bigO     = function(a) return "O\\left(" .. a .. "\\right)" end,
  litO     = function(a) return "o\\left(" .. a .. "\\right)" end,
  -- geometry
  ortho    = function(a) return a .. "^{\\perp}" end,
}

-- Two-argument primitives keyed by name. Each gets {a, b} already cooked and
-- returns the full string. C(n,k)/A(n,k) only fire on EXACTLY two comma
-- arguments (checked at the call site), so C(t) stays a function call.
local TWOARG = {
  C   = function(a, b) return "\\binom{" .. a .. "}{" .. b .. "}" end,
  A   = function(a, b) return "A_{" .. a .. "}^{" .. b .. "}" end,
  cov = function(a, b) return "\\operatorname{Cov}(" .. a .. ", " .. b .. ")" end,
  range = function(a, b) return "\\lBrack " .. a .. ", " .. b .. "\\rBrack " end,
  normal = function(a, b) return "\\mathcal{N}\\left(" .. a .. ", " .. b .. "^{2}\\right)" end,
  binomial = function(a, b) return "\\mathcal{B}\\left(" .. a .. ", " .. b .. "\\right)" end,
  repart = function(a, b) return "F_{" .. a .. "}(" .. b .. ")" end,
  densite= function(a, b) return "f_{" .. a .. "}(" .. b .. ")" end,
  dirderiv = function(a, b) return "\\nabla_{" .. b .. "} " .. a end,
  -- geometry
  collinear = function(a, b) return "\\overrightarrow{" .. a .. "} \\mathbin{/\\!/} \\overrightarrow{" .. b .. "}" end,
  inner = function(a, b) return "\\left\\langle " .. a .. ", " .. b .. "\\right\\rangle" end,
  distance = function(a, b) return "d\\left(" .. a .. ", " .. b .. "\\right)" end,
  midpoint = function(a, b) return "I_{" .. a .. b .. "}" end,
  orthogonalprojection = function(a, b) return "p_{" .. a .. "}\\left(" .. b .. "\\right)" end,
}

function M.differential(num, den)
  local n_d = num == "d" or num:match("^d%a") or num:match("^d%^")
  local d_d = den:match("^d%a")
  if n_d and d_d then
    local function roman_d(x)
      return (x:gsub("^d", "\\mathrm{d}"))
    end
    return roman_d(num), roman_d(den)
  end
  if num:match("^\\partial") and den:match("^\\partial") then
    return num, den
  end
  return num, den
end

function M.mathlite(s)
  local n = #s
  local pos = 1

  local function skipws() while pos <= n and s:sub(pos,pos):match("%s") do pos = pos + 1 end end

  -- Removes one enclosing delimiter pair from a rendered atom: ordinary
  -- parentheses, the extensible \left( \right) pair (so a fraction lifted
  -- into a numerator does not keep redundant parentheses), or a brace group.
  -- Only the fraction builder uses it, where the surrounding \frac already
  -- supplies the grouping.
  local function strip_paren(t)
    local stripped = t:gsub("^\\left%((.*)\\right%)$", "%1")
    if stripped ~= t then return stripped end
    return (t:gsub("^%((.*)%)$", "%1"):gsub("^{(.*)}$", "%1"))
  end

  local read_atom, read_scripts

  -- Splits a raw argument string on its top-level commas, respecting nested
  -- () and {} (and $ math spans). Used by the multi-argument primitives so
  -- C(n, k) sees two arguments while C(f(x,y)) inside another call is not
  -- mis-split. Returns a list of trimmed argument strings.
  local function split_top_commas(str)
    local args, depth, start, k, m = {}, 0, 1, 1, #str
    while k <= m do
      local ch = str:sub(k, k)
      if ch == "(" or ch == "{" then depth = depth + 1
      elseif ch == ")" or ch == "}" then depth = depth - 1
      elseif ch == "," and depth == 0 then
        args[#args+1] = str:sub(start, k - 1):gsub("^%s+",""):gsub("%s+$","")
        start = k + 1
      end
      k = k + 1
    end
    args[#args+1] = str:sub(start):gsub("^%s+",""):gsub("%s+$","")
    return args
  end

  -- Position of the first separating '=' at bracket depth 0 in `str`, or nil.
  -- A sum/prod/lim/int body runs up to this '=', so that the right-hand side
  -- of an identity stays outside the operator. Two refinements over a plain
  -- find: a '=' nested in parentheses or braces (the X = k inside PP(X = k))
  -- is skipped, and a '=' that is part of a compound relation (<=, >=, !=,
  -- ==, =>) is not a separator, so a body ending in a comparison is kept whole.
  local function find_top_eq(str)
    local depth, k, m = 0, 1, #str
    while k <= m do
      local ch = str:sub(k, k)
      if ch == "(" or ch == "{" then depth = depth + 1
      elseif ch == ")" or ch == "}" then depth = depth - 1
      elseif ch == "=" and depth == 0 then
        local prev = str:sub(k - 1, k - 1)
        local nxt  = str:sub(k + 1, k + 1)
        if prev ~= "<" and prev ~= ">" and prev ~= "!" and prev ~= "="
           and nxt ~= "=" and nxt ~= ">" then
          return k
        end
      end
      k = k + 1
    end
    return nil
  end

  read_scripts = function(base)
    while true do
      skipws()
      local c = s:sub(pos, pos)
      if c ~= "^" and c ~= "_" then break end
      pos = pos + 1
      skipws()
      if s:sub(pos, pos) == "{" then
        local depth, j = 0, pos
        while j <= n do
          local d = s:sub(j, j)
          if d == "{" then depth = depth + 1
          elseif d == "}" then depth = depth - 1; if depth == 0 then break end end
          j = j + 1
        end
        base = base .. c .. s:sub(pos, j)
        pos = j + 1
      else
        local sign = ""
        local sc = s:sub(pos, pos)
        if sc == "-" or sc == "+" then sign = sc; pos = pos + 1 end
        local term = read_atom():gsub("^%((.*)%)$", "%1")
        base = base .. c .. "{" .. sign .. term .. "}"
      end
    end
    return base
  end

  read_atom = function()
    skipws()
    if pos > n then return "" end
    local c = s:sub(pos, pos)

    if c == "(" then
      local depth, j = 0, pos
      while j <= n do
        local d = s:sub(j,j)
        if d == "(" then depth = depth + 1
        elseif d == ")" then depth = depth - 1; if depth == 0 then break end end
        j = j + 1
      end
      local inner = s:sub(pos + 1, j - 1)
      pos = j + 1
      local body = M.mathlite(inner)
      -- A parenthesised group whose body carries a fraction grows to full
      -- fraction height, so flat parentheses read wrong -- conspicuously once
      -- a script is lifted onto the group, as in (a/b)^2. Such a body gets
      -- extensible \left( \right). A plain body (including a scalar root like
      -- 1-sqrt(2)) keeps ordinary parentheses, so intervals (a+b) and calls
      -- f(-x) are untouched.
      if body:find("\\frac", 1, true) then
        return "\\left(" .. body .. "\\right)"
      end
      return "(" .. body .. ")"
    end

    if c == "{" then
      local depth, j = 0, pos
      while j <= n do
        local d = s:sub(j, j)
        if d == "{" then depth = depth + 1
        elseif d == "}" then depth = depth - 1; if depth == 0 then break end end
        j = j + 1
      end
      local inner = s:sub(pos + 1, j - 1)
      pos = j + 1
      return "{" .. M.mathlite(inner) .. "}"
    end

    if c == "\\" then
      local j = pos + 1
      if s:sub(j,j):match("%a") then
        while j <= n and s:sub(j,j):match("%a") do j = j + 1 end
      else
        j = pos + 2
      end
      local cmd = s:sub(pos, j - 1)
      pos = j
      return cmd
    end

    if c:match("%a") then
      local word = s:sub(pos):match("^(%a+)")
      local after = pos + #word

      -- Number sets: doubled keyword -> blackboard bold.
      if BBSET[word] then
        pos = after; return BBSET[word]

      elseif word == "sqrt" and s:sub(after, after) == "(" then
        pos = after
        local arg = read_atom()
        arg = arg:gsub("^%((.*)%)$", "%1")
        return "\\sqrt{" .. arg .. "}"

      -- Geometric angle (French convention): angle(A) -> \widehat{A},
      -- angle(ABC) -> \widehat{ABC}. The angle is always the hat; the bare
      -- \angle glyph is not used.
      elseif word == "angle" and s:sub(after, after) == "(" then
        pos = after
        local arg = read_atom():gsub("^%((.*)%)$", "%1")
        return "\\widehat{" .. M.mathlite(arg) .. "}"

      elseif word == "angle" then
        error("scholatex: angle expects point names: "
            .. "angle(A) or angle(ABC)")

      -- Triangle on three points: triangle(ABC) -> the symbol then the points.
      elseif word == "triangle" and s:sub(after, after) == "(" then
        pos = after
        local arg = read_atom():gsub("^%((.*)%)$", "%1")
        return "\\bigtriangleup " .. M.mathlite(arg)

      -- Arc over two points: arc(AB) -> \overparen{AB}.
      elseif word == "arc" and s:sub(after, after) == "(" then
        pos = after
        local arg = read_atom():gsub("^%((.*)%)$", "%1")
        return "\\overparen{" .. M.mathlite(arg) .. "}"

      -- Coordinate system: frame(O, i, j) -> (O, \vec{i}, \vec{j}), origin bare
      -- and every basis vector arrowed; any number of basis vectors (2D, 3D...).
      elseif word == "frame" and s:sub(after, after) == "(" then
        pos = after
        local raw = read_atom():gsub("^%((.*)%)$", "%1")
        local a = split_top_commas(raw)
        if #a < 3 then
          error("scholatex: frame(O, i, j) needs an origin and at least two "
              .. "basis vectors; got " .. #a .. " argument(s)")
        end
        local parts = { M.mathlite(a[1]) }
        for k = 2, #a do
          parts[#parts+1] = "\\overrightarrow{" .. M.mathlite(a[k]) .. "}"
        end
        return "\\left(" .. table.concat(parts, ", ") .. "\\right)"

      -- Circle: circle(O, r) -> C(O, r) centre and radius, or circle(A, B, C)
      -- -> C(A, B, C) through three points. Two signatures, one rendering;
      -- 2 or 3 comma-separated arguments accepted.
      elseif word == "circle" and s:sub(after, after) == "(" then
        pos = after
        local raw = read_atom():gsub("^%((.*)%)$", "%1")
        local a = split_top_commas(raw)
        if #a ~= 2 and #a ~= 3 then
          error("scholatex: circle takes circle(O, r) (centre, radius) or "
              .. "circle(A, B, C) (three points); got " .. #a .. " argument(s)")
        end
        local parts = {}
        for k = 1, #a do parts[#parts+1] = M.mathlite(a[k]) end
        return "\\mathcal{C}\\left(" .. table.concat(parts, ", ") .. "\\right)"

      -- Vector components, inline: vector(x, y) -> (x, y). The arrow accent
      -- vec(...) is separate; this is the coordinate tuple.
      elseif word == "vector" and s:sub(after, after) == "(" then
        pos = after
        local raw = read_atom():gsub("^%((.*)%)$", "%1")
        local a = split_top_commas(raw)
        if #a < 2 then
          error("scholatex: vector(x, y) needs at least two components; got "
              .. #a)
        end
        local parts = {}
        for k = 1, #a do parts[#parts+1] = M.mathlite(a[k]) end
        return "\\left(" .. table.concat(parts, ", ") .. "\\right)"

      -- Vector components, column: colvec(x, y) -> a column vector.
      elseif word == "colvec" and s:sub(after, after) == "(" then
        pos = after
        local raw = read_atom():gsub("^%((.*)%)$", "%1")
        local a = split_top_commas(raw)
        if #a < 2 then
          error("scholatex: colvec(x, y) needs at least two components; got "
              .. #a)
        end
        local parts = {}
        for k = 1, #a do parts[#parts+1] = M.mathlite(a[k]) end
        return "\\begin{pmatrix}" .. table.concat(parts, " \\\\ ")
            .. "\\end{pmatrix}"

      -- Orthonormal coordinate system: same as frame, set in an orthonormal
      -- basis; rendered identically (the orthonormality is a property, not a
      -- different notation), kept as a distinct name for intent.
      elseif word == "orthoframe" and s:sub(after, after) == "(" then
        pos = after
        local raw = read_atom():gsub("^%((.*)%)$", "%1")
        local a = split_top_commas(raw)
        if #a < 3 then
          error("scholatex: orthoframe(O, i, j) needs an origin and at least "
              .. "two basis vectors; got " .. #a .. " argument(s)")
        end
        local parts = { M.mathlite(a[1]) }
        for k = 2, #a do
          parts[#parts+1] = "\\overrightarrow{" .. M.mathlite(a[k]) .. "}"
        end
        return "\\left(" .. table.concat(parts, ", ") .. "\\right)"

      -- Accents over one atom: bar/not/conj/vec/hat/tilde/dotacc/ddotacc.
      -- Checked before FENCE and SYM so not( is the overline, not the sign.
      elseif ACCENT[word] and s:sub(after, after) == "(" then
        pos = after
        local arg = read_atom():gsub("^%((.*)%)$", "%1")
        local rendered = ACCENT[word] .. "{" .. arg .. "}"
        if word == "vec" then
          local save = pos
          skipws()
          local opc = s:sub(pos, pos)
          if (opc == "." or opc == "^") then
            local q = pos + 1
            while q <= n and s:sub(q, q):match("%s") do q = q + 1 end
            if s:sub(q, q + 3) == "vec(" then
              pos = q + 3
              local rhs = read_atom():gsub("^%((.*)%)$", "%1")
              local glue = (opc == ".") and " \\cdot " or " \\wedge "
              return rendered .. glue .. "\\overrightarrow{" .. rhs .. "}"
            end
          end
          pos = save
        end
        return rendered

      -- Fences over one atom: abs/norm/floor/ceil/round/set/abr.
      elseif FENCE[word] and s:sub(after, after) == "(" then
        pos = after
        local arg = read_atom():gsub("^%((.*)%)$", "%1")
        if word == "set" then
          arg = arg:gsub("%s*|%s*", " \\mid ")
        end
        return FENCE[word][1] .. arg .. FENCE[word][2]

      -- Named upright operators: ker(f), rank(A), div(F), lcm(a,b)...
      -- The whole parenthesised group is kept and re-cooked, so the argument
      -- may itself be any maths. lap renders as \Delta (a symbol, not an
      -- operatorname), handled by the leading-backslash check.
      elseif SYMOP[word] then
        -- Delta f : the symbol prefixes the atom that follows. A bare operand
        -- (a single variable, lap f or lap(f)) needs no parentheses -> Delta f.
        -- A compound operand keeps grouping parentheses, so lap(x^2+y^2) is
        -- Delta(x^2+y^2), not Delta x^2 + y^2 with the +y^2 escaping.
        pos = after
        skipws()
        local operand = read_atom()
        local bare = operand:gsub("^%((.*)%)$", "%1")
        -- "simple" = a single token: a variable, a Greek command, or one
        -- carrying a script. Anything with a top-level +, -, etc. is compound
        -- and keeps its fence so the operator does not leak past it.
        local trimmed = bare:gsub("%s+$", "")
        if trimmed:match("^\\?%a[%w]*$")
           or trimmed:match("^\\?%a[%w]*%^?_?{?[%w}]*$") then
          return SYMOP[word] .. bare
        end
        return SYMOP[word] .. "\\left(" .. bare .. "\\right)"

      elseif NAMED[word] and s:sub(after, after) == "(" then
        pos = after
        local arg = read_atom():gsub("^%((.*)%)$", "%1")
        local cooked = M.mathlite(arg)
        local op = NAMED[word]
        if op:sub(1, 1) == "\\" then
          return op .. "\\left(" .. cooked .. "\\right)"
        end
        return "\\operatorname{" .. op .. "}\\left(" .. cooked .. "\\right)"

      -- One-argument wrappers with a bespoke rendering: powerset, transpose,
      -- inv, laplace, fourier, euler, mobius, var, std, factorial.
      elseif WRAP1[word] and s:sub(after, after) == "(" then
        pos = after
        local arg = read_atom():gsub("^%((.*)%)$", "%1")
        return WRAP1[word](M.mathlite(arg))

      -- Taylor expansion template (form, not computation): taylor(f, x, a, n).
      elseif word == "taylor" and s:sub(after, after) == "(" then
        pos = after
        local raw = read_atom():gsub("^%((.*)%)$", "%1")
        local a = split_top_commas(raw)
        if #a ~= 4 then
          error("scholatex: taylor(f, x, a, n) needs four arguments "
              .. "(function, variable, point, order); got " .. #a)
        end
        local f, x, pt, ord =
          M.mathlite(a[1]), M.mathlite(a[2]), M.mathlite(a[3]), M.mathlite(a[4])
        return f .. "(" .. pt .. ")"
            .. "+" .. f .. "'(" .. pt .. ")(" .. x .. "-" .. pt .. ")"
            .. "+\\dots+\\dfrac{" .. f .. "^{(" .. ord .. ")}(" .. pt .. ")}{"
            .. ord .. "!}(" .. x .. "-" .. pt .. ")^{" .. ord .. "}"
            .. "+o\\left((" .. x .. "-" .. pt .. ")^{" .. ord .. "}\\right)"

      -- Jacobian / Hessian templates: jacobian(f, n), hessian(f, n).
      elseif (word == "jacobian" or word == "hessian")
             and s:sub(after, after) == "(" then
        pos = after
        local raw = read_atom():gsub("^%((.*)%)$", "%1")
        local a = split_top_commas(raw)
        if #a ~= 2 then
          error("scholatex: " .. word .. "(f, n) needs two arguments "
              .. "(function, dimension); got " .. #a)
        end
        local f, nn = M.mathlite(a[1]), M.mathlite(a[2])
        if word == "jacobian" then
          return "\\left(\\dfrac{\\partial " .. f .. "_{i}}{\\partial x_{j}}"
              .. "\\right)_{1\\le i,j\\le " .. nn .. "}"
        end
        return "\\left(\\dfrac{\\partial^{2} " .. f
            .. "}{\\partial x_{i}\\,\\partial x_{j}}"
            .. "\\right)_{1\\le i,j\\le " .. nn .. "}"

      -- Surface / volume integrals: surfint(S), volint(V), flux(F, S).
      elseif word == "surfint" and s:sub(after, after) == "(" then
        pos = after
        local arg = read_atom():gsub("^%((.*)%)$", "%1")
        return "\\oiint_{" .. M.mathlite(arg) .. "}"
      elseif word == "volint" and s:sub(after, after) == "(" then
        pos = after
        local arg = read_atom():gsub("^%((.*)%)$", "%1")
        return "\\iiint_{" .. M.mathlite(arg) .. "}"
      elseif word == "flux" and s:sub(after, after) == "(" then
        pos = after
        local raw = read_atom():gsub("^%((.*)%)$", "%1")
        local a = split_top_commas(raw)
        local F = M.mathlite(a[1] or "")
        local S = M.mathlite(a[2] or "")
        return "\\iint_{" .. S .. "} " .. F
            .. "\\cdot\\mathrm{d}\\overrightarrow{S}"

      -- Two-argument primitives: C(n,k), A(n,k), cov(X,Y), range(1,n)...
      -- C and A ONLY become binom/arrangement on EXACTLY two comma arguments,
      -- so C(t) and A(x) stay ordinary function calls.
      -- Scalar triple product: triple(u, v, w) -> [u, v, w] with arrows.
      elseif word == "triple" and s:sub(after, after) == "(" then
        pos = after
        local raw = read_atom():gsub("^%((.*)%)$", "%1")
        local a = split_top_commas(raw)
        if #a ~= 3 then
          error("scholatex: triple(u, v, w) needs three arguments "
              .. "(three vectors); got " .. #a)
        end
        return "\\left[\\overrightarrow{" .. M.mathlite(a[1])
            .. "}, \\overrightarrow{" .. M.mathlite(a[2])
            .. "}, \\overrightarrow{" .. M.mathlite(a[3]) .. "}\\right]"

      elseif TWOARG[word] and s:sub(after, after) == "(" then
        pos = after
        local raw = read_atom():gsub("^%((.*)%)$", "%1")
        local a = split_top_commas(raw)
        if #a == 2 then
          return TWOARG[word](M.mathlite(a[1]), M.mathlite(a[2]))
        end
        -- not exactly two arguments: ordinary function call, e.g. C(t), A(x).
        -- The group is already read; re-cook it and rebuild name(group).
        return word .. "(" .. M.mathlite(raw) .. ")"

      -- Decorated arrow with text underneath: arrow(n to +inf) ->
      -- a long rightarrow with the limit prose set under it.
      elseif word == "arrow" and s:sub(after, after) == "(" then
        pos = after
        local sub = read_atom():gsub("^%((.*)%)$", "%1")
        sub = M.mathlite(sub)
        return "\\mathrel{\\underset{" .. sub .. "}{\\longrightarrow}}"

      elseif UNDEROP[word] and s:sub(after, after) == "(" then
        pos = after
        local grp = read_atom():gsub("^%((.*)%)$", "%1")
        grp = grp:gsub("%->", "\\to ")
        local rest = s:sub(pos)
        local body_raw, tail = rest, ""
        local eqpos = find_top_eq(rest)
        if eqpos then body_raw = rest:sub(1, eqpos - 1); tail = rest:sub(eqpos) end
        pos = n + 1
        local body = M.mathlite(body_raw:gsub("^%s+",""):gsub("%s+$",""))
        local op = "{\\displaystyle " .. UNDEROP[word] .. "\\limits_{"
          .. M.mathlite(grp:gsub("^%s+",""):gsub("%s+$","")) .. "} " .. body .. "}"
        return op .. (tail ~= "" and (" " .. M.mathlite(tail)) or "")

      elseif INTOP[word] and s:sub(after, after) == "(" then
        pos = after
        local spec = read_atom():gsub("^%((.*)%)$", "%1")
        local rest = s:sub(pos)
        local body_raw, tail = rest, ""
        local eqpos = find_top_eq(rest)
        if eqpos then
          body_raw = rest:sub(1, eqpos - 1)
          tail = rest:sub(eqpos)
        end
        pos = n + 1
        local body = M.mathlite(body_raw:gsub("^%s+",""):gsub("%s+$",""))
        local op = INTOP[word]
        local domains = {}
        for piece in (spec .. ";"):gmatch("(.-);") do
          domains[#domains+1] = piece:gsub("^%s+",""):gsub("%s+$","")
        end
        if #domains == 0 then domains = { spec } end
        local symbols, diffs = {}, {}
        for _, dom in ipairs(domains) do
          local var, lo, hi = dom:match("^(%S+)%s*=%s*(.-)%s*,%s*(.-)%s*$")
          if var then
            symbols[#symbols+1] = "\\int_{" .. lo .. "}^{" .. hi .. "}"
            table.insert(diffs, 1, "\\,\\mathrm{d}" .. var)
          elseif dom:match("^%l$") then
            symbols[#symbols+1] = "\\int"
            table.insert(diffs, 1, "\\,\\mathrm{d}" .. dom)
          else
            symbols[#symbols+1] = "\\iint_{" .. dom .. "}"
            table.insert(diffs, 1, "\\,\\mathrm{d}\\omega")
          end
        end
        local head
        if op.contour then
          head = op.pre .. "_{" .. spec .. "}"
          diffs = {}
          local v = spec:match("^%a$") and spec or "z"
          diffs[1] = "\\,\\mathrm{d}" .. (spec:match("^%l$") and spec or "z")
        elseif op.pre ~= "" then
          local var, lo, hi = spec:match("^(%S+)%s*=%s*(.-)%s*,%s*(.-)%s*$")
          if var then
            head = op.pre .. "_{" .. lo .. "}^{" .. hi .. "}"
            diffs = { "\\,\\mathrm{d}" .. var }
          else
            head = op.pre .. (spec:match("^%l$") and "" or ("_{" .. spec .. "}"))
            diffs = { "\\,\\mathrm{d}" .. (spec:match("^%l$") and spec or "\\omega") }
          end
        else
          head = table.concat(symbols)
        end
        return "{\\displaystyle " .. head .. " " .. body .. table.concat(diffs) .. "}" .. (tail ~= "" and (" " .. M.mathlite(tail)) or "")

      elseif BIGOP[word] and s:sub(after, after) == "(" then
        pos = after
        local grp = read_atom()
        grp = grp:gsub("^%((.*)%)$", "%1")
        local lo, hi = grp:match("^(.-),(.*)$")
        local sub
        if lo then
          sub = BIGOP[word] .. "_{" .. M.mathlite(lo:gsub("^%s+",""):gsub("%s+$",""))
              .. "}^{" .. M.mathlite(hi:gsub("^%s+",""):gsub("%s+$","")) .. "}"
        else
          sub = BIGOP[word] .. "_{" .. M.mathlite(grp) .. "}"
        end
        local rest = s:sub(pos)
        local body_raw, tail = rest, ""
        local eqpos = find_top_eq(rest)
        if eqpos then body_raw = rest:sub(1, eqpos - 1); tail = rest:sub(eqpos) end
        pos = n + 1
        local body = M.mathlite(body_raw:gsub("^%s+",""):gsub("%s+$",""))
        return "{\\displaystyle " .. sub .. " " .. body .. "}"
          .. (tail ~= "" and (" " .. M.mathlite(tail)) or "")

      elseif FUNC[word] then
        pos = after
        if s:sub(pos, pos) == "(" then
          local arg = read_atom()
          return "\\" .. word .. arg
        end
        return "\\" .. word .. " "

      elseif word == "inf" then
        pos = after; return "\\infty "

      -- Congruence modulus: a equiv b mod n -> a \equiv b \pmod{n}. The word
      -- mod takes the next atom as its modulus.
      elseif word == "mod" then
        pos = after
        skipws()
        local m = read_atom():gsub("^%((.*)%)$", "%1")
        return "\\pmod{" .. M.mathlite(m) .. "}"

      -- Word-keyword symbols (quantifiers, connectives, relations, dots).
      elseif SYM[word] then
        pos = after; return SYM[word]

      elseif GREEK[word] then
        pos = after; return "\\" .. word .. " "

      else
        pos = after; return word
      end
    end

    if c:match("%d") then
      local num = s:sub(pos):match("^([%d.]+)")
      pos = pos + #num
      if M.decsep and M.decsep ~= "." then
        num = num:gsub("%.", M.decsep)
      end
      return num
    end

    pos = pos + 1
    return c
  end

  local out = {}
  while pos <= n do
    skipws()
    if pos > n then break end
    local c  = s:sub(pos, pos)
    local c2 = s:sub(pos + 1, pos + 1)
    local c3 = s:sub(pos + 2, pos + 2)

    -- Multi-character symbolic operators, longest match first so that
    -- <=> and <-> win over <= and <- , and => / -> win over = , - and < .
    if c == "<" and c2 == "=" and c3 == ">" then
      out[#out+1] = " \\Leftrightarrow "; pos = pos + 3
    elseif c == "<" and c2 == "-" and c3 == ">" then
      out[#out+1] = " \\leftrightarrow "; pos = pos + 3
    elseif c == "=" and c2 == ">" then
      out[#out+1] = " \\Rightarrow "; pos = pos + 2
    elseif c == "<" and c2 == "=" then
      out[#out+1] = " \\leq "; pos = pos + 2
    elseif c == ">" and c2 == "=" then
      out[#out+1] = " \\geq "; pos = pos + 2
    elseif c == "-" and c2 == ">" then
      out[#out+1] = " \\to "; pos = pos + 2
    elseif c == "<" and c2 == "-" then
      out[#out+1] = " \\leftarrow "; pos = pos + 2
    elseif c == "!" and c2 == "=" then
      out[#out+1] = " \\neq "; pos = pos + 2
    elseif c == "\194" and c2 == "\176" then
      out[#out+1] = "^{\\circ}"; pos = pos + 2
    elseif c == "!" and c2:match("%a") then
      -- Negation prefix: !word negates the relation/quantifier that follows.
      local word = s:sub(pos + 1):match("^(%a+)")
      if NEG[word] then
        out[#out+1] = " " .. NEG[word]
        pos = pos + 1 + #word
      elseif SYM[word] then
        -- No native negated glyph: strike the symbol with \not.
        out[#out+1] = " \\not" .. SYM[word]
        pos = pos + 1 + #word
      else
        error("scholatex: '!" .. word .. "' is not a negatable symbol; "
            .. "use ! before a relation or quantifier (e.g. !in, !exists, "
            .. "!subset), or != for 'not equal'")
      end
    elseif c == "+" and c2 == "-" then
      out[#out+1] = " \\pm "; pos = pos + 2
    elseif c == "-" and c2 == "+" then
      out[#out+1] = " \\mp "; pos = pos + 2
    elseif c == "*" then
      out[#out+1] = " \\times "; pos = pos + 1
    elseif c == "/" then
      local num = table.remove(out) or ""
      -- Differential of order n: the source d^2y reads as two atoms, d^{2}
      -- then y, because ^ binds to the atom on its left (the language's one
      -- rule). At the fraction bar, rejoin them so the numerator is the whole
      -- d^{2}y, letting M.differential set the upright d. Same for a single
      -- d y written with a space. Only fires when what precedes is exactly a
      -- bare d (optionally with a numeric power) and the den starts with d.
      local prev = out[#out]
      if (num:match("^%a") or num:match("^\\")) and prev
         and (prev == "d" or prev:match("^d%^{%d+}$")) then
        table.remove(out)
        num = prev .. num
      end
      num = strip_paren(num)
      pos = pos + 1
      local den = read_scripts(read_atom())
      den = strip_paren(den)
      num, den = M.differential(num, den)
      local frac = "\\frac{" .. num .. "}{" .. den .. "}"
      skipws()
      while s:sub(pos, pos) == "/" do
        pos = pos + 1
        local nxt = strip_paren(read_scripts(read_atom()))
        frac = "\\frac{" .. frac .. "}{" .. nxt .. "}"
        skipws()
      end
      out[#out+1] = frac
    elseif c == "^" or c == "_" then
      pos = pos + 1
      skipws()
      if s:sub(pos, pos) == "{" then
        local depth, j = 0, pos
        while j <= n do
          local d = s:sub(j,j)
          if d == "{" then depth = depth + 1
          elseif d == "}" then depth = depth - 1; if depth == 0 then break end end
          j = j + 1
        end
        out[#out+1] = c .. s:sub(pos, j)
        pos = j + 1
      else
        local sign = ""
        local sc = s:sub(pos, pos)
        if sc == "-" or sc == "+" then sign = sc; pos = pos + 1 end
        local term = read_atom()
        term = term:gsub("^%((.*)%)$", "%1")
        out[#out+1] = c .. "{" .. sign .. term .. "}"
      end
    elseif c == "+" or c == "-" or c == "=" or c == "<" or c == ">"
        or c == "," or c == ")" then
      out[#out+1] = c; pos = pos + 1
    else
      out[#out+1] = read_scripts(read_atom())
    end
  end
  return table.concat(out)
end

return M
