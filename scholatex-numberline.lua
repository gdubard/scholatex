local U = require("scholatex-util")

-- =====================================================================
-- <numberline> --- the graduated number line, with interval sets.
--
-- Declared set (tag form):
--   <numberline x:{-5, 5} set:{[-2, 3) union (4, inf)} points:{1}>
--
-- Solved set (block form -- the inequality may use < and >, which the
-- braces of a tag cannot carry):
--   <numberline x:{-5, 5}>{
--       abs(x - 1/2) >= 5/2
--   }
--
-- The block takes ONE inequality: an affine expression against a
-- constant, a product/quotient of affine factors against 0, or
-- abs(affine) against a constant. The solution is computed exactly by
-- the affine engine: endpoints are rationals, open/closed follows
-- strict/non-strict, and a zero of a denominator is always excluded.
--
-- Brackets in set:{...} follow the international convention: [ ]
-- included, ( ) excluded; a bound may be inf, the segment then runs to
-- the arrow. points:{...} pins isolated values. One unit is one
-- centimetre, halved automatically while the line exceeds 16 cm.
-- =====================================================================

local INF = math.huge

local function parse_bound(tok, what)
  tok = U.trim(tok)
  if tok == "inf" or tok == "+inf" then return INF end
  if tok == "-inf" then return -INF end
  local v = tonumber(tok)
  if not v then
    error("scholatex: <numberline> " .. what .. " bound '" .. tok
        .. "' is not a number nor inf")
  end
  return v
end

