# scholatex — Guide de l'utilisateur (français)

**Des fiches d'exercices prêtes à imprimer, sans écrire de LaTeX.** — Un petit langage de balises, cohérent, pour les documents qu'un enseignant fabrique réellement.

[![CTAN](https://img.shields.io/badge/CTAN-scholatex-d35400?style=flat-square)](https://ctan.org/pkg/scholatex)
[![Version](https://img.shields.io/badge/version-2.5-2980b9?style=flat-square)](https://ctan.org/pkg/scholatex)
[![Engine](https://img.shields.io/badge/engine-LuaLaTeX-1F3A5F?style=flat-square)](https://www.luatex.org/)
[![TeX Live](https://img.shields.io/badge/TeX_Live-included-27ae60?style=flat-square)](https://tug.org/texlive/)
[![License](https://img.shields.io/badge/license-GPL_v3+-8e44ad?style=flat-square)](https://www.gnu.org/licenses/gpl-3.0)

> Ce guide est la traduction française du `README.md`. Les mots-clés du langage restent en anglais : c'est la syntaxe de scholatex, identique pour tous ses utilisateurs. Seule la prose est traduite.

## Pourquoi scholatex ?

Écrivez un unique fichier `.tex` dans une syntaxe minuscule et lisible, et obtenez une fiche propre, prête à imprimer — exercices encadrés, tableau de résultats, formules simples, une image — sans `\begin{tabular}{|c|c|}`, sans compter les esperluettes, sans se rappeler quel package dessine un cadre coloré.

```latex
% !TeX program = lualatex
\documentclass[margins=20, size=12]{scholatex}
\begin{document}

<Navy b 18pt c>My first scholatex document
...
\end{document}
```

## Démarrage rapide

```bash
tlmgr install scholatex      # ajoutez sudo sous macOS/Linux ; voir Installation
```

```latex
\documentclass[margins=20, size=12, lang=en]{scholatex}
\begin{document}
<Navy b section>First topic
A paragraph with <b>{bold} and <Red>{colour}.
\end{document}
```

## Fonctionnalités clés

- **🏷️ Une seule syntaxe de balise** — `<attributs>{contenu}` couvre texte, tableaux, images, maths, cadres, listes et mises en page pleine page
- **🎨 151 couleurs** — la palette CSS / svgnames complète en CamelCase
- **📐 Un mini-langage mathématique** — fractions, racines, sommes, produits, intégrales, dérivées, trigonométrie, matrices et systèmes, le tout dans `$...$`
- **📦 Cadres et grilles** — panneaux `<box>` colorés et mises en page à zones nommées façon CSS Grid
- **📊 Des tableaux sans douleur** — placement de cellule en deux lettres, fusions, en-têtes, bordures, aucun `&` à compter
- **♻️ Alias et macros** — factorisez un style une fois, nommez-le partout ; une seule retouche restyle tout le document
- **🔁 Structures de contrôle** — boucles, conditionnelles et interpolation `#{...}` dans le corps du document
- **🔒 Option bac à sable** — `untrusted=true` exécute le Lua du document dans un environnement restreint

---

## La règle unique

Tout est une **balise** : `<attributs>` suivi soit de `{contenu}` (en ligne), soit d'une ligne se terminant par `{` (un bloc). Les mots d'attribut suivent une convention de casse unique :

| Forme | Signification | Exemples |
|------|---------|----------|
| `minuscules` | un mot-clé court (style, alignement, saut) | `b`, `i`, `c`, `2tab` |
| `CamelCase` | une couleur CSS étendue (151 au total) | `SteelBlue`, `Crimson` |
| `MAJUSCULES` | un nom de police | `DEJAVU SANS` |

L'ordre des mots à l'intérieur d'une balise n'a jamais d'importance — l'émission est toujours normalisée (saut de page, puis sauts verticaux, puis alignement, puis tabulations, puis styles).

---

## Installation

`scholatex` est sur CTAN et livré avec TeX Live : sur une distribution TeX Live ou MacTeX à jour, il est déjà là — compilez avec `lualatex`, rien de plus. Si votre installation est antérieure au package, installez-le une fois pour toutes avec le gestionnaire TeX Live ; les deux mêmes commandes valent pour **macOS, Linux et Windows** :

```bash
tlmgr update --self
tlmgr install scholatex
```

Sous macOS (MacTeX) et la plupart des Linux, `tlmgr` demande les droits administrateur : préfixez les deux commandes par `sudo`. Sous Windows, ouvrez la *TeX Live Command-Line* (ou un terminal en administrateur) et lancez-les sans `sudo`. Les utilisateurs de MiKTeX passent par la MiKTeX Console (*Packages* → chercher `scholatex` → *Install*), ou par `mpm --install=scholatex`.

`tlmgr update --self` vient en premier : le gestionnaire refuse d'installer des packages quand sa propre version est plus ancienne que celle du dépôt. Après installation, vérifiez que la classe est trouvée :

```bash
kpsewhich scholatex.cls
```

Un chemin sous votre arborescence TeX doit s'afficher. Dès lors, `\documentclass{scholatex}` fonctionne depuis n'importe quel dossier.

Si `tlmgr install scholatex` annonce que le package n'est *pas présent dans le dépôt*, votre miroir n'a pas encore synchronisé une version récente ; attendez un jour, ou basculez sur le miroir principal de CTAN et réessayez :

```bash
sudo tlmgr option repository https://mirror.ctan.org/systems/texlive/tlnet
sudo tlmgr update --self
sudo tlmgr install scholatex
```

### Installation manuelle (tout OS, sans attendre)

Pour utiliser le package immédiatement, sans `tlmgr`, déposez les fichiers dans votre arborescence TeX personnelle, en calquant l'arborescence CTAN, puis rafraîchissez la base des noms de fichiers. L'arborescence personnelle est `~/Library/texmf` sous macOS, `~/texmf` sous Linux et `%USERPROFILE%\texmf` sous Windows :

```bash
mkdir -p ~/texmf/tex/luatex/latex/scholatex
cp scholatex.cls scholatex.lua scholatex-*.lua ~/texmf/tex/luatex/latex/scholatex/
mktexlsr ~/texmf
```

Le moteur LuaLaTeX est requis (`lualatex`) ; le package ne compile **pas** avec `pdflatex` ni `xelatex`.

---
## Options de classe

À poser dans `\documentclass[...]{scholatex}` :

| Option | Défaut | Signification |
|--------|---------|---------|
| `margins` | `20` | `N` (les quatre côtés) ou `{haut,droite,bas,gauche}` en mm |
| `font` | `Latin Modern Roman` | police du texte courant |
| `mathfont` | `Latin Modern Math` | police mathématique |
| `size` | `11` | corps de base en pt |
| `imgdir` | `img` | dossier(s) où chercher les noms d'image nus ; liste séparée par des virgules, p. ex. `{IMG, IMAGES/PNG}` |
| `tabwidth` | `8` | largeur d'une tabulation, en mm (un grand carreau Seyès) |
| `lineheight` | `8` | hauteur d'un saut de ligne explicite (`<line>`, `<Nlines>`), en mm |
| `linespread` | `1.0` | interligne global (1.5 = un et demi) ; les maths hautes ne se touchent jamais, même à 1.0 |
| `scriptscale` | `100` | échelle (%) des exposants/indices `up`/`down` |
| `padding` | `2` | marge intérieure (mm) entre le cadre d'un box/grid et son contenu ; localement `sep:N` |
| `lang` | `fr` | séparateur décimal : `fr` (virgule) ou `en` (point) ; vaut pour les décimaux tapés comme interpolés |
| `precision` | `-1` | décimales auxquelles une valeur calculée `#{...}` est arrondie à l'affichage (`-1` = pas d'arrondi) ; `round(x, d)` surcharge localement |
| `untrusted` | `false` | exécute le Lua du document dans un bac à sable restreint — voir [Sécurité](#sécurité) |

Les titres ne portent ni espacement vertical supplémentaire ni couleur d'office : pour styler un titre, repliez un mot-clé de titre dans un alias, p. ex. `let h = <line Navy b section>` puis `<h>My title`.

---

## Attributs de texte

**Styles en ligne** — `b` gras, `i` italique, `u` souligné, `emph`, `sf` sans empattements, `sc` petites capitales. Ils se combinent dans une même balise : `<b i Red>{gras italique rouge}`.

**Couleurs** — une couleur est toujours l'une des 151 couleurs CSS, écrite en CamelCase : `Navy`, `Red`, `Tomato`, `SteelBlue`, `ForestGreen`, … Une seule règle, pas de raccourcis minuscules — les couleurs courantes prennent simplement la majuscule (`Red`, `Blue`, `Green`, `Gray`). Voir la [référence des couleurs](#référence-des-couleurs).

**Polices et tailles** — un nom de police en CAPITALES (`<DEJAVU SANS>{…}`) ; les tailles en `Npt` ou `Npx` (`<14pt>{…}`).

**Alignement** — `l` gauche, `c` centré, `r` droite, `j` justifié.

**Tabulations et sauts** (le nombre est toujours un préfixe) — `Ntab` indente la première ligne de N tabulations ; les sauts verticaux suivent l'accord singulier/pluriel : `line` ou `1line` saute une ligne, `2lines`, `3lines`, … en sautent plusieurs. Un `tab` nu vaut `1tab`.

**Exposants et indices** — `upN` monte le texte de N mm, `downN` le descend : `x<up4>{2}`, `H<down2>{2}O`.

**Saut de page** — `nextpage`.

**Titres de section** — `section`, `subsection`, `subsubsection` donnent les trois niveaux, numérotés automatiquement :

```
<section>First topic
<subsection>A detail
<subsubsection>A finer point
```

rend `1 First topic`, `1.1 A detail`, `1.1.1 A finer point`. La **table des matières** s'imprime avec `<tableofcontents>` ; donnez-lui un titre entre accolades : `<tableofcontents>{Table des matières}`.

**Style de numérotation** — par défaut, les numéros sont hiérarchiques (`1`, puis `1.1`, puis `1.1.1`). Un mot-clé de compteur sur un titre change le style de *ce* niveau, seul — sans préfixe hérité : `num` (1, 2, 3), `roman` (i, ii, iii), `ROMAN` (I, II, III), `alpha` (a, b, c), `ALPHA` (A, B, C). Par exemple `let study = <Navy b section ROMAN>` et `let step = <Navy b subsection num>` donnent des sections `I`, `II` et, sous chacune, des étapes `1`, `2`, `3` (pas `I.1`). Chaque niveau est indépendant ; sans mot-clé, la numérotation hiérarchique par défaut demeure.

---

## Alias et macros — l'outil de factorisation

Définissez un style **une fois**, en tête de document, puis nommez-le partout au lieu de répéter ses attributs. Une retouche à la définition restyle tout le document.

```
let title = <Navy b 18pt c>          % alias de style
let h1    = <Navy b section>         % un style de titre, réutilisable
let p     = <tab>                    % le paragraphe standard indenté
<title>My heading
<h1>First topic
<p>{ A paragraph, indented and justified, named not described. }

let n = 7                            % valeur, utilisable dans #{...}
Seven squared is #{n*n}.

let greet{name} = Hello #name!       % macro de texte à paramètres
```

Changez une fois `let h1 = <Navy b section>` en `<ForestGreen b section>` et **tous** les titres de premier niveau suivent — l'unique point de contrôle qui garde une longue fiche cohérente.

---

## Tableaux

Les colonnes se déclarent entre crochets, **un code de placement de deux lettres par colonne**. La première lettre est verticale (`t`/`m`/`b`), la seconde horizontale (`l`/`c`/`r`) : `mc` est milieu-centre, `br` bas-droite. C'est la seule syntaxe de placement de scholatex — dans les tableaux comme dans les cadres et les grilles.

```
<table [mc, ml, mc, mc] borders header fill:AliceBlue line:Navy headerfill:Navy headertext:White>{
<colspan:4 mc>{Term report}
Day | Subject | Mark | Coef.
<rowspan:2 mc>{Monday} | Maths | 15 | 4
. | French | 12 | 3
}
```

Une ligne par rangée, `|` entre les cellules. `<colspan:N>` et `<rowspan:N>` fusionnent ; `.` marque une cellule couverte par une fusion au-dessus. `N:` devant un code de placement fixe la largeur d'une colonne en mm.

---

## Images

```
<img 30>{photo.png}        % 30 mm de large
<img 40x25>{photo.png}     % 40 mm × 25 mm
<img>{photo.png}           % pleine largeur disponible, jamais agrandie
```

Un nom nu est cherché dans chaque dossier d'`imgdir` tour à tour, puis à la racine du projet. Un chemin explicite marche toujours (`<img 20>{IMG/PNG/chat.png}`).

---
## Mathématiques

Les maths s'écrivent dans `$…$`. Un petit mini-langage les garde légères :

| Vous écrivez | Vous obtenez |
|-----------|---------|
| `*` | × |
| `+-` | ± |
| `<=` `>=` `!=` | ≤ ≥ ≠ |
| `a/b` | fraction (enchaîné, `a/b/c` se lit `(a/b)/c`) |
| `x^2` `x_i` | puissance / indice (liant plus fort que `/`, donc `x^2/y` est `\frac{x^2}{y}`) |
| `sqrt(2)` | √2 |
| `sum(i=1, n) i` | ∑ avec bornes, en style display |
| `prod(k=1, n) k` | ∏ avec bornes, en style display |
| `int(x) f(x)` | ∫ f(x) dx (primitive ; la différentielle est ajoutée) |
| `int(x=a, b) f(x)` | ∫ de a à b, f(x) dx |
| `contourint(C) f(z)` | ∮ intégrale de contour |
| `pvint(x=a, b) f(x)` | valeur principale de Cauchy p.v. ∫ |
| `meanint(x=a, b) f(x)` | ⨍ intégrale moyenne (normalisée) |
| `dy/dx`, `df/dx` | dérivée, d droit (ISO) |
| `sin(x)` `cos(x)` `ln(x)` … | noms de fonctions en romain |
| `abs(x)` | \|x\| |
| `norm(v)` | ‖v‖ |
| `vec(AB)` | →AB (vecteur, flèche au-dessus) |
| `floor(x)` `ceil(x)` | ⌊x⌋ ⌈x⌉ (partie entière) |
| `bar(z)`, `conj(z)` | z̄ (conjugué, moyenne, adhérence) |
| `not(A cup B)` | (A∪B)‾ (négation logique, même surlignement) |
| `lim(x->0) f(x)` | limite, `->` devient la flèche, la cible sous le mot |
| `partial`, `nabla` | ∂, ∇ (écrire `(partial f)/(partial x)` pour ∂f/∂x) |
| `pi`, `alpha`, … | lettres grecques |
| `inf` | ∞ |

Les aides s'emboîtent, si bien que les classiques du secondaire viennent tout seuls : `norm(vec(AB))` est la norme d'un vecteur, `vec(AB) + vec(BC) = vec(AC)` la relation de Chasles.

### Ensembles, logique et relations

Du collège aux classes supérieures, une fiche a besoin des notations standards. Elles s'écrivent en mots simples et raccourcis ASCII : un énoncé se lit comme il se tape.

**Ensembles de nombres** — une capitale doublée donne l'ensemble en gras de tableau (la convention ASCIIMath). Le doublement écarte tout conflit avec une variable d'une lettre :

| Vous écrivez | Vous obtenez |
|---|---|
| `NN` `ZZ` `DD` `QQ` `RR` `CC` | ℕ ℤ 𝔻 ℚ ℝ ℂ |
| `PP` `KK` `HH` `FF` `EE` `UU` | ℙ 𝕂 ℍ 𝔽 𝔼 𝕌 (avancés) |

**Quantificateurs et logique** — `forall` ∀, `exists` ∃ ; connecteurs `and` ∧, `or` ∨, `lnot` ¬, `neg` ¬. Implication et équivalence existent en mots comme en flèches : `=>` ou `implies` ⇒, `<=>` ou `iff` ⇔ (à l'intérieur d'une formule ; en prose courante, doublez les chevrons : `<<=>>`). Les formes longues des flèches l'emportent sur la comparaison qu'elles contiennent : `abs(x) <= 1 <=> -1 <= x <= 1` s'analyse correctement.

**Négation** — une règle : `!` devant une relation ou un quantificateur le nie, avec le bon glyphe barré. Ainsi `!in` est ∉, `!exists` ∄, `!subset` ⊄, `!subseteq` ⊈, `!equiv` ≢. (`!=` reste « différent de », ≠.)

**Relations ensemblistes** — `in` ∈, `subset` ⊂, `supset` ⊃, `subseteq` ⊆, `supseteq` ⊇, `cup` ∪, `cap` ∩, `setminus` ∖, `emptyset` ∅ (chacune se nie avec `!`).

**Flèches** — `->` ou `to` →, `mapsto` ↦.

```
$forall epsilon > 0, exists eta > 0$
$x in RR setminus QQ$
$x !in QQ$
$(P and Q) => P$
```

### Crochets et accents

La partie entière et quelques enveloppes à un argument suivent la même forme `nom(...)` qu'`abs` et `vec` : `floor(x)` ⌊x⌋, `ceil(x)` ⌈x⌉, `set(x : x > 0)` un ensemble entre accolades, `abr(u, v)` ⟨u, v⟩ un produit scalaire.

Le surlignement se nomme par intention — la même règle sous deux mots : `bar(...)` pour la barre générique (conjugué complexe, moyenne, adhérence) et `not(...)` pour la négation logique ; ainsi `bar(z)` est z̄ et `not(A cup B)` est (A∪B)‾. Les accents usuels complètent : `hat(f)`, `tilde(x)`.

### Limites avec flèche

`lim(x->0) f(x)` compose déjà une limite avec sa cible sous le mot. Pour la phrase « uₙ tend vers ℓ » écrite au-dessus d'une flèche, utilisez `arrow(...)` : `u_n arrow(n to +inf) l` compose une longue flèche droite avec la condition dessous. `to` et `->` y sont interchangeables.

```
$lim(n -> +inf) u_n = l$
$u_n arrow(n to +inf) l$
```

### Opérateurs à indice : sum, prod, lim

`sum`, `prod` et `lim` portent leur indice dans `(...)` et composent toute leur expression en style display : une fraction dans le corps garde sa pleine taille, et la cible d'une limite s'assied **sous** le mot, comme au tableau. Le corps court jusqu'à la fin de la formule ou jusqu'au premier `=` :

```
$sum(i=1, n) i = n(n+1)/2$
$prod(k=1, n) k$
$lim(x->0) sin(x)/x = 1$
$lim(x->+inf) 1/x$
```

### Fonctions et trigonométrie

Les noms de fonctions passent en romain automatiquement — aucune contre-oblique. Le jeu couvre `sin cos tan cot sec csc`, les réciproques `arcsin arccos arctan`, les hyperboliques `sinh cosh tanh coth`, et `ln log exp det dim gcd deg ker arg max min sup`. Un nom collé à `(...)` prend son argument comme un seul atome : fractions et puissances se comportent bien :

```
$sin(x)^2 + cos(x)^2 = 1$
$cos(a+b) = cos(a)cos(b) - sin(a)sin(b)$
$tan(x) = sin(x)/cos(x)$
```

### Intégrales

La famille des intégrales écrit variable et bornes dans la tête `(...)` et capture l'intégrande comme corps ; la différentielle `\,dx` est ajoutée automatiquement. Sans bornes, une primitive ; avec un couple séparé par une virgule, une intégrale définie :

```
$int(x) f(x)$              ∫ f(x) dx
$int(x=a, b) f(x)$         ∫ de a à b de f(x) dx
```

**Intégrales multiples** — séparez plusieurs domaines par `;`. Leur nombre choisit ∫, ∬ ou ∭ ; les différentielles sortent en ordre inverse (Fubini) :

```
$int(x=a, b ; y=c, d) f(x,y)$            ∬ … dy dx
$int(x=a, b ; y=c, d ; z=e, g) f$        ∭ … dz dy dx
```

Un domaine nommé seul est une intégrale de région : `int(D) f` donne ∬_D f dω. **Intégrales nommées** : `contourint(C) f(z)` est une intégrale de contour ∮, `pvint(x=a, b) f(x)` une valeur principale de Cauchy, `meanint(x=a, b) f(x)` l'intégrale moyenne ⨍.

### Dérivées

Une dérivée de Leibniz s'écrit comme la fraction qu'elle est, et la différentielle `d` se compose droite (ISO 80000-2), assortie au `d` des intégrales — **seulement** quand les deux côtés de la fraction la portent : une variable nommée `d` n'est jamais dérangée (`d/2` reste la fraction d sur 2) :

```
$dy/dx$                 dy/dx, d droit
$(d^2 y)/(dx^2)$        dérivée seconde
$dy/dx + y = 0$         une équation différentielle
```

Les dérivées partielles utilisent `partial` (∂) ; parenthésez chaque côté pour que la fraction se groupe bien :

```
$(partial f)/(partial x)$
$(partial u)/(partial t) = (partial^2 u)/(partial x^2)$
```

`nabla` (∇) est disponible pour gradients et divergences.

### Blocs mathématiques

Matrices et systèmes sont des blocs : **une ligne est une rangée**, et dans une matrice `;` sépare les coefficients. Chaque cellule passe par le mini-langage.

```
<matrix>{
1 ; 2 ; 3
4 ; 5 ; 6
}
```

`<matrix>` dessine des parenthèses, `<det>` les barres d'un déterminant, `<bmatrix>` des crochets. Un `|` seul dans une rangée dessine la barre d'une **matrice augmentée** (permis sur `matrix` et `bmatrix`, jamais sur `det`). Un `<system>` empile des équations sous une accolade, alignées sur le premier opérateur relationnel :

```
<system>{
2x + 3y = 7
x - y = 1
}
```

Injectez une valeur calculée avec `#{expr}` (ou `#nom`), y compris dans les maths : `$#k^2$`. Les nombres décimaux suivent l'option `lang`.

**L'expression dispose d'une bibliothèque de fonctions complète.** Dans `#{...}`, les fonctions transcendantes sont disponibles, en radians par défaut :

- circulaires `sin cos tan cot sec csc` et réciproques `arcsin arccos arctan` ; les variantes en degrés `sind cosd tand` et `arcsind arccosd arctand` prennent ou renvoient des degrés, si bien que `#{sind(30)}` vaut `0.5` et `#{arcsind(0.5)}` vaut `30` ;
- hyperboliques `sinh cosh tanh coth sech csch` et réciproques `arcsinh arccosh arctanh` ;
- exponentielle et logarithmes `exp`, `ln` (népérien), `log` (base 10), `log2`, `logb(v, b)` (base *b*) ;
- algébriques et arrondis `sqrt cbrt abs sign min max floor ceil` et `round(x, d)` (à *d* décimales, à l'écart de zéro sur les demi-entiers), avec les constantes `pi` et `e`.

Ainsi `#{sin(pi/6)}`, `#{exp(1)}`, `#{logb(81, 3)}` s'évaluent. La même bibliothèque sert `<plot>` : une courbe de `cosh(x)` ou `arctan(x)` se trace à partir de la définition identique.

**Arrondi à l'affichage : `precision`.** L'option de classe `precision:N` arrondit chaque valeur calculée `#{...}` à *N* décimales, en supprimant les zéros de queue (`3.50` affiche `3,5`, `4.0` affiche `4`). Le défaut `-1` affiche le nombre tel que calculé. `precision` fixe le défaut du document ; `round(x, d)` le surcharge localement dans une expression donnée. `precision:2` transforme donc `#{1/3}` en `0,33` tandis que `#{round(1/3, 5)}` donne encore `0,33333`.

### Vocabulaire avancé

Pour les classes supérieures, le mini-langage porte les notations nommées des probabilités, de l'algèbre linéaire et de l'analyse vectorielle. Chaque entrée garde la forme `nom(...)`, et le rendu est le LaTeX canonique des manuels.

**Dénombrement et probabilités** — le coefficient binomial et l'arrangement se reconnaissent à leurs **deux** arguments : un `C(t)` à un argument reste une fonction ordinaire. Probabilité et espérance sont les doubles lettres de tableau, la barre conditionnelle s'écrit `mid` :

| Vous écrivez | Vous obtenez |
|---|---|
| `C(n, k)` | coefficient binomial ⁽ⁿₖ⁾ |
| `A(n, k)` | arrangement Aₙᵏ |
| `factorial(n)` ou `n!` | n! |
| `PP(A)`, `PP(A mid B)` | ℙ(A), ℙ(A ∣ B) |
| `EE(X)` | 𝔼(X) |
| `var(X)` `std(X)` `cov(X, Y)` | Var(X), σ(X), Cov(X, Y) |
| `normal(mu, sigma)` | 𝒩(μ, σ²) |
| `poisson(lambda)` | 𝒫(λ) |
| `binomial(n, p)` | ℬ(n, p) |
| `repart(X, x)` `densite(X, x)` | F_X(x), f_X(x) |

**Algèbre linéaire** — des opérateurs nommés au-dessus des blocs de matrices :

| Vous écrivez | Vous obtenez |
|---|---|
| `ker(f)` `im(f)` `rank(A)` | Ker(f), Im(f), rg(A) |
| `span(u, v)` `tr(A)` `com(A)` | Span(u, v), tr(A), com(A) |
| `transpose(A)` `inv(A)` | Aᵀ, A⁻¹ |
| `eigen(A)` `adj(A)` | Sp(A) (le spectre), adj(A) |

**Analyse vectorielle et transformées** — les opérateurs différentiels, les notations de Landau (en toutes lettres, pour laisser libres les lettres `o`/`O`), et les transformées intégrales :

| Vous écrivez | Vous obtenez |
|---|---|
| `grad(f)` `div(F)` `curl(F)` | grad f, div F, rot F |
| `lap(f)` | Δf (se préfixe à son opérande, sans parenthèses) |
| `dirderiv(f, u)` | ∇_u f |
| `bigO(...)` `litO(...)` | O(·), o(·) |
| `laplace(f)` `fourier(f)` | ℒ{f}, ℱ{f} |
| `ilaplace(f)` `ifourier(f)` | ℒ⁻¹{f}, ℱ⁻¹{f} |
| `surfint(S)` `volint(V)` `flux(F, S)` | ∯_S, ∭_V, un flux |

**Arithmétique, théorie des nombres et ensembles** — et quelques gabarits de calcul :

| Vous écrivez | Vous obtenez |
|---|---|
| `lcm(a, b)` `gcd(a, b)` `sign(x)` | ppcm, pgcd, sgn |
| `card(A)` `powerset(A)` | card(A), 𝒫(A) |
| `range(1, n)` | ⟦1, n⟧ (intervalle d'entiers) |
| `set(x mid x > 0)` | {x ∣ x > 0} (le mot `mid` espace la barre) |
| `euler(n)` `mobius(n)` | φ(n), μ(n) |
| `a equiv b mod n` | a ≡ b (mod n) |
| `taylor(f, x, a, n)` | la forme de Taylor (gabarit) |
| `jacobian(f, n)` `hessian(f, n)` | les matrices génériques de dérivées partielles |

```
$EE(X) = sum(k=1, n) k PP(X = k)$
$var(X) = EE(X^2) - EE(X)^2$
$dim(ker(f)) + rank(f) = dim(E)$
$lap(f) = div(grad(f))$
$flux(F, S) = volint(V) div(F)$
```

---

## Études de fonctions

Trois balises transforment une fonction en tableau de variations et en courbe. Elles partagent une seule source de vérité : un **objet fonction** construit une fois avec `<fn>`, puis lu par `<vartab>` (le tableau) et `<plot>` (le graphe).

### L'objet fonction : `<fn>`

La forme équation se lit comme au tableau et s'enregistre elle-même sous le nom de son membre de gauche — la variable est déclarée en situation, et une étude tient en trois lignes qui se lisent comme l'énoncé :

```
<fn f(x) = (x+2)(x-3)>
<signtab f>
<plot f x:{-4, 5}>
```

Les attributs de tableau restent des attributs après l'expression :

```
<fn g(t) = t^2 - 2t
    x:{-inf | 1 | +inf}
    deriv:{- | +}
    var:{+inf \ -1 / +inf}>
```

Un objet purement tabulaire (un tableau sans formule) prend l'en-tête sans `=` — `<fn v(x) x:{...} deriv:{...} var:{...}>`. Les objets se lient **séquentiellement** : un `<fn f(x) = ...>` ultérieur masque le nom pour la suite, jamais pour ce qui précède — chaque `<signtab f>` ou `<plot f>` voit la définition au-dessus de lui. Les attributs `name:`/`expr:` de la 2.4 restent lus mais sont dépréciés ; la forme équation est la forme canonique :

```
let k = <fn name:{k(x)}
            expr:{(x^2+1)/(x-1)}
            x:{-inf | 1-sqrt(2) | 1 | 1+sqrt(2) | +inf}
            second:{- | - || + | +}
            deriv:{+ | - || - | +}
            var:{-inf / 2-2sqrt(2) \ -inf || +inf \ 2+2sqrt(2) / +inf}>
```

`let NOM = <fn …>` range l'objet sous `NOM` (l'affectation peut s'étendre sur plusieurs lignes, jusqu'au `>` fermant). Champs :

- `name:{k(x)}` — la fonction et sa variable ; règle les libellés de lignes `x`, `k'(x)`, `k(x)` (et `k''(x)` si une ligne de dérivée seconde s'affiche). `name:{k}` seul emploie `x` ; sans `name:`, on a `f(x)`.
- `expr:{…}` — la formule, dans le mini-langage. **Lue seulement par `<plot>`** ; `<vartab>` l'ignore.
- `x:{… | … | …}` — les abscisses remarquables, séparées par `|`.
- `deriv:{…}` — le signe de la dérivée première, un signe par intervalle.
- `second:{…}` — le signe de la dérivée seconde (convexité), un par intervalle. Optionnel.
- `var:{…}` — la ligne de variations (voir plus bas).

### Le tableau : `<vartab>`

`<vartab k>` lit l'objet `k`. Ou écrivez les données en ligne : `<vartab x:{…} deriv:{…} var:{…}>`.

**Quatre formes** sont permises, selon les lignes de signes fournies. Seuls `x:` et `var:` sont requis ; `deriv:` et `second:` sont chacun optionnels :

| forme | champs | lignes |
|-------|--------|------|
| étude complète | `second:` + `deriv:` | x, f″(x), f′(x), f(x) |
| variations classiques | `deriv:` | x, f′(x), f(x) |
| convexité seule | `second:` | x, f″(x), f(x) |
| tableau de valeurs | aucun | x, f(x) |

`f″` s'assied toujours au-dessus de `f′`. Le tableau de valeurs (aucune ligne de signes) relie simplement les valeurs listées par des flèches.

**Les lignes de signes** (`deriv:`, `second:`) prennent un signe par intervalle : `+`, `-`, ou vide. `||` (double barre) marque une valeur interdite (un pôle) : la barre traverse toutes les lignes. Les zéros aux changements de signe sont placés automatiquement — vous ne les écrivez pas.

**La ligne de variations** (`var:`) alterne valeur et connecteur. Un connecteur est `/` (monte) ou `\` (descend), **entouré d'espaces** — collé, comme dans `2/3`, c'est une fraction, pas une flèche. `||` porte les deux limites autour d'un pôle. Les valeurs peuvent être des nombres, `+inf`/`-inf`, ou toute expression mathématique (`2-2sqrt(2)`, `27/4`).

Règles que le tableau impose : une valeur entre deux flèches de **même** sens est refusée — un tableau de variations ne liste que bornes et extrémums, jamais un point d'une branche monotone (ce point appartient au graphe). Quand `f″` et `f′` s'affichent ensemble, `x:` doit lister l'**union** de leurs zéros, puisque toutes les lignes partagent les mêmes colonnes.

### Le tableau de signes : `<signtab>`

Le compagnon de `<vartab>` pour les expressions factorisées. **Automatique** : les lignes sont calculées depuis un produit/quotient de facteurs affines — zéros rationnels exacts, valeur interdite à chaque zéro du dénominateur, multiplicités paires connues pour ne pas changer de signe :

```
<fn f(x) = (x+2)(x-3)>
<signtab f>

<fn g(x) = (x+1)/(x-2)>
<signtab g>

<fn h(x) = -2(x+1)^2 (x - 1/2)>
<signtab h>
```

**Manuel** (la forme générale, pour les lignes que le moteur affin ne sait pas dériver) — une ligne par facteur, d'ordinaire une ligne de conclusion à la fin :

```
<signtab x:{-inf | -2 | 3 | +inf}>{
    x+2  : - | 0 | + | +
    x-3  : - | - | 0 | +
    f(x) : + | 0 | - | 0 | +
}
```

Une cellule est un signe par intervalle ; un `0` marque un zéro **à la borne qu'il suit**, `||` une valeur interdite. L'invariant est vérifié à la compilation : une ligne qui change de signe sans `0` ni `||` à la borne est une erreur, pas un tableau faux à l'impression — une expression ne change pas de signe sans s'annuler ou cesser d'exister.

### Le graphe : `<plot>`

```
<plot k samples:200 x:{-4, 6} y:{-10, 12}>
```

`<plot k>` lit `expr:` et `name:` dans l'objet. Options :

- `x:{a, b}` — fenêtre horizontale d'affichage (virgule entre les deux bornes). À défaut, les abscisses finies du tableau.
- `y:{c, d}` — fenêtre verticale. Requise quand la fonction file à l'infini (un pôle), pour cadrer la vue.
- `samples:N` — nombre de points calculés (100 par défaut).

`expr:` est traduit vers la syntaxe du traceur : la variable devient la variable de tracé, les appels trigonométriques reçoivent la conversion en degrés, et les produits implicites (`2x`, `2(x-1)`) deviennent explicites. Les pôles sont gérés : aucune fausse verticale ne relie les branches. Admis dans `expr:` : `+ - * / ^`, parenthèses, `sin cos tan exp ln log sqrt abs`, et `pi`.

`<vartab>` est déclaratif, `<plot>` est calculé. Si `var:` ne correspond pas à `expr:`, le tableau et la courbe se contredisent en silence — leur cohérence vous revient.

**Aires.** `area:{a,b}` teinte la région entre la courbe et l'axe des abscisses sur [a, b], avec des verticales en pointillés aux bornes ; `between:g` teinte entre deux courbes (recadré par `area:` s'il est donné) :

```
<plot f x:{-1, 4} area:{1, 3}>
<plot f x:{-1, 4} between:g area:{0, 3}>
```

**Suites : l'escalier.** `cobweb:{u0}` (ou `cobweb:{u0, n}`, n = 8 par défaut) trace la bissectrice y = x et l'escalier de u(n+1) = f(u(n)) ; les itérés sont calculés à la compilation, les trois premiers étiquetés sur l'axe :

```
let h = <fn name:{h(x)} expr:{sqrt(2x+3)}>
<plot h x:{0, 4} y:{0, 4} cobweb:{0.2, 10}>
```

**Lois de probabilité.** Les deux lois du lycée n'ont pas besoin d'objet `<fn>` ; `area:` met en valeur P(a ≤ X ≤ b) sur les deux — région teintée sous la gaussienne, bâtons renforcés sur la binomiale. La fenêtre de la normale vaut μ ± 4σ par défaut ; les masses de la binomiale sont calculées exactement :

```
<plot normal:{0, 1} area:{-1, 1.5}>
<plot binomial:{12, 0.4} area:{3, 6}>
```

> Note mathématique : en prose, utilisez les graphies du mini-langage `!=`, `+-`, `>=`, `<=` (pas `\neq`, `\pm`, …). Écrivez `$f(x)$` pour composer une formule ; un `f(x)/x` sans balises s'analyse comme `f` fois `(x)/x` — tournez la phrase en « le rapport de `$f(x)$` à `$x$` ».

---

## La boîte à outils du lycée

Cinq figures de plus achèvent le programme du secondaire (2.5).

**L'arbre de probabilités pondéré** — `<tree>`, l'objet le plus dessiné de première et terminale. Chaque ligne se lit `ÉTIQUETTE PROBABILITÉ`, une accolade optionnelle ouvrant les enfants ; un `!` initial est l'événement contraire (surligné). Les probabilités peuvent être des nombres ou des symboles (`p`, `1-p`). Un nœud à branche unique reçoit automatiquement son complémentaire — le seul cas mathématiquement déterminé ; des branches sœurs dont la somme diffère de 1 sont une erreur de compilation. `products:on` écrit P(A ∩ B) = 0.18 au bout de chaque feuille — le produit exact quand tout est numérique, la chaîne symbolique sinon. La disposition est calculée : feuilles régulièrement espacées, nœuds à la hauteur moyenne de leurs enfants.

```
<tree products:on>{
    A 0.3 {
        B 0.6
    }
    !A 0.7 {
        B 0.1
    }
}
```

**Statistique descriptive** — une balise, `<stats>`, cinq `kind:`, chaque nombre calculé à la compilation :

```
<stats kind:bars data:{1: 4 | 2: 7 | 3: 2}>
<stats kind:bars data:{Walk: 5 | Bus: 3 | Bike: 2}>
<stats kind:histogram bounds:{0, 5, 10, 20} counts:{3, 7, 2}>
<stats kind:pie data:{Walk: 5 | Bus: 3 | Bike: 2}>
<stats kind:boxplot data:{12, 15, 9, 21, 14, 15, 18}>
<stats kind:scatter data:{(1, 2.1) (2, 2.6) (3, 3.4)} fit:on>
```

Le dictionnaire `clé: valeur | …` est la forme des *applications* — bâtons (clés numériques : axe numérique ; mots : catégories) et circulaire ; les couples `(x, y)` restent la forme des *nuages*, où une abscisse peut se répéter.

**Variables de données.** Une table Lua déclarée par `let` se passe par son nom — le foyer naturel des données réutilisées d'une figure à l'autre :

```
let notes = {
    Mathematiques = 15.5,
    Francais = 12.0,
    Anglais = 18.0
}
<stats kind:bars data:notes>
<stats kind:pie data:notes>
```

Une table Lua n'a pas d'ordre d'écriture : les clés d'un dictionnaire sortent donc **triées** (nombres numériquement, mots alphabétiquement) ; quand l'ordre compte, une liste de couples le conserve : `let trimestres = {{"T1", 11.5}, {"T2", 13.0}}`. Les listes de nombres nourrissent `boxplot`, les listes de couples `{x, y}` nourrissent `scatter`, et deux variables listes nourrissent `histogram` par `bounds:` et `counts:`.

Trois garanties d'honnêteté, parce qu'une figure statistique enseigne par sa construction : l'histogramme trace la **densité** (effectif sur amplitude), donc les classes inégales restent véridiques ; la boîte à moustaches emploie les quartiles du secondaire français (Q1 la plus petite valeur telle qu'au moins un quart des données lui soit inférieur ou égal, Q3 de même aux trois quarts) ; `fit:on` trace la droite des moindres carrés — calculée, pas estimée à l'œil.

**La droite graduée** — `<numberline>`, la figure des inéquations et de la valeur absolue. **Résolue** : la forme bloc prend une inéquation (les accolades d'une balise ne peuvent porter `<` ni `>`) et calcule l'ensemble exactement — expression affine contre une constante, produit/quotient de facteurs affines contre 0, ou `abs(affine)` contre une constante. Le strict/large décide de l'ouvert/fermé ; un zéro du dénominateur est toujours exclu ; une solution isolée est un point :

```
<numberline x:{-5, 5}>{
    abs(x - 1/2) >= 5/2
}
```

**Déclarée**, quand l'ensemble est donné plutôt que résolu — crochets à la convention internationale (`[ ]` inclus, `( )` exclus) ; une borne peut être `inf`, le segment court alors jusqu'à la flèche ; `points:` épingle des valeurs isolées :

```
<numberline x:{-5, 5} set:{[-2, 3) union (4, inf)} points:{-4}>
```

**Le cercle trigonométrique** — une ligne de `<draw>` : le cercle, ses axes, et les seize angles remarquables étiquetés par leur mesure principale dans (−π, π]. `values:on` ajoute les projections en pointillés du cosinus et du sinus (valeurs exactes aux angles remarquables, deux décimales ailleurs). Dynamique : `step:{pi/12}` trace les multiples du pas, `range:{0, pi/2}` restreint à un arc — le gros plan sur le premier quadrant. Des étiquettes trop serrées pour être lisibles sont une erreur de compilation suggérant un pas plus grand :

```
<draw>trigcircle radius:4 values:on
<draw>trigcircle radius:4 step:{pi/6}
<draw>trigcircle radius:4 range:{0, pi/2} step:{pi/12} values:on
```

**Géométrie dans l'espace** — les lignes `solid` dans `<draw>` rendent tout le répertoire en *perspective cavalière* (fuyantes à 45°, coefficient 0.5 ; surcharge par `angle:`/`ratio:`). Les arêtes cachées sont **calculées, pas déclarées** : une face d'un solide convexe est visible exactement quand la projection préserve son orientation extérieure, et une arête est en pointillés exactement quand ses deux faces sont cachées. Plusieurs solides dans un bloc se rangent côte à côte. Les noms de sommets sont optionnels sur `cube`, `cuboid` (huit lettres, base puis dessus) et `pyramid` (sommet d'abord). Les sections planes sont remises à une version ultérieure.

```
<draw>{
    solid cube ABCDEFGH edge:4
    solid pyramid SABCD base:4 height:5
}
<draw>{
    solid cuboid sides:{5, 3, 2}
    solid cylinder radius:1.5 height:4
    solid cone radius:2 height:4.5
    solid sphere radius:2.5
}
```

---

## Cadres

```
<box line:Crimson fill:MistyRose radius:4 title:{A note}>{
Content here.
}
```

Options : `line:` couleur du cadre, `fill:` fond, `text:` couleur du texte, `radius:N` coins arrondis (mm), `width:N` ou `width:N%`, `boxrule:N`, `sep:N` (marge intérieure, mm ; `boxsep:N` est un synonyme), `break:yes`, `title:{…}`, `titlefill:`, `titletext:`. Une ligne ne contenant que `---` scinde un cadre en deux régions.

`<row gap:N>{ … }` range ses cadres enfants côte à côte, largeurs égales et hauteurs égalisées. Un cadre prend aussi un code de placement de deux lettres (`tl`…`br`, défaut `tl`) ; la partie verticale exige un `height:` pour agir.

---

## Grille (zones nommées)

Pour les mises en page pleine page — un en-tête de fiche avec logo, bandeau de titre, champs d'information et corps — `<grid>` emprunte à CSS Grid l'idée des zones nommées. Un `template:[ … ]` de rangées entre guillemets dessine la disposition ; chaque mot nomme une cellule. Un nom répété horizontalement fusionne les colonnes, verticalement les rangées ; un point `.` est vide.

```
<grid template:[
  "title  title  logo"
  "intro  info   logo"
  "body   body   body"
] gap:4>{
  <area title>{ <Red b 16pt>Maths assessment }
  <area logo >{ <img>{blason.png} }
  <area intro>{ Instructions: no calculator. }
  <area info >{ Name: \\ First name: }
  <area body >{ <s1>Exercise 1
    Solve the equation... }
}
```

Une zone s'encadre comme un cadre (`line:`, `fill:`, `radius:`, `title:`). La grille prend `width:` et `height:` ; une zone ou la grille prend un code de placement de deux lettres pour positionner le contenu dans les cellules.

---

## Listes

Une liste est `<list:STYLE>` — le style suit le nom, un élément par ligne, aucune balise d'élément :

```
<list:decimal>{
Read the instructions
Underline the key words
Write your answer
}
```

Styles — puces : `none` `disc` `circle` `square` ; numérotés : `decimal` `alpha` `ALPHA` `roman` `ROMAN` (la casse du mot-clé règle la casse des lettres) ; cases à cocher : `check`. Une liste écrite sous un élément devient sa sous-liste, imbriquée à volonté. Les attributs de texte sur la balise habillent toute la liste : `<list:ROMAN TIMES NEW ROMAN 12pt i>{ … }`.

---

## Alias de blocs

Définissez un composant réutilisable une fois ; les emplacements `#param` sont remplis à l'appel, et le corps du site d'appel devient le contenu du bloc — il peut donc contenir ses propres sous-blocs.

```
let card{title, frame} = <box title:{#title} line:#frame radius:2>

<card First, Crimson>{ Called with two arguments. }
<card Second, Navy>{ Same component, different look. }
```

---

## Structures de contrôle

```
for n in 1..3 {
<c Navy b>Sheet #n
}

for f in [chat.png, chien.png] {
<img 16>{#f}
}

if score >= 10 {
<Green>Passed.
} else {
<Red>Try again.
}
```

Boucles et conditions fonctionnent dans le corps du document, dans les cadres et dans les corps de tableaux. La variable de boucle s'interpole partout via `#`.

---

## Échappements

Pour imprimer un caractère que scholatex traite spécialement, **doublez-le** : `<<` `>>` `{{` `}}` `##` donnent un `<` `>` `{` `}` `#` littéral. La contre-oblique est un caractère ordinaire — un chemin comme `C:\Users\Leo` ou une regex `\d+\s*\w` s'imprime tel quel, rien à échapper. Les caractères `_ & % ~` sont échappés automatiquement. Un saut de ligne dans un paragraphe est la balise `<nextline>`. Une ligne dont le premier caractère non blanc est `%` est un commentaire. Un `#` nu, non suivi d'un nom ou de `{…}`, est un `#` littéral.

Les accolades portent la structure, donc une **accolade littérale doit être appariée** : écrivez la paire `{{…}}` pour imprimer `{…}`. Un `{{` ou `}}` seul, non apparié, est signalé comme accolade déséquilibrée avec sa ligne, plutôt que de corrompre silencieusement le bloc — la notation en compréhension `{{ x : x > 0 }}` s'écrit donc en paire. Chevrons et dièses n'exigent pas cet appariement ; seules les accolades.

---
## Référence des couleurs

Chaque couleur s'écrit en **CamelCase** — une règle, aucun raccourci minuscule. Les couleurs courantes prennent simplement la majuscule : `Red` `Blue` `Green` `Navy` `Orange` `Purple` `Teal` `Brown` `Gray`/`Grey` `Pink` `Yellow` `Black` `White` `Violet` `Cyan` `Magenta` `Lime` `Olive` `Aqua` `Silver` `Maroon`.

Pour la palette complète, écrivez n'importe laquelle des **151 couleurs CSS / svgnames en CamelCase** (`<SteelBlue>{…}`, `fill:MistyRose`, `line:DarkOrange`). Elles sont regroupées ci-dessous par famille, pour le parcours ; toutes valent partout où une couleur est attendue (`line:` `fill:` `text:` et balises en ligne).

**Rouges et roses** (14) — `Brown`, `Crimson`, `DarkRed`, `FireBrick`, `IndianRed`, `LightCoral`, `LightPink`, `Maroon`, `MistyRose`, `Pink`, `Red`, `RosyBrown`, `Salmon`, `Tomato`

**Oranges et bruns** (23) — `AntiqueWhite`, `Bisque`, `BlanchedAlmond`, `BurlyWood`, `Chocolate`, `Coral`, `DarkGoldenrod`, `DarkOrange`, `DarkSalmon`, `Goldenrod`, `LightSalmon`, `Moccasin`, `NavajoWhite`, `Orange`, `OrangeRed`, `PapayaWhip`, `PeachPuff`, `Peru`, `SaddleBrown`, `SandyBrown`, `Sienna`, `Tan`, `Wheat`

**Jaunes et ors** (11) — `Cornsilk`, `DarkKhaki`, `Gold`, `Khaki`, `LemonChiffon`, `LightGoldenrod`, `LightGoldenrodYellow`, `LightYellow`, `Olive`, `PaleGoldenrod`, `Yellow`

**Verts** (20) — `Aquamarine`, `Chartreuse`, `DarkGreen`, `DarkOliveGreen`, `DarkSeaGreen`, `ForestGreen`, `Green`, `GreenYellow`, `LawnGreen`, `LightGreen`, `Lime`, `LimeGreen`, `MediumAquamarine`, `MediumSeaGreen`, `MediumSpringGreen`, `OliveDrab`, `PaleGreen`, `SeaGreen`, `SpringGreen`, `YellowGreen`

**Cyans et bleus-verts** (17) — `Aqua`, `CadetBlue`, `Cyan`, `DarkCyan`, `DarkSlateGray`, `DarkSlateGrey`, `DarkTurquoise`, `DeepSkyBlue`, `LightBlue`, `LightCyan`, `LightSeaGreen`, `MediumTurquoise`, `PaleTurquoise`, `PowderBlue`, `SkyBlue`, `Teal`, `Turquoise`

**Bleus** (21) — `Blue`, `CornflowerBlue`, `DarkBlue`, `DarkSlateBlue`, `DodgerBlue`, `LightSkyBlue`, `LightSlateBlue`, `LightSlateGray`, `LightSlateGrey`, `LightSteelBlue`, `MediumBlue`, `MediumPurple`, `MediumSlateBlue`, `MidnightBlue`, `Navy`, `NavyBlue`, `RoyalBlue`, `SlateBlue`, `SlateGray`, `SlateGrey`, `SteelBlue`

**Violets et pourpres** (17) — `BlueViolet`, `DarkMagenta`, `DarkOrchid`, `DarkViolet`, `DeepPink`, `Fuchsia`, `HotPink`, `Indigo`, `Magenta`, `MediumOrchid`, `MediumVioletRed`, `Orchid`, `PaleVioletRed`, `Plum`, `Purple`, `Violet`, `VioletRed`

**Gris** (10) — `DarkGray`, `DarkGrey`, `DimGray`, `DimGrey`, `Gray`, `Grey`, `LightGray`, `LightGrey`, `Silver`, `Thistle`

**Blancs et blancs cassés** (17) — `AliceBlue`, `Azure`, `Beige`, `FloralWhite`, `Gainsboro`, `GhostWhite`, `Honeydew`, `Ivory`, `Lavender`, `LavenderBlush`, `Linen`, `MintCream`, `OldLace`, `Seashell`, `Snow`, `White`, `WhiteSmoke`

**Noir** (1) — `Black`

Ce sont exactement les couleurs que xcolor fournit sous son option `svgnames` (les 147 noms du CSS Color Module plus les quatre extras X11 `LightGoldenrod`, `LightSlateBlue`, `NavyBlue` et `VioletRed`). Les noms sont sensibles à la casse : écrivez `Seashell`, pas `SeaShell`.

---
## Sécurité

`scholatex` évalue `let nom = expr`, `#{expr}` et les conditions des `for`/`if`/`while` comme du Lua à la compilation : par défaut, un document peut donc exécuter du code arbitraire — exactement comme `\directlua`.

Poser `untrusted=true` dans `\documentclass[...]{scholatex}` exécute ce Lua dans un environnement restreint : seuls les noms purs, sans effet de bord, sont visibles ; `os`, `io`, `package`, `require`, `load`, `debug` et les autres vecteurs d'évasion sont absents. Un accès bloqué arrête la compilation avec un message clair ; une boucle folle est interrompue par un plafond d'instructions ; `string.rep`/`string.format` sont bornés.

```latex
\documentclass[untrusted=true]{scholatex}
```

`untrusted` durcit **la seule couche d'expressions de scholatex**. Il ne met pas LuaLaTeX tout entier en bac à sable — un `.tex` hostile peut toujours appeler `\directlua`, `\write18`, `\input`. Employez-le quand le **corps** scholatex vient d'une source semi-fiable tandis que le `.tex` environnant est le vôtre ; pour un `.tex` entièrement douteux, lancez `lualatex` sans `--shell-escape`, idéalement dans un conteneur.

---

## Exemples

Le dossier `examples/` contient huit documents autonomes, entièrement commentés, qui ensemble exercent chaque fonctionnalité :

| Fichier | Couvre |
|------|--------|
| `text-style.tex` | la règle de casse, styles, couleurs, polices, tailles, alignement, tabulations, sauts, exposants ; **la factorisation des styles en alias** ; une table des matières depuis les mots-clés de titre |
| `containers.tex` | tableaux, cadres et grille à zones nommées, chacun construit de sa forme la plus simple jusqu'à l'en-tête de fiche complet |
| `basics.tex` | le mini-langage en ligne, ensembles de nombres, quantificateurs et connecteurs, la négation par `!`, les relations ensemblistes, la partie entière, le surlignement, les aides arithmétiques |
| `analysis.tex` | opérateurs à indice, limites, trigonométrie, dérivées, opérateurs vectoriels, la famille des intégrales, transformées — puis tableaux de signes, droite graduée, aires et escaliers, et quatre études de fonctions complètes (`<fn>`, `<vartab>`, `<plot>`), du polynôme à l'hyperbolique |
| `algebra.tex` | les blocs matrice / déterminant / matrice augmentée / système, et le vocabulaire d'algèbre linéaire |
| `statistics-probability.tex` | dénombrement, probabilité et espérance, variance, lois et densité — puis arbres pondérés, les deux lois, et les cinq figures de statistique descriptive |

Compilez n'importe lequel avec `lualatex <fichier>.tex` depuis le dossier `examples/`.

---

## Arborescence du projet

```
scholatex.cls            classe LaTeX : options, packages, lit et injecte le corps
scholatex.lua            cœur du transpileur : balises, texte, contrôle, alias
scholatex-style.lua      résolution d'attributs (couleurs, styles, tailles, alignement…)
scholatex-math.lua       le mini-langage mathématique de $…$
scholatex-util.lua       primitives d'analyse (groupes, équilibre d'accolades, virgules)
scholatex-table.lua      le bloc <table>
scholatex-img.lua        la balise <img>
scholatex-box.lua        les blocs <box> et <row>
scholatex-grid.lua       le bloc <grid> à zones nommées
scholatex-section.lua    les blocs <section>/<subsection>/<subsubsection>
scholatex-list.lua       le bloc <list:STYLE>
scholatex-matrix.lua     les blocs <matrix>/<det>/<bmatrix> et <system>
scholatex-vartab.lua     l'objet <fn> et le tableau <vartab>
scholatex-signtab.lua    le tableau de signes <signtab>
scholatex-plot.lua       la courbe <plot> : aires, escaliers, lois de probabilité
scholatex-tree.lua       l'arbre de probabilités pondéré <tree>
scholatex-stats.lua      les figures de statistique descriptive <stats>
scholatex-numberline.lua la droite graduée <numberline>, déclarée ou résolue
scholatex-affine.lua     analyse de signes exacte des facteurs affines (zéros rationnels)
scholatex-figure.lua     le bloc <draw> : figures, points, segments, trigcircle
scholatex-solid.lua      la géométrie dans l'espace en perspective cavalière (solid …)
scholatex-toc.lua        la balise <tableofcontents>
examples/                huit documents de démonstration commentés
```

Les nouvelles balises s'enregistrent via `scholatex.register_tag` / `scholatex.register_block` ; une collision de noms lève une erreur au lieu d'écraser en silence, si bien que les modules restent indépendants.

---

## Diagnostics

Les erreurs pointent la ligne source, p. ex. `scholatex: line 12: unknown tag attribute: 'xyz'`. Définir un alias dont le nom est un mot réservé (`let section = …`) imprime un avertissement : le mot réservé gagne toujours, l'alias serait donc silencieusement mort — choisissez un autre nom.

---

## Nouveautés

### 2.5

La version du lycée : les neuf dernières figures et les derniers tableaux du programme du secondaire français, pour qu'une fiche de la seconde à la terminale ne quitte jamais le langage de balises.

- **Tableaux de signes `<signtab>`** — automatique (`<signtab f>` calcule les lignes, zéros et valeurs interdites exacts depuis l'expression factorisée) ou manuel (une ligne par facteur, `0` au zéro d'une borne, `||` à une valeur interdite ; un changement de signe sans l'un ni l'autre est une erreur de compilation).
- **Arbres de probabilités pondérés `<tree>`** — branches déclaratives, `!B` pour le contraire, probabilités symboliques admises, branche unique complétée automatiquement par son contraire, `products:on` pour les produits aux feuilles (exacts quand tout est numérique).
- **Aires dans `<plot>`** — `area:{a,b}` sous une courbe, `between:g` entre deux courbes.
- **Escaliers** — `cobweb:{u0, n}` trace l'escalier de u(n+1) = f(u(n)) avec la bissectrice, itérés calculés.
- **Lois de probabilité** — `<plot normal:{mu,sigma}>` et `<plot binomial:{n,p}>` sans objet `<fn>` ; `area:` met en valeur P(a ≤ X ≤ b) sur les deux.
- **La forme équation de `<fn>`** — `<fn f(x) = (x+2)(x-3)>` s'enregistre sous le nom de son membre de gauche ; la déclaration se lit comme l'énoncé.
- **Variables de données** — `let notes = {Mathematiques = 15.5, ...}` puis `<stats kind:bars data:notes>` ; tables `let` multi-lignes acceptées.
- **Statistiques `<stats>`** — bâtons (dictionnaire d'effectifs, numérique ou catégoriel), histogramme (densité : honnête avec les classes inégales), circulaire, boîte à moustaches (quartiles français), nuage avec droite des moindres carrés `fit:on` calculée.
- **Cercle trigonométrique** — `<draw>trigcircle`, angles remarquables en mesure principale par défaut, `step:{pi/12}` et `range:{0, pi/2}` pour une graduation choisie ou le gros plan sur le premier quadrant, `values:on` pour les projections cos/sin.
- **Droite graduée `<numberline>`** — ensembles déclarés (bornes incluses/exclues, `union`, bornes infinies, points isolés) ou inéquation résolue (forme bloc), l'ensemble calculé exactement.
- **Géométrie dans l'espace** — `solid cube/cuboid/pyramid/cylinder/cone/sphere` en perspective cavalière, arêtes cachées calculées depuis l'orientation des faces, solides rangés côte à côte.

### 2.4

- **Géométrie analytique dans `<draw>` : le mode `axes:`** — `<draw axes:{xmin,xmax,ymin,ymax}>` dessine un repère cartésien gradué et lit chaque ligne comme une directive en coordonnées plutôt qu'une construction. Une unité reste un centimètre et le dessin est rogné à la fenêtre. Un bloc sans `axes:` garde le comportement de construction de la 2.3, inchangé.
  - `point NOM (x,y)` place et étiquette un point, disponible par son nom aux lignes suivantes.
  - `vector u (x,y)` trace un vecteur libre depuis l'origine ; `vector AB` le vecteur lié entre deux points placés. Un vecteur nommé est mémorisé : `vector s = u+v` (ou `u-v`) trace la somme ou la différence, étiquetée par l'expression le long de la flèche ; `from:` déplace la queue de tout vecteur (un point placé, un couple littéral, ou `~u` pour la pointe d'un vecteur tracé) et `style:` restyle la copie (`style:dashed-gray`, `style:Blue`) — les règles du parallélogramme et du triangle se lisent sur un seul repère.
  - `line` par équation (`y = 2x-1`, `x = -3`, le général `2x+3y = 6`) ou `line through A B`.
  - `circle center:A radius:r` (centre un point placé ou un couple littéral) ou par équation `circle x^2+y^2 = 4` ; un cercle nommé porte une `tangent to:C at:P` en un de ses points.
  - `region` teinte le demi-plan d'une inéquation linéaire (`<`, `>`), la frontière en pointillés.
- **Courbes paramétriques et polaires dans `<plot>` : le champ `kind:`** — `kind:parametric` lit `expr:{x(t), y(t)}` sur `t:{a, b}` ; `kind:polar` lit `expr:{r(theta)}` sur `theta:{a, b}`, tracé comme `(r cos theta, r sin theta)`. Les bornes acceptent `pi`. Les coniques découlent du paramétrage (ellipse `{a cos(t), b sin(t)}`, parabole `{t, t^2}`, hyperbole `{a cosh(t), b sinh(t)}`) — aucune directive conique séparée. Un `<plot>` sans `kind:` est le graphe de fonction, inchangé.

### 2.3

- **Le dessin de figures : le bloc `<draw>`** — une figure plane se décrit, ne se place pas à la main. Nommez la forme et donnez ses mesures ; les coordonnées sont calculées trigonométriquement et émises en nombres durs. Une unité de dessin est un centimètre : `side:5` trace un côté de 5 cm.
  - **Triangles** par toute définition classique — `equilateral`, `isosceles`, `right` (angle droit au premier point, ou `right:X`), trois côtés `sides:(a,b,c)`, deux côtés et l'angle inclus `sides:(a,b) angle:t`, deux angles et un côté `angles:(A,B) side:c`, ou trois côtés nommés un à un (`AB:3 BC:4 CA:5`).
  - **Quadrilatères** — `square`, `rectangle`, `rhombus`, `parallelogram`, `trapezoid`, et `kite` (deux paires de côtés adjacents égaux, le losange étant le cas où les deux paires sont égales).
  - **Polygones réguliers** par leur nom à partir du pentagone (`pentagon`, `hexagon`, `octagon`), ou `polygon` avec autant de points que donnés.
  - **Cercles** par centre et `radius:r` ou `diameter:d` (le rayon éventuellement un segment placé, `radius:AB`) ; `circle ABC` est le cercle circonscrit à trois points placés, `inscribed` pour le cercle inscrit.
- **Codage et mesures** — `marks:on` code les côtés égaux et les angles droits ; `measures:cm` / `measures:mm` étiquette chaque côté de sa longueur. Tous deux sur demande. Quand une figure a deux paires de côtés égaux de longueurs différentes (cerf-volant, rectangle, parallélogramme), les paires se distinguent par le nombre de traits — un trait sur l'une, deux sur l'autre — un cerf-volant ne se lit donc jamais comme un losange.
- **Figures composées** — plusieurs figures d'un même bloc partagent leurs points ; une figure répétant un point s'y greffe, et une figure partageant une arête en déduit la longueur et bascule de l'autre côté pour aboutement. Une arête partagée est étiquetée une fois et codée une fois, pas deux.
- **Noms de points multi-caractères** — outre les lettres collées (`triangle ABC`), une liste parenthésée à virgules nomme des points multi-caractères : `triangle (O, A0, B0)`.
- **Boucles, interpolation et rotation dans `<draw>`** — les mêmes boucles `for VARIABLE in FROM..TO { … }` que le reste du langage ; `#k` et `#{expr}` interpolent noms de points et mesures ; `rotate:θ` tourne une figure autour de son premier point, `scale:F` multiplie toutes les coordonnées du dessin par F sans toucher à la taille du texte (défaut 1, toutes les formes de `<draw>`), et `labels:off` masque les noms de sommets — de quoi éventailler, faire des rosaces ou des marches autour d'un centre.
- **Primitives de bas niveau `point` et `line`** — `point(P)` place un point aux coordonnées déclarées par `let P = {x, y}` ; `line(A, B)` trace un segment entre deux points (noms ou couples littéraux `{x, y}`), acceptant `measures:` comme un côté de figure. Chaque coordonnée étant une expression ordinaire, une boucle peut calculer les extrémités — la brique des dessins libres.
- **Exemples** — une nouvelle vitrine `geometry` couvre le vocabulaire de géométrie en ligne et le bloc `<draw>` complet.

### 2.2

- **Probabilités et statistiques** — les opérateurs de tableau `PP(...)` ℙ et `EE(...)` 𝔼 (avec `PP(A mid B)` pour un conditionnement), la dispersion (`var`, `std`, `cov`), les lois (`normal`, `poisson`, `binomial`), et les fonctions de répartition/densité (`repart`, `densite`).
- **Dénombrement** — le coefficient binomial `C(n, k)` et l'arrangement `A(n, k)`, reconnus à leurs deux arguments (un `C(t)` à un argument reste une fonction) ; la factorielle `factorial(n)` ou `n!`.
- **Vocabulaire d'algèbre linéaire** — `ker`, `im`, `rank`, `span`, `tr`, `com`, `eigen` (le spectre), `adj`, avec `transpose(A)` → Aᵀ et `inv(A)` → A⁻¹.
- **Analyse vectorielle** — `grad`, `div`, `curl`, le laplacien `lap(f)` Δf, la dérivée directionnelle `dirderiv(f, u)`, les notations de Landau `bigO`/`litO`, les transformées `laplace`/`fourier` et leurs inverses, et les intégrales de surface/volume `surfint`/`volint`/`flux`.
- **Théorie des nombres et aides** — `euler` φ, `mobius` μ, la congruence `a equiv b mod n`, plus `lcm`, `sign`, `card`, `powerset`, l'intervalle d'entiers `range(1, n)` ⟦1, n⟧, le mot-clé `mid` pour une barre espacée, et les gabarits `taylor`, `jacobian`, `hessian`.
- **Corrections** — un groupe parenthésé au-dessus d'une fraction prend désormais toute sa hauteur (`(a/b)^2`) ; les différentielles d'ordre supérieur `d^2y/dx^2` composent le d droit partout ; les graduations d'un tracé restent lisibles où une courbe croise un axe, et la flèche d'axe dégage la dernière graduation.
- **Exemples par domaine** — la vitrine mathématique reflète désormais les quatre catégories du manuel : `basics`, `algebra`, `analysis` (qui porte les études de fonctions) et `probability`.

### 2.1

- **Vocabulaire mathématique** — ensembles de nombres en gras de tableau (`NN` `ZZ` `DD` `QQ` `RR` `CC`, plus `PP` `KK` `HH` `FF` `EE` `UU`), quantificateurs et connecteurs (`forall` `exists` `and` `or` `lnot` `neg`), implication et équivalence en mots ou flèches (`=>`/`implies`, `<=>`/`iff`), relations ensemblistes (`in` `subset` `cup` `cap` `setminus` `emptyset` …), partie entière (`floor` `ceil` `round`) et accents (`bar`/`conj` pour le surlignement conjugué-moyenne-adhérence, `not` pour la négation logique, `hat` `tilde`).
- **Négation par un seul `!`** — `!` devant une relation ou un quantificateur le nie avec le bon glyphe barré : `!in` ∉, `!exists` ∄, `!subset` ⊄, `!subseteq` ⊈, `!equiv` ≢. `!=` reste « différent de ».
- **Flèche de limite** — `arrow(n to +inf)` compose une longue flèche droite avec sa condition dessous, pour la tournure « uₙ → l » en maths courantes.
- **Couleurs en CamelCase seulement** *(rupture)* — les mots-clés minuscules (`red`, `navy`, …) sont retirés ; écrivez la forme CamelCase (`Red`, `Navy`). Une règle pour les 151 couleurs. Une couleur minuscule lève désormais une erreur nommant le remplacement CamelCase.
- **Études de fonctions** — trois balises nouvelles pour l'analyse : `<fn>` construit un objet fonction (nom, formule, abscisses, signes des dérivées, variations), `<vartab>` rend son tableau de variations, `<plot>` trace sa courbe (via pgfplots, pôles gérés). Le tableau vient en quatre formes — complète (f″, f′, f), classique (f′, f), convexité (f″, f), ou tableau de valeurs (f) — puisque les deux lignes de dérivées sont indépendantes et optionnelles.
- **Styles de numérotation des sections** — `num`, `roman`, `ROMAN`, `alpha`, `ALPHA` fixent le style de compteur d'un niveau de titre, seul, sans préfixe hérité ; le défaut reste hiérarchique.
- **Exemples réorganisés** — la vitrine devient `text-style`, `containers`, `math-language`, `math-analysis`, `math-algebra` et `functions` (l'ancien `03-math` unique est scindé par thème).

### 2.0

- **Nouvelles règles d'échappement** *(rupture)* — pour imprimer un caractère spécial, doublez-le : `<<` `>>` `{{` `}}` `##` donnent un `<` `>` `{` `}` `#` littéral. La contre-oblique est désormais un caractère ordinaire (`C:\Users` marche tel quel) ; ce n'est plus un échappement. Les anciennes formes `\<` `\>` `\{` `\}` `\#` ne s'appliquent plus.
- **Le saut de ligne est une balise** *(rupture)* — utilisez `<nextline>` (en texte et dans les cellules) à la place de l'ancien `\\`. En texte courant, une ligne vide ouvre déjà un paragraphe : `<nextline>` ne sert qu'au saut sans changement de paragraphe.

### 1.2

- **Correction de précédence exposant/fraction** — `^` et `_` lient désormais plus fort que `/` : `x^2/y` se rend comme la fraction de `x^2` sur `y` (et `1/i^2` comme `1` sur `i^2`), conformément à la lecture mathématique ordinaire.
- **Espacement automatique des lignes hautes** — des lignes consécutives portant fractions ou intégrales ne se touchent plus ; TeX insère juste l'air nécessaire, le texte ordinaire inchangé.

### 1.1

- **Extension mathématique** — famille complète des intégrales (`int`, intégrales multiples ordonnées façon Fubini, `contourint`, `pvint`, `meanint`), fonctions et trigonométrie en romain, dérivées de Leibniz et partielles avec d droits ISO 80000-2.
- **Opérateurs en style display** — `sum`, `prod`, `lim` gardent les fractions à pleine taille et posent les limites sous le mot.
- **Parité complète des couleurs** — les 151 couleurs svgnames de xcolor reconnues, groupées par famille dans la [référence](#référence-des-couleurs).
- **Installation multiplateforme** — chemins `tlmgr` et manuels documentés pour macOS, Linux et Windows.

---

## Remerciements

`scholatex` s'appuie sur d'excellents packages LaTeX :

- [tcolorbox](https://ctan.org/pkg/tcolorbox) — cadres et affiches
- [tabularray](https://ctan.org/pkg/tabularray) — mise en page 2-D fiable des tableaux
- [unicode-math](https://ctan.org/pkg/unicode-math) — mathématiques OpenType
- [fontspec](https://ctan.org/pkg/fontspec) — polices système sous LuaLaTeX
- [xcolor](https://ctan.org/pkg/xcolor) — la palette svgnames

---

## Licence

Copyright © 2026 Gérard Dubard.
