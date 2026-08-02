// PDFKit's built-in "Helvetica"/"Helvetica-Bold" are the PDF standard-14
// fonts, encoded as WinAnsi — they're missing the Turkish-specific letters
// (ı, İ, ğ, Ğ, ş, Ş), which silently render as garbage or drop entirely.
//
// DejaVu Sans, not a Google-Fonts-style webfont: Google Fonts / Fontsource
// packages (@fontsource/noto-sans, @fontsource/roboto, ...) split every
// family into disjoint per-unicode-range files (e.g. "latin" vs
// "latin-ext") meant to be layered together via CSS unicode-range in a
// browser — used standalone, the "latin-ext" file is missing plain ASCII
// and punctuation, and the "latin" file is missing the Turkish letters.
// Confirmed this with fontkit's `hasGlyphForCodePoint` before picking a
// font — see DECISIONS.md's "PDF text and Turkish characters" section.
// DejaVu Sans ships as one complete, non-subsetted TTF per weight with
// full Latin Extended-A + general punctuation coverage, and its license
// (Bitstream Vera-derived) permits embedding/redistribution freely.
export const FONT_REGULAR = require.resolve("dejavu-fonts-ttf/ttf/DejaVuSans.ttf");
export const FONT_BOLD = require.resolve("dejavu-fonts-ttf/ttf/DejaVuSans-Bold.ttf");
