local U = require("scholatex-util")
local NUMEVAL = require("scholatex-numeval")

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

local function num_bound(tok, what)
  tok = U.trim(tok)
  if tok:match("inf") then
    error("scholatex: <plot> " .. what .. " bound cannot be infinite ('"
        .. tok .. "'); give a finite display window, e.g. x:{-3, 3}")
  end
  return tok
end

-- Functions whose ARGUMENT is an angle: pgfplots trig works in DEGREES,
-- so the scholatex radian argument is wrapped in deg(...).
local TRIG = { sin=true, cos=true, tan=true, cot=true, sec=true, csc=true }
-- Inverse trig return degrees in pgfplots; the result is converted back to
-- radians with rad(...) so a plotted arctan matches #{arctan(...)}.
local INVTRIG = { arcsin=true, arccos=true, arctan=true,
                  asin=true, acos=true, atan=true }
-- scholatex name -> pgfplots name (pgf's math engine, degrees for trig).
local PGF = {
  sin="sin", cos="cos", tan="tan", cot="cot", sec="sec", csc="cosec",
  arcsin="asin", arccos="acos", arctan="atan",
  asin="asin", acos="acos", atan="atan",
  sinh="sinh", cosh="cosh", tanh="tanh",
  exp="exp", sqrt="sqrt", abs="abs",
}
-- Functions pgf lacks natively, given as a pgfplots expression of one
-- argument written %s. These keep plots working for the full library.
local PGF_COMPOSED = {
  coth = "(cosh(%s)/sinh(%s))", sech = "(1/cosh(%s))", csch = "(1/sinh(%s))",
  arcsinh = "ln(%s + sqrt((%s)^2 + 1))",
  arccosh = "ln(%s + sqrt((%s)^2 - 1))",
  arctanh = "(0.5*ln((1 + %s)/(1 - %s)))",
  asinh = "ln(%s + sqrt((%s)^2 + 1))",
  acosh = "ln(%s + sqrt((%s)^2 - 1))",
  atanh = "(0.5*ln((1 + %s)/(1 - %s)))",
  log2 = "(ln(%s)/ln(2))", cbrt = "(sign(%s)*abs(%s)^(1/3))",
  sind = "sin(%s)", cosd = "cos(%s)", tand = "tan(%s)",  -- arg already deg
}

local function translate(expr, var)
  if var ~= "x" then
    expr = expr:gsub("([%a_]?)(" .. var .. ")([%w_]?)", function(a, m, b)
      if a == "" and b == "" then return "x" else return a .. m .. b end
    end)
  end

  local out, i, n = {}, 1, #expr
  while i <= n do
    local word = expr:match("^(%a+)", i)
    if word then
      i = i + #word
      if expr:sub(i, i) == "(" then
        local depth, j = 0, i
        while j <= n do
          local c = expr:sub(j, j)
          if c == "(" then depth = depth + 1
          elseif c == ")" then depth = depth - 1; if depth == 0 then break end end
          j = j + 1
        end
        local arg = expr:sub(i + 1, j - 1)
        local targ = translate(arg, "x")
        if TRIG[word] then
          -- radian argument -> pgfplots degrees
          out[#out+1] = PGF[word] .. "(deg(" .. targ .. "))"
        elseif INVTRIG[word] then
          -- pgfplots returns degrees -> back to radians
          out[#out+1] = "rad(" .. PGF[word] .. "(" .. targ .. "))"
        elseif word == "arcsind" or word == "arccosd" or word == "arctand" then
          out[#out+1] = PGF[word:sub(1,-2)] .. "(" .. targ .. ")"  -- keep degrees
        elseif word == "ln" then
          out[#out+1] = "ln(" .. targ .. ")"
        elseif word == "log" then
          out[#out+1] = "log10(" .. targ .. ")"
        elseif word == "logb" then
          -- logb(v, b): the comma-split argument, base-changed
          local cut
          local d = 0
          for p = 1, #targ do
            local c = targ:sub(p,p)
            if c == "(" then d = d + 1 elseif c == ")" then d = d - 1
            elseif c == "," and d == 0 then cut = p; break end
          end
          if cut then
            out[#out+1] = "(ln(" .. targ:sub(1, cut-1) .. ")/ln("
                       .. targ:sub(cut+1) .. "))"
          else
            out[#out+1] = "ln(" .. targ .. ")"
          end
        elseif PGF_COMPOSED[word] then
          local tmpl = PGF_COMPOSED[word]
          out[#out+1] = tmpl:gsub("%%s", (targ:gsub("%%", "%%%%")))
        elseif PGF[word] then
          out[#out+1] = PGF[word] .. "(" .. targ .. ")"
        else
          out[#out+1] = word .. "(" .. targ .. ")"
        end
        i = j + 1
      else
        out[#out+1] = word
      end
    else
      out[#out+1] = expr:sub(i, i)
      i = i + 1
    end
  end
  local result = table.concat(out)

  -- Implicit multiplication: 2x -> 2*x, )( -> )*(. A digit that is the
  -- last character of a FUNCTION NAME (log10, log2) must be spared, so
  -- those names are shielded with a sentinel first.
  result = result:gsub("log10%(", "\1("):gsub("log2%(", "\2(")
  result = result:gsub("(%d)([%a%(])", "%1*%2")
  result = result:gsub("(%))([%w%(])", "%1*%2")
  result = result:gsub("\1%(", "log10("):gsub("\2%(", "log2(")
  return result
end

-- ---------------------------------------------------------------------
-- Numeric evaluation of a scholatex expression, for features that must
-- COMPUTE (cobweb iterates, binomial masses) rather than delegate to
-- pgfplots. Reuses translate() for the implicit-multiplication pass, then
-- maps the function words to Lua's math library. Returns f : number ->
-- number, or raises a scholatex error naming the offending expression.
-- ---------------------------------------------------------------------
-- ---------------------------------------------------------------------
-- Numeric evaluation of a scholatex expression, for features that must
-- COMPUTE (cobweb iterates, binomial masses) rather than delegate to
-- pgfplots. It binds the SHARED function library (scholatex-numeval), so
-- a cobweb of h(x)=cosh(x) and #{cosh(...)} call the very same function.
-- Returns f : number -> number, or raises a scholatex error naming the
-- offending expression.
-- ---------------------------------------------------------------------
-- Just the implicit-multiplication pass (no pgfplots deg/rad rewriting).
local function implicit_mult(expr, var)
  if var and var ~= "x" then
    expr = expr:gsub("([%a_]?)(" .. var .. ")([%w_]?)", function(a, m, b)
      if a == "" and b == "" then return "x" else return a .. m .. b end
    end)
  end
  expr = expr:gsub("(%d)([%a%(])", "%1*%2")
  expr = expr:gsub("(%))([%w%(])", "%1*%2")
  return expr
end

local function compile_num(expr, var)
  local e = implicit_mult(U.trim(expr), var or "x")
  local chunk, err = load(
    NUMEVAL.inject_locals()
    .. "return function(x) return " .. e .. " end")
  if not chunk then
    error("scholatex: <plot> cannot evaluate expr '" .. expr .. "' ("
        .. tostring(err) .. ")")
  end
  return chunk()
end

local function hwindow(attrs, obj)
  if attrs.x then
    local a, b = attrs.x:match("^%s*(.-)%s*,%s*(.-)%s*$")
    if not a then
      error("scholatex: <plot> x:{a, b} needs two bounds separated by a comma")
    end
    return num_bound(a, "x"), num_bound(b, "x")
  end
  if not (obj and obj.x) then
    error("scholatex: <plot> needs an x:{a, b} window (or a referenced "
        .. "object carrying abscissas)")
  end
  local cells = {}
  for c in (obj.x .. "|"):gmatch("(.-)|") do
    c = U.trim(c)
    if c ~= "" then cells[#cells+1] = c end
  end
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

-- A two-bound window "a, b" from an attribute value. Bounds may use pi and
-- implicit multiplication (2pi, 3pi/2); translate inserts the * and leaves
-- pi as pgfplots understands it.
local function param_window(val, what)
  local a, b = val:match("^%s*(.-)%s*,%s*(.-)%s*$")
  if not a then
    error("scholatex: <plot> " .. what .. ":{a, b} needs two bounds separated by a comma")
  end
  return translate(U.trim(a), "@none"), translate(U.trim(b), "@none")
end

-- Parametric and polar curves. Both render through the same pgfplots axis as
-- the function plot; only the \addplot directive differs. Polar is emitted as
-- a parametric pair (r cos t, r sin t) so a single code path serves both and
-- no extra axis type is pulled in.
local function plot_curve(api, attrs, obj, kind, fn)
  local pvar = (kind == "polar") and "theta" or "t"
  local wattr = attrs[pvar] or (kind == "polar" and attrs.t) or attrs.t
  if not wattr then
    error("scholatex: <plot kind:" .. kind .. "> needs a parameter window "
        .. pvar .. ":{a, b}  (e.g. " .. pvar .. ":{0, 2pi})")
  end
  local pa, pb = param_window(wattr, pvar)

  local samples = attrs.samples or "200"
  local axisopts = {}
  axisopts[#axisopts+1] = "width=10cm, height=7cm"
  axisopts[#axisopts+1] = "axis lines=middle"
  axisopts[#axisopts+1] = "axis equal=true"
  axisopts[#axisopts+1] = "every tick label/.append style={"
                       .. "fill=white, inner sep=1pt, font=\\footnotesize}"
  axisopts[#axisopts+1] = "axis line style={shorten >=-6pt}"
  axisopts[#axisopts+1] = "xlabel=$x$"
  axisopts[#axisopts+1] = "ylabel=$y$"
  axisopts[#axisopts+1] = "xlabel style={at={(ticklabel* cs:1)}, anchor=west}"
  axisopts[#axisopts+1] = "ylabel style={at={(ticklabel* cs:1)}, anchor=south west}"
  if attrs.x then
    local a, b = attrs.x:match("^%s*(.-)%s*,%s*(.-)%s*$")
    if a then axisopts[#axisopts+1] = "xmin=" .. U.trim(a) .. ", xmax=" .. U.trim(b) end
  end
  if attrs.y then
    local c, d = attrs.y:match("^%s*(.-)%s*,%s*(.-)%s*$")
    if c then axisopts[#axisopts+1] = "ymin=" .. U.trim(c) .. ", ymax=" .. U.trim(d) end
  end
  axisopts[#axisopts+1] = "samples=" .. samples

  local addplot
  if kind == "parametric" then
    -- expr:{x(t), y(t)} — split the pair on its top-level comma.
    local raw = U.trim(obj.expr)
    local depth, cut = 0, nil
    for i = 1, #raw do
      local c = raw:sub(i, i)
      if c == "(" or c == "{" then depth = depth + 1
      elseif c == ")" or c == "}" then depth = depth - 1
      elseif c == "," and depth == 0 then cut = i; break end
    end
    if not cut then
      error("scholatex: <plot kind:parametric> needs expr:{x(t), y(t)} — "
          .. "two comma-separated components")
    end
    -- translate canonicalises the parameter to x; the pgfplots variable is
    -- then \x and the domain runs on x, keeping one convention throughout.
    local xt = translate(U.trim(raw:sub(1, cut - 1)), pvar)
    local yt = translate(U.trim(raw:sub(cut + 1)), pvar)
    axisopts[#axisopts+1] = "variable=\\x"
    addplot = "\\addplot[Blue, thick, domain=" .. pa .. ":" .. pb
            .. ", samples=" .. samples .. "] ({" .. xt .. "}, {" .. yt .. "});"
  else
    -- polar: expr:{r(theta)} -> (r cos theta, r sin theta), the angle in
    -- radians on the plot variable x, converted to degrees for cos/sin.
    local r = translate(U.trim(obj.expr), pvar)
    axisopts[#axisopts+1] = "variable=\\x"
    addplot = "\\addplot[Blue, thick, domain=" .. pa .. ":" .. pb
            .. ", samples=" .. samples .. "] "
            .. "({(" .. r .. ")*cos(deg(x))}, {(" .. r .. ")*sin(deg(x))});"
  end

  local out = {}
  out[#out+1] = "\\begin{center}\\begin{tikzpicture}"
  out[#out+1] = "\\begin{axis}[" .. table.concat(axisopts, ", ") .. "]"
  out[#out+1] = addplot
  out[#out+1] = "\\end{axis}"
  out[#out+1] = "\\end{tikzpicture}\\end{center}"
  api.raw('emit(' .. string.format("%q", table.concat(out)) .. ")\n")
end

-- Binomial law B(n, p): the bar plot of the mass function, computed here
-- (no pgfplots math needed, and the exact values matter). area:{a,b}
-- highlights the bars of P(a <= X <= b) in a stronger tone.
local function plot_binomial(api, attrs)
  local ns, ps = attrs.binomial:match("^%s*(.-)%s*,%s*(.-)%s*$")
  local n, p = tonumber(ns), tonumber(ps)
  if not n or not p or n < 1 or n ~= math.floor(n) or p < 0 or p > 1 then
    error("scholatex: <plot binomial:{n, p}> needs an integer n >= 1 and 0 <= p <= 1")
  end
  local ha, hb
  if attrs.area then
    local a, b = attrs.area:match("^%s*(.-)%s*,%s*(.-)%s*$")
    ha, hb = tonumber(a), tonumber(b)
    if not ha then
      error("scholatex: <plot binomial> area:{a, b} needs two integer bounds")
    end
  end

  -- P(X=k) by the multiplicative recurrence — exact enough and overflow-free.
  local masses, m = {}, (1 - p)^n
  masses[0] = m
  for k = 1, n do
    m = m * (n - k + 1) / k * p / (1 - p)
    masses[k] = m
  end

  local base, high, ymax = {}, {}, 0
  for k = 0, n do
    local pt = ("(%d,%.6f)"):format(k, masses[k])
    if ha and k >= ha and k <= hb then high[#high+1] = pt
    else base[#base+1] = pt end
    if masses[k] > ymax then ymax = masses[k] end
  end

  local axisopts = {
    "width=10cm, height=7cm",
    "ybar", "bar width=0.7",
    "axis lines=middle",
    "every tick label/.append style={fill=white, inner sep=1pt, font=\\footnotesize}",
    "xlabel=$k$", "ylabel={$P(X=k)$}",
    ("xmin=-0.8, xmax=%d"):format(n + 1),
    ("ymin=0, ymax=%.6f"):format(ymax * 1.15),
  }

  local out = {}
  out[#out+1] = "\\begin{center}\\begin{tikzpicture}"
  out[#out+1] = "\\begin{axis}[" .. table.concat(axisopts, ", ") .. "]"
  -- bar shift=0pt: two series here are one law split by tone, not two
  -- dodged data sets, so both must sit on the same abscissa.
  if #base > 0 then
    out[#out+1] = "\\addplot[fill=Blue!25, draw=Blue, bar shift=0pt] coordinates {"
      .. table.concat(base, " ") .. "};"
  end
  if #high > 0 then
    out[#out+1] = "\\addplot[fill=Blue!70, draw=Blue, bar shift=0pt] coordinates {"
      .. table.concat(high, " ") .. "};"
  end
  out[#out+1] = "\\end{axis}"
  out[#out+1] = "\\end{tikzpicture}\\end{center}"
  api.raw('emit(' .. string.format("%q", table.concat(out)) .. ")\n")
end

return function(sl)
  sl.register_tag("plot", function(api, words, content)
    local parts = {}
    for k = 2, #words do parts[#parts+1] = words[k] end
    local attrs = parse_attrs(U.trim(table.concat(parts, " ")))

    local ref = attrs._ref

    -- Probability laws need no <fn> object: the expression is the law's.
    -- binomial:{n,p} is a bar plot of the mass function, computed here;
    -- normal:{mu,sigma} synthesises the density and rejoins the ordinary
    -- function path, so area:{a,b} shading works identically on it.
    if attrs.binomial then
      return plot_binomial(api, attrs)
    end
    local obj
    if attrs.normal then
      local mu, sigma = attrs.normal:match("^%s*(.-)%s*,%s*(.-)%s*$")
      local m, s = tonumber(mu), tonumber(sigma)
      if not m or not s or s <= 0 then
        error("scholatex: <plot normal:{mu, sigma}> needs two numbers, sigma > 0")
      end
      obj = {
        expr = ("1/(%.6g*sqrt(2pi))*exp(-(x-%.6g)^2/(2*%.6g^2))"):format(s, m, s),
        name = "f(x)",
      }
      if not attrs.x then
        attrs.x = ("%.6g, %.6g"):format(m - 4*s, m + 4*s)
      end
    else
      if not ref then
        error("scholatex: <plot> needs a function object, e.g. <plot k ...> "
            .. "after  let k = <fn ...>  (or a law: normal:{mu,sigma}, "
            .. "binomial:{n,p})")
      end
      obj = sl._objects and sl._objects[ref]
      if not obj then
        error("scholatex: <plot " .. ref .. "> refers to an object that is not "
            .. "defined; write  let " .. ref .. " = <fn ... expr:{...} ...>  first")
      end
    end
    if not obj.expr then
      error("scholatex: <plot " .. ref .. "> needs the object to carry an "
          .. "expr:{...} (the formula to plot)")
    end

    local fn, var = "f", "x"
    if obj.name then
      local f, v = obj.name:match("^%s*([%a]%w*)%s*%(%s*([%a]%w*)%s*%)%s*$")
      if f then fn, var = f, v
      else fn = obj.name:match("^%s*([%a]%w*)%s*$") or "f" end
    end

    -- kind: chooses the curve family. The default (no kind, or kind:function)
    -- is y = f(x). parametric and polar reuse the same TikZ axis; only the
    -- \addplot line changes, so the frame, labels and windowing are shared.
    local kind = attrs.kind or "function"
    if kind ~= "function" and kind ~= "parametric" and kind ~= "polar" then
      error("scholatex: <plot> kind: takes 'function', 'parametric' or 'polar' "
          .. "(got '" .. tostring(kind) .. "')")
    end

    if kind == "parametric" or kind == "polar" then
      return plot_curve(api, attrs, obj, kind, fn)
    end

    local body = translate(U.trim(obj.expr), var)

    local xa, xb = hwindow(attrs, obj)
    local samples = attrs.samples or "100"

    local axisopts = {}
    axisopts[#axisopts+1] = "width=10cm, height=7cm"
    axisopts[#axisopts+1] = "axis lines=middle"
    axisopts[#axisopts+1] = "every tick label/.append style={"
                         .. "fill=white, inner sep=1pt, font=\\footnotesize}"
    axisopts[#axisopts+1] = "axis line style={shorten >=-6pt}"
    -- With centred axes the default ylabel sits at the TOP OF THE Y-AXIS —
    -- for a density centred at 0 that is the peak of the bell, so the label
    -- lands ON the curve. Anchor both labels past the axis tips instead.
    axisopts[#axisopts+1] = "xlabel=$" .. var .. "$"
    axisopts[#axisopts+1] = "ylabel=$" .. fn .. "(" .. var .. ")$"
    axisopts[#axisopts+1] = "xlabel style={at={(ticklabel* cs:1)}, anchor=west}"
    axisopts[#axisopts+1] = "ylabel style={at={(ticklabel* cs:1)}, anchor=south west}"
    axisopts[#axisopts+1] = "xmin=" .. xa .. ", xmax=" .. xb
    if attrs.y then
      local c, d = attrs.y:match("^%s*(.-)%s*,%s*(.-)%s*$")
      if not c then
        error("scholatex: <plot> y:{c, d} needs two bounds separated by a comma")
      end
      local ct, dt = U.trim(c), U.trim(d)
      axisopts[#axisopts+1] = "ymin=" .. ct .. ", ymax=" .. dt
      local cn, dn = tonumber(ct), tonumber(dt)
      if cn and dn then
        axisopts[#axisopts+1] = "restrict y to domain=" .. (cn * 3) .. ":" .. (dn * 3)
      end
    end
    axisopts[#axisopts+1] = "samples=" .. samples
    axisopts[#axisopts+1] = "unbounded coords=jump"

    local opt = table.concat(axisopts, ", ")

    -- Extras around the main curve. `pre` is drawn first (fills sit under
    -- the curve), `post` after it (the staircase sits on top).
    local pre, post = {}, {}

    -- area:{a,b} — the region between the curve and the x-axis, shaded,
    -- with dashed verticals at the bounds. between:g shades between this
    -- curve and the curve of the object g instead (fillbetween library).
    local area_a, area_b
    if attrs.area then
      area_a, area_b = attrs.area:match("^%s*(.-)%s*,%s*(.-)%s*$")
      if not area_a then
        error("scholatex: <plot> area:{a, b} needs two bounds separated by a comma")
      end
    end
    local between_body
    if attrs.between then
      local gobj = sl._objects and sl._objects[attrs.between]
      if not (gobj and gobj.expr) then
        error("scholatex: <plot ... between:" .. tostring(attrs.between)
            .. "> needs  let " .. tostring(attrs.between)
            .. " = <fn expr:{...}>  defined first")
      end
      between_body = translate(U.trim(gobj.expr), var)
    end

    if area_a and not between_body then
      pre[#pre+1] = "\\addplot[fill=Blue!15, draw=none, domain=" .. area_a .. ":"
        .. area_b .. ", samples=" .. samples .. "] {" .. body .. "} \\closedcycle;"
      local fnum = compile_num(obj.expr, var)
      local na, nb = tonumber(area_a), tonumber(area_b)
      if na and nb then
        post[#post+1] = ("\\draw[Blue, dashed] (axis cs:%s,0) -- (axis cs:%s,%.4f);")
          :format(area_a, area_a, fnum(na))
        post[#post+1] = ("\\draw[Blue, dashed] (axis cs:%s,0) -- (axis cs:%s,%.4f);")
          :format(area_b, area_b, fnum(nb))
      end
    end

    -- cobweb:{u0}  or  cobweb:{u0, n} — the staircase (or spiral) of the
    -- sequence u(k+1) = f(u(k)), with the bisector y = x. The iterates are
    -- computed here; the first three are labelled on the x-axis.
    if attrs.cobweb then
      local u0s, ns = attrs.cobweb:match("^%s*(.-)%s*,%s*(.-)%s*$")
      if not u0s then u0s = U.trim(attrs.cobweb) end
      local u0 = tonumber(u0s)
      local n  = tonumber(ns or "") or 8
      if not u0 then
        error("scholatex: <plot> cobweb:{u0} or cobweb:{u0, n} — u0 must be a number")
      end
      local fnum = compile_num(obj.expr, var)
      pre[#pre+1] = "\\addplot[Gray, thin, domain=" .. xa .. ":" .. xb .. "] {x};"
      local pts = { ("(%.4f,0)"):format(u0) }
      local u = u0
      for _ = 1, n do
        local v = fnum(u)
        if not v or v ~= v or math.abs(v) > 1e6 then break end
        pts[#pts+1] = ("(%.4f,%.4f)"):format(u, v)
        pts[#pts+1] = ("(%.4f,%.4f)"):format(v, v)
        u = v
      end
      post[#post+1] = "\\addplot[Red, thick] coordinates {"
        .. table.concat(pts, " ") .. "};"
      local u1 = fnum(u0)
      local u2 = u1 and fnum(u1)
      post[#post+1] = ("\\node[below, font=\\footnotesize, Red] at (axis cs:%.4f,0) {$u_0$};"):format(u0)
      if u1 then post[#post+1] = ("\\node[below, font=\\footnotesize, Red] at (axis cs:%.4f,0) {$u_1$};"):format(u1) end
      if u2 then post[#post+1] = ("\\node[below, font=\\footnotesize, Red] at (axis cs:%.4f,0) {$u_2$};"):format(u2) end
    end

    local out = {}
    out[#out+1] = "\\begin{center}\\begin{tikzpicture}"
    out[#out+1] = "\\begin{axis}[" .. opt .. "]"
    for _, p in ipairs(pre) do out[#out+1] = p end
    if between_body then
      out[#out+1] = "\\addplot[name path=SLA, Blue, thick, domain=" .. xa .. ":" .. xb
                .. "] {" .. body .. "};"
      out[#out+1] = "\\addplot[name path=SLB, Red, thick, domain=" .. xa .. ":" .. xb
                .. "] {" .. between_body .. "};"
      local clip = area_a
        and (", soft clip={domain=" .. area_a .. ":" .. area_b .. "}") or ""
      out[#out+1] = "\\addplot[Blue!15] fill between[of=SLA and SLB" .. clip .. "];"
    else
      out[#out+1] = "\\addplot[Blue, thick, domain=" .. xa .. ":" .. xb
                .. "] {" .. body .. "};"
    end
    for _, p in ipairs(post) do out[#out+1] = p end
    out[#out+1] = "\\end{axis}"
    out[#out+1] = "\\end{tikzpicture}\\end{center}"

    api.raw('emit(' .. string.format("%q", table.concat(out)) .. ")\n")
  end)
end
