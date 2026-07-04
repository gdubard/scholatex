local U = require("scholatex-util")

local ITEMIZE = {
  none   = "label={}",
  disc   = "label=$\\bullet$",
  circle = "label=$\\circ$",
  square = "label=$\\blacksquare$",
  check  = "label=$\\square$",
}

local ENUMERATE = {
  decimal = "label=\\arabic*.",
  alpha   = "label=\\alph*)",
  ALPHA   = "label=\\Alph*.",
  roman   = "label=\\roman*.",
  ROMAN   = "label=\\Roman*.",
}

local function style_env(style)
  if ITEMIZE[style] then return "itemize", ITEMIZE[style] end
  if ENUMERATE[style] then return "enumerate", ENUMERATE[style] end
  error("scholatex: <list:" .. style .. "> unknown style; use one of none, disc, "
      .. "circle, square, decimal, alpha, ALPHA, roman, ROMAN, check")
end

local function split_style(words_str)
  local s = U.trim(words_str or "")
  local style = s:match("^:(%S+)")
  if not style then
    error("scholatex: <list> needs a style, written <list:STYLE> (e.g. <list:disc>, "
        .. "<list:ROMAN>); got <list" .. (s ~= "" and " " .. s or "") .. ">")
  end
  local rest = U.trim(s:sub(#style + 2))
  return style, rest
end

local function is_list_open(line)
  return type(line) == "string"
     and line:match("^%s*<list:%S*.->%s*{%s*$") ~= nil
end

return function(sl)
  sl.register_block("list", function(api, words_str, inner)
    local style, textattrs = split_style(words_str)
    local env, label = style_env(style)

    local open, close = {}, {}
    if textattrs ~= "" then
      local words = {}
      for _, w in ipairs(U.split_opts(textattrs)) do words[#words+1] = w end
      for _, e in ipairs(sl.style.classify_words(words, sl.alias or {})) do
        open[#open+1] = e[1]; close[#close+1] = e[2]
      end
    end

    for _, o in ipairs(open) do
      api.raw("emit(" .. string.format("%q", o) .. ")\n")
    end
    api.raw('emit("\\\\begin{' .. env .. '}[' .. label:gsub("\\", "\\\\")
          .. ', leftmargin=*, nosep]")\n')

    local i, n = 1, #inner
    while i <= n do
      local l = inner[i]
      if is_list_open(l) then
        local bwords = l:match("^%s*<list:(%S*.-)>%s*{%s*$")
        local sub
        sub, i = U.collect_block(inner, i + 1)
        sl._blocks["list"](api, ":" .. bwords, sub)
      elseif type(l) == "string" and l:match("%S") then
        api.raw('emit("\\\\item ")\n')
        api.forward_text(U.trim(l))
        i = i + 1
      else
        i = i + 1
      end
    end

    api.raw('emit("\\\\end{' .. env .. '}")\n')
    for j = #close, 1, -1 do
      api.raw("emit(" .. string.format("%q", close[j]) .. ")\n")
    end
  end)
end
