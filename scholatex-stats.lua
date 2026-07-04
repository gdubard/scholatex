local U = require("scholatex-util")
local NE = require("scholatex-numeval")

-- Captured at register time so the render helpers (defined above the
-- closure) can read sl.config.precision.

-- =====================================================================
-- <stats> --- descriptive statistics, five figures, one tag.
--
--   <stats kind:bars data:{(1,4) (2,7) (3,2)}>          value, count
--   <stats kind:histogram bounds:{0,5,10,20} counts:{3,7,2}>
--   <stats kind:pie data:{Red: 5 | Blue: 3 | Green: 2}>
--   <stats kind:boxplot data:{12, 15, 9, 21, 14, 15, 18}>
--   <stats kind:scatter data:{(1,2) (2,2.6) (3,3.1)} fit:on>
--
-- Everything is computed here, in Lua, at compile time:
--   - the histogram draws DENSITY (count / class width), so unequal
--     classes stay honest;
--   - the boxplot uses the French secondary-school quartiles: Q1 is the
--     smallest value with at least a quarter of the data below or equal,
--     Q3 the smallest with at least three quarters;
--   - fit:on draws the least-squares line through the scatter.
-- =====================================================================

local PALETTE = { "Blue!60", "Red!60", "Green!55", "Orange!70",
                  "Purple!55", "Teal!60", "Brown!55", "Gray!55" }

local function fmt(v)
  return (("%.4f"):format(v)):gsub("0+$", ""):gsub("%.$", "")
end

