-- Suite de non-régression v2.5 — lancer depuis le dossier du package :
--   texlua tests-audit.lua
package.path = "./?.lua;" .. package.path
tex = { print = function() end }
local pass, fail = 0, 0
local function check(name, cond, detail)
  if cond then pass = pass + 1; print("PASS  " .. name)
  else fail = fail + 1; print("FAIL  " .. name .. "  " .. tostring(detail)) end
end

local sl = require("scholatex")

-- 1. Cercle monique : inchangé
sl.config = { lang = "fr" }
local ok, res = pcall(sl.transpile,
  "<draw axes:{-5,5,-5,5}>{\ncircle C x^2 + y^2 - 2x - 2y - 4 = 0\n}")
check("cercle monique (1,1) r=2.4495", ok and
  res:find("(1.0000,1.0000) circle [radius=2.4495]", 1, true), res)

-- 2. Cercle non monique : désormais NORMALISÉ (même cercle)
ok, res = pcall(sl.transpile,
  "<draw axes:{-5,5,-5,5}>{\ncircle C 2x^2 + 2y^2 - 4x - 4y - 8 = 0\n}")
check("cercle 2x^2+2y^2... normalisé", ok and
  res:find("(1.0000,1.0000) circle [radius=2.4495]", 1, true), res)

-- 3. Coefficients x^2 / y^2 différents : erreur claire (pas un cercle)
ok, res = pcall(sl.transpile,
  "<draw axes:{-5,5,-5,5}>{\ncircle C x^2 + 2y^2 - 2x = 0\n}")
check("ellipse refusée", not ok and tostring(res):find("not a circle"), res)

-- 4. Terme illisible : erreur, plus d'ignorance silencieuse
ok, res = pcall(sl.transpile,
  "<draw axes:{-5,5,-5,5}>{\ncircle C x^2 + y^2 + 3z - 2x = 0\n}")
check("terme parasite refusé", not ok and tostring(res):find("cannot read the term"), res)

-- 5. for in [1,2,3] : comparaison numérique désormais valide
ok, res = pcall(sl.transpile, "for k in [1,2,3] {\nif k > 2 {\nGrand : #k\n}\n}")
check("for in liste numérique", ok and res:find("Grand : 3", 1, true), res)

-- 6. Liste mixte / textuelle : toujours des chaînes
ok, res = pcall(sl.transpile, "for j in [lundi, mardi] {\nJour #j\n}")
check("for in liste textuelle", ok and res:find("Jour lundi", 1, true)
  and res:find("Jour mardi", 1, true), res)

-- 7. CRLF normalisé
ok, res = pcall(sl.transpile, "let a = 2\r\nValeur #a\r\n")
check("CRLF normalisé", ok and res:find("Valeur 2", 1, true)
  and not res:find("\r"), res)

-- 8. Bac à sable : échappements toujours bloqués
sl.config = { lang = "fr", untrusted = true }
for _, g in ipairs({"io.open('x')", "os.execute('ls')", "load('return 1')()"}) do
  ok, res = pcall(sl.transpile, "let z = " .. g .. "\n#z")
  check("sandbox bloque " .. g, not ok and tostring(res):find("untrusted"), res)
end

