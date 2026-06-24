# Changelog

All notable changes to **scholatex** are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project adheres to a simple `MAJOR.MINOR` scheme. Entries marked
**BREAKING** change the surface syntax: a document written for an earlier
version may need a small edit, described in the migration note.

## [2.1] — 2026-06-23

### Added

- **Mathematical vocabulary.** The inline mini-language now carries the
  notation a course needs to *state* things, not only compute:
  - Number sets in blackboard bold, doubled-capital ASCIIMath style:
    `NN ZZ DD QQ RR CC`, plus `PP KK HH FF EE UU` for the advanced ones.
  - Quantifiers and connectives: `forall` ∀, `exists` ∃, `and` ∧, `or` ∨,
    `lnot`/`neg` ¬.
  - Implication and equivalence, as words or ASCII arrows: `=>`/`implies`
    ⇒, `<=>`/`iff` ⇔.
  - Set relations and operations: `in subset supset subseteq supseteq cup
    cap setminus emptyset`.
  - The integer part: `floor(x)` ⌊x⌋, `ceil(x)` ⌈x⌉, `round(x)`.
  - One-argument wrappers `set(...)` and `abr(...)` (inner product), and the
    accents `bar`/`conj` (the conjugate–mean–closure overline), `not` (the
    same overline read as logical negation), `hat`, `tilde`.
- **Negation with a single `!`.** A `!` in front of a relation or
  quantifier negates it with the proper struck-through glyph: `!in` ∉,
  `!exists` ∄, `!subset` ⊄, `!subseteq` ⊈, `!equiv` ≢. `!=` keeps its
  meaning "not equal" (≠).
- **Limit arrow.** `arrow(n to +inf)` sets a long right arrow with its
  condition written underneath, for the "uₙ → l" phrasing in running maths.
- **Function studies.** Three tags share one source of truth: `<fn>` builds
  a function object (name, formula, abscissas, derivative signs, variation),
  `<vartab>` renders its variation table, `<plot>` draws its curve through
  pgfplots with pole handling. The table comes in four shapes — full
  (f″, f′, f), classic (f′, f), convexity (f″, f), or a plain value table —
  since the two derivative lines are independent and optional.
- **Section numbering styles.** `num`, `roman`, `ROMAN`, `alpha`, `ALPHA`
  set the counter style of a heading level on its own, with no inherited
  prefix; the default stays hierarchical.

### Changed

- **BREAKING — colours are CamelCase only.** The lowercase colour keywords
  (`red`, `blue`, `green`, `navy`, …) have been removed. There is now a
  single rule: a colour is one of the 151 CSS / svgnames names written in
  CamelCase. The everyday colours are simply the capitalised form (`Red`,
  `Blue`, `Navy`, `Gray`). A lowercase colour now raises an error that names
  its CamelCase replacement.
- **Examples reorganised.** The single `03-math.tex` is split by topic, and
  the showcase set drops its numbering: `text-style`, `containers`,
  `math-language`, `math-analysis`, `math-algebra`, `functions`.

### Migration (1.x / 2.0 → 2.1)

- Replace every lowercase colour keyword with its CamelCase form. The
  mapping is a plain capitalisation:
  `red→Red`, `blue→Blue`, `green→Green`, `navy→Navy`, `orange→Orange`,
  `purple→Purple`, `teal→Teal`, `brown→Brown`, `gray→Gray`, `grey→Grey`,
  `pink→Pink`, `yellow→Yellow`, `black→Black`, `white→White`,
  `violet→Violet`, `cyan→Cyan`, `magenta→Magenta`, `lime→Lime`,
  `olive→Olive`, `aqua→Aqua`, `silver→Silver`, `maroon→Maroon`.
  A sed one-liner for a single file:
  ```
  sed -i -E 's/\b(red|blue|green|navy|orange|purple|teal|brown|gray|grey|pink|yellow|black|white|violet|cyan|magenta|lime|olive|aqua|silver|maroon)\b/\u&/g' file.tex
  ```
  Apply it only to scholatex documents (not to English prose), since it
  capitalises whole words.
- To print a comparison or arrow operator **in running prose** (outside
  `$…$`), double the chevrons: `<<=>>` for ⇔, `<<=` for ≤, `>>=` for ≥.
  Inside a formula nothing changes.

## [2.0] — 2026-06-21

### Changed

- **BREAKING — new escape rules.** To print a special character, double it:
  `<<` `>>` `{{` `}}` `##` give a literal `<` `>` `{` `}` `#`. A backslash is
  now an ordinary character (so `C:\Users` just works) and no longer an
  escape; the old `\<` `\>` `\{` `\}` `\#` forms no longer apply.
- **BREAKING — line break is a tag.** Use `<nextline>` (in text and table
  cells) instead of the old `\\`. In running text a blank line already
  starts a new paragraph, so `<nextline>` is only for a break without a
  paragraph change.

### Security

- Closed-language design: the backslash is inert, so raw LaTeX in the body
  is typeset literally rather than executed. The `untrusted` option runs the
  document's Lua in a restricted sandbox.

## [1.2]

### Fixed

- **Script/fraction precedence.** `^` and `_` now bind tighter than `/`, so
  `x^2/y` is the fraction of `x^2` over `y` (and `1/i^2` is `1` over `i^2`),
  matching ordinary mathematical reading.

### Added

- **Automatic spacing for tall lines.** Consecutive lines with fractions or
  integrals no longer touch; ordinary text is unchanged.

## [1.1]

### Added

- **Maths expansion.** Full integral family (`int`, multiple integrals with
  Fubini ordering, `contourint`, `pvint`, `meanint`), upright functions and
  trigonometry, Leibniz and partial derivatives with ISO 80000-2 upright
  differentials.
- **Operators in display style.** `sum`, `prod`, `lim` keep fractions
  full-size and place limits under the word.
- **Full colour parity.** All 151 xcolor svgnames colours recognised,
  grouped by family in the colour reference.
- **Cross-platform install.** Documented `tlmgr` and manual paths for macOS,
  Linux and Windows.

## [1.0]

- First CTAN release: the tag-based language, text attributes, aliases and
  macros, tables, images, the inline maths mini-language, boxes, the
  named-area grid, lists, control flow.

[2.1]: https://ctan.org/pkg/scholatex
[2.0]: https://ctan.org/pkg/scholatex
[1.2]: https://ctan.org/pkg/scholatex
[1.1]: https://ctan.org/pkg/scholatex
[1.0]: https://ctan.org/pkg/scholatex