-- data:{(x1,y1) (x2,y2) ...} -> list of pairs
local function parse_pairs(s, tag)
  local out = {}
  for a, b in s:gmatch("%(%s*(-?[%d%.]+)%s*,%s*(-?[%d%.]+)%s*%)") do
    out[#out+1] = { tonumber(a), tonumber(b) }
  end
  if #out == 0 then
    error("scholatex: <stats " .. tag .. "> data:{...} needs pairs like (1, 4)")
  end
  return out
end

-- data:{12, 15, 9, ...} -> sorted list of numbers
local function parse_numbers(s, tag)
  local out = {}
  for tok in (s .. ","):gmatch("(.-),") do
    tok = U.trim(tok)
    if tok ~= "" then
      local v = tonumber(tok)
      if not v then
        error("scholatex: <stats " .. tag .. "> data entry '" .. tok
            .. "' is not a number")
      end
      out[#out+1] = v
    end
  end
  if #out == 0 then error("scholatex: <stats " .. tag .. "> data:{...} is empty") end
  table.sort(out)
  return out
end

-- data:{Key: value | Key: value | ...} -> ordered {key, v} list.
-- The same shape serves bars and pie: a dictionary of frequencies.
local function parse_dict(s, tag)
  local entries, total = {}, 0
  for cell in (s .. "|"):gmatch("(.-)|") do
    cell = U.trim(cell)
    if cell ~= "" then
      local key, v = cell:match("^(.-)%s*:%s*(-?[%d%.]+)$")
      if not key or key == "" then
        error("scholatex: <stats " .. tag .. "> data cells read  Key: value, got '"
            .. cell .. "'")
      end
      entries[#entries+1] = { key = key, v = tonumber(v) }
      total = total + tonumber(v)
    end
  end
  if #entries == 0 then
    error("scholatex: <stats " .. tag .. "> data:{...} is empty")
  end
  return entries, total
end

-- ---------------------------------------------------------------------
local function bars_render(entries, attrs)
  local numeric = true
  for _, e in ipairs(entries) do
    if not tonumber(e.key) then numeric = false break end
  end

  local pts, ymax = {}, 0
  for _, e in ipairs(entries) do
    if e.v > ymax then ymax = e.v end
  end

  -- Numeric keys: vertical bars on a centred numeric axis, as before.
  -- Symbolic keys: HORIZONTAL bars, the categories on the y-axis — a long
  -- category name then has the whole line to breathe instead of being
  -- truncated or overlapping its neighbours under a vertical bar.
  local opts = {
    numeric and "width=10cm, height=6.5cm" or "width=10cm",
    numeric and "ybar" or "xbar",
    numeric and "bar width=0.55" or "bar width=14pt",
    "every tick label/.append style={fill=white, inner sep=1pt, font=\\footnotesize}",
    "xlabel=" .. (attrs.xlabel or ""), "ylabel=" .. (attrs.ylabel or ""),
    numeric and ("ymin=0, ymax=%s"):format(fmt(ymax * 1.15))
            or  ("xmin=0, xmax=%s"):format(fmt(ymax * 1.15)),
  }
  -- a symbolic axis has no x = 0, so the centred axis style only fits
  -- the numeric case; categories take the classic bottom/left axes.
  if numeric then
    opts[#opts+1] = "axis lines=middle"
  else
    opts[#opts+1] = "axis x line*=bottom"
    opts[#opts+1] = "axis y line*=left"
  end
  if numeric then
    local xmin, xmax = math.huge, -math.huge
    for _, e in ipairs(entries) do
      local x = tonumber(e.key)
      if x < xmin then xmin = x end
      if x > xmax then xmax = x end
      pts[#pts+1] = ("(%s,%s)"):format(fmt(x), fmt(e.v))
    end
    opts[#opts+1] = ("xmin=%s, xmax=%s"):format(fmt(xmin - 1), fmt(xmax + 1))
  else
    local names = {}
    for _, e in ipairs(entries) do
      names[#names+1] = e.key
      pts[#pts+1] = ("(%s,%s)"):format(fmt(e.v), e.key)
    end
    -- one bar takes ~26pt of height: size the axis to the data
    opts[1] = ("width=10cm, height=%dpt"):format(60 + 26 * #entries)
    opts[#opts+1] = "symbolic y coords={" .. table.concat(names, ",") .. "}"
    opts[#opts+1] = "ytick=data"
    opts[#opts+1] = "enlarge y limits=" .. (#entries > 1 and "0.2" or "0.6")
  end
  return "\\begin{center}\\begin{tikzpicture}\\begin{axis}["
    .. table.concat(opts, ", ") .. "]\\addplot[fill=Blue!30, draw=Blue] "
    .. "coordinates {" .. table.concat(pts, " ") .. "};"
    .. "\\end{axis}\\end{tikzpicture}\\end{center}"
end

local function bars(attrs)
  -- data:{1: 4 | 2: 7}  (numeric values)  or  data:{Cat: 5 | Dog: 3}
  -- (categories). All-numeric keys give a numeric axis; otherwise the
  -- keys become the tick labels, in writing order.
  return bars_render(parse_dict(attrs.data, "bars"), attrs)
end

-- ---------------------------------------------------------------------
local function histogram_render(bs, cs, attrs)
  if #cs ~= #bs - 1 then
    error("scholatex: <stats histogram> " .. #bs .. " bounds give " .. (#bs - 1)
        .. " classes, but " .. #cs .. " counts were given")
  end
  local out, dmax = {}, 0
  for k = 1, #cs do
    local d = cs[k] / (bs[k+1] - bs[k])
    if d > dmax then dmax = d end
    out[#out+1] = ("\\fill[Blue!30] (%s,0) rectangle (%s,%s);")
      :format(fmt(bs[k]), fmt(bs[k+1]), fmt(d))
    out[#out+1] = ("\\draw[Blue] (%s,0) rectangle (%s,%s);")
      :format(fmt(bs[k]), fmt(bs[k+1]), fmt(d))
  end
  -- axes, scaled so the tallest class is ~4cm high and the width ~10cm
  local xspan = bs[#bs] - bs[1]
  local xs, ys = 10 / xspan, 4 / dmax
  local axes = {}
  axes[#axes+1] = ("\\draw[->,>=stealth] (%s,0) -- (%s,0);")
    :format(fmt(bs[1] - 0.03 * xspan), fmt(bs[#bs] + 0.06 * xspan))
  for _, b in ipairs(bs) do
    axes[#axes+1] = ("\\draw (%s,0) -- (%s,-0.06) node[below,font=\\footnotesize]{$%s$};")
      :format(fmt(b), fmt(b), fmt(b))
  end
  return "\\begin{center}\\begin{tikzpicture}[x="
    .. ("%.4f"):format(xs) .. "cm, y=" .. ("%.4f"):format(ys) .. "cm]"
    .. table.concat(out) .. table.concat(axes)
    .. "\\end{tikzpicture}\\end{center}"
end

local function histogram(attrs)
  if not (attrs.bounds and attrs.counts) then
    error("scholatex: <stats kind:histogram> needs bounds:{b0,b1,...} and counts:{n1,...}")
  end
  local bs = parse_numbers(attrs.bounds, "histogram")
  local cs = {}
  for tok in (attrs.counts .. ","):gmatch("(.-),") do
    tok = U.trim(tok)
    if tok ~= "" then cs[#cs+1] = tonumber(tok)
      or error("scholatex: <stats histogram> count '" .. tok .. "' is not a number") end
  end
  return histogram_render(bs, cs, attrs)
end

-- ---------------------------------------------------------------------
local function pie_render(entries, attrs)
  local slices, total = {}, 0
  for _, e in ipairs(entries) do
    slices[#slices+1] = { lbl = e.key, v = e.v }
    total = total + e.v
  end
  local out, a0 = {}, 90     -- start at 12 o'clock, clockwise
  for k, s in ipairs(slices) do
    local sweep = 360 * s.v / total
    local a1 = a0 - sweep
    local col = PALETTE[(k - 1) % #PALETTE + 1]
    out[#out+1] = ("\\fill[%s] (0,0) -- (%s:2.4) arc (%s:%s:2.4) -- cycle;")
      :format(col, fmt(a0), fmt(a0), fmt(a1))
    out[#out+1] = ("\\draw (0,0) -- (%s:2.4) arc (%s:%s:2.4) -- cycle;")
      :format(fmt(a0), fmt(a0), fmt(a1))
    local mid = (a0 + a1) / 2
    -- The label is anchored on the side FACING the disc, so however long
    -- the text is it grows outward and never lies on the pie: west of the
    -- label against a right-hand slice, east against a left-hand one,
    -- south/north near the vertical.
    local m = mid % 360
    local anchor
    if     m <  60 or m > 300 then anchor = "west"
    elseif m < 120             then anchor = "south"
    elseif m < 240             then anchor = "east"
    else                            anchor = "north" end
    -- A percentage reads best rounded: the document `precision` applies as
    -- everywhere else, and with none set the pie falls back to 2 decimals.
    -- Trailing zeros drop, so an exact 25 % shows "25".
    local pct = NE.display(100 * s.v / total, ".", 2)
    out[#out+1] = ("\\node[font=\\footnotesize, anchor=%s] at (%s:2.55) {%s (%s\\,\\%%)};")
      :format(anchor, fmt(mid), s.lbl, pct)
    a0 = a1
  end
  return "\\begin{center}\\begin{tikzpicture}"
    .. table.concat(out) .. "\\end{tikzpicture}\\end{center}"
end

local function pie(attrs)
  return pie_render(parse_dict(attrs.data, "pie"), attrs)
end

-- ---------------------------------------------------------------------
local function boxplot_render(xs, attrs)
  local n = #xs
  -- French secondary-school quartiles
  local q1 = xs[math.ceil(n / 4)]
  local q2 = (n % 2 == 1) and xs[(n + 1) / 2] or (xs[n/2] + xs[n/2 + 1]) / 2
  local q3 = xs[math.ceil(3 * n / 4)]
  local lo, hi = xs[1], xs[n]
  local span = hi - lo
  if span == 0 then span = 1 end
  local unit = 10 / span
  local Y0, H = 0, 0.8

  local out = {}
  out[#out+1] = ("\\draw[<->,>=stealth] (%s,-1) -- (%s,-1);")
    :format(fmt(lo - 0.05 * span), fmt(hi + 0.08 * span))
  local step = 10 ^ math.floor(math.log(span, 10))
  if span / step < 5 then step = step / 2 end
  local t0 = math.ceil(lo / step) * step
  local t = t0
  while t <= hi + 1e-9 do
    out[#out+1] = ("\\draw (%s,-1.06) -- (%s,-0.94) node[below=6pt,font=\\footnotesize]{$%s$};")
      :format(fmt(t), fmt(t), fmt(t))
    t = t + step
  end
  -- whiskers, box, median
  out[#out+1] = ("\\draw (%s,%s) -- (%s,%s);"):format(fmt(lo), fmt(Y0 + H/2), fmt(q1), fmt(Y0 + H/2))
  out[#out+1] = ("\\draw (%s,%s) -- (%s,%s);"):format(fmt(q3), fmt(Y0 + H/2), fmt(hi), fmt(Y0 + H/2))
  out[#out+1] = ("\\draw (%s,%s) -- (%s,%s);"):format(fmt(lo), fmt(Y0 + 0.2), fmt(lo), fmt(Y0 + H - 0.2))
  out[#out+1] = ("\\draw (%s,%s) -- (%s,%s);"):format(fmt(hi), fmt(Y0 + 0.2), fmt(hi), fmt(Y0 + H - 0.2))
  out[#out+1] = ("\\draw[fill=Blue!15] (%s,%s) rectangle (%s,%s);")
    :format(fmt(q1), fmt(Y0), fmt(q3), fmt(Y0 + H))
  out[#out+1] = ("\\draw[Blue, line width=1.2pt] (%s,%s) -- (%s,%s);")
    :format(fmt(q2), fmt(Y0), fmt(q2), fmt(Y0 + H))
  for _, m in ipairs({{lo,"\\mathrm{min}"},{q1,"Q_1"},{q2,"\\mathrm{Me}"},{q3,"Q_3"},{hi,"\\mathrm{max}"}}) do
    out[#out+1] = ("\\node[above,font=\\footnotesize] at (%s,%s) {$%s$};")
      :format(fmt(m[1]), fmt(Y0 + H), m[2])
  end
  return "\\begin{center}\\begin{tikzpicture}[x="
    .. ("%.4f"):format(unit) .. "cm]" .. table.concat(out)
    .. "\\end{tikzpicture}\\end{center}"
end

local function boxplot(attrs)
  return boxplot_render(parse_numbers(attrs.data, "boxplot"), attrs)
end

-- ---------------------------------------------------------------------
local function scatter_render(pts, attrs)
  local sx, sy, sxx, sxy, n = 0, 0, 0, 0, #pts
  local xmin, xmax, ymin, ymax = math.huge, -math.huge, math.huge, -math.huge
  local coords = {}
  for _, p in ipairs(pts) do
    local x, y = p[1], p[2]
    sx, sy, sxx, sxy = sx + x, sy + y, sxx + x*x, sxy + x*y
    if x < xmin then xmin = x end; if x > xmax then xmax = x end
    if y < ymin then ymin = y end; if y > ymax then ymax = y end
    coords[#coords+1] = ("(%s,%s)"):format(fmt(x), fmt(y))
  end
  local dx, dy = (xmax - xmin), (ymax - ymin)
  if dx == 0 then dx = 1 end
  if dy == 0 then dy = 1 end
  local opts = {
    "width=10cm, height=6.5cm", "axis lines=middle",
    "every tick label/.append style={fill=white, inner sep=1pt, font=\\footnotesize}",
    ("xmin=%s, xmax=%s"):format(fmt(xmin - 0.1*dx), fmt(xmax + 0.1*dx)),
    ("ymin=%s, ymax=%s"):format(fmt(math.min(0, ymin - 0.1*dy)), fmt(ymax + 0.15*dy)),
  }
  local body = {"\\addplot[only marks, mark=*, Blue] coordinates {"
    .. table.concat(coords, " ") .. "};"}
  if attrs.fit == "on" then
    local denom = n * sxx - sx * sx
    if math.abs(denom) < 1e-12 then
      error("scholatex: <stats kind:scatter fit:on> — all abscissas are equal, "
          .. "no least-squares line exists")
    end
    local a = (n * sxy - sx * sy) / denom
    local b = (sy - a * sx) / n
    body[#body+1] = ("\\addplot[Red, thick, domain=%s:%s] {%s*x + %s};")
      :format(fmt(xmin - 0.05*dx), fmt(xmax + 0.05*dx), fmt(a), fmt(b))
  end
  return "\\begin{center}\\begin{tikzpicture}\\begin{axis}["
    .. table.concat(opts, ", ") .. "]" .. table.concat(body)
    .. "\\end{axis}\\end{tikzpicture}\\end{center}"
end

local function scatter(attrs)
  return scatter_render(parse_pairs(attrs.data, "scatter"), attrs)
end

-- ---------------------------------------------------------------------
local KINDS = { bars = bars, histogram = histogram, pie = pie,
                boxplot = boxplot, scatter = scatter }

-- ---------------------------------------------------------------------
-- Runtime bridge: <stats kind:bars data:notes> where  notes  is a Lua
-- table declared with let. The tag emits a call executed when the
-- document's let-bindings exist. Accepted shapes, in Rust terms:
--   bars / pie : a map  {Maths = 15.5, ["Géo"] = 12}  -- like a HashMap,
--                a Lua table has NO writing order, so the keys come out
--                SORTED (BTreeMap semantics: numbers numerically, words
--                alphabetically) -- or a Vec of pairs
--                {{"Maths", 15.5}, {"Géo", 12}}  when the order matters.
--   boxplot    : a list of numbers  {12, 15, 9}
--   scatter    : a list of pairs    {{1, 2.1}, {2, 2.6}}
--   histogram  : two lists, bounds and counts
-- ---------------------------------------------------------------------
local function to_entries(t, kind)
  if type(t) ~= "table" then
    error("scholatex: <stats kind:" .. kind .. "> data names a variable that "
        .. "is not a table")
  end
  local entries = {}
  if #t > 0 then
    -- array part: a Vec of {key, value} pairs, writing order kept
    for i, pair in ipairs(t) do
      if type(pair) ~= "table" or pair[1] == nil or type(pair[2]) ~= "number" then
        error("scholatex: <stats kind:" .. kind .. "> entry " .. i
            .. " is not a {key, value} pair")
      end
      entries[#entries+1] = { key = tostring(pair[1]), v = pair[2] }
    end
    return entries
  end
  for k, v in pairs(t) do
    if type(v) ~= "number" then
      error("scholatex: <stats kind:" .. kind .. "> the value of '"
          .. tostring(k) .. "' is not a number")
    end
    entries[#entries+1] = { key = tostring(k), v = v, rawkey = k }
  end
  if #entries == 0 then
    error("scholatex: <stats kind:" .. kind .. "> the table is empty")
  end
  local allnum = true
  for _, e in ipairs(entries) do
    if type(e.rawkey) ~= "number" then allnum = false break end
  end
  table.sort(entries, function(p, q)
    if allnum then return p.rawkey < q.rawkey end
    return p.key < q.key
  end)
  return entries
end

local function to_numbers(t, kind)
  if type(t) ~= "table" or #t == 0 then
    error("scholatex: <stats kind:" .. kind .. "> expects a list of numbers")
  end
  local xs = {}
  for i, v in ipairs(t) do
    if type(v) ~= "number" then
      error("scholatex: <stats kind:" .. kind .. "> entry " .. i
          .. " is not a number")
    end
    xs[#xs+1] = v
  end
  return xs
end

local function to_pairs(t, kind)
  if type(t) ~= "table" or #t == 0 then
    error("scholatex: <stats kind:" .. kind .. "> expects a list of {x, y} pairs")
  end
  local pts = {}
  for i, p in ipairs(t) do
    if type(p) ~= "table" or type(p[1]) ~= "number" or type(p[2]) ~= "number" then
      error("scholatex: <stats kind:" .. kind .. "> entry " .. i
          .. " is not an {x, y} pair of numbers")
    end
    pts[#pts+1] = { p[1], p[2] }
  end
  return pts
end

local RUNTIME = {
  bars    = function(v, _, attrs) return bars_render(to_entries(v, "bars"), attrs) end,
  pie     = function(v, _, attrs) return pie_render(to_entries(v, "pie"), attrs) end,
  boxplot = function(v, _, attrs)
    local xs = to_numbers(v, "boxplot"); table.sort(xs)
    return boxplot_render(xs, attrs)
  end,
  scatter = function(v, _, attrs) return scatter_render(to_pairs(v, "scatter"), attrs) end,
  histogram = function(bounds, counts, attrs)
    local bs = to_numbers(bounds, "histogram"); table.sort(bs)
    return histogram_render(bs, to_numbers(counts, "histogram"), attrs)
  end,
}

return function(sl)
  sl.build_stats_runtime = function(kind, v1, v2, attrs)
    local f = RUNTIME[kind]
    if not f then
      error("scholatex: <stats> kind '" .. tostring(kind)
          .. "' does not take a variable")
    end
    return f(v1, v2, attrs or {})
  end

  sl.register_tag("stats", function(api, words, content)
    local parts = {}
    for k = 2, #words do parts[#parts+1] = words[k] end
    local attrs = U.parse_attrs(U.trim(table.concat(parts, " ")), {
      tag = "stats",
      hint = "expects kind:bars|histogram|pie|boxplot|scatter then data:{...}",
    })
    local kind = U.trim(attrs.kind or "")
    local f = KINDS[kind]
    if not f then
      error("scholatex: <stats> kind: takes bars, histogram, pie, boxplot "
          .. "or scatter (got '" .. kind .. "')")
    end
    if kind ~= "histogram" and not attrs.data then
      error("scholatex: <stats kind:" .. kind .. "> needs data:{...} or "
          .. "data:VARIABLE (a table declared with let)")
    end

    -- data:NAME (no braces) names a Lua table declared with let: the
    -- figure is then built at run time, when the binding exists.
    local function is_ident(s) return s and s:match("^[%a_][%w_]*$") end
    local runtime = (kind == "histogram")
      and (is_ident(attrs.bounds) and is_ident(attrs.counts))
      or  is_ident(attrs.data)
    if runtime then
      local opts = {}
      for _, k in ipairs({"xlabel", "ylabel", "fit"}) do
        if attrs[k] then
          opts[#opts+1] = k .. "=" .. string.format("%q", attrs[k])
        end
      end
      local optstr = "{" .. table.concat(opts, ", ") .. "}"
      local a1 = (kind == "histogram") and attrs.bounds or attrs.data
      local a2 = (kind == "histogram") and attrs.counts or "nil"
      api.raw(('emit(__statsbuild(%q, %s, %s, %s))\n')
        :format(kind, a1, a2, optstr))
      return
    end

    api.raw('emit(' .. string.format("%q", f(attrs)) .. ")\n")
  end)
end
