local U = require("scholatex-util")

-- =====================================================================
-- <draw> --- geometric figures from a description.
--   <draw>triangle ABC equilateral side:5
--   <draw>{
--   triangle ABC right sides:(4,3)
--   square BCEF side:3
--   }
-- Several figures in one block share a point dictionary: a figure naming
-- already-placed points grafts onto them, and a shared edge is deduced and
-- flipped to abut. Loops, #-interpolation, rotate:, and the point()/line()
-- primitives build free-form drawings. (The legacy name <figure> is kept as
-- an alias.)
-- =====================================================================

local sin = function(d) return math.sin(math.rad(d)) end
local cos = function(d) return math.cos(math.rad(d)) end

local function num(v, what)
  local stripped = (v or ""):gsub("^%((.*)%)$", "%1")
  local x = tonumber(stripped)
  if not x then error("scholatex: <draw> "..what.." must be a number, got '"..tostring(v).."'") end
  return x
end
local function numlist(v, what)
  v = (v or ""):gsub("^%((.*)%)$", "%1")
  local t = {}
  for piece in v:gmatch("[^,]+") do
    local x = tonumber(U.trim(piece))
    if not x then error("scholatex: <draw> "..what.." must be numbers, got '"..piece.."'") end
    t[#t+1] = x
  end
  return t
end

local Tri = {}
function Tri.equilateral(P,s) return {{P[1],0,0},{P[2],s,0},{P[3],s*cos(60),s*sin(60)}}, {sides="all"} end
function Tri.isosceles(P,e,b)
  local d=e*e-(b/2)*(b/2)
  if d<=0 then return nil,"equal side too short for the given base" end
  local h=math.sqrt(d)
  return {{P[1],b/2,h},{P[2],0,0},{P[3],b,0}}, {sides={{1,2},{1,3}}}
end
function Tri.right(P,p,q,at)
  at=at or 1
  local v={}; v[at]={P[at],0,0}
  local i2=(at%3)+1; local i3=(i2%3)+1
  v[i2]={P[i2],p,0}; v[i3]={P[i3],0,q}
  return v,{right=at}
end
function Tri.sss(P,a,b,c)
  local cosA=(a*a+c*c-b*b)/(2*a*c)
  if cosA<-1 or cosA>1 then return nil,"sides violate the triangle inequality" end
  local A=math.deg(math.acos(cosA))
  return {{P[1],0,0},{P[2],a,0},{P[3],c*cos(A),c*sin(A)}}, {}
end
function Tri.sas(P,a,b,t) return {{P[1],0,0},{P[2],a,0},{P[3],b*cos(t),b*sin(t)}}, {} end
function Tri.asa(P,angA,angB,c)
  if angA+angB>=180 then return nil,"the two given angles sum to 180 degrees or more" end
  local angC=180-angA-angB
  local AC=c*sin(angB)/sin(angC)
  return {{P[1],0,0},{P[2],c,0},{P[3],AC*cos(angA),AC*sin(angA)}}, {}
end

local Quad = {}
function Quad.square(P,s) return {{P[1],0,0},{P[2],s,0},{P[3],s,s},{P[4],0,s}}, {sides="all",right="all"} end
function Quad.rectangle(P,w,h) return {{P[1],0,0},{P[2],w,0},{P[3],w,h},{P[4],0,h}},
  {right="all", sides={{1,2,1},{3,4,1},{2,3,2},{4,1,2}}} end
function Quad.rhombus(P,s,t) return {{P[1],0,0},{P[2],s,0},{P[3],s+s*cos(t),s*sin(t)},{P[4],s*cos(t),s*sin(t)}}, {sides="all"} end
function Quad.parallelogram(P,a,b,t) return {{P[1],0,0},{P[2],a,0},{P[3],a+b*cos(t),b*sin(t)},{P[4],b*cos(t),b*sin(t)}},
  {sides={{1,2,1},{3,4,1},{2,3,2},{4,1,2}}} end
function Quad.trapezoid(P,b1,b2,h,offset)
  local o=offset or (b1-b2)/2
  return {{P[1],0,0},{P[2],b1,0},{P[3],o+b2,h},{P[4],o,h}}, {}
end
-- Kite ABCD: axis of symmetry AC, the two upper sides AB=AD=a equal and the
-- two lower sides CB=CD=b equal (a, b distinct -- a rhombus is the case a=b).
-- t is the apex half-handled through the full apex angle at A. A sits at the
-- top, C at the bottom on the vertical axis; B right, D left.
function Quad.kite(P,a,b,t)
  local half=math.rad(t/2)
  local hx=a*math.sin(half)            -- half-width at the apex level
  local ay=a*math.cos(half)            -- drop from A to the B/D level
  -- C sits on the axis below B/D only if the lower side b can reach the axis
  -- from B, i.e. b >= hx. When b < hx the figure cannot close: C would fall on
  -- the line B-D and the kite collapses to a triangle. Refuse it with the
  -- governing inequality rather than silently flattening the shape.
  local inside=b*b-hx*hx
  if inside<=0 then
    return nil, string.format(
      "lower side b=%g too short for upper side a=%g at apex %g° "
      .. "(need b > a·sin(%g°) = %.3f) — the kite would flatten to a triangle",
      b, a, t, t/2, hx)
  end
  local cy=ay+math.sqrt(inside)        -- drop from A to C
  -- The two upper sides AB=AD carry a single tick, the two lower sides
  -- CB=CD a double tick: each pair is internally equal, the pairs distinct.
  return {{P[1],0,0},{P[2],hx,-ay},{P[3],0,-cy},{P[4],-hx,-ay}},
         {sides={{1,2,1},{1,4,1},{2,3,2},{3,4,2}}}
end

local Circle = {}
-- Circumscribed circle of triangle (A,B,C): centre equidistant from the three
-- vertices, radius that common distance. Returns cx, cy, r or nil on a
-- degenerate (collinear) triangle.
function Circle.circumscribed(ax,ay,bx,by,cx,cy)
  local d=2*(ax*(by-cy)+bx*(cy-ay)+cx*(ay-by))
  if math.abs(d)<1e-9 then return nil end
  local a2,b2,c2=ax*ax+ay*ay, bx*bx+by*by, cx*cx+cy*cy
  local ux=(a2*(by-cy)+b2*(cy-ay)+c2*(ay-by))/d
  local uy=(a2*(cx-bx)+b2*(ax-cx)+c2*(bx-ax))/d
  local r=math.sqrt((ux-ax)^2+(uy-ay)^2)
  return ux,uy,r
end
-- Inscribed circle of triangle (A,B,C): incentre is the side-length-weighted
-- average of the vertices, radius = area / semiperimeter.
function Circle.inscribed(ax,ay,bx,by,cx,cy)
  local a=math.sqrt((bx-cx)^2+(by-cy)^2)   -- side opposite A
  local b=math.sqrt((ax-cx)^2+(ay-cy)^2)   -- side opposite B
  local c=math.sqrt((ax-bx)^2+(ay-by)^2)   -- side opposite C
  local p=a+b+c
  if p<1e-9 then return nil end
  local ix=(a*ax+b*bx+c*cx)/p
  local iy=(a*ay+b*by+c*cy)/p
  local s=p/2
  local area=math.abs((bx-ax)*(cy-ay)-(cx-ax)*(by-ay))/2
  return ix,iy,area/s
end

local function regular_polygon(P,s)
  local n=#P; s=s or 1
  local R=s/(2*math.sin(math.pi/n))
  local verts={}
  local a0=-90-180/n
  for k=1,n do
    local ang=a0+(k-1)*360/n
    verts[#verts+1]={P[k],R*cos(ang),R*sin(ang)}
  end
  return verts,{sides="all"}
end

local function compute(line, dict)
  local tag, rest = line:match("^%s*(%S+)%s*(.*)$")
  rest = U.trim(rest or "")

  -- Point names. Two forms, told apart by the first non-space character of the
  -- argument list:
  --   triangle ABC          -- glued single letters: A, B, C
  --   triangle (O, A0, B0)   -- a parenthesised, comma-separated list, for
  --                             multi-character names (O, A0, B0...)
  local P, optstr = {}, {}
  if rest:sub(1,1) == "(" then
    local inside, after = rest:match("^(%b())%s*(.*)$")
    if not inside then error("scholatex: <draw> "..tag.." has an unclosed '(' in its point list") end
    for nm in inside:sub(2,-2):gmatch("[^,]+") do
      local t = U.trim(nm)
      if t ~= "" then P[#P+1] = t end
    end
    for w in after:gmatch("%S+") do optstr[#optstr+1] = w end
  else
    local words={}
    for w in rest:gmatch("%S+") do words[#words+1]=w end
    local points=nil
    for _,w in ipairs(words) do
      if not points and w:match("^%a+$") and not w:match(":") then points=w
      else optstr[#optstr+1]=w end
    end
    if not points then error("scholatex: <draw> "..tag.." needs point names, e.g. "..tag.." ABC ...") end
    for ch in points:gmatch("%a") do P[#P+1]=ch end
  end

  local attrs=U.parse_attrs(table.concat(optstr," "),{
    tag="figure",
    on_bare=function(word,a)
      if word:match("^right:%a$") then a.right=word:sub(7); return true end
      a[word]=true; return true
    end,
  })

  -- Named sides: options whose key is a pair of the figure's points (DK:6)
  -- mean "side DK measures 6". This only applies when points are single
  -- letters, so the two-letter key splits unambiguously; with multi-character
  -- names (O, A0...) there is no named-side form.
  local pointset = {}
  local all_single = true
  for _, ch in ipairs(P) do
    pointset[ch] = true
    if #ch ~= 1 then all_single = false end
  end
  local named_sides = {}
  if all_single then
    for k, v in pairs(attrs) do
      if type(k) == "string" and #k == 2
         and pointset[k:sub(1,1)] and pointset[k:sub(2,2)] then
        local x = tonumber(v)
        if not x then error("scholatex: <draw> side " .. k .. " must be a number, got '" .. tostring(v) .. "'") end
        named_sides[k] = x
        named_sides[k:sub(2,2)..k:sub(1,1)] = x   -- DK and KD both
      end
    end
  end

  -- Memory of the past: if a side measurement is omitted, deduce it from a
  -- shared edge already in the dictionary. The figure's points are P[1..n] in
  -- order; the first edge between two consecutive already-placed points gives
  -- the side length. If side: IS given, it is left for graft() to check.
  if dict then
    local function dist(n1,n2)
      local p,q=dict[n1],dict[n2]
      if p and q then return math.sqrt((q[1]-p[1])^2+(q[2]-p[2])^2) end
    end
    local known_edge
    for k=1,#P do
      local d=dist(P[k], P[(k % #P)+1])
      if d then known_edge=d; break end
    end
    if known_edge then
      local function fmt(x)
        return (("%.6f"):format(x)):gsub("%.?0+$","")
      end
      -- single-length figures: equilateral, square, rhombus
      if not attrs.side and (attrs.equilateral or tag=="square" or tag=="rhombus") then
        attrs.side = fmt(known_edge)
      end
    end
  end

  -- Circle: a centre and a radius, with no polygon edges. Two forms:
  --   circle O radius:3   (or diameter:6)  -- autonomous, centre named O
  --   circle ABC          -- circle through three already-placed points
  --                          (circumscribed), or  ... inscribed  for the incircle
  -- The circle is returned as a fourth value; build_block stores it apart from
  -- the polygon vertices.
  if tag=="circle" then
    if attrs.radius or attrs.diameter then
      if #P~=1 then
        error("scholatex: circle by radius needs exactly one point, the centre, "
            .. "e.g. circle O radius:3")
      end
      -- A radius (or diameter) is either a number — radius:3 — or a pair of
      -- already-placed points naming a segment whose length is taken as the
      -- value: radius:AB is the compass set to the span A–B.
      local function length_value(v, what)
        local n = tonumber(v)
        if n then return n end
        if type(v)=="string" and #v==2 then
          local p,q = dict and dict[v:sub(1,1)], dict and dict[v:sub(2,2)]
          if p and q then
            return math.sqrt((q[1]-p[1])^2+(q[2]-p[2])^2)
          end
        end
        error("scholatex: circle "..what..":"..tostring(v).." must be a number "
            .. "or two already-placed points naming a segment, e.g. "..what..":AB")
      end
      local r = attrs.radius and length_value(attrs.radius,"radius")
             or length_value(attrs.diameter,"diameter")/2
      local C = dict and dict[P[1]]
      local cx,cy = C and C[1] or 0, C and C[2] or 0
      return nil, {}, attrs, {name=P[1], cx=cx, cy=cy, r=r}
    end
    if #P~=3 then
      error("scholatex: circle through points needs three points "
          .. "(circle ABC), or a centre with radius:/diameter:")
    end
    local function pt(ch)
      local q = dict and dict[ch]
      if not q then
        error("scholatex: circle "..table.concat(P).." needs A, B, C already "
            .. "placed by an earlier figure; or give a centre with radius:")
      end
      return q[1], q[2]
    end
    local ax,ay=pt(P[1]); local bx,by=pt(P[2]); local cxp,cyp=pt(P[3])
    local ux,uy,r
    if attrs.inscribed then
      ux,uy,r=Circle.inscribed(ax,ay,bx,by,cxp,cyp)
    else
      ux,uy,r=Circle.circumscribed(ax,ay,bx,by,cxp,cyp)
    end
    if not ux then
      error("scholatex: circle "..table.concat(P).." — the three points are "
          .. "collinear, no circle through them")
    end
    return nil, {}, attrs, {cx=ux, cy=uy, r=r}
  end

  local verts,marks,err
  if tag=="triangle" then
    if #P~=3 then error("scholatex: triangle needs 3 points, got "..#P) end
    if attrs.equilateral then verts,marks=Tri.equilateral(P,num(attrs.side,"side"))
    elseif attrs.isosceles then verts,err=Tri.isosceles(P,num(attrs.side,"side"),num(attrs.base,"base"))
    elseif attrs.right~=nil then
      local at=1
      if type(attrs.right)=="string" then for k,ch in ipairs(P) do if ch==attrs.right then at=k end end end
      -- the two legs run from the right-angle vertex to the other two points
      local i2=(at%3)+1
      local i3=(i2%3)+1
      -- each leg's length: from a named side (DK:6), or a known shared edge,
      -- or the positional sides:(p,q).
      local function leg_len(other_idx)
        local key = P[at]..P[other_idx]
        if named_sides[key] then return named_sides[key] end
        if dict and dict[P[at]] and dict[P[other_idx]] then
          local p,q=dict[P[at]],dict[P[other_idx]]
          return math.sqrt((q[1]-p[1])^2+(q[2]-p[2])^2)
        end
        return nil
      end
      local p = leg_len(i2)
      local q = leg_len(i3)
      -- fall back to positional sides:(p,q) for any leg still unknown
      if (not p or not q) and attrs.sides then
        local s=numlist(attrs.sides,"sides")
        if #s==2 then p = p or s[1]; q = q or s[2] end
      end
      if not p or not q then
        error("scholatex: triangle right needs the two legs — give sides:(p,q), "
            .. "or name a side like " .. P[at]..P[i2] .. ":6, or share an edge")
      end
      verts,marks=Tri.right(P,p,q,at)
    elseif attrs.sides and attrs.angle then
      local s=numlist(attrs.sides,"sides")
      if #s~=2 then error("scholatex: triangle sides:(a,b) angle:t needs two sides") end
      verts,marks=Tri.sas(P,s[1],s[2],num(attrs.angle,"angle"))
    elseif attrs.sides then
      local s=numlist(attrs.sides,"sides")
      if #s~=3 then error("scholatex: triangle sides:(a,b,c) needs three sides, or add angle: for two sides") end
      verts,err=Tri.sss(P,s[1],s[2],s[3])
    elseif attrs.angles and attrs.side then
      local a=numlist(attrs.angles,"angles")
      if #a~=2 then error("scholatex: triangle angles:(A,B) needs two angles") end
      verts,err=Tri.asa(P,a[1],a[2],num(attrs.side,"side"))
    elseif named_sides[P[1]..P[2]] and named_sides[P[2]..P[3]] and named_sides[P[3]..P[1]] then
      -- Three named sides: SSS in cyclic order. triangle ABC AB:3 BC:4 CA:5
      -- is exactly triangle ABC sides:(3,4,5) — first the side AB, then BC,
      -- then CA, the side CA being opposite the vertex B.
      verts,err=Tri.sss(P, named_sides[P[1]..P[2]],
                            named_sides[P[2]..P[3]],
                            named_sides[P[3]..P[1]])
    else error("scholatex: triangle needs a definition: equilateral side:s, isosceles side:e base:b, right sides:(p,q), sides:(a,b,c), named sides AB:.. BC:.. CA:.., sides:(a,b) angle:t, or angles:(A,B) side:c") end
  elseif tag=="square" then
    if #P~=4 then error("scholatex: square needs 4 points") end
    if not attrs.side then error("scholatex: square needs side:s (or a shared edge to deduce it from)") end
    verts,marks=Quad.square(P,num(attrs.side,"side"))
  elseif tag=="rectangle" then
    if #P~=4 then error("scholatex: rectangle needs 4 points") end
    local s=numlist(attrs.sides,"sides")
    if #s~=2 then error("scholatex: rectangle needs sides:(w,h)") end
    verts,marks=Quad.rectangle(P,s[1],s[2])
  elseif tag=="rhombus" then
    if #P~=4 then error("scholatex: rhombus needs 4 points") end
    if not attrs.side then error("scholatex: rhombus needs side:s (or a shared edge to deduce it from)") end
    verts,marks=Quad.rhombus(P,num(attrs.side,"side"),num(attrs.angle,"angle"))
  elseif tag=="parallelogram" then
    if #P~=4 then error("scholatex: parallelogram needs 4 points") end
    local s=numlist(attrs.sides,"sides")
    if #s~=2 then error("scholatex: parallelogram needs sides:(a,b) angle:t") end
    verts,marks=Quad.parallelogram(P,s[1],s[2],num(attrs.angle,"angle"))
  elseif tag=="trapezoid" then
    if #P~=4 then error("scholatex: trapezoid needs 4 points") end
    local b=numlist(attrs.bases,"bases")
    if #b~=2 then error("scholatex: trapezoid needs bases:(b1,b2) height:h") end
    local off=attrs.offset and num(attrs.offset,"offset") or nil
    verts,marks=Quad.trapezoid(P,b[1],b[2],num(attrs.height,"height"),off)
  elseif tag=="kite" then
    if #P~=4 then error("scholatex: kite needs 4 points") end
    local s=numlist(attrs.sides,"sides")
    if #s~=2 then error("scholatex: kite needs sides:(a,b) angle:t — a the two "
                      .. "upper sides, b the two lower, t the apex angle") end
    verts,marks=Quad.kite(P,s[1],s[2],num(attrs.angle,"angle"))
    if not verts then err=marks; marks=nil end
  elseif tag=="polygon" or tag=="pentagon" or tag=="hexagon" or tag=="octagon" then
    local need = ({pentagon=5, hexagon=6, octagon=8})[tag]
    if need and #P~=need then
      error("scholatex: "..tag.." needs "..need.." points, got "..#P)
    end
    if #P<3 then error("scholatex: polygon needs at least 3 points") end
    verts,marks=regular_polygon(P,attrs.side and num(attrs.side,"side") or 1)
  else error("scholatex: <draw> unknown figure '"..tag.."'") end

  if not verts then error("scholatex: "..tag.." — "..(err or "figure impossible")) end

  -- rotate:θ turns the whole figure by θ degrees about its first vertex (the
  -- reference point). Used to fan figures out — a dozen triangles stepped 30°
  -- apart share one apex and sweep a full turn.
  if attrs.rotate then
    local th = tonumber(attrs.rotate)
    if not th then
      error("scholatex: rotate: must be a number of degrees, got '"..tostring(attrs.rotate).."'")
    end
    local a = math.rad(th)
    local ca, sa = math.cos(a), math.sin(a)
    local ox, oy = verts[1][2], verts[1][3]
    for _, v in ipairs(verts) do
      local dx, dy = v[2]-ox, v[3]-oy
      v[2] = ox + dx*ca - dy*sa
      v[3] = oy + dx*sa + dy*ca
    end
  end

  return verts,marks or {},attrs
end

local function graft(verts,dict)
  local known={}
  for i,v in ipairs(verts) do if dict[v[1]] then known[#known+1]={i,v[1]} end end
  if #known==0 then return verts end
  if #known==1 then
    local i,name=known[1][1],known[1][2]
    local dx=dict[name][1]-verts[i][2]
    local dy=dict[name][2]-verts[i][3]
    local out={}
    for _,v in ipairs(verts) do out[#out+1]={v[1],v[2]+dx,v[3]+dy} end
    return out
  end
  local a,b=known[1],known[2]
  local la={verts[a[1]][2],verts[a[1]][3]}
  local lb={verts[b[1]][2],verts[b[1]][3]}
  local ga=dict[a[2]]; local gb=dict[b[2]]
  local llen=math.sqrt((lb[1]-la[1])^2+(lb[2]-la[2])^2)
  local glen=math.sqrt((gb[1]-ga[1])^2+(gb[2]-ga[2])^2)
  if math.abs(llen-glen)>1e-3*math.max(glen,1) then
    error("scholatex: <draw> cannot graft '"..a[2]..b[2].."': shared side length "
      ..string.format("%.2f",llen).." differs from the existing "
      ..string.format("%.2f",glen).." — make the measurements match")
  end
  local ang_l=math.atan(lb[2]-la[2],lb[1]-la[1])
  local ang_g=math.atan(gb[2]-ga[2],gb[1]-ga[1])
  local r=ang_g-ang_l
  local cr,sr=math.cos(r),math.sin(r)
  local out={}
  for _,v in ipairs(verts) do
    local x,y=v[2]-la[1],v[3]-la[2]
    out[#out+1]={v[1], x*cr-y*sr+ga[1], x*sr+y*cr+ga[2]}
  end
  -- Side test: which side of the shared edge (ga->gb) does each body lie on?
  -- The existing figure's body = the already-placed points NOT on the edge.
  -- The new figure's body = its non-shared points. If both are on the same
  -- side, reflect the new figure across the edge so the two pieces abut.
  local ex, ey = gb[1]-ga[1], gb[2]-ga[2]      -- edge direction
  local function side_of(px, py)
    return (px-ga[1])*ey - (py-ga[2])*ex       -- signed: >0 one side, <0 other
  end
  local shared = { [a[2]]=true, [b[2]]=true }
  -- existing body centroid (placed points not on the edge)
  local exsum, eysum, ecnt = 0, 0, 0
  for name, p in pairs(dict) do
    if not shared[name] then exsum=exsum+p[1]; eysum=eysum+p[2]; ecnt=ecnt+1 end
  end
  -- new body centroid (this figure's non-shared points)
  local nxsum, nysum, ncnt = 0, 0, 0
  for _, v in ipairs(out) do
    if not shared[v[1]] then nxsum=nxsum+v[2]; nysum=nysum+v[3]; ncnt=ncnt+1 end
  end
  if ecnt > 0 and ncnt > 0 then
    local se = side_of(exsum/ecnt, eysum/ecnt)
    local sn = side_of(nxsum/ncnt, nysum/ncnt)
    if se ~= 0 and sn ~= 0 and (se > 0) == (sn > 0) then
      -- reflect 'out' across the line ga->gb
      local elen2 = ex*ex + ey*ey
      local ref = {}
      for _, v in ipairs(out) do
        local wx, wy = v[2]-ga[1], v[3]-ga[2]
        local dot = (wx*ex + wy*ey) / elen2
        local projx, projy = dot*ex, dot*ey
        ref[#ref+1] = {v[1], ga[1]+2*projx-wx, ga[2]+2*projy-wy}
      end
      out = ref
    end
  end
  return out
end

local function emit_figure(f,opts,measured,ticked)
  -- `measured` and `ticked` are dictionaries shared across every figure of the
  -- block, each keyed by the normalised vertex-name pair of an edge. `measured`
  -- tracks edges that already carry a length label; `ticked` tracks edges that
  -- already carry an equal-side tick. A shared edge (the same two named points
  -- in two figures) is thus labelled once and ticked once, not twice.
  measured = measured or {}
  ticked   = ticked   or {}

  -- A point primitive: just the dot. Its name, if any, is placed by
  -- emit_labels, which can see the segments leaving it and push the label
  -- clear of them.
  if f.point then
    local p=f.point
    return string.format("\\fill (%.4f,%.4f) circle [radius=0.05];",p.x,p.y)
  end

  -- A line primitive: a straight segment between two resolved endpoints, with
  -- its length labelled on measures:cm / measures:mm, parallel to the segment.
  if f.segment then
    local s=f.segment
    local t={string.format("\\draw (%.4f,%.4f) -- (%.4f,%.4f);",s.x1,s.y1,s.x2,s.y2)}
    local munit=opts.measures
    if munit=="cm" or munit=="mm" then
      local dx,dy=s.x2-s.x1,s.y2-s.y1
      local lcm=math.sqrt(dx*dx+dy*dy); local l=math.max(lcm,1e-6)
      local mx,my=(s.x1+s.x2)/2,(s.y1+s.y2)/2
      local px,py=-dy/l,dx/l
      local ang=math.deg(math.atan(dy,dx))
      if ang>90 then ang=ang-180 elseif ang<=-90 then ang=ang+180 end
      local value=(munit=="mm") and lcm*10 or lcm
      local label=(("%.2f"):format(value)):gsub("%.?0+$","").." "..munit
      t[#t+1]=string.format("\\node[rotate=%.2f] at (%.4f,%.4f) {\\footnotesize %s};",
        ang,mx+px*0.28,my+py*0.28,label)
    end
    return table.concat(t,"\n")
  end

  -- A circle figure carries no polygon vertices: draw the disc outline, the
  -- centre dot, and (on measures:) the radius along a horizontal spoke.
  if f.circle then
    local c=f.circle
    local t={}
    t[#t+1]=string.format("\\draw (%.4f,%.4f) circle [radius=%.4f];",c.cx,c.cy,c.r)
    t[#t+1]=string.format("\\fill (%.4f,%.4f) circle [radius=0.04];",c.cx,c.cy)
    local munit=opts.measures
    if munit=="cm" or munit=="mm" then
      t[#t+1]=string.format("\\draw (%.4f,%.4f) -- (%.4f,%.4f);",
        c.cx,c.cy, c.cx+c.r,c.cy)
      local value=(munit=="mm") and c.r*10 or c.r
      local label=(("%.2f"):format(value)):gsub("%.?0+$","").." "..munit
      t[#t+1]=string.format("\\node at (%.4f,%.4f) {\\footnotesize %s};",
        c.cx+c.r/2, c.cy+0.28, label)
    end
    return table.concat(t,"\n")
  end

  local verts,marks=f.verts,f.marks
  local t={}
  for _,v in ipairs(verts) do t[#t+1]=string.format("\\coordinate (%s) at (%.4f,%.4f);",v[1],v[2],v[3]) end
  local names={}
  for _,v in ipairs(verts) do names[#names+1]="("..v[1]..")" end
  t[#t+1]="\\draw "..table.concat(names," -- ").." -- cycle;"

  -- Equal-side ticks and right-angle squares: drawn only on marks:on.
  if opts.marks=="on" then
    local function unit(ax,ay,bx,by)
      local dx,dy=bx-ax,by-ay; local l=math.max(math.sqrt(dx*dx+dy*dy),1e-6)
      return dx/l,dy/l
    end
    local function rightsquare(idx)
      local nx,ny=verts[idx][2],verts[idx][3]
      local i2=(idx%#verts)+1; local i3=((idx-2)%#verts)+1
      local u1x,u1y=unit(nx,ny,verts[i2][2],verts[i2][3])
      local u2x,u2y=unit(nx,ny,verts[i3][2],verts[i3][3])
      local d=0.3
      t[#t+1]=string.format("\\draw (%.4f,%.4f) -- (%.4f,%.4f) -- (%.4f,%.4f);",
        nx+u1x*d,ny+u1y*d, nx+u1x*d+u2x*d,ny+u1y*d+u2y*d, nx+u2x*d,ny+u2y*d)
    end
    if marks.right and marks.right~="all" then rightsquare(marks.right)
    elseif marks.right=="all" then
      -- "all" means every right angle, not just one: mark each vertex whose two
      -- incident edges are actually perpendicular (square, rectangle -> the four
      -- corners). Testing the angle keeps a non-right vertex from being marked.
      for k=1,#verts do
        local i2=(k%#verts)+1; local i3=((k-2)%#verts)+1
        local u1x,u1y=unit(verts[k][2],verts[k][3],verts[i2][2],verts[i2][3])
        local u2x,u2y=unit(verts[k][2],verts[k][3],verts[i3][2],verts[i3][3])
        if math.abs(u1x*u2x+u1y*u2y) < 1e-6 then rightsquare(k) end
      end
    end
    local edges={}
    if marks.sides=="all" then for k=1,#verts do edges[#edges+1]={k,(k%#verts)+1} end
    elseif type(marks.sides)=="table" then for _,pr in ipairs(marks.sides) do edges[#edges+1]=pr end end
    for _,e in ipairs(edges) do
      -- A shared edge carries the same two named points in both figures; key it
      -- by the sorted name pair so a previous figure's tick is not repeated.
      local na,nb=verts[e[1]][1],verts[e[2]][1]
      local key=(na<nb) and (na.."\1"..nb) or (nb.."\1"..na)
      if not ticked[key] then
        ticked[key]=true
        local ax,ay=verts[e[1]][2],verts[e[1]][3]
        local bx,by=verts[e[2]][2],verts[e[2]][3]
        local mx,my=(ax+bx)/2,(ay+by)/2
        local dx,dy=bx-ax,by-ay; local l=math.max(math.sqrt(dx*dx+dy*dy),1e-6)
        local px,py=-dy/l,dx/l; local s=0.12
        -- The third element of the pair, if any, is the tick multiplicity: one,
        -- two or three short strokes mark distinct equality groups (e.g. a kite's
        -- two upper sides single, two lower sides double). The strokes are spread
        -- along the edge direction (ux,uy), centred on the midpoint.
        local mult=e[3] or 1
        local ux,uy=dx/l,dy/l; local gap=0.08
        for m=1,mult do
          local off=((m-1)-(mult-1)/2)*gap
          local ox,oy=mx+ux*off,my+uy*off
          t[#t+1]=string.format("\\draw (%.4f,%.4f) -- (%.4f,%.4f);",
            ox-px*s,oy-py*s,ox+px*s,oy+py*s)
        end
      end
    end
  end

  -- Side measurements: drawn only on measures:cm or measures:mm. The
  -- coordinates are in centimetres (one unit = 1 cm), so the side length in
  -- cm is the Euclidean distance; in mm it is multiplied by ten. The figure
  -- is drawn convex by construction, so the outward normal of an edge points
  -- away from the centroid; the label sits just outside the edge midpoint and
  -- is rotated to run parallel to the side, the angle folded into ]-90, 90]
  -- so the text never reads upside down.
  local munit=opts.measures
  if munit=="cm" or munit=="mm" then
    local cx,cy,n=0,0,#verts
    for _,v in ipairs(verts) do cx=cx+v[2]; cy=cy+v[3] end
    cx,cy=cx/math.max(n,1),cy/math.max(n,1)
    for k=1,#verts do
      local a,b=verts[k],verts[(k%#verts)+1]
      -- A shared edge carries the same two named points in both figures.
      -- Key it by the sorted name pair so A-B and B-A collide, and skip it
      -- if a previous figure has already labelled it.
      local na,nb=a[1],b[1]
      local key=(na<nb) and (na.."\1"..nb) or (nb.."\1"..na)
      if not measured[key] then
        measured[key]=true
        local ax,ay,bx,by=a[2],a[3],b[2],b[3]
        local mx,my=(ax+bx)/2,(ay+by)/2
        local dx,dy=bx-ax,by-ay
        local lcm=math.sqrt(dx*dx+dy*dy)
        local l=math.max(lcm,1e-6)
        local px,py=-dy/l,dx/l
        -- orient the normal away from the centroid
        if px*(mx-cx)+py*(my-cy) < 0 then px,py=-px,-py end
        local off=0.28
        local ang=math.deg(math.atan(dy,dx))
        if ang>90 then ang=ang-180 elseif ang<=-90 then ang=ang+180 end
        local value=(munit=="mm") and lcm*10 or lcm
        local label=(("%.2f"):format(value)):gsub("%.?0+$","").." "..munit
        t[#t+1]=string.format("\\node[rotate=%.2f] at (%.4f,%.4f) {\\footnotesize %s};",
          ang,mx+px*off,my+py*off,label)
      end
    end
  end

  return table.concat(t,"\n")
end

local function emit_labels(figs)
  local cx,cy,n=0,0,0
  local seen={}
  for _,f in ipairs(figs) do
    if f.verts then
      for _,v in ipairs(f.verts) do
        if not seen[v[1]] then seen[v[1]]=true; cx=cx+v[2]; cy=cy+v[3]; n=n+1 end
      end
    end
  end
  cx,cy=cx/math.max(n,1),cy/math.max(n,1)
  local t,placed={},{}
  for _,f in ipairs(figs) do
    if f.verts then
      for _,v in ipairs(f.verts) do
        if not placed[v[1]] then
          placed[v[1]]=true
          local dx,dy=v[2]-cx,v[3]-cy
          local l=math.max(math.sqrt(dx*dx+dy*dy),1e-6)
          t[#t+1]=string.format("\\node at (%.4f,%.4f) {$%s$};",v[2]+dx/l*0.35,v[3]+dy/l*0.35,v[1])
        end
      end
    elseif f.circle and f.circle.name and not placed[f.circle.name] then
      placed[f.circle.name]=true
      local c=f.circle
      t[#t+1]=string.format("\\node[below left] at (%.4f,%.4f) {$%s$};",c.cx,c.cy,c.name)
    end
  end

  -- Named points: place each label away from the segments leaving the point,
  -- so the name never crosses a line. The push direction is opposite the mean
  -- direction of the attached segments; a lone point with no segment defaults
  -- to up-and-right.
  for _,f in ipairs(figs) do
    if f.point and f.point.name and not placed[f.point.name] then
      placed[f.point.name]=true
      local px,py=f.point.x,f.point.y
      local sx,sy,m=0,0,0
      for _,g in ipairs(figs) do
        if g.segment then
          local s=g.segment
          local function near(ax,ay) return math.abs(ax-px)<1e-6 and math.abs(ay-py)<1e-6 end
          if near(s.x1,s.y1) then
            local dx,dy=s.x2-px,s.y2-py; local l=math.max(math.sqrt(dx*dx+dy*dy),1e-6)
            sx=sx+dx/l; sy=sy+dy/l; m=m+1
          elseif near(s.x2,s.y2) then
            local dx,dy=s.x1-px,s.y1-py; local l=math.max(math.sqrt(dx*dx+dy*dy),1e-6)
            sx=sx+dx/l; sy=sy+dy/l; m=m+1
          end
        end
      end
      local ox,oy
      if m>0 and (sx*sx+sy*sy)>1e-9 then
        local l=math.sqrt(sx*sx+sy*sy); ox,oy=-sx/l,-sy/l
      else
        ox,oy=0.7071,0.7071   -- up-right default
      end
      t[#t+1]=string.format("\\node at (%.4f,%.4f) {$%s$};",px+ox*0.35,py+oy*0.35,f.point.name)
    end
  end
  return table.concat(t,"\n")
end

local function build_block(lines)
  local figs,dict={},{}
  local gopt={}
  for _,line in ipairs(lines) do
    if type(line)=="table" and line.kind then
      -- A low-level primitive (point or line) carries already-resolved
      -- coordinates. A named point also joins the dictionary so later lines
      -- can refer to it.
      if line.measures then gopt.measures=line.measures end
      if line.kind=="point" then
        if line.name then dict[line.name]={line.x,line.y} end
        figs[#figs+1]={point=line}
      elseif line.kind=="line" then
        figs[#figs+1]={segment=line}
      end
    else
      local verts,marks,attrs,circle=compute(line,dict)
      if circle then
        -- a named centre joins the dictionary so later figures and labels see it
        if circle.name and not dict[circle.name] then
          dict[circle.name]={circle.cx,circle.cy}
        end
        figs[#figs+1]={circle=circle}
      else
        verts=graft(verts,dict)
        for _,v in ipairs(verts) do if not dict[v[1]] then dict[v[1]]={v[2],v[3]} end end
        figs[#figs+1]={verts=verts,marks=marks}
      end
      if attrs.marks then gopt.marks=attrs.marks end
      if attrs.measures then gopt.measures=attrs.measures end
      if attrs.labels then gopt.labels=attrs.labels end
    end
  end
  -- Coordinates are kept as computed: one unit = one centimetre, so DK:4.5
  -- draws a 4.5 cm side. No global rescaling — a figure wider than the page
  -- is the author's cue to adjust the measurements before printing.
  gopt.marks    = gopt.marks    or "off"
  gopt.measures = gopt.measures or "off"
  if gopt.marks~="on" and gopt.marks~="off" then
    error("scholatex: <draw> marks: takes 'on' or 'off' (got '"..tostring(gopt.marks).."')")
  end
  if gopt.measures~="off" and gopt.measures~="cm" and gopt.measures~="mm" then
    error("scholatex: <draw> measures: takes 'off', 'cm' or 'mm' (got '"..tostring(gopt.measures).."')")
  end
  local out={"\\begin{center}\\begin{tikzpicture}[line width=0.5pt]"}
  local measured={}
  local ticked={}
  for _,f in ipairs(figs) do out[#out+1]=emit_figure(f,gopt,measured,ticked) end
  if gopt.labels~="off" then out[#out+1]=emit_labels(figs) end
  out[#out+1]="\\end{tikzpicture}\\end{center}"
  return table.concat(out,"\n")
end

-- Turn a raw figure line into a Lua string expression that, when run, yields
-- the line with #name and #{expr} interpolated in the loop's scope. A line
-- with no # is emitted as a plain quoted string; otherwise it is built by
-- concatenation so that #{k*30} and A#k evaluate against live loop variables.
local function line_to_luaexpr(line)
  if not line:find("#", 1, true) then
    return string.format("%q", line)
  end
  local parts, p = {}, 1
  while true do
    local h = line:find("#", p, true)
    if not h then parts[#parts+1] = string.format("%q", line:sub(p)); break end
    if h > p then parts[#parts+1] = string.format("%q", line:sub(p, h-1)) end
    local expr, after
    if line:sub(h+1, h+1) == "{" then
      expr, after = U.read_group(line, h+1)
    else
      expr = line:match("^#([%a_][%w_]*)", h)
      after = h + 1 + #expr
    end
    parts[#parts+1] = "tostring(" .. expr .. ")"
    p = after
  end
  return table.concat(parts, "..")
end

-- Detect a low-level primitive — point(arg) or line(arg, arg) — and return the
-- Lua that pushes a resolved table onto the accumulator, or nil if the line is
-- an ordinary figure. Each argument is either a name bound by `let A = {x, y}`
-- or a literal pair {x, y}; in both cases (ARG)[1] and (ARG)[2] read its
-- coordinates at runtime. Trailing words after the closing parenthesis are
-- options (currently measures:cm / measures:mm on a segment).
local function primitive_opts(rest)
  rest = U.trim(rest or "")
  if rest == "" then return "" end
  local m = rest:match("^measures:(%a+)$")
  if m == "cm" or m == "mm" then return (", measures=%q"):format(m) end
  error("scholatex: <draw> primitive option not understood: '" .. rest .. "'")
end

local function primitive_to_lua(line)
  line = U.trim(line)

  local parg, prest = line:match("^point%s*(%b())%s*(.-)$")
  if parg then
    parg = U.trim(parg:sub(2, -2))
    local nm = parg:match("^([%a_][%w_]*)$")
    local namefld = nm and ("name=%q, "):format(nm) or ""
    return ("__dadd({kind=\"point\", %sx=(%s)[1], y=(%s)[2]%s})")
           :format(namefld, parg, parg, primitive_opts(prest))
  end

  local largs, lrest = line:match("^line%s*(%b())%s*(.-)$")
  if largs then
    largs = largs:sub(2, -2)
    -- Split on the top-level comma (arguments may themselves be {x, y}).
    local depth, cut = 0, nil
    for k = 1, #largs do
      local c = largs:sub(k, k)
      if c == "{" or c == "(" then depth = depth + 1
      elseif c == "}" or c == ")" then depth = depth - 1
      elseif c == "," and depth == 0 then cut = k; break end
    end
    if not cut then
      error("scholatex: <draw> line(...) needs two points, e.g. line(A, B)")
    end
    local a = U.trim(largs:sub(1, cut - 1))
    local b = U.trim(largs:sub(cut + 1))
    return ("__dadd({kind=\"line\", x1=(%s)[1], y1=(%s)[2], x2=(%s)[1], y2=(%s)[2]%s})")
           :format(a, a, b, b, primitive_opts(lrest))
  end

  return nil
end

return function(sl)
  sl.build_figure_block = build_block   -- exposed for the runtime accumulator

  local function register(name)
    -- Inline form (no body braces): <draw>triangle ABC ... — a single figure
    -- line, no loop. Kept as a tag so the core's inline dispatch finds it.
    sl.register_tag(name, function(api, words, content)
      local parts = {}
      for k = 2, #words do parts[#parts+1] = words[k] end
      local line = U.trim((table.concat(parts, " ") .. " " .. (content or "")))
      local prim = primitive_to_lua(line)
      if prim then
        api.raw("do local __dfig = {}\n")
        api.raw("local function __dadd(s) __dfig[#__dfig+1] = s end\n")
        api.raw(prim .. "\n")
        api.raw('emit(__drawbuild(__dfig)) end\n')
      else
        api.raw('emit(__drawbuild({' .. line_to_luaexpr(line) .. '}))\n')
      end
    end)

    -- Block form (with body braces): accepts for/if/while and #-interpolation.
    sl.register_block(name, function(api, words_str, inner)
      local single = U.trim(words_str or "")

      api.raw("do local __dfig = {}\n")
      api.raw("local function __dadd(s) __dfig[#__dfig+1] = s end\n")

      local function emit_line(line)
        line = U.trim(line)
        if line == "" then return end
        local prim = primitive_to_lua(line)
        if prim then api.raw(prim .. "\n")
        else api.raw("__dadd(" .. line_to_luaexpr(line) .. ")\n") end
      end

      if single ~= "" then emit_line(single) end

      local i, total = 1, #inner
      while i <= total do
        local l = inner[i]
        if type(l) == "string" and l:match("^%s*}%s*$") then
          api.raw("end\n"); i = i + 1
        elseif type(l) == "string" and api.is_control_open(l) then
          api.raw(api.lua_control(l) .. "\n"); i = i + 1
        elseif type(l) == "string" and l:match("%S") then
          emit_line(l); i = i + 1
        else
          i = i + 1
        end
      end

      api.raw('emit(__drawbuild(__dfig)) end\n')
    end)
  end

  register("draw")
  register("figure")   -- kept as an alias during the transition
end
