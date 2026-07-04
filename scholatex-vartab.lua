local U    = require("scholatex-util")
local Math = require("scholatex-math")

-- =====================================================================
-- <vartab> --- tableaux de variations (mode manuel pur).
--
-- Trois attributs nommés, valeurs séparées par '|' (le séparateur de
-- cellules déjà connu de <table> et <matrix>) :
--
--   <vartab x:{-4 | -2 | 0 | 2 | 4}
--           deriv:{+ | - || - | +}
--           var:{-3 / 5 \ -inf || +inf \ 1 / 7}>
--
--   x      : les abscisses (bornes des intervalles), gauche -> droite.
--   deriv  : OPTIONNEL. Un signe par intervalle (+, -, 0 ou vide), donc
--            #x-1 cellules ; un '||' marque la derivee non definie a la
--            borne ou il est ecrit (il ne compte pas comme un signe).
--   var    : alternance VALEUR puis CONNECTEUR puis VALEUR ..., ou le
--            connecteur est  /  (monte),  \  (descend) ou  ||  (double
--            barre). Un '||' peut etre borde de deux valeurs (asymptote a
--            deux limites), d'une seule, ou d'aucune (barre seche).
--
-- Rendu via tkz-tab : \tkzTabInit, \tkzTabLine (signes), \tkzTabVar
-- (variations). La fonction elle-meme n'apparait jamais : <vartab> est
-- purement declaratif, il met en forme, il ne calcule rien.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Extraction des attributs key:{...} de la chaine d'options du tag.
-- Renvoie une table {x=..., deriv=..., var=..., ...} de chaines brutes.
-- ---------------------------------------------------------------------
local function parse_attrs(s)
  return U.parse_attrs(s, {
    tag           = "vartab",
    require_group = true,
    hint          = "expects key:{...} options (x, deriv, var)",
  })
end

