
local U     = require("scholatex-util")
local STYLE = require("scholatex-style")
local MATH  = require("scholatex-math")
local NUMEVAL = require("scholatex-numeval")

local sl = {}
sl.util   = U
sl.style  = STYLE
sl.math   = MATH
sl._tags   = {}
sl._blocks = {}

local ALIAS, MACRO, BLOCKALIAS

-- Warnings must land in the .log (and the terminal): editors such as
-- TeXstudio show the log, not stderr. Outside LuaTeX (plain texlua tests),
-- texio is absent and stderr is the fallback.
local function warn(msg)
  if texio and texio.write_nl then
    texio.write_nl("term and log", msg)
  else
    io.stderr:write(msg .. "\n")
  end
end

function sl.register_tag(name, fn)
  if sl._tags[name] then
    error("scholatex: tag '" .. name .. "' is already registered (name clash)")
  end
  sl._tags[name] = fn
end

function sl.register_block(name, fn)
  if sl._blocks[name] then
    error("scholatex: block '" .. name .. "' is already registered (name clash)")
  end
  sl._blocks[name] = fn
end

function sl.use(modname)
  local m = require(modname)
  if type(m) == "function" then m(sl) end
  return m
end

local forward_text

local function lit(code, text)
  if text ~= "" then
    code[#code + 1] = "emit(" .. string.format("%q", text) .. ")\n"
  end
end

local function warn_if_shadows(name, lineno)
  local native = false
  local ok, r = pcall(STYLE.resolve, name)
  if ok and r then native = true end
  if sl._blocks[name] or sl._tags[name] then native = true end
  if native then
    local where = lineno and (" (line " .. lineno .. ")") or ""
    warn("scholatex: warning: 'let " .. name .. "'" .. where
      .. " shadows a built-in name and will be ignored; "
      .. "the built-in '" .. name .. "' always takes precedence. "
      .. "Use a different alias name.")
  end
end

local function ends_struct_open(line)
  local t = line:gsub("%s+$", "")
  if t:sub(-1) ~= "{" then return false end
  if t:sub(-2) == "{{" then return false end
  return true
end

local function is_control_open(line)
  if line:match("^%s*for%s+[%a_][%w_]*%s+in%s+%b[]%s*{%s*$") then return true end
  if line:match("^%s*for%s+[%a_][%w_]*%s+in%s+%S+%.%.%S+%s*{%s*$") then return true end
  if line:match("^%s*}%s*else%s*{%s*$") then return true end
  if line:match("^%s*if%s+.+{%s*$") and ends_struct_open(line) then return true end
  if line:match("^%s*while%s+.+{%s*$") and ends_struct_open(line) then return true end
  return false
end

local function lua_control(line)
  local lv, llist = line:match("^%s*for%s+([%a_][%w_]*)%s+in%s+%[(.-)%]%s*{%s*$")
  if lv then
    local items = U.split_commas(llist)
    local quoted = {}
    for _, it in ipairs(items) do
      -- A numeric item stays a NUMBER, so that  for k in [1, 2, 3]  then
      -- if k > 2  compares numbers, exactly as the range form 1..3 does.
      -- Anything else is a string literal.
      if tonumber(it) then
        quoted[#quoted + 1] = it
      else
        quoted[#quoted + 1] = string.format("%q", it)
      end
    end
    return ("for _, %s in ipairs({%s}) do"):format(lv, table.concat(quoted, ", "))
  end
  local v, a, b = line:match("^%s*for%s+([%a_][%w_]*)%s+in%s+(.-)%.%.(.-)%s*{%s*$")
  if v then return ("for %s = %s, %s do"):format(v, a, b) end
  local cond = line:match("^%s*if%s+(.-)%s*{%s*$")
  if cond then return "if " .. cond .. " then" end
  if line:match("^%s*}%s*else%s*{%s*$") then return "else" end
  local wc = line:match("^%s*while%s+(.-)%s*{%s*$")
  if wc then return "while " .. wc .. " do" end
  return nil
end

local process_lines

local function mkapi(code)
  return {
    lit             = function(t) lit(code, t) end,
    raw             = function(t) code[#code + 1] = t end,
    forward_text    = function(t) forward_text(code, t) end,
    is_control_open = is_control_open,
    lua_control     = lua_control,
    process_block   = function(lines)
      local norm = {}
      for _, l in ipairs(lines) do
        if type(l) == "string" then norm[#norm+1] = {text = l}
        else norm[#norm+1] = l end
      end
      process_lines(code, norm)
    end,
  }
end

local function emit_tag(code, words_str, content)
  local words = {}
  for w in words_str:gmatch("%S+") do words[#words + 1] = w end
  local head = words[1]

  local handler = sl._tags[head]
  if handler then
    handler(mkapi(code), words, content)
    return
  end

  if MACRO[head] then
    local m = MACRO[head]
    local args = {}
    local depth, start, k, idx, n = 0, 1, 0, 1, #content
    while idx <= n do
      local c = content:sub(idx, idx)
      if c == "\\" then idx = idx + 2
      else
        if c == "{" then depth = depth + 1
        elseif c == "}" then depth = depth - 1
        elseif c == "," and depth == 0 then
          k = k + 1
          args[k] = U.trim(content:sub(start, idx - 1))
          start = idx + 1
        end
        idx = idx + 1
      end
    end
    k = k + 1
    args[k] = U.trim(content:sub(start))

    local body = m.body
    for pi, pname in ipairs(m.params) do
      local repl = (args[pi] or ""):gsub("%%", "%%%%")
      body = body:gsub("#" .. pname .. "%f[%W]", repl)
    end
    forward_text(code, body)
    return
  end

  local outer, inner = STYLE.classify_split(words, ALIAS)

  for _, e in ipairs(outer) do lit(code, e[1]) end

  local raw = U.split_top_newlines(content)
  local paras = {}
  for _, para in ipairs(raw) do
    local clean = para:gsub("^[ \t]+", ""):gsub("[ \t]+$", "")
    if clean ~= "" then paras[#paras + 1] = clean end
  end
  for pi, para in ipairs(paras) do
    if pi > 1 then lit(code, " \\par ") end
    for _, e in ipairs(inner) do lit(code, e[1]) end
    forward_text(code, para)
    for j = #inner, 1, -1 do lit(code, inner[j][2]) end
  end

  for j = #outer, 1, -1 do lit(code, outer[j][2]) end
end

forward_text = function(code, s)
  local i, n = 1, #s
  local buf = {}
  local function flush() lit(code, table.concat(buf)); buf = {} end

  while i <= n do
    local c = s:sub(i, i)

    if c == "$" then
      local close = s:find("$", i + 1, true)
      if not close then
        local where = sl._line and (" (line " .. sl._line .. ")") or ""
        warn("scholatex: warning: unterminated '$'" .. where
          .. "; treating it as a literal dollar sign.")
        buf[#buf + 1] = "\\$"; i = i + 1
        goto continue
      end
      local inner = s:sub(i + 1, close - 1)
      flush()

      local exprs = {}
      local rebuilt, k = {}, 1
      while k <= #inner do
        local hash = inner:find("#", k, true)
        if not hash then rebuilt[#rebuilt+1] = inner:sub(k); break end
        rebuilt[#rebuilt+1] = inner:sub(k, hash - 1)
        local expr, after
        if inner:sub(hash+1, hash+1) == "{" then
          expr, after = U.read_group(inner, hash + 1)
        else
          local name = inner:match("^#([%a_][%w_]*)", hash)
          if name then
            expr, after = name, hash + 1 + #name
          else
            rebuilt[#rebuilt+1] = "\\#"
            k = hash + 1
            goto cont_hash
          end
        end
        exprs[#exprs+1] = expr
        rebuilt[#rebuilt+1] = "\\scholatexI{" .. #exprs .. "}"
        k = after
        ::cont_hash::
      end

      local transformed = MATH.mathlite(table.concat(rebuilt))

      lit(code, "$")
      local p = 1
      while p <= #transformed do
        local a, b, num = transformed:find("\\scholatexI{(%d+)}", p)
        if not a then lit(code, transformed:sub(p)); break end
        if a > p then lit(code, transformed:sub(p, a - 1)) end
        code[#code+1] = "emit(_fmtm(" .. exprs[tonumber(num)] .. "))\n"
        p = b + 1
      end
      lit(code, "$")
      i = close + 1

    elseif c == "\\" then
      buf[#buf + 1] = "\\textbackslash{}"; i = i + 1

    elseif c == "<" then
      if s:sub(i + 1, i + 1) == "<" then
        buf[#buf + 1] = "\\textless{}"; i = i + 2
        goto continue
      end
      local close = s:find(">", i + 1, true)
      if not close then
        local where = sl._line and (" (line " .. sl._line .. ")") or ""
        warn("scholatex: warning: unterminated '<'" .. where
          .. "; treating it as a literal '<'. To print a literal '<', double it as <<.")
        buf[#buf + 1] = "\\textless{}"; i = i + 1
        goto continue
      end
      local words_str = s:sub(i + 1, close - 1)
      local after_gt = close + 1
      local probe = after_gt
      while s:sub(probe, probe):match("[ \t]") do probe = probe + 1 end
      flush()
      if s:sub(probe, probe) == "{" then
        local content, after = U.read_group(s, probe)
        emit_tag(code, words_str, content)
        i = after
      else
        local nl = s:find("\n", after_gt, true)
        local stop = nl and (nl - 1) or #s
        local content = s:sub(after_gt, stop)
        emit_tag(code, words_str, content)
        i = stop + 1
      end

    elseif c == "#" then
      local nxt = s:sub(i + 1, i + 1)
      if nxt == "#" then
        buf[#buf + 1] = "\\#"; i = i + 2
      elseif nxt == "{" then
        local expr, after = U.read_group(s, i + 1)
        flush()
        code[#code + 1] = "emit(_fmt(" .. expr .. "))\n"
        i = after
      else
        local name = s:match("^#([%a_][%w_]*)", i)
        if name then
          flush()
          code[#code + 1] = "emit(_fmt(" .. name .. "))\n"
          i = i + 1 + #name
        else
          buf[#buf + 1] = "\\#"; i = i + 1
        end
      end

    else
      if c == "\n" then
        flush()
        lit(code, " \\par ")
      elseif c == ">" then
        if s:sub(i + 1, i + 1) == ">" then i = i + 1 end
        buf[#buf + 1] = "\\textgreater{}"
      elseif c == "{" then
        if s:sub(i + 1, i + 1) == "{" then i = i + 1 end
        buf[#buf + 1] = "\\{"
      elseif c == "}" then
        if s:sub(i + 1, i + 1) == "}" then i = i + 1 end
        buf[#buf + 1] = "\\}"
      elseif c == "_" then buf[#buf + 1] = "\\_"
      elseif c == "&" then buf[#buf + 1] = "\\&"
      elseif c == "%" then buf[#buf + 1] = "\\%"
      elseif c == "^" then buf[#buf + 1] = "\\textasciicircum{}"
      elseif c == "~" then buf[#buf + 1] = "\\textasciitilde{}"
      elseif c == "\194" and s:sub(i + 1, i + 1) == "\176" then
        buf[#buf + 1] = "\\ensuremath{^\\circ}"; i = i + 1
      else buf[#buf + 1] = c end
      i = i + 1
    end
    ::continue::
  end
  flush()
end

local function tag_brace_delta(line)
  local delta, i, n = 0, 1, #line
  while i <= n do
    local c = line:sub(i, i)
    if c == "<" then
      local close = line:find(">", i + 1, true)
      if close then
        local b = close + 1
        while line:sub(b, b):match("%s") do b = b + 1 end
        if line:sub(b, b) == "{" then
          local depth, j = 0, b
          while j <= n do
            local d = line:sub(j, j)
            if d == "{" then depth = depth + 1
            elseif d == "}" then depth = depth - 1 end
            if depth == 0 then break end
            j = j + 1
          end
          delta = delta + depth
          i = (depth == 0) and (j + 1) or (n + 1)
        else
          i = close + 1
        end
      else
        i = i + 1
      end
    elseif c == "#" and line:sub(i + 1, i + 1) == "{" then
      local depth, j = 0, i + 1
      while j <= n do
        local d = line:sub(j, j)
        if d == "{" then depth = depth + 1
        elseif d == "}" then depth = depth - 1 end
        if depth == 0 then break end
        j = j + 1
      end
      delta = delta + depth
      i = (depth == 0) and (j + 1) or (n + 1)
    else
      i = i + 1
    end
  end
  return delta
end

local function opener_unclosed(line)
  if not line:match("^%s*<%a[%w_]*") then return false end
  local i, n, depth, bdepth = 1, #line, 0, 0
  while i <= n do
    local c = line:sub(i, i)
    if c == "[" then
      bdepth = bdepth + 1; i = i + 1
    elseif c == "]" then
      if bdepth > 0 then bdepth = bdepth - 1 end
      i = i + 1
    elseif c == ">" and depth == 0 and bdepth == 0 then
      return false
    else
      local kind, j = U.brace_scan(line, i)
      if kind == "open" then depth = depth + 1
      elseif kind == "close" then if depth > 0 then depth = depth - 1 end end
      i = j
    end
  end
  return true
end

process_lines = function(code, body_lines)
  local idx, total = 1, #body_lines
  while idx <= total do
    local entry = body_lines[idx]
    if entry.lineno then sl._line = entry.lineno end
    if entry.fninner then
      local attrs = sl.fn_parse(entry.fninner)
      local key = entry.fnreg
      if not key or key == false then
        key = attrs.name and attrs.name:match("^([%a_][%w_]*)")
        if not key then
          error("scholatex: line " .. (entry.lineno or "?")
              .. ": a standalone <fn> registers itself and so needs the "
              .. "equation form  <fn f(x) = ...>  (or bind it with let)", 0)
        end
        warn_if_shadows(key, entry.lineno or 0)
      end
      sl._objects = sl._objects or {}
      sl._objects[key] = attrs
      idx = idx + 1
    elseif entry.var then
      code[#code + 1] = "local " .. entry.var .. " = " .. entry.expr .. "\n"
      idx = idx + 1
    else
      local line = entry.text
      if opener_unclosed(line) then
        local j = idx
        local joined = line
        while j < total and opener_unclosed(joined) do
          j = j + 1
          joined = joined .. "\n" .. (body_lines[j].text or "")
        end
        if not opener_unclosed(joined) then
          line = joined
          idx = j
        end
      end
      local bname, bwords = line:match("^%s*<(%a[%w_]*)%s*(.-)>%s*{%s*$")
      if bname and BLOCKALIAS[bname] then
        local def = BLOCKALIAS[bname]
        local opts = def.opts
        if #def.params > 0 then
          local args = U.split_commas(bwords or "")
          for pi, pname in ipairs(def.params) do
            local repl = (args[pi] or ""):gsub("%%", "%%%%")
            opts = opts:gsub("#" .. pname .. "%f[%W]", repl)
          end
          bwords = ""
        end
        bwords = opts .. " " .. (bwords or "")
        bname = def.block
      end
      if bname and sl._blocks[bname] then
        idx = idx + 1
        local inner
        inner, idx = U.collect_block(body_lines, idx)
        local inner_str = {}
        for _, e in ipairs(inner) do
          inner_str[#inner_str+1] = (type(e) == "table") and e.text or e
        end
        sl._blocks[bname](mkapi(code), bwords or "", inner_str)
        code[#code + 1] = 'emit(" \\\\par ")\n'
      elseif line:match("^%s*}%s*$") then
        code[#code + 1] = "end\n"
        idx = idx + 1
      elseif is_control_open(line) then
        code[#code + 1] = lua_control(line) .. "\n"
        idx = idx + 1
      else
        local chunk, delta = line, tag_brace_delta(line)
        while delta > 0 and idx < total do
          idx = idx + 1
          local nxt = body_lines[idx].text or ""
          chunk = chunk .. "\n" .. nxt
          delta = delta + U.raw_brace_delta(nxt)
        end
        forward_text(code, chunk)
        code[#code + 1] = 'emit(" \\\\par ")\n'
        idx = idx + 1
      end
    end
  end
end

local function build_lua(src)
  local lang = (sl.config and sl.config.lang) or "fr"
  local prec = (sl.config and sl.config.precision) or -1
  local sep_txt  = (lang == "en") and "." or ","
  local sep_math = (lang == "en") and "." or "{,}"
  local function q(s) return string.format("%q", s) end
  local code = {
    "local _parts = {}\n",
    "local function emit(s) _parts[#_parts+1] = s end\n",
    NUMEVAL.PREAMBLE,
    NUMEVAL.inject_locals(),
    "local abs=math.abs; local max=math.max; local min=math.min\n",
    "local _SEPT=" .. q(sep_txt) .. "; local _SEPM=" .. q(sep_math) .. "\n",
    "local _PREC=" .. tostring(prec) .. "\n",
    -- Display a computed number: round to _PREC decimals when _PREC >= 0
    -- (trailing zeros then dropped, so 3.50 -> 3.5, 4.0 -> 4), otherwise
    -- print it as Lua would. Non-numbers pass through untouched. _fmt is
    -- for text mode (decimal sep _SEPT), _fmtm for maths mode (_SEPM).
    "local function _show(v, sep)\n"
    -- A locally round()-ed value carries its own decimal count and overrides
    -- the document `precision`; a bare number obeys `precision`.
    .. "  local fixed\n"
    .. "  if type(v)=='table' and v.v~=nil and v.d~=nil then fixed=v.d; v=v.v end\n"
    .. "  if type(v)~='number' then if v==nil then return '' end return tostring(v) end\n"
    .. "  local s\n"
    .. "  local p = fixed or _PREC\n"
    .. "  if p and p >= 0 then\n"
    .. "    s = string.format('%.'..p..'f', v)\n"
    .. "    if s:find('%.') then s = s:gsub('0+$',''):gsub('%.$','') end\n"
    .. "  else s = tostring(v) end\n"
    .. "  return (s:gsub('%.', sep, 1))\n"
    .. "end\n",
    "local function _fmt(v) return _show(v, _SEPT) end\n",
    "local function _fmtm(v) return _show(v, _SEPM) end\n",
  }

  local body_lines = {}
  local lineno = 0
  local pending_obj = nil   -- {name=, buf=, startline=} pendant l'accumulation
  local pending_let = nil   -- {name=, buf=, depth=, startline=} table Lua ouverte
                            -- d'un  let X = <fn ... >  multi-lignes
  for srcline in (src .. "\n"):gmatch("(.-)\n") do
    lineno = lineno + 1
    local line = srcline

    -- Accumulation d'un objet <fn> ouvert sur plusieurs lignes.
    if pending_obj then
      pending_obj.buf[#pending_obj.buf + 1] = line
      if line:match(">%s*$") then
        local whole = table.concat(pending_obj.buf, "\n")
        local inner = whole:match("^%s*<%s*fn%s*(.-)>%s*$")
        if not inner then
          error("scholatex: line " .. pending_obj.startline
              .. ": malformed <fn ...> object", 0)
        end
        -- l'enregistrement est DIFFERE en passe 2 : les objets se lient
        -- dans l'ordre du document, une redefinition ne masque que la
        -- suite (shadowing sequentiel), jamais les usages precedents.
        body_lines[#body_lines + 1] = {fnreg = pending_obj.name,
          fninner = inner, lineno = pending_obj.startline}
        pending_obj = nil
      end
      goto continue
    end

    -- Accumulation d'un  let NOM = { ...  multi-lignes (table Lua ouverte,
    -- p. ex. un dictionnaire de donnees pour <stats>). Les lignes sont
    -- jointes en une seule expression quand les accolades s'equilibrent.
    if pending_let then
      pending_let.buf[#pending_let.buf + 1] = line
      pending_let.depth = pending_let.depth + U.raw_brace_delta(line)
      if pending_let.depth <= 0 then
        body_lines[#body_lines + 1] = {var = pending_let.name,
          expr = table.concat(pending_let.buf, " "),
          lineno = pending_let.startline}
        pending_let = nil
      end
      goto continue
    end
    do
      local vn, vexpr = line:match("^%s*let%s+([%a_][%w_]*)%s*=%s*({.*)$")
      if vn then
        local d = U.raw_brace_delta(vexpr)
        if d > 0 then
          warn_if_shadows(vn, lineno)
          pending_let = {name = vn, buf = {vexpr}, depth = d, startline = lineno}
          goto continue
        end
      end
    end

    -- Detection d'un  let NOM = <fn ...  (eventuellement multi-lignes).
    do
      local oname, orest = line:match("^%s*let%s+([%a_][%w_]*)%s*=%s*<%s*fn%f[%s>](.*)$")
      if oname then
        warn_if_shadows(oname, lineno)
        if orest:match(">%s*$") then
          -- objet complet sur une seule ligne
          local inner = orest:gsub(">%s*$", "")
          body_lines[#body_lines + 1] = {fnreg = oname, fninner = inner,
                                         lineno = lineno}
        else
          pending_obj = {name = oname, buf = { "<fn " .. orest },
                         startline = lineno}
        end
        goto continue
      end
    end

    -- Detection d'un  <fn f(x) = ...>  autonome : l'objet s'enregistre
    -- lui-meme sous le nom du membre de gauche, comme  vector s = u+v
    -- s'auto-nomme dans un bloc draw. La phrase du document se lit alors
    -- comme l'enonce : « Soit f(x) = ... ».
    do
      local orest = line:match("^%s*<%s*fn%f[%s>](.*)$")
      if orest then
        if orest:match(">%s*$") then
          local inner = orest:gsub(">%s*$", "")
          body_lines[#body_lines + 1] = {fnreg = false, fninner = inner,
                                         lineno = lineno}
        else
          pending_obj = {name = nil, buf = { "<fn " .. orest },
                         startline = lineno}
        end
        goto continue
      end
    end

    do
      local lead, rest = line:match("^(%s*)\\(%%.*)$")
      if lead then
        line = lead .. rest
      elseif line:match("^%s*%%") then
        goto continue
      end
    end
    local name, params, rhs = line:match("^%s*let%s+([%a_][%w_]*)%s*{(.-)}%s*=%s*(.+)$")
    if name then
      warn_if_shadows(name, lineno)
      local plist = {}
      for p in params:gmatch("[%a_][%w_]*") do plist[#plist + 1] = p end
      local barhs = rhs:match("^%s*<(.-)>%s*$")
      local bblock, bopts = nil, {}
      if barhs then
        for w in barhs:gmatch("%S+") do
          if not bblock and sl._blocks[w] then
            bblock = w
          else
            bopts[#bopts + 1] = w
          end
        end
      end
      if bblock then
        BLOCKALIAS[name] = {block = bblock,
                            opts = table.concat(bopts, " "),
                            params = plist}
      else
        MACRO[name] = {params = plist, body = rhs}
      end
    else
      local an, arhs = line:match("^%s*let%s+([%a_][%w_]*)%s*=%s*<(.-)>%s*$")
      if an then
        warn_if_shadows(an, lineno)
        local blockname, opts = nil, {}
        for w in arhs:gmatch("%S+") do
          if not blockname and sl._blocks[w] then
            blockname = w
          else
            opts[#opts + 1] = w
          end
        end
        if blockname then
          BLOCKALIAS[an] = {block = blockname,
                            opts = table.concat(opts, " "),
                            params = {}}
          local words = {}
          for w in arhs:gmatch("%S+") do words[#words + 1] = w end
          ALIAS[an] = STYLE.resolve_styles(words, ALIAS)
        else
          local words = {}
          for w in arhs:gmatch("%S+") do words[#words + 1] = w end
          ALIAS[an] = STYLE.resolve_styles(words, ALIAS)
        end
      else
        local vn, vexpr = line:match("^%s*let%s+([%a_][%w_]*)%s*=%s*(.+)$")
        if vn then
          body_lines[#body_lines + 1] = {var = vn, expr = vexpr, lineno = lineno}
        else
          body_lines[#body_lines + 1] = {text = line, lineno = lineno}
        end
      end
    end
    ::continue::
  end

  do
    local depth, first_open = 0, nil
    for _, e in ipairs(body_lines) do
      local l = e.text
      if l then
        local d = U.raw_brace_delta(l)
        if d > 0 and not first_open then first_open = e.lineno end
        depth = depth + d
        if depth < 0 then
          error("scholatex: line " .. (e.lineno or "?")
              .. ": unbalanced '}' (a closing brace with no matching opener; "
              .. "to print a literal brace, double it as {{ }})", 0)
        end
      end
    end
    if depth > 0 then
      error("scholatex: line " .. (first_open or "?")
          .. ": unbalanced '{' (an opening brace is never closed; to print a "
          .. "literal brace, double it as {{ }})", 0)
    end
  end

  process_lines(code, body_lines)

  code[#code + 1] = "return table.concat(_parts)\n"
  return table.concat(code)
end

local function collapse_par(s)
  local prev
  repeat
    prev = s
    s = s:gsub("(\\par[%s}]*)\\par", "%1")
  until s == prev
  return s
end

local SANDBOX_ALLOW = {
  math = true, string = true, table = true,
  type = true, tostring = true, tonumber = true, ipairs = true,
  pairs = true, next = true, select = true, error = true,
  assert = true, unpack = (table and table.unpack) and "table.unpack" or true,
}

local SANDBOX_STR_CAP = 100000
local function safe_string()
  local s = {}
  for k, v in pairs(string) do s[k] = v end
  s.dump = nil
  s.rep = function(str, n, sep)
    n = tonumber(n) or 0
    local unit = #tostring(str) + (sep and #tostring(sep) or 0)
    if n * unit > SANDBOX_STR_CAP then
      error("scholatex: string.rep result too large in untrusted mode (limit "
          .. SANDBOX_STR_CAP .. " characters)", 0)
    end
    return string.rep(str, n, sep)
  end
  s.format = function(fmt, ...)
    local out = string.format(fmt, ...)
    if #out > SANDBOX_STR_CAP then
      error("scholatex: string.format result too large in untrusted mode (limit "
          .. SANDBOX_STR_CAP .. " characters)", 0)
    end
    return out
  end
  return s
end

local function make_sandbox_env()
  local env = {}
  local safestr
  for name in pairs(SANDBOX_ALLOW) do
    if name == "unpack" then
      env.unpack = table and table.unpack
    elseif name == "string" then
      safestr = safe_string()
      env.string = safestr
    else
      env[name] = _G[name]
    end
  end
  env.vector = function(...)
    local c = {...}
    if #c < 2 then
      error("scholatex: vector(x, y) needs at least two components, got "
          .. #c)
    end
    return c
  end
  env.__drawbuild = sl.build_figure_block
  env.__statsbuild = sl.build_stats_runtime
  return env, safestr
end

local SANDBOX_MAX_STEPS = 2e7
local SANDBOX_MAX_KB    = 256 * 1024   -- memory growth cap: 256 MB
local function run_limited(chunk, safestr)
  local prevmt = debug.getmetatable("")
  debug.setmetatable("", { __index = safestr })
  local co = coroutine.create(chunk)
  local steps = 0
  local mem0 = collectgarbage("count")
  -- The instruction count does not bound allocation: a handful of doubling
  -- concatenations builds gigabytes in a few dozen instructions, before a
  -- pure count hook ever fires. The hook therefore also fires on every
  -- transpiled LINE ("l"), and the memory cap is checked each time, so the
  -- run aborts cleanly before the whole TeX process is starved.
  debug.sethook(co, function(event)
    if event == "count" then
      steps = steps + 1
      if steps > SANDBOX_MAX_STEPS / 1e5 then
        error("scholatex: untrusted document exceeded the instruction limit "
            .. "(possible runaway loop); aborted", 0)
      end
    end
    if collectgarbage("count") - mem0 > SANDBOX_MAX_KB then
      collectgarbage()
      if collectgarbage("count") - mem0 > SANDBOX_MAX_KB then
        error("scholatex: untrusted document exceeded the memory limit ("
            .. math.floor(SANDBOX_MAX_KB / 1024) .. " MB); aborted", 0)
      end
    end
  end, "l", 1e5)
  local ok, res = coroutine.resume(co)
  debug.sethook(co)
  debug.setmetatable("", prevmt)
  if not ok then error(res, 0) end
  return res
end

function sl.transpile(src)
  ALIAS, MACRO, BLOCKALIAS = {}, {}, {}
  sl._objects = {}
  sl._line = nil
  -- Windows editors save CRLF; a stray \r at end of line would defeat the
  -- $-anchored line patterns and leak into the emitted TeX.
  src = src:gsub("\r\n?", "\n")
  local lang = (sl.config and sl.config.lang) or "fr"
  MATH.decsep = (lang == "en") and "." or "{,}"
  NUMEVAL.set_precision((sl.config and sl.config.precision) or -1)
  local okb, lua_code = pcall(build_lua, src)
  if not okb then
    local msg = tostring(lua_code):gsub("^.-:%d+: ", "")
    msg = msg:gsub("^sl: ", ""):gsub("^scholatex: ", "")
    if sl._line then
      error("scholatex: line " .. sl._line .. ": " .. msg, 0)
    end
    error("scholatex: " .. msg, 0)
  end
  local untrusted = sl.config and sl.config.untrusted
  local chunk, err, safestr
  if untrusted then
    local env
    env, safestr = make_sandbox_env()
    chunk, err = load(lua_code, "=sl-body", "t", env)
  else
    _G.vector = _G.vector or function(...)
      local c = {...}
      if #c < 2 then
        error("scholatex: vector(x, y) needs at least two components, got "
            .. #c)
      end
      return c
    end
    _G.__drawbuild = sl.build_figure_block
    _G.__statsbuild = sl.build_stats_runtime
    chunk, err = load(lua_code, "=sl-body")
  end
  if not chunk then
    error("scholatex: transpilation error\n" .. err)
  end
  local ok, result
  if untrusted then
    ok, result = pcall(run_limited, chunk, safestr)
  else
    ok, result = pcall(chunk)
  end
  if not ok then
    local msg = tostring(result)
    if untrusted and (msg:find("instruction limit", 1, true)
                   or msg:find("result too large", 1, true)) then
      error("scholatex: " .. (msg:match("scholatex: (.*)$") or msg), 0)
    end
    if untrusted then
      local blocked = msg:match("nil value %(global '([%a_][%w_]*)'%)")
                   or msg:match("call a nil value %(global '([%a_][%w_]*)'%)")
      if blocked then
        error("scholatex: '" .. blocked .. "' is not available in untrusted mode "
            .. "(only pure maths and string/table helpers are permitted)", 0)
      end
    end
    error("scholatex: execution error\n" .. msg, 0)
  end
  return collapse_par(result)
end

local function print_par_lines(out)
  out = out:gsub("\n", " ")
  local lines = {}
  for seg in (out .. "\\par "):gmatch("(.-)\\par%f[%A]") do
    lines[#lines + 1] = seg
    lines[#lines + 1] = "\\par"
  end
  tex.print(lines)
end

sl._buf = {}
function sl_reset() sl._buf = {} end
function sl_addline(s) sl._buf[#sl._buf + 1] = s end
function sl_flush()
  print_par_lines(sl.transpile(table.concat(sl._buf, "\n")))
end

function sl.inject(body)
  print_par_lines(sl.transpile(body))
end

function sl.respace(macro)
  local v = token.get_macro(macro)
  if not v then return end
  v = v:gsub("(%l)(%u)", "%1 %2"):gsub("(%u)(%u%l)", "%1 %2")
  token.set_macro(macro, v)
end

sl._mathlite = MATH.mathlite

sl.use("scholatex-box")
sl.use("scholatex-table")
sl.use("scholatex-img")
sl.use("scholatex-section")
sl.use("scholatex-grid")
sl.use("scholatex-list")
sl.use("scholatex-matrix")
sl.use("scholatex-vartab")
sl.use("scholatex-signtab")
sl.use("scholatex-numberline")
sl.use("scholatex-tree")
sl.use("scholatex-stats")
sl.use("scholatex-plot")
sl.use("scholatex-figure")
sl.use("scholatex-toc")

return sl
