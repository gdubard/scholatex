local U = {}

function U.trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function U.brace_scan(s, i)
  local c = s:sub(i, i)
  if c == "{" then return "open", i + 1
  elseif c == "}" then return "close", i + 1
  elseif c == "$" then return "math", i + 1
  end
  return "char", i + 1
end

function U.read_group(s, open)
  local depth, i, n = 0, open, #s
  while i <= n do
    local kind, j = U.brace_scan(s, i)
    if kind == "open" then
      depth = depth + 1
    elseif kind == "close" then
      depth = depth - 1
      if depth == 0 then return s:sub(open + 1, i - 1), j end
    end
    i = j
  end
  error("scholatex: missing closing brace from position " .. open)
end

function U.raw_brace_delta(line)
  local delta, i, n = 0, 1, #line
  while i <= n do
    local kind, j = U.brace_scan(line, i)
    if kind == "open" then delta = delta + 1
    elseif kind == "close" then delta = delta - 1 end
    i = j
  end
  return delta
end

function U.split_commas(s)
  local items, depth, start, i, n = {}, 0, 1, 1, #s
  while i <= n do
    local c = s:sub(i, i)
    if c == "\\" then i = i + 2
    else
      if c == "{" or c == "[" then depth = depth + 1
      elseif c == "}" or c == "]" then depth = depth - 1
      elseif c == "," and depth == 0 then
        items[#items + 1] = U.trim(s:sub(start, i - 1))
        start = i + 1
      end
      i = i + 1
    end
  end
  items[#items + 1] = U.trim(s:sub(start))
  return items
end

function U.split_top_newlines(s)
  local paras, depth, inmath, start, i, n = {}, 0, false, 1, 1, #s
  while i <= n do
    if s:sub(i, i) == "\n" and depth == 0 and not inmath then
      paras[#paras + 1] = s:sub(start, i - 1)
      start = i + 1; i = i + 1
    else
      local kind, j = U.brace_scan(s, i)
      if kind == "math" then inmath = not inmath
      elseif not inmath and kind == "open" then depth = depth + 1
      elseif not inmath and kind == "close" then depth = depth - 1 end
      i = j
    end
  end
  paras[#paras + 1] = s:sub(start)
  return paras
end

local function getline(e)
  if type(e) == "string" then return e end
  if type(e) == "table" then return e.text end
  return nil
end

function U.collect_block(lines, start)
  local sub, depth, i, n = {}, 1, start, #lines
  while i <= n and depth > 0 do
    local e = lines[i]
    local l = getline(e)
    if l ~= nil then
      if l:match("^%s*<%a[%w_]*.->%s*{%s*$") then
        depth = depth + 1
        sub[#sub + 1] = e
      elseif l:match("^%s*}%s*$") and depth == 1 then
        i = i + 1; break
      else
        depth = depth + U.raw_brace_delta(l)
        sub[#sub + 1] = e
      end
    else
      sub[#sub + 1] = e
    end
    i = i + 1
  end
  return sub, i
end

local PLACE_V = {t = "top", m = "center", b = "bottom"}
local PLACE_H = {l = "left", c = "center", r = "right"}

function U.place_code(w)
  if type(w) ~= "string" or #w ~= 2 then return nil end
  local v, h = PLACE_V[w:sub(1, 1)], PLACE_H[w:sub(2, 2)]
  if v and h then return v, h end
  return nil
end

function U.split_opts(s)
  local toks, i, n = {}, 1, #s
  while i <= n do
    while i <= n and s:sub(i, i):match("%s") do i = i + 1 end
    if i > n then break end
    local start = i
    while i <= n and not s:sub(i, i):match("%s") do
      if s:sub(i, i) == "{" then
        local _, after = U.read_group(s, i)
        i = after
      else
        i = i + 1
      end
    end
    toks[#toks + 1] = s:sub(start, i - 1)
  end
  return toks
end

function U.width_coeff(pct)
  local f = string.format("%.4f", tonumber(pct) / 100)
  return (f:gsub("0+$", ""):gsub("%.$", ""))
end

function U.parse_attrs(s, opts)
  opts = opts or {}
  local tag = opts.tag or "tag"
  local attrs, i, n = {}, 1, #s
  while i <= n do
    while i <= n and s:sub(i, i):match("%s") do i = i + 1 end
    if i > n then break end
    local key = s:match("^([%a_]+):", i)
    if not key then
      local word = s:match("^(%S+)", i) or s:sub(i)
      if opts.on_bare and opts.on_bare(word, attrs) then
        i = i + #word
      else
        error("scholatex: <" .. tag .. "> "
            .. (opts.hint or "expects key:value options")
            .. ", got the bare word '" .. word .. "'")
      end
    else
      local after = i + #key + 1
      local c = s:sub(after, after)
      if c == "{" then
        local value, aft = U.read_group(s, after)
        attrs[key] = value
        i = aft
      elseif c == "[" and opts.brackets then
        local depth, j = 0, after
        while j <= n do
          local d = s:sub(j, j)
          if d == "[" then depth = depth + 1
          elseif d == "]" then depth = depth - 1; if depth == 0 then break end end
          j = j + 1
        end
        attrs[key] = s:sub(after + 1, j - 1)
        i = j + 1
      elseif opts.require_group then
        error("scholatex: <" .. tag .. "> option '" .. key .. "' must be "
            .. "followed by {...} (e.g. " .. key .. ":{...})")
      else
        local value = s:match("^(%S+)", after) or ""
        attrs[key] = value
        i = after + #value
      end
    end
  end
  return attrs
end

return U