-- 9. Bac à sable : bombe mémoire par doublement -> erreur propre
local lines = { 'let s = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"' }
for i = 1, 30 do lines[#lines+1] = "let s = s .. s" end
lines[#lines+1] = "fin"
local t0 = os.clock()
ok, res = pcall(sl.transpile, table.concat(lines, "\n"))
check("sandbox limite mémoire", not ok and tostring(res):find("memory limit"),
  tostring(res):sub(1,80) .. string.format("  (%.1fs)", os.clock()-t0))

-- 10. Bac à sable : boucle infinie -> limite d'instructions intacte
ok, res = pcall(sl.transpile, "let x = 0\nwhile 1 == 1 {\nlet x = x + 1\n}\nfin")
check("sandbox limite instructions", not ok and tostring(res):find("instruction limit"), res)

-- 11. Objets <fn> réinitialisés entre deux transpilations
sl.config = { lang = "fr" }
pcall(sl.transpile, "let g = <fn expr:{(x+1)}>\nrien")
local ok11, r11 = pcall(sl.transpile, "<signtab g>")
check("_objets réinitialisés", not ok11 and tostring(r11):find("defined first"), r11)

-- 11b. Cercle nommé en forme équation : la tangente le retrouve
ok, res = pcall(sl.transpile,
  "<draw axes:{-5,5,-5,5}>{\npoint A (3, 1)\ncircle C x^2 + y^2 - 10 = 0\ntangent to:C at:A\n}")
check("tangente sur cercle nommé (équation)", ok and res:find("radius=3.1623", 1, true), res)

-- 12. Régression : signtab automatique inchangé
ok, res = pcall(sl.transpile, "<signtab expr:{(x+2)(x-3)} name:{f(x)}>")
check("signtab auto", ok and res:find("tkzTabInit", 1, true)
  and res:find("-2", 1, true) and res:find("tkzTabLine", 1, true), res)

-- ---------------------------------------------------------------------
-- Bibliothèque numérique partagée et precision
-- ---------------------------------------------------------------------
local function val(prec, src)
  sl.config = { lang = "en", precision = prec }
  local okv, r = pcall(sl.transpile, src)
  if not okv then return "ERR:" .. tostring(r):sub(1, 70) end
  return (r:match("%$(.-)%$") or r:gsub("%s*\\par%s*$", ""))
end

-- 13. precision globale : arrondi + suppression des zéros de queue
check("precision -1 (brut)",  val(-1, "$#{1/2}$"):find("0.5", 1, true))
check("precision 2 sur 1/3",  val(2,  "$#{1/3}$"):find("0.33", 1, true))
check("precision 4 sur 1/3",  val(4,  "$#{1/3}$"):find("0.3333", 1, true))
check("precision 2 : 7/2->3.5 (pas 3.50)",
  val(2, "$#{7/2}$") == "3.5")
check("precision 2 : 2+2->4 (pas 4.00)",
  val(2, "$#{2+2}$") == "4")

-- 14. round(x, d) local, indépendant de precision
check("round(pi,2)",  val(-1, "$#{round(pi,2)}$"):find("3.14", 1, true))
check("round(pi,4)",  val(-1, "$#{round(pi,4)}$"):find("3.1416", 1, true))
check("round(-2.5,0) s'éloigne de zéro",
  val(-1, "$#{round(-2.5,0)}$"):find("-3", 1, true))

-- 15. transcendantes dans #{...} : mêmes valeurs que la théorie
local function approx(prec, src, target)
  local s = val(prec, src)
  local n = tonumber((s:gsub(",", ".")))
  return n and math.abs(n - target) < 10^(-prec)
end
check("sin(pi/6) = 0.5",       approx(4, "$#{sin(pi/6)}$", 0.5))
check("cos(pi/3) = 0.5",       approx(4, "$#{cos(pi/3)}$", 0.5))
check("exp(1) = e",            approx(4, "$#{exp(1)}$", math.exp(1)))
check("ln(e) = 1",             approx(4, "$#{ln(e)}$", 1))
check("log(1000) base 10 = 3", approx(4, "$#{log(1000)}$", 3))
check("log2(8) = 3",           approx(4, "$#{log2(8)}$", 3))
check("logb(81,3) = 4",        approx(4, "$#{logb(81,3)}$", 4))
check("sind(30) = 0.5",        approx(4, "$#{sind(30)}$", 0.5))
check("cosh(0) = 1",           approx(4, "$#{cosh(0)}$", 1))
check("tanh(0) = 0",           approx(4, "$#{tanh(0)}$", 0))
check("coth(1) fini",          approx(4, "$#{coth(1)}$", math.cosh(1)/math.sinh(1)))
check("arctan(1) = pi/4",      approx(4, "$#{arctan(1)}$", math.pi/4))
check("arcsind(0.5) = 30",     approx(4, "$#{arcsind(0.5)}$", 30))
check("arcsinh(0) = 0",        approx(4, "$#{arcsinh(0)}$", 0))
check("cbrt(27) = 3",          approx(4, "$#{cbrt(27)}$", 3))
check("sqrt(2)",               approx(4, "$#{sqrt(2)}$", math.sqrt(2)))

-- 16. les transcendantes se tracent (traduction pgfplots)
sl.config = { lang = "en", precision = -1 }
local function plots(expr, window)
  local src = "<fn f(x) = " .. expr .. "\nx:{-inf|0|+inf}\nvar:{0/0}>\n"
           .. "<plot f x:{" .. window .. "} y:{-2,2}>"
  local okp, r = pcall(sl.transpile, src)
  return okp and r
end
check("plot cosh -> cosh",   (plots("cosh(x)", "-2,2") or ""):find("cosh(", 1, true))
check("plot cot -> deg",     (plots("cot(x)", "0.3,3") or ""):find("cot(deg(", 1, true))
check("plot arctan -> rad",  (plots("arctan(x)", "-4,4") or ""):find("rad(atan(", 1, true))
check("plot log2 intact",    (plots("log2(x)", "0.2,8") or ""):find("log2(", 1, true)
                          and not (plots("log2(x)", "0.2,8") or ""):find("log2*", 1, true))
check("plot coth composé",   (plots("coth(x)", "0.3,3") or ""):find("cosh(x)/sinh(x)", 1, true))

-- 17. le sandbox laisse passer les transcendantes (locals) mais bloque io
sl.config = { lang = "en", precision = 4, untrusted = true }
ok, res = pcall(sl.transpile, "$#{cosh(0)}$")
check("untrusted : cosh disponible", ok and res:find("1", 1, true))
ok, res = pcall(sl.transpile, "$#{io.open('x')}$")
check("untrusted : io bloqué", not ok and tostring(res):find("untrusted"))

-- 18. round(x,d) local prime sur la precision globale
sl.config = { lang = "en", precision = 4 }
ok, res = pcall(sl.transpile, "$#{round(pi,8)}$")
check("round local > precision globale", ok and res:find("3.14159265", 1, true), res)
ok, res = pcall(sl.transpile, "$#{round(1/3,2)+1}$")
check("round arithmétique (0.33+1)", ok and res:find("1.33", 1, true), res)

print(("\n%d réussis, %d échecs"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
