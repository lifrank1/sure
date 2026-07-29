# Bundled typefaces

Every family below is vendored as a latin-subset variable `woff2` and served
from this app (`font-src 'self'`) rather than a CDN — a finance app should not
leak a request per pageview to a third party.

| Directory | Family | License |
|---|---|---|
| `geist/`, `geist_mono/` | Geist, Geist Mono | SIL OFL 1.1 (Vercel) |
| `instrument_sans/`, `instrument_serif/` | Instrument Sans, Instrument Serif | SIL OFL 1.1 |
| `fraunces/` | Fraunces | SIL OFL 1.1 |
| `bricolage/` | Bricolage Grotesque | SIL OFL 1.1 |
| `plex_sans/`, `plex_mono/` | IBM Plex Sans, IBM Plex Mono | SIL OFL 1.1 (IBM) |
| `sora/` | Sora | SIL OFL 1.1 |
| `newsreader/` | Newsreader | SIL OFL 1.1 |
| `archivo/` | Archivo | SIL OFL 1.1 |
| `jetbrains_mono/` | JetBrains Mono | SIL OFL 1.1 |
| `atkinson/` | Atkinson Hyperlegible Next | SIL OFL 1.1 (Braille Institute) |

The OFL permits bundling and redistribution as part of a larger work. Full
license text: <https://openfontlicense.org/>. Reserved Font Names are unchanged —
none of these files have been modified beyond subsetting to latin by the
Google Fonts API.

Used by the typeface axis of the theme lab; see
`docs/frank-finance/THEME_LAB.md`.
