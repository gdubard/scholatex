local U = require("scholatex-util")

local DEFAULT = {
  line    = "Gray",
  boxrule = "0.4",
  sep     = "3",
  break_  = "no",
}

local function color_name(sl, word)
  local r = sl.style.resolve(word)
  if r and r.kind == "color" then
    return r.open:match("\\textcolor{(.-)}")
  end
  error("scholatex: unknown frame colour: '" .. word .. "'")
end

local function parse_opts(s)
  return U.parse_attrs(s, {
    tag  = "box",
    hint = "expects key:value options (line:, title:, rule:, sep:, break:) "
         .. "or a placement code (tl, mc, br...); layout attributes like tab "
         .. "or line belong on the box body, not on the box itself",
    on_bare = function(word, opts)
      if U.place_code(word) then opts.place = word; return true end
      return false
    end,
  })
end

local function build_tcb_options(sl, opts)
  local o = {}
  local line = opts.line or DEFAULT.line
  o[#o+1] = "colframe=" .. color_name(sl, line)
  if opts.fill then o[#o+1] = "colback=" .. color_name(sl, opts.fill)
  else o[#o+1] = "colback=White" end
  if opts.text then o[#o+1] = "coltext=" .. color_name(sl, opts.text) end

  o[#o+1] = "boxrule=" .. (opts.boxrule or DEFAULT.boxrule) .. "mm"

  local pad = opts.boxsep
            or opts.sep
            or (sl.config and sl.config.padding)
            or DEFAULT.sep
  o[#o+1] = "boxsep=" .. pad .. "mm"
  o[#o+1] = "left=0mm, right=0mm, top=0mm, bottom=0mm"

  if opts.radius then
    o[#o+1] = "rounded corners"
    o[#o+1] = "arc=" .. opts.radius .. "mm"
  else
    o[#o+1] = "sharp corners"
  end

  if opts.width then
    local pct = opts.width:match("^(%d+%.?%d*)%%$")
    if pct then
      o[#o+1] = "width=" .. U.width_coeff(pct) .. "\\linewidth"
    else
      o[#o+1] = "width=" .. opts.width .. "mm"
    end
  end

  if opts.height then
    o[#o+1] = "height=" .. opts.height .. "mm"
  end

  if opts.place then
    local v, h = U.place_code(opts.place)
    if v then o[#o+1] = "valign=" .. v .. ", halign=" .. h end
  end

  if (opts["break"] or DEFAULT.break_) == "yes" then
    o[#o+1] = "breakable"
  else
    o[#o+1] = "unbreakable"
  end

  if opts.title then
    o[#o+1] = "colbacktitle=" ..
      color_name(sl, opts.titlefill or (opts.line or DEFAULT.line))
    if opts.titletext then
      o[#o+1] = "coltitle=" .. color_name(sl, opts.titletext)
    end
  end

  return table.concat(o, ", ")
end

return function(sl)
  sl.box_parse_opts    = parse_opts
  sl.box_build_options = function(opts) return build_tcb_options(sl, opts) end
  sl.box_color_name    = function(word) return color_name(sl, word) end

  sl.register_block("box", function(api, words_str, inner)
    local opts = parse_opts(words_str or "")
    local tcb  = build_tcb_options(sl, opts)

    if opts.title then
      api.raw('emit("\\\\begin{tcolorbox}[enhanced, ' ..
        tcb:gsub("\\", "\\\\") .. ', title={")\n')
      api.forward_text(opts.title)
      api.raw('emit("}]")\n')
    else
      api.raw('emit("\\\\begin{tcolorbox}[enhanced, ' ..
        tcb:gsub("\\", "\\\\") .. ']")\n')
    end

    local split = nil
    for k, l in ipairs(inner) do
      if type(l) == "string" and l:match("^%s*%-%-%-%s*$") then split = k; break end
    end
    if split then
      local upper, lower = {}, {}
      for k = 1, split - 1 do upper[#upper+1] = inner[k] end
      for k = split + 1, #inner do lower[#lower+1] = inner[k] end
      api.process_block(upper)
      api.raw('emit(" \\\\tcblower ")\n')
      api.process_block(lower)
    else
      api.process_block(inner)
    end

    api.raw('emit("\\\\end{tcolorbox}")\n')
  end)

  sl.register_block("row", function(api, words_str, inner)
    local opts = parse_opts(words_str or "")
    local gap  = opts.gap or "4"

    local children = {}
    local i, n = 1, #inner
    while i <= n do
      local l = inner[i]
      local bname, bwords
      if type(l) == "string" then
        bname, bwords = l:match("^%s*<(%a[%w_]*)%s*(.-)>%s*{%s*$")
      end
      if bname then
        local sub
        sub, i = U.collect_block(inner, i + 1)
        children[#children+1] = { name = bname, words = bwords or "", inner = sub }
      else
        if type(l) == "string" and l:match("%S") then
          error("scholatex: <row> only accepts child blocks (<box ...>); "
              .. "stray content: '" .. U.trim(l) .. "'")
        end
        i = i + 1
      end
    end

    local ncols = #children
    if ncols < 1 then ncols = 1 end

    api.raw('emit("\\\\begin{tcbraster}[raster columns=' .. ncols ..
            ', raster equal height, raster column skip=' .. gap .. 'mm, ' ..
            'raster row skip=' .. gap .. 'mm]")\n')
    for _, ch in ipairs(children) do
      if sl._blocks[ch.name] then
        sl._blocks[ch.name](api, ch.words, ch.inner)
      end
    end
    api.raw('emit("\\\\end{tcbraster}")\n')
  end)
end
