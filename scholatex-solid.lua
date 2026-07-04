local U = require("scholatex-util")

-- =====================================================================
-- scholatex-solid --- space geometry in the French "perspective
-- cavaliere" (cabinet oblique projection), inside <draw>:
--
--   <draw>{
--       solid cube ABCDEFGH edge:4
--       solid cuboid ABCDEFGH sides:{5, 3, 2}
--       solid pyramid SABCD base:4 height:5
--       solid cylinder radius:1.5 height:4
--       solid cone radius:2 height:4.5
--       solid sphere radius:2.5
--   }
--
-- Projection: (x, y, z) -> (x + k y cos(alpha), z + k y sin(alpha)),
-- with the school convention alpha = 45 degrees, k = 0.5; override with
-- angle: and ratio:. x runs right, z up, y into the picture.
--
-- Hidden edges are computed, not declared: a face of a convex solid is
-- stored with its vertices ordered counterclockwise seen from outside;
-- the face is visible exactly when the projection preserves that
-- orientation (positive shoelace area), and an edge is dashed exactly
-- when both its faces are hidden. Curved solids use the same idea on
-- their silhouette: back half-ellipses are dashed.
--
-- Several solid lines in one block sit side by side, left to right.
-- Plane sections are not in this release.
-- =====================================================================

local M = {}

local function fmt(v)
  return (("%.4f"):format(v)):gsub("0+$", ""):gsub("%.$", "")
end

-- ---------------------------------------------------------------------
-- Projection factory.
-- ---------------------------------------------------------------------
local function projector(attrs)
  local alpha = math.rad(tonumber(attrs.angle or "") or 45)
  local k     = tonumber(attrs.ratio or "") or 0.5
  local c, s  = k * math.cos(alpha), k * math.sin(alpha)
  return function(p) return p[1] + c * p[2], p[3] + s * p[2] end
end