-- ---------------------------------------------------------------------
-- Split sur '|' de premier niveau. Les spans maths $...$ sont proteges,
-- et un '||' double est conserve comme un seul token litteral (barre).
-- Renvoie la liste des cellules trimmees, ET indique si l'on veut les
-- '||' comme tokens a part (keep_bars) ou comme simples separateurs.
-- ---------------------------------------------------------------------
local function split_bar(line, keep_bars)
  local cells, buf, i, n, inmath = {}, {}, 1, #line, false
  local function flush() cells[#cells+1] = U.trim(table.concat(buf)); buf = {} end
  while i <= n do
    local c = line:sub(i, i)
    if c == "$" then
      inmath = not inmath; buf[#buf+1] = c; i = i + 1
    elseif c == "|" and not inmath then
      if line:sub(i+1, i+1) == "|" then
        if keep_bars then
          flush(); cells[#cells+1] = "||"; i = i + 2
        else
          buf[#buf+1] = "||"; i = i + 2   -- conserve comme litteral (rare)
        end
      else
        flush(); i = i + 1
      end
    else
      buf[#buf+1] = c; i = i + 1
    end
  end
  flush()
  -- retire d'eventuelles cellules vides nees d'un '||' colle a un '|'
  local out = {}
  for _, c in ipairs(cells) do
    if c ~= "" or not keep_bars then out[#out+1] = c end
  end
  return keep_bars and out or cells
end

-- ---------------------------------------------------------------------
-- Rendu d'une valeur (abscisse ou ordonnee) en maths. Si l'auteur a deja
-- mis des $...$, on respecte ; sinon on passe par le mini-langage maths
-- (qui gere -inf -> -\infty, pi/2 -> \pi/2, fractions, etc.).
-- ---------------------------------------------------------------------
local function render(cell)
  if cell == "" then return "{}" end
  if cell:match("^%$.*%$$") then return cell:sub(2, -2) end  -- enleve les $
  return Math.mathlite(cell)
end

local function mathwrap(cell)
  return "$" .. render(cell) .. "$"
end

-- ---------------------------------------------------------------------
-- DERIV : transforme les signes-par-intervalle en tokens \tkzTabLine.
-- L'auteur ecrit  + | - || - | +  : 4 signes (un par intervalle) plus un
-- '||' a la borne discontinue. tkzTabLine veut une alternance
--   <borne>, <signe>, <borne>, <signe>, ..., <borne>
-- soit 2*#x-1 tokens. On synthetise les bornes : 'z' sur un changement de
-- signe (ou un 0 explicite), 'd' (double barre) sur un '||', vide sinon.
--
-- `cells` est la liste issue de split_bar(deriv, true) : signes et '||'.
-- `nx` est le nombre d'abscisses.
-- ---------------------------------------------------------------------
local function build_deriv(cells, nx)
  -- separe les signes (par intervalle) des marqueurs de borne '||'
  local signs, barat = {}, {}   -- barat[k] = true si '||' AVANT le signe k+1
  for _, c in ipairs(cells) do
    if c == "||" then
      barat[#signs] = true       -- la barre suit le dernier signe lu
    elseif c == "+" or c == "-" or c == "0" or c == "" then
      signs[#signs+1] = c
    else
      error("scholatex: <vartab> deriv cell '" .. c .. "' is not a sign "
          .. "(+, -, 0 or empty) nor a double bar ||")
    end
  end
  if #signs ~= nx - 1 then
    error("scholatex: <vartab> deriv has " .. #signs .. " sign cells, "
        .. (nx-1) .. " expected (one per interval)")
  end

  local tokens = { "" }                         -- borne gauche
  for k = 1, #signs do
    local cur = signs[k]
    tokens[#tokens+1] = (cur == "0") and "" or cur
    if k < #signs then                          -- borne interieure
      if barat[k] then
        tokens[#tokens+1] = "d"                 -- double barre tkz-tab
      else
        local nxt = signs[k+1]
        local changes = (cur == "+" and nxt == "-")
                     or (cur == "-" and nxt == "+")
                     or (cur == "0") or (nxt == "0")
        tokens[#tokens+1] = changes and "z" or ""
      end
    end
  end
  tokens[#tokens+1] = ""                         -- borne droite
  return table.concat(tokens, ", ")
end

-- ---------------------------------------------------------------------
-- VAR : transforme l'alternance valeur/connecteur en tokens \tkzTabVar.
--
-- On lit la sequence en tokens (valeurs, et connecteurs / \ ||). On en
-- deduit la HAUTEUR de chaque valeur (haute = +, basse = -) :
--   - la 1re valeur est haute si le 1er connecteur descend (\),  basse
--     s'il monte (/) ; pres d'un '||' initial, voir plus bas.
--   - une valeur atteinte par '/' est haute, par '\' est basse.
-- Le '||' (double barre) relie deux branches : il peut porter une valeur
-- a gauche (limite a gauche) et/ou une a droite (limite a droite). On
-- emet le code tkz-tab adequat : +D-, -D+, +D, -D, D+, D-, ou D (seche).
--
-- Pour rester simple et correct, on construit d'abord une liste de
-- SEGMENTS separes par les '||', chaque segment etant une variation
-- continue (valeurs + fleches /\). On rend chaque segment, puis on
-- raccorde les segments par le bon code de double barre.
-- ---------------------------------------------------------------------

-- decoupe la sequence brute en : segments {values=..., arrows=...} et
-- la liste des barres entre eux.
local function lex_var(tokens, rowno)
  -- tokens alternent valeur, connecteur, valeur, connecteur...
  -- un connecteur est /, \, ou ||
  local segs = { { values = {}, arrows = {} } }
  local expect_value = true
  for _, t in ipairs(tokens) do
    if t == "/" or t == "\\" then
      if expect_value then
        error("scholatex: <vartab> var row " .. rowno .. " has an arrow '" .. t
            .. "' where a value was expected")
      end
      segs[#segs].arrows[#segs[#segs].arrows+1] = t
      expect_value = true
    elseif t == "||" then
      -- fin d'un segment, debut d'un nouveau
      segs[#segs+1] = { values = {}, arrows = {} }
      expect_value = true
    else
      -- une valeur
      segs[#segs].values[#segs[#segs].values+1] = t
      expect_value = false
    end
  end
  return segs
end

-- hauteur de chaque valeur d'un segment, d'apres ses fleches.
-- renvoie une liste de "+"/"-" de meme longueur que values.
local function seg_heights(seg, rowno)
  local v, a = seg.values, seg.arrows
  local h = {}
  if #v == 0 then return h end
  if #a ~= #v - 1 then
    error("scholatex: <vartab> var row " .. rowno .. " segment must alternate "
        .. "value, arrow, value (got " .. #v .. " values, " .. #a .. " arrows)")
  end
  if #v == 1 then
    h[1] = "?"                  -- hauteur indeterminee (resolue par la barre)
    return h
  end

  -- Une valeur interieure n'est legitime que si elle est un EXTREMUM : ses
  -- deux fleches adjacentes changent de sens (/\ maximum, \/ minimum). Deux
  -- fleches de meme sens (// ou \\) signaleraient une valeur intermediaire
  -- sur une branche monotone -- ce qui n'a pas sa place dans un tableau de
  -- variations (l'ordonnee d'un point courant se lit sur le trace, pas ici).
  -- On le refuse explicitement.
  h[1] = (a[1] == "/") and "-" or "+"
  for i = 2, #v - 1 do
    local ain, aout = a[i-1], a[i]
    if ain == aout then
      error("scholatex: <vartab> has a value between two '"
          .. (ain == "/" and "/" or "\\") .. "' arrows (same direction); a "
          .. "variation table lists only bounds and extrema, not intermediate "
          .. "points. Remove that value (and its abscissa); a point like "
          .. "f(0)=1 belongs on the plot, not the table.")
    elseif ain == "/" and aout == "\\" then
      h[i] = "+"                          -- maximum
    else                                  -- ain == "\\" and aout == "/"
      h[i] = "-"                          -- minimum
    end
  end
  h[#v] = (a[#a] == "/") and "+" or "-"
  return h
end

local function build_var(line, rowno)
  -- on tokenise en gardant /, \, || comme connecteurs distincts
  local tokens = {}
  local i, n, buf, inmath = 1, #line, {}, false
  local function flush()
    local w = U.trim(table.concat(buf)); buf = {}
    if w ~= "" then tokens[#tokens+1] = w end
  end
  while i <= n do
    local c = line:sub(i, i)
    if c == "$" then inmath = not inmath; buf[#buf+1] = c; i = i + 1
    elseif not inmath and c == "|" and line:sub(i+1, i+1) == "|" then
      flush(); tokens[#tokens+1] = "||"; i = i + 2
    elseif not inmath and (c == "/" or c == "\\")
           and (i == 1 or line:sub(i-1, i-1):match("%s"))
           and (i == n or line:sub(i+1, i+1):match("%s")) then
      -- Une fleche est un / ou \ ISOLE par des espaces (ou en bord). Un /
      -- colle a un chiffre est une barre de fraction (2/3), pas une fleche.
      flush(); tokens[#tokens+1] = c; i = i + 1
    elseif not inmath and c:match("%s") then
      flush(); i = i + 1
    else
      buf[#buf+1] = c; i = i + 1
    end
  end
  flush()

  local segs = lex_var(tokens, rowno)

  -- calcule les hauteurs segment par segment
  for _, seg in ipairs(segs) do
    seg.heights = seg_heights(seg, rowno)
  end

  -- Resolution des hauteurs indeterminees ('?') des segments a 1 valeur :
  -- un segment isole d'une seule valeur tire sa hauteur du contexte. Par
  -- defaut on le met haut ('+') ; ce cas est rare (barre seche bordee d'un
  -- seul cote). On laisse l'auteur preciser via une fleche s'il le veut.
  for _, seg in ipairs(segs) do
    for k, hh in ipairs(seg.heights) do
      if hh == "?" then seg.heights[k] = "+" end
    end
  end

  -- Emission des tokens \tkzTabVar. On parcourt les segments ; entre deux
  -- segments consecutifs il y a une double barre, rendue par un code D.
  local out = {}
  for si, seg in ipairs(segs) do
    local v, h = seg.values, seg.heights
    for k = 1, #v do
      local isLast  = (k == #v)
      local isFirst = (k == 1)
      local height  = h[k]
      local valtex  = mathwrap(v[k])

      if isLast and si < #segs then
        -- derniere valeur AVANT une double barre : c'est la limite a
        -- gauche de la barre. On regarde la 1re valeur du segment suivant
        -- (limite a droite) pour choisir le code a deux hauteurs.
        local nxt = segs[si+1]
        if #nxt.values > 0 then
          local lh = height                       -- hauteur limite gauche
          local rh = nxt.heights[1]               -- hauteur limite droite
          local rtex = mathwrap(nxt.values[1])
          local code = lh .. "D" .. rh            -- +D-, -D+, +D+, -D-
          out[#out+1] = code .. "/" .. valtex .. "/" .. rtex
          nxt._consumed_first = true              -- ne pas re-emettre
        else
          -- barre sans limite a droite : limite gauche seule
          out[#out+1] = (height .. "D") .. "/" .. valtex
        end
      elseif isFirst and si > 1 and segs[si]._consumed_first then
        -- cette 1re valeur a deja ete emise avec la barre precedente
      else
        out[#out+1] = height .. "/" .. valtex
      end
    end
  end

  return table.concat(out, ", ")
end

-- ---------------------------------------------------------------------
-- Libelles. name:{g(t)} -> fonction "g", variable "t", derivee "g'(t)".
-- name:{g}    -> fonction "g", variable "x" (defaut).
-- absent      -> "f", "x".
-- Renvoie xlabel, dlabel, flabel (chacun deja en maths, sans les $).
-- ---------------------------------------------------------------------
local function labels(name)
  local fn, var = "f", "x"
  if name and name ~= "" then
    local f, v = name:match("^%s*([%a]%w*)%s*%(%s*([%a]%w*)%s*%)%s*$")
    if f then
      fn, var = f, v
    else
      local f2 = name:match("^%s*([%a]%w*)%s*$")
      if f2 then fn = f2
      else
        error("scholatex: <vartab> name:{...} must be a function name like "
            .. "g or g(t), got '" .. name .. "'")
      end
    end
  end
  return Math.mathlite(var),
         Math.mathlite(fn) .. "'(" .. Math.mathlite(var) .. ")",
         Math.mathlite(fn) .. "(" .. Math.mathlite(var) .. ")",
         Math.mathlite(fn) .. "''(" .. Math.mathlite(var) .. ")"
end

-- ---------------------------------------------------------------------
-- Genere le code tkz-tab a partir d'une table d'attributs bruts
-- {name=, x=, deriv=, var=, expr=}. Le champ `expr` est ignore
-- ici (reserve a <plot>) ; il est simplement transporte par l'objet.
-- ---------------------------------------------------------------------
local function generate(attrs)
  if not attrs.x then
    error("scholatex: <vartab> needs an x:{...} list of abscissas")
  end
  if not attrs.var then
    error("scholatex: <vartab> needs a var:{...} variation list")
  end
  -- Sign lines are all optional. Four shapes are allowed, from fullest to
  -- barest:
  --   x / f'' / f' / f   (second: + deriv:)  full study
  --   x / f' / f         (deriv:)            classic variation table
  --   x / f'' / f        (second:)           convexity table
  --   x / f              (neither)           plain value table
  -- f (the var: line) is always present; f'' sits above f' when both show.

  local xlabel, dlabel, flabel, ddlabel = labels(attrs.name)

  local xcells = split_bar(attrs.x, false)
  local xs = {}
  for _, c in ipairs(xcells) do xs[#xs+1] = mathwrap(c) end
  if #xs < 2 then
    error("scholatex: <vartab> x:{...} needs at least two abscissas")
  end

  local rowdefs, rowbodies = {}, {}
  -- Ligne f'' (convexite), OPTIONNELLE, placee au-dessus de f'. C'est une
  -- ligne de signe comme f' : un signe par intervalle, '||' pour une valeur
  -- interdite. Un '+' marque la convexite, un '-' la concavite ; un zero
  -- (changement de signe) est un point d'inflexion.
  if attrs.second then
    local scells = split_bar(attrs.second, true)
    rowdefs[#rowdefs+1] = "$" .. ddlabel .. "$ / 1"
    rowbodies[#rowbodies+1] = { kind = "line", body = build_deriv(scells, #xs) }
  end
  if attrs.deriv then
    local dcells = split_bar(attrs.deriv, true)
    rowdefs[#rowdefs+1] = "$" .. dlabel .. "$ / 1"
    rowbodies[#rowbodies+1] = { kind = "line", body = build_deriv(dcells, #xs) }
  end
  rowdefs[#rowdefs+1] = "$" .. flabel .. "$ / 2.6"
  rowbodies[#rowbodies+1] = { kind = "var", body = build_var(attrs.var, 1) }

  local init  = "$" .. xlabel .. "$ / 1 , " .. table.concat(rowdefs, " , ")
  local xlist = table.concat(xs, " , ")

  local out = {}
  out[#out+1] = "\\begin{center}\\begin{tikzpicture}"
  out[#out+1] = "\\tkzTabInit[espcl=2.2]{" .. init .. "}{" .. xlist .. "}"
  for _, rb in ipairs(rowbodies) do
    if rb.kind == "line" then
      out[#out+1] = "\\tkzTabLine{" .. rb.body .. "}"
    else
      out[#out+1] = "\\tkzTabVar{" .. rb.body .. "}"
    end
  end
  out[#out+1] = "\\end{tikzpicture}\\end{center}"
  return table.concat(out)
end

-- ---------------------------------------------------------------------
-- Enregistrement.
-- ---------------------------------------------------------------------
return function(sl)
  -- Parseur d'objet, appele par le moteur sur  let X = <fn ...>.
  -- Renvoie la table d'attributs bruts, stockee dans sl._objects[X].
  -- Deux formes :
  --   attributs purs :   name:{f(x)} expr:{...} x:{...} ...
  --   forme equation :   f(x) = (x+2)(x-3)  [attributs ensuite]
  -- L'equation se lit comme au tableau ; elle fournit name: et expr: et
  -- declare la variable en situation. Les attributs de tableau (x:,
  -- deriv:, var:, second:) restent des attributs apres l'expression.
  sl.fn_parse = function(inner)
    inner = U.trim(inner or "")
    local fname, fvar, tail =
      inner:match("^([%a_][%w_]*)%s*%(%s*([%a_][%w_]*)%s*%)%s*(.*)$")
    if not fname then
      return parse_attrs(inner)
    end
    -- en-tete sans '=' : objet purement tabulaire (un tableau sans
    -- formule) ; le nom et la variable suffisent, les attributs suivent.
    if not tail:match("^=") then
      if tail ~= "" and not tail:match("^[%a_][%w_]*:") then
        error("scholatex: <fn " .. fname .. "(" .. fvar .. ") ...> expects "
            .. "either  = expression  or table attributes (x:, deriv:, var:)")
      end
      local attrs = parse_attrs(U.trim(tail))
      if attrs.name or attrs.expr then
        error("scholatex: <fn> takes either the head form  " .. fname .. "("
            .. fvar .. ")  or name:/expr: attributes, not both")
      end
      attrs.name = fname .. "(" .. fvar .. ")"
      return attrs
    end
    local tail2 = U.trim(tail:sub(2))
    -- l'expression court jusqu'au premier attribut `mot:` (aucune
    -- expression du mini-langage ne contient de ':')
    local p = tail2:find("%f[%S][%a_][%w_]*:")
    local expr, attrstr
    if p then
      expr, attrstr = U.trim(tail2:sub(1, p - 1)), tail2:sub(p)
    else
      expr, attrstr = tail2, ""
    end
    if expr == "" then
      error("scholatex: <fn " .. fname .. "(" .. fvar .. ") = ...> has an "
          .. "empty right-hand side")
    end
    local attrs = parse_attrs(U.trim(attrstr))
    if attrs.name or attrs.expr then
      error("scholatex: <fn> takes either the equation form  " .. fname .. "("
          .. fvar .. ") = ...  or name:/expr: attributes, not both")
    end
    attrs.name = fname .. "(" .. fvar .. ")"
    attrs.expr = expr
    return attrs
  end

  sl.register_tag("vartab", function(api, words, content)
    -- Deux formes :
    --   <vartab g>                 -> reference a un objet <fn>
    --   <vartab x:{...} var:{...}> -> attributs inline
    -- On distingue : si le seul mot (hors "vartab") n'a pas de ':' et
    -- nomme un objet connu, c'est une reference ; sinon, inline.
    local parts = {}
    for k = 2, #words do parts[#parts+1] = words[k] end

    local attrs
    if #parts == 1 and not parts[1]:find(":", 1, true)
       and sl._objects and sl._objects[parts[1]] then
      attrs = sl._objects[parts[1]]
    elseif #parts == 1 and not parts[1]:find(":", 1, true) then
      error("scholatex: <vartab " .. parts[1] .. "> refers to an object that "
          .. "is not defined; write  let " .. parts[1]
          .. " = <fn ...>  first, or give x:{...} var:{...} inline")
    else
      attrs = parse_attrs(U.trim(table.concat(parts, " ")))
    end

    api.raw('emit(' .. string.format("%q", generate(attrs)) .. ")\n")
  end)
end