-- set:{...} -> list of {x1, x2, c1, c2} (c = closed endpoint)
local function parse_intervals(s)
  local list = {}
  for part in (s .. " union "):gmatch("(.-)%s+union%s+") do
    part = U.trim(part)
    if part ~= "" then
      local lb, a, b, rb = part:match("^([%[%(])%s*(.-)%s*,%s*(.-)%s*([%]%)])$")
      if not lb then
        error("scholatex: <numberline> interval '" .. part .. "' must read "
            .. "[a, b], [a, b), (a, b] or (a, b), bounds possibly inf")
      end
      local iv = { x1 = parse_bound(a, "left"), x2 = parse_bound(b, "right"),
                   c1 = (lb == "["), c2 = (rb == "]") }
      if iv.x1 >= iv.x2 then
        error("scholatex: <numberline> interval '" .. part
            .. "' has its bounds out of order")
      end
      list[#list+1] = iv
    end
  end
  return list
end

-- ---------------------------------------------------------------------
-- Renderer, shared by both forms.
-- ---------------------------------------------------------------------
local function render(a, b, ivs, pts)
  local unit = 1
  while (b - a) * unit > 16 do unit = unit / 2 end

  local out = {}
  out[#out+1] = "\\begin{center}\\begin{tikzpicture}[x="
              .. string.format("%.4f", unit) .. "cm]"
  out[#out+1] = string.format(
    "\\draw[<->,>=stealth] (%.4f,0) -- (%.4f,0);", a - 0.6/unit, b + 0.6/unit)
  for k = math.ceil(a), math.floor(b) do
    out[#out+1] = string.format(
      "\\draw (%d,-0.08) -- (%d,0.08) node[below=6pt,font=\\footnotesize]{$%d$};",
      k, k, k)
  end

  for _, iv in ipairs(ivs or {}) do
    local x1, k1 = iv.x1, iv.c1 and "closed" or "open"
    local x2, k2 = iv.x2, iv.c2 and "closed" or "open"
    if x1 == -INF then x1, k1 = a - 0.5/unit, "arrow" end
    if x2 ==  INF then x2, k2 = b + 0.5/unit, "arrow" end
    out[#out+1] = string.format(
      "\\draw[Blue, line width=1.6pt] (%.4f,0) -- (%.4f,0);", x1, x2)
    local function endpoint(x, kind)
      if kind == "closed" then
        out[#out+1] = string.format(
          "\\fill[Blue] (%.4f,0) circle [radius=0.09];", x)
      elseif kind == "open" then
        out[#out+1] = string.format(
          "\\draw[Blue, line width=1pt, fill=white] (%.4f,0) circle [radius=0.09];", x)
      end
    end
    endpoint(x1, k1); endpoint(x2, k2)
  end

  for _, v in ipairs(pts or {}) do
    out[#out+1] = string.format(
      "\\fill[Blue] (%.4f,0) circle [radius=0.09];", v)
  end

  out[#out+1] = "\\end{tikzpicture}\\end{center}"
  return table.concat(out)
end

-- ---------------------------------------------------------------------
-- Inequality solver (block form). Returns ivs, pts.
-- ---------------------------------------------------------------------
local OPS = { ">=", "<=", ">", "<", "=" }

local function solve(line)
  local A = require("scholatex-affine")
  local lhs, op, rhs
  for _, o in ipairs(OPS) do
    local i = line:find(o, 1, true)
    if i then
      lhs, op, rhs = U.trim(line:sub(1, i - 1)), o, U.trim(line:sub(i + #o))
      break
    end
  end
  if not op then
    error("scholatex: <numberline> block expects an inequality "
        .. "(expression >= constant, or a product against 0)")
  end
  local raf = A.parse_affine(rhs)
  if not raf or A.rsign(raf.a) ~= 0 then
    error("scholatex: <numberline> right-hand side '" .. rhs
        .. "' must be a constant")
  end
  local c = raf.b
  local strict = (op == ">" or op == "<")
  local wantpos = (op == ">" or op == ">=")

  local ivs, pts = {}, {}
  local function ray_left(x, closed)  ivs[#ivs+1] = {x1=-INF, x2=x, c1=false, c2=closed} end
  local function ray_right(x, closed) ivs[#ivs+1] = {x1=x, x2=INF, c1=closed, c2=false} end

  -- abs(affine) against a constant --------------------------------------
  local inner = lhs:match("^abs%s*(%b())%s*$")
  if inner then
    local af, err = A.parse_affine(inner:sub(2, -2))
    if not af or A.rsign(af.a) == 0 then
      error("scholatex: <numberline> abs(...) takes an affine expression ("
          .. tostring(err) .. ")")
    end
    local cs = A.rsign(c)
    local x0 = A.rnum(A.rdiv(A.rneg(af.b), af.a))
    if cs < 0 then
      if op == "<" or op == "<=" or op == "=" then
        error("scholatex: the solution set of  " .. U.trim(line) .. "  is empty")
      end
      ivs[#ivs+1] = {x1=-INF, x2=INF, c1=false, c2=false}
      return ivs, pts
    end
    if cs == 0 then
      if op == ">=" then ivs[#ivs+1] = {x1=-INF, x2=INF, c1=false, c2=false}
      elseif op == ">" then ray_left(x0, false); ray_right(x0, false)
      elseif op == "<" then
        error("scholatex: the solution set of  " .. U.trim(line) .. "  is empty")
      else pts[#pts+1] = x0 end
      return ivs, pts
    end
    local e1 = A.rdiv(A.rsub(A.rneg(c), af.b), af.a)
    local e2 = A.rdiv(A.rsub(c, af.b), af.a)
    if A.rcmp(e1, e2) > 0 then e1, e2 = e2, e1 end
    local lo, hi = A.rnum(e1), A.rnum(e2)
    if op == "=" then
      pts[#pts+1] = lo; pts[#pts+1] = hi
    elseif op == "<" or op == "<=" then
      ivs[#ivs+1] = {x1=lo, x2=hi, c1=not strict, c2=not strict}
    else
      ray_left(lo, not strict); ray_right(hi, not strict)
    end
    return ivs, pts
  end

  -- product / quotient of affine factors --------------------------------
  local prod, perr = A.parse_product(lhs)
  if not prod then
    error("scholatex: <numberline> cannot read '" .. lhs .. "' (" .. tostring(perr)
        .. "); it takes an affine expression, a product/quotient of affine "
        .. "factors, or abs(affine)")
  end
  if #prod.factors == 0 then
    error("scholatex: <numberline> left-hand side '" .. lhs .. "' is constant")
  end
  if A.rsign(c) ~= 0 then
    if #prod.factors == 1 and prod.factors[1].mult == 1
       and not prod.factors[1].den then
      -- affine op c  ->  (affine - c) op 0, folding the constant in
      local f = prod.factors[1]
      local a2 = A.rmul(prod.c, f.a)
      local b2 = A.rsub(A.rmul(prod.c, f.b), c)
      prod = { c = A.rat(1), factors = {
        { a = a2, b = b2, mult = 1, den = false, label = lhs } } }
      -- the constant is folded into the single factor; nothing reads c below
    else
      error("scholatex: <numberline> a factored expression is compared to 0; "
          .. "move the constant to the left-hand side")
    end
  end

  local zeros, isigns = A.analyse(prod)
  local satisfied = {}
  for k, s in ipairs(isigns) do
    satisfied[k] = (op ~= "=") and ((wantpos and s > 0) or (not wantpos and s < 0))
  end
  local included = {}
  for k, z in ipairs(zeros) do
    included[k] = (not z.den) and z.nummult > 0
                  and (op == "=" or not strict)
  end

  -- assemble: walk intervals and boundaries left to right
  local cuts = { -INF }
  for _, z in ipairs(zeros) do cuts[#cuts+1] = A.rnum(z.x) end
  cuts[#cuts+1] = INF

  local open_iv = nil
  for k = 1, #isigns do
    if satisfied[k] then
      if not open_iv then
        open_iv = { x1 = cuts[k], x2 = nil,
                    c1 = (k > 1) and included[k-1] or false }
      end
    end
    -- boundary after interval k (zero k), if any
    if k <= #zeros then
      if satisfied[k] and satisfied[k+1] and included[k] then
        -- merge through the boundary: keep open_iv running
      else
        if open_iv then
          open_iv.x2 = cuts[k+1]
          open_iv.c2 = included[k]
          ivs[#ivs+1] = open_iv
          open_iv = nil
        end
        if included[k] and not satisfied[k] and not satisfied[k+1] then
          pts[#pts+1] = cuts[k+1]        -- isolated solution point
        elseif included[k] and not satisfied[k] and satisfied[k+1] then
          -- the point opens the next interval; handled when it opens
        end
      end
    end
  end
  if open_iv then
    open_iv.x2 = INF; open_iv.c2 = false
    ivs[#ivs+1] = open_iv
  end
  if op == "=" and #pts == 0 and #ivs == 0 then
    error("scholatex: the solution set of  " .. U.trim(line) .. "  is empty")
  end
  return ivs, pts
end

-- ---------------------------------------------------------------------
return function(sl)
  local function window(attrs)
    if not attrs.x then
      error("scholatex: <numberline> needs a window x:{a, b}")
    end
    local xa, xb = attrs.x:match("^%s*(.-)%s*,%s*(.-)%s*$")
    local a, b = tonumber(xa), tonumber(xb)
    if not a or not b or a >= b then
      error("scholatex: <numberline> x:{a, b} needs two finite ordered numbers")
    end
    return a, b
  end

  local function parse_points(s)
    local pts = {}
    for tok in ((s or "") .. ","):gmatch("(.-),") do
      tok = U.trim(tok)
      if tok ~= "" then
        local v = tonumber(tok)
        if not v then
          error("scholatex: <numberline> points:{...} entries must be numbers, got '"
              .. tok .. "'")
        end
        pts[#pts+1] = v
      end
    end
    return pts
  end

  sl.register_tag("numberline", function(api, words, content)
    local parts = {}
    for k = 2, #words do parts[#parts+1] = words[k] end
    local attrs = U.parse_attrs(U.trim(table.concat(parts, " ")), {
      tag = "numberline", require_group = true,
      hint = "expects x:{a, b} and set:{...} / points:{...}",
    })
    local a, b = window(attrs)
    local ivs = attrs.set and parse_intervals(attrs.set) or {}
    local pts = parse_points(attrs.points)
    api.raw('emit(' .. string.format("%q", render(a, b, ivs, pts)) .. ")\n")
  end)

  sl.register_block("numberline", function(api, words_str, inner)
    local attrs = U.parse_attrs(U.trim(words_str or ""), {
      tag = "numberline", require_group = true,
      hint = "expects x:{a, b}, then one inequality in the block body",
    })
    local a, b = window(attrs)
    local ineq
    for _, l in ipairs(inner) do
      if type(l) == "string" and l:match("%S") and not l:match("^%s*}%s*$") then
        if ineq then
          error("scholatex: <numberline> block takes exactly one inequality; "
              .. "write one figure per inequality")
        end
        ineq = U.trim(l)
      end
    end
    if not ineq then
      error("scholatex: <numberline> block body is empty; write one inequality")
    end
    local ivs, pts = solve(ineq)
    api.raw('emit(' .. string.format("%q", render(a, b, ivs, pts)) .. ")\n")
  end)
end