-- ---------------------------------------------------------------------
-- Convex polyhedron: vertices (3D), faces (lists of vertex indices,
-- counterclockwise from outside), names (vertex labels, optional).
-- ---------------------------------------------------------------------
local function shoelace(pts)
  local a = 0
  for i = 1, #pts do
    local p, q = pts[i], pts[i % #pts + 1]
    a = a + p[1] * q[2] - q[1] * p[2]
  end
  return a / 2
end

local function poly_render(verts, faces, names, proj, ox)
  -- project
  local P = {}
  for i, v in ipairs(verts) do
    local x, y = proj(v)
    P[i] = { x + ox, y }
  end
  -- face visibility
  local vis = {}
  for fi, f in ipairs(faces) do
    local pts = {}
    for _, vi in ipairs(f) do pts[#pts+1] = P[vi] end
    vis[fi] = shoelace(pts) > 1e-9
  end
  -- edges with their two faces
  local edges = {}
  local function ekey(i, j) if i > j then i, j = j, i end return i .. "-" .. j end
  for fi, f in ipairs(faces) do
    for k = 1, #f do
      local i, j = f[k], f[k % #f + 1]
      local key = ekey(i, j)
      local e = edges[key]
      if not e then e = { i = math.min(i,j), j = math.max(i,j), faces = {} }; edges[key] = e end
      e.faces[#e.faces+1] = fi
    end
  end

  local out, xmin, xmax = {}, math.huge, -math.huge
  for _, p in ipairs(P) do
    if p[1] < xmin then xmin = p[1] end
    if p[1] > xmax then xmax = p[1] end
  end
  -- dashed first, solid on top
  local solidseg, dashseg = {}, {}
  for _, e in pairs(edges) do
    local anyvis = false
    for _, fi in ipairs(e.faces) do if vis[fi] then anyvis = true end end
    local seg = ("(%s,%s) -- (%s,%s)"):format(
      fmt(P[e.i][1]), fmt(P[e.i][2]), fmt(P[e.j][1]), fmt(P[e.j][2]))
    if anyvis then solidseg[#solidseg+1] = seg else dashseg[#dashseg+1] = seg end
  end
  for _, s in ipairs(dashseg)  do out[#out+1] = "\\draw[dashed] " .. s .. ";" end
  for _, s in ipairs(solidseg) do out[#out+1] = "\\draw " .. s .. ";" end

  -- Vertex labels. A radial push from the centroid can land a label right
  -- on an edge: in cabinet projection the receding edges of a cube leave
  -- two vertices ALONG the centroid direction. The label goes instead into
  -- the widest empty angular sector between the projected edges incident
  -- to the vertex; ties break toward the centroid-out direction.
  if names then
    local cx, cy = 0, 0
    for _, p in ipairs(P) do cx = cx + p[1]; cy = cy + p[2] end
    cx, cy = cx / #P, cy / #P
    -- incident projected edge directions per vertex
    local inc = {}
    for _, e in pairs(edges) do
      local a = math.atan(P[e.j][2]-P[e.i][2], P[e.j][1]-P[e.i][1])
      inc[e.i] = inc[e.i] or {}; inc[e.i][#inc[e.i]+1] = a
      inc[e.j] = inc[e.j] or {}; inc[e.j][#inc[e.j]+1] = a + math.pi
    end
    for i, nm in ipairs(names) do
      if nm and nm ~= "" then
        local rx, ry = P[i][1] - cx, P[i][2] - cy
        local rn = math.sqrt(rx*rx + ry*ry)
        local radial = (rn > 1e-9) and math.atan(ry, rx) or (math.pi/2)
        local ang = radial
        local dirs = inc[i]
        if dirs and #dirs > 0 then
          table.sort(dirs, function(a, b) return a % (2*math.pi) < b % (2*math.pi) end)
          local bestgap, bestang, bestrad = -1, radial, math.huge
          for k = 1, #dirs do
            local a1 = dirs[k] % (2*math.pi)
            local a2 = (k < #dirs) and dirs[k+1] % (2*math.pi)
                                    or (dirs[1] % (2*math.pi) + 2*math.pi)
            local gap = a2 - a1
            local mid = (a1 + a2) / 2
            local dr = math.abs(((mid - radial) + math.pi) % (2*math.pi) - math.pi)
            if gap > bestgap + 1e-6
               or (gap > bestgap - 1e-6 and dr < bestrad) then
              bestgap, bestang, bestrad = gap, mid, dr
            end
          end
          ang = bestang
        end
        out[#out+1] = ("\\node[font=\\footnotesize] at (%s,%s) {$%s$};")
          :format(fmt(P[i][1] + 0.3 * math.cos(ang)),
                  fmt(P[i][2] + 0.3 * math.sin(ang)), nm)
      end
    end
  end
  return table.concat(out, "\n"), xmin, xmax
end

-- ---------------------------------------------------------------------
-- Solid constructors -> verts, faces.
-- ---------------------------------------------------------------------
local function box_geometry(a, b, c)
  local verts = {
    {0,0,0}, {a,0,0}, {a,b,0}, {0,b,0},   -- A B C D (bottom)
    {0,0,c}, {a,0,c}, {a,b,c}, {0,b,c},   -- E F G H (top, E above A)
  }
  local faces = {
    {1,4,3,2},   -- bottom
    {5,6,7,8},   -- top
    {1,2,6,5},   -- front
    {3,4,8,7},   -- back
    {1,5,8,4},   -- left
    {2,3,7,6},   -- right
  }
  return verts, faces
end

local function pyramid_geometry(b, h)
  local verts = {
    {b/2, b/2, h},                          -- S (apex first: SABCD)
    {0,0,0}, {b,0,0}, {b,b,0}, {0,b,0},     -- A B C D
  }
  local faces = {
    {2,5,4,3},          -- base
    {2,3,1},            -- front  SAB
    {3,4,1},            -- right  SBC
    {4,5,1},            -- back   SCD
    {5,2,1},            -- left   SDA
  }
  return verts, faces
end

-- ---------------------------------------------------------------------
-- Curved solids. Ellipse of the horizontal circle radius r at height z,
-- sampled; halves split at sin t = 0 (front: sin t < 0 toward viewer).
-- ---------------------------------------------------------------------
local N = 36

local function ellipse_path(r, z, proj, ox, t0, t1)
  local pts = {}
  for i = 0, N do
    local t = t0 + (t1 - t0) * i / N
    local x, y = proj({ r * math.cos(t), r * math.sin(t), z })
    pts[#pts+1] = ("(%s,%s)"):format(fmt(x + ox), fmt(y))
  end
  return table.concat(pts, " -- ")
end

local function cylinder_render(r, h, proj, ox)
  local out = {}
  -- bottom: back half dashed, front half solid; top: full, solid
  out[#out+1] = "\\draw[dashed] " .. ellipse_path(r, 0, proj, ox, 0, math.pi) .. ";"
  out[#out+1] = "\\draw " .. ellipse_path(r, 0, proj, ox, math.pi, 2*math.pi) .. ";"
  out[#out+1] = "\\draw " .. ellipse_path(r, h, proj, ox, 0, 2*math.pi) .. ";"
  -- silhouette verticals where d(proj_x)/dt = 0
  local x2 = (proj({0,1,0}))
  local c = x2                       -- k cos(alpha)
  local ts = { math.atan(c), math.atan(c) + math.pi }
  for _, t in ipairs(ts) do
    local bx, by = proj({ r * math.cos(t), r * math.sin(t), 0 })
    local tx, ty = proj({ r * math.cos(t), r * math.sin(t), h })
    out[#out+1] = ("\\draw (%s,%s) -- (%s,%s);")
      :format(fmt(bx + ox), fmt(by), fmt(tx + ox), fmt(ty))
  end
  return table.concat(out, "\n")
end

local function cone_render(r, h, proj, ox)
  local out = {}
  out[#out+1] = "\\draw[dashed] " .. ellipse_path(r, 0, proj, ox, 0, math.pi) .. ";"
  out[#out+1] = "\\draw " .. ellipse_path(r, 0, proj, ox, math.pi, 2*math.pi) .. ";"
  local ax, ay = proj({0, 0, h})
  ax = ax + ox
  -- tangency: cross(P(t) - apex, P'(t)) = 0, solved by scan + bisection
  local function g(t)
    local px, py = proj({ r * math.cos(t), r * math.sin(t), 0 })
    px = px + ox
    local dx, dy = proj({ -r * math.sin(t), r * math.cos(t), 0 })
    return (px - ax) * dy - (py - ay) * dx
  end
  local roots = {}
  local steps = 720
  local prev = g(0)
  for i = 1, steps do
    local t = 2 * math.pi * i / steps
    local cur = g(t)
    if prev * cur <= 0 and #roots < 2 then
      local lo, hi = 2 * math.pi * (i - 1) / steps, t
      for _ = 1, 50 do
        local mid = (lo + hi) / 2
        if g(lo) * g(mid) <= 0 then hi = mid else lo = mid end
      end
      roots[#roots+1] = (lo + hi) / 2
    end
    prev = cur
  end
  for _, t in ipairs(roots) do
    local px, py = proj({ r * math.cos(t), r * math.sin(t), 0 })
    out[#out+1] = ("\\draw (%s,%s) -- (%s,%s);")
      :format(fmt(ax), fmt(ay), fmt(px + ox), fmt(py))
  end
  return table.concat(out, "\n")
end

local function sphere_render(r, proj, ox)
  local out = {}
  out[#out+1] = ("\\draw (%s,0) circle [radius=%s];"):format(fmt(ox), fmt(r))
  out[#out+1] = "\\draw[dashed] " .. ellipse_path(r, 0, proj, ox, 0, math.pi) .. ";"
  out[#out+1] = "\\draw " .. ellipse_path(r, 0, proj, ox, math.pi, 2*math.pi) .. ";"
  return table.concat(out, "\n")
end

-- ---------------------------------------------------------------------
-- Parse a `solid ...` line; returns the TikZ and updates state.cursor.
-- ---------------------------------------------------------------------
local KINDS = { cube=true, cuboid=true, pyramid=true,
                cylinder=true, cone=true, sphere=true }

local function num_attr(attrs, key, what)
  local v = tonumber(attrs[key] or "")
  if not v or v <= 0 then
    error("scholatex: <draw> solid " .. what .. " needs " .. key
        .. ":{a positive number}")
  end
  return v
end

function M.render(rest, state)
  local kind, tail = rest:match("^%s*(%S+)%s*(.*)$")
  if not KINDS[kind] then
    error("scholatex: <draw> solid takes cube, cuboid, pyramid, cylinder, "
        .. "cone or sphere (got '" .. tostring(kind) .. "')")
  end
  -- optional glued point names, then attributes
  local names, optstr = nil, {}
  for w in tail:gmatch("%S+") do
    if not names and w:match("^%a+$") and not w:find(":") then
      names = {}
      for ch in w:gmatch("%a") do names[#names+1] = ch end
    else
      optstr[#optstr+1] = w
    end
  end
  local attrs = U.parse_attrs(table.concat(optstr, " "), { tag = "solid" })
  local proj = projector(attrs)
  local ox = state.cursor

  local tex, xmax, _
  if kind == "cube" or kind == "cuboid" then
    local a, b, c
    if kind == "cube" then
      a = num_attr(attrs, "edge", "cube"); b, c = a, a
    else
      local sv = attrs.sides
      if not sv then
        error("scholatex: <draw> solid cuboid needs sides:{a, b, c}")
      end
      a, b, c = sv:match("^%s*([%d%.]+)%s*,%s*([%d%.]+)%s*,%s*([%d%.]+)%s*$")
      a, b, c = tonumber(a), tonumber(b), tonumber(c)
      if not a then
        error("scholatex: <draw> solid cuboid sides:{a, b, c} needs three numbers")
      end
    end
    if names and #names ~= 8 then
      error("scholatex: <draw> solid " .. kind .. " names 8 vertices (ABCDEFGH), got "
          .. #names)
    end
    local verts, faces = box_geometry(a, b, c)
    tex, _, xmax = poly_render(verts, faces, names, proj, ox)
    state.cursor = xmax + 1.5
  elseif kind == "pyramid" then
    local b = num_attr(attrs, "base", "pyramid")
    local h = num_attr(attrs, "height", "pyramid")
    if names and #names ~= 5 then
      error("scholatex: <draw> solid pyramid names 5 vertices (SABCD), got " .. #names)
    end
    local verts, faces = pyramid_geometry(b, h)
    tex, _, xmax = poly_render(verts, faces, names, proj, ox)
    state.cursor = xmax + 1.5
  elseif kind == "cylinder" then
    local r = num_attr(attrs, "radius", "cylinder")
    local h = num_attr(attrs, "height", "cylinder")
    tex = cylinder_render(r, h, proj, ox + r)      -- centre the base at ox + r
    state.cursor = ox + 2*r + 1.9
  elseif kind == "cone" then
    local r = num_attr(attrs, "radius", "cone")
    local h = num_attr(attrs, "height", "cone")
    tex = cone_render(r, h, proj, ox + r)
    state.cursor = ox + 2*r + 1.9
  else -- sphere
    local r = num_attr(attrs, "radius", "sphere")
    tex = sphere_render(r, proj, ox + r)
    state.cursor = ox + 2*r + 1.9
  end
  return tex
end

return M
