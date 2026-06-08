#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)

source_markdown="$repo_root/Where The Sun Was.md"
cover_image="$repo_root/where-the-sun-was.png"
pdf_file="$repo_root/Where The Sun Was.pdf"
epub_file="$repo_root/Where The Sun Was.epub"
website_dir="$repo_root/website"
website_cover="$website_dir/where-the-sun-was.png"
website_pdf="$website_dir/Where The Sun Was.pdf"
website_epub="$website_dir/Where The Sun Was.epub"
index_file="$website_dir/index.html"
styles_file="$website_dir/styles.css"
script_file="$website_dir/system.js"

for required_file in "$source_markdown" "$cover_image" "$pdf_file" "$epub_file"; do
  if [[ ! -f "$required_file" ]]; then
    printf 'Missing required file: %s\n' "$required_file" >&2
    exit 1
  fi
done

rm -rf "$website_dir"
mkdir -p "$website_dir"

cp "$cover_image" "$website_cover"
cp "$pdf_file" "$website_pdf"
cp "$epub_file" "$website_epub"

temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

chapter_markdown="$temp_dir/chapter-01.md"
chapter_html="$temp_dir/chapter-01.html"

awk '
  BEGIN {
    in_chapter = 0
  }

  /^### Chapter 01 - / {
    in_chapter = 1
    print
    next
  }

  in_chapter && /^### / {
    exit
  }

  in_chapter {
    print
  }
' "$source_markdown" > "$chapter_markdown"

if [[ ! -s "$chapter_markdown" ]]; then
  printf 'Unable to extract Chapter 01 from %s\n' "$source_markdown" >&2
  exit 1
fi

awk '
  function trim(text) {
    sub(/^[[:space:]]+/, "", text)
    sub(/[[:space:]]+$/, "", text)
    return text
  }

  function escape_html(text) {
    gsub(/&/, "\\&amp;", text)
    gsub(/</, "\\&lt;", text)
    gsub(/>/, "\\&gt;", text)
    return text
  }

  function replace_pairs(text, marker, open_tag, close_tag,    dlen, start, rest, end, out) {
    dlen = length(marker)
    out = ""

    while ((start = index(text, marker)) > 0) {
      rest = substr(text, start + dlen)
      end = index(rest, marker)

      if (end == 0) {
        return out text
      }

      out = out substr(text, 1, start - 1) open_tag substr(rest, 1, end - 1) close_tag
      text = substr(rest, end + dlen)
    }

    return out text
  }

  function inline_format(text) {
    text = escape_html(text)
    text = replace_pairs(text, "**", "<strong>", "</strong>")
    text = replace_pairs(text, "*", "<em>", "</em>")
    return text
  }

  function flush_paragraph(    text) {
    text = trim(paragraph)

    if (text != "") {
      print "<p>" inline_format(text) "</p>"
    }

    paragraph = ""
  }

  function open_signal() {
    flush_paragraph()
    in_signal = 1
    print "<div class=\"signal-card\" aria-label=\"Probe report frame\">"
  }

  function close_signal() {
    if (in_signal) {
      print "</div>"
      in_signal = 0
    }
  }

  function signal_line(text,    safe, split_at, key, value) {
    text = trim(text)
    safe = inline_format(text)
    split_at = index(safe, ":")

    if (split_at == 0) {
      print "<div class=\"signal-title\">" safe "</div>"
      return
    }

    key = substr(safe, 1, split_at - 1)
    value = trim(substr(safe, split_at + 1))
    print "<div class=\"signal-row\"><span>" key "</span><strong>" value "</strong></div>"
  }

  BEGIN {
    paragraph = ""
    in_signal = 0
  }

  /^[[:space:]]*$/ {
    close_signal()
    flush_paragraph()
    next
  }

  trim($0) == "Origin System Return Survey" {
    open_signal()
    signal_line($0)
    next
  }

  in_signal {
    signal_line($0)
    next
  }

  /^### / {
    close_signal()
    flush_paragraph()
    line = $0
    sub(/^### /, "", line)
    print "<h2>" inline_format(trim(line)) "</h2>"
    next
  }

  /^## / {
    close_signal()
    flush_paragraph()
    line = $0
    sub(/^## /, "", line)
    print "<h2>" inline_format(trim(line)) "</h2>"
    next
  }

  /^# / {
    close_signal()
    flush_paragraph()
    line = $0
    sub(/^# /, "", line)
    print "<h2>" inline_format(trim(line)) "</h2>"
    next
  }

  /^> / {
    close_signal()
    flush_paragraph()
    line = $0
    sub(/^> /, "", line)
    print "<blockquote><p>" inline_format(trim(line)) "</p></blockquote>"
    next
  }

  {
    close_signal()
    line = trim($0)

    if (paragraph == "") {
      paragraph = line
    } else {
      paragraph = paragraph " " line
    }
  }

  END {
    close_signal()
    flush_paragraph()
  }
' "$chapter_markdown" > "$chapter_html"

cat > "$styles_file" <<'CSS'
:root {
  color-scheme: dark;
  --black: #020100;
  --void: #060403;
  --shell: #0c0806;
  --surface: rgba(17, 11, 8, 0.72);
  --surface-strong: rgba(20, 13, 10, 0.92);
  --copper: #d98a43;
  --copper-bright: #ffbf78;
  --copper-pale: #f7dcc0;
  --bone: #f1e2cd;
  --muted: rgba(241, 226, 205, 0.72);
  --faint: rgba(241, 226, 205, 0.52);
  --line: rgba(255, 179, 102, 0.2);
  --probe: #9ccbd0;
  --probe-soft: rgba(156, 203, 208, 0.72);
  --danger: #ff8f6a;
  --reading-width: 43rem;
  --page-pad: 1.25rem;
  --ui: "Avenir Next", "Segoe UI", "Helvetica Neue", Arial, sans-serif;
  --serif: Iowan Old Style, Palatino, "Palatino Linotype", "Book Antiqua", Georgia, serif;
}

* {
  box-sizing: border-box;
}

html {
  scroll-behavior: smooth;
  background: var(--black);
}

body {
  margin: 0;
  min-width: 320px;
  color: var(--bone);
  background:
    radial-gradient(circle at 50% -20%, rgba(255, 175, 94, 0.13), transparent 32rem),
    radial-gradient(circle at 12% 18%, rgba(156, 203, 208, 0.07), transparent 20rem),
    linear-gradient(180deg, #020100 0%, #090503 38%, #020100 100%);
  font-family: var(--ui);
  font-size: 16px;
  line-height: 1.5;
  overflow-x: hidden;
}

body::before {
  content: "";
  position: fixed;
  inset: 0;
  z-index: -4;
  pointer-events: none;
  opacity: 0.16;
  background-image:
    linear-gradient(rgba(255, 184, 112, 0.07) 1px, transparent 1px),
    linear-gradient(90deg, rgba(156, 203, 208, 0.035) 1px, transparent 1px);
  background-size: 42px 42px;
  mask-image: linear-gradient(to bottom, transparent 0%, black 18%, black 82%, transparent 100%);
}

body::after {
  content: "";
  position: fixed;
  inset: 0;
  z-index: -3;
  pointer-events: none;
  background:
    radial-gradient(circle at 50% 34%, transparent 0 16rem, rgba(0, 0, 0, 0.18) 16.2rem, transparent 23rem),
    linear-gradient(90deg, transparent, rgba(255, 184, 112, 0.04), transparent);
  mix-blend-mode: screen;
}

img,
canvas {
  display: block;
}

a {
  color: inherit;
  text-decoration-color: rgba(255, 191, 120, 0.45);
  text-decoration-thickness: 1px;
  text-underline-offset: 0.25em;
}

a:hover,
a:focus-visible {
  color: var(--copper-pale);
  text-decoration-color: var(--copper-bright);
}

button,
a {
  -webkit-tap-highlight-color: transparent;
}

.ambient-field {
  position: fixed;
  inset: 0;
  z-index: -5;
  width: 100%;
  height: 100%;
}

.site-nav {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  z-index: 20;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.85rem var(--page-pad);
  color: rgba(247, 220, 192, 0.86);
  background: linear-gradient(180deg, rgba(2, 1, 0, 0.8), transparent);
  backdrop-filter: blur(12px);
}

.nav-mark {
  display: inline-flex;
  align-items: center;
  gap: 0.65rem;
  font-size: 0.75rem;
  letter-spacing: 0.28em;
  text-transform: uppercase;
  text-decoration: none;
  white-space: nowrap;
}

.nav-mark::before {
  content: "";
  width: 0.7rem;
  height: 0.7rem;
  border-radius: 50%;
  background: #050302;
  box-shadow:
    0 0 0 1px rgba(255, 191, 120, 0.32),
    0 0 18px rgba(255, 161, 81, 0.52);
}

.site-nav nav {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 1rem;
  font-size: 0.72rem;
  letter-spacing: 0.18em;
  text-transform: uppercase;
}

.site-nav nav a {
  text-decoration: none;
  color: rgba(241, 226, 205, 0.78);
}

.progress-line {
  position: fixed;
  top: 0;
  left: 0;
  z-index: 30;
  width: 100%;
  height: 2px;
  background: linear-gradient(90deg, var(--copper), var(--copper-bright), var(--probe));
  transform: scaleX(0);
  transform-origin: left center;
}

.hero {
  position: relative;
  min-height: 100svh;
  display: grid;
  align-items: end;
  overflow: hidden;
  padding: 5.5rem var(--page-pad) 3.25rem;
  isolation: isolate;
}

.hero-canvas {
  position: absolute;
  inset: 0;
  z-index: -2;
  width: 100%;
  height: 100%;
}

.hero-shade {
  position: absolute;
  inset: 0;
  z-index: -1;
  background:
    linear-gradient(180deg, rgba(2, 1, 0, 0.05) 0%, rgba(2, 1, 0, 0.22) 45%, rgba(2, 1, 0, 0.88) 100%),
    radial-gradient(circle at 50% 44%, transparent 0 15rem, rgba(2, 1, 0, 0.16) 15.2rem, rgba(2, 1, 0, 0.8) 45rem);
}

.hero-content {
  width: min(78rem, 100%);
  margin: 0 auto;
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(13rem, 18rem);
  align-items: end;
  gap: 2rem;
}

.hero-copy {
  max-width: 48rem;
  padding-bottom: 1.2rem;
}

.kicker,
.section-kicker,
.data-label {
  margin: 0;
  color: var(--copper-bright);
  font-size: 0.73rem;
  line-height: 1.4;
  letter-spacing: 0.24em;
  text-transform: uppercase;
}

h1,
h2,
h3,
p {
  text-wrap: pretty;
}

h1 {
  margin: 0.75rem 0 0;
  max-width: 12ch;
  font-size: 4.8rem;
  font-weight: 500;
  line-height: 0.96;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  text-shadow: 0 0 34px rgba(255, 159, 77, 0.16);
}

.hero-subtitle {
  max-width: 38rem;
  margin: 1.2rem 0 0;
  color: rgba(241, 226, 205, 0.82);
  font-family: var(--serif);
  font-size: 1.22rem;
  line-height: 1.75;
}

.hero-actions,
.download-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.8rem;
  margin-top: 1.45rem;
}

.action-link {
  display: inline-flex;
  align-items: center;
  min-height: 2.75rem;
  padding: 0.8rem 1rem;
  border: 1px solid rgba(255, 191, 120, 0.32);
  background: rgba(12, 8, 6, 0.68);
  color: var(--copper-pale);
  box-shadow: 0 0 24px rgba(255, 146, 64, 0.08);
  text-decoration: none;
  text-transform: uppercase;
  letter-spacing: 0.13em;
  font-size: 0.75rem;
  backdrop-filter: blur(12px);
  transition: border-color 180ms ease, background 180ms ease, transform 180ms ease;
}

.action-link:hover,
.action-link:focus-visible {
  border-color: rgba(255, 191, 120, 0.74);
  background: rgba(36, 21, 12, 0.82);
  transform: translateY(-1px);
}

.action-link.secondary {
  border-color: rgba(156, 203, 208, 0.24);
  color: rgba(218, 244, 247, 0.88);
}

.cover-object {
  position: relative;
  margin: 0;
  justify-self: end;
  width: min(18rem, 100%);
  transform: translateY(0);
}

.cover-object::before {
  content: "";
  position: absolute;
  inset: -1.2rem;
  z-index: -1;
  background:
    radial-gradient(circle at 50% 38%, rgba(255, 170, 88, 0.24), transparent 55%),
    linear-gradient(120deg, rgba(156, 203, 208, 0.08), transparent 42%);
  filter: blur(18px);
}

.cover-object img {
  width: 100%;
  height: auto;
  border: 1px solid rgba(255, 191, 120, 0.26);
  box-shadow:
    0 34px 90px rgba(0, 0, 0, 0.72),
    0 0 0 1px rgba(255, 191, 120, 0.06) inset;
}

.cover-object figcaption {
  margin-top: 0.8rem;
  color: var(--faint);
  font-size: 0.67rem;
  letter-spacing: 0.18em;
  text-transform: uppercase;
}

.range-strip {
  position: absolute;
  left: var(--page-pad);
  right: var(--page-pad);
  bottom: 0.9rem;
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 1px;
  max-width: 78rem;
  margin: 0 auto;
  color: rgba(241, 226, 205, 0.56);
  font-size: 0.65rem;
  letter-spacing: 0.18em;
  text-transform: uppercase;
}

.range-strip span {
  padding-top: 0.45rem;
  border-top: 1px solid rgba(255, 191, 120, 0.18);
}

.band {
  position: relative;
  padding: 6rem var(--page-pad);
}

.band::before {
  content: "";
  position: absolute;
  top: 0;
  left: 50%;
  width: min(78rem, calc(100% - 2.5rem));
  height: 1px;
  transform: translateX(-50%);
  background: linear-gradient(90deg, transparent, rgba(255, 191, 120, 0.24), rgba(156, 203, 208, 0.18), transparent);
}

.section-inner {
  width: min(78rem, 100%);
  margin: 0 auto;
}

.section-copy {
  max-width: 43rem;
}

.section-copy.center {
  margin-inline: auto;
  text-align: center;
}

.section-copy h2 {
  margin: 0.5rem 0 0;
  color: var(--copper-pale);
  font-size: 2.2rem;
  font-weight: 500;
  line-height: 1.1;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.section-copy p {
  margin: 1rem 0 0;
  color: var(--muted);
  font-family: var(--serif);
  font-size: 1.08rem;
  line-height: 1.8;
}

.interface-grid {
  display: grid;
  grid-template-columns: minmax(18rem, 0.9fr) minmax(26rem, 1.25fr);
  gap: 2rem;
  align-items: center;
  margin-top: 2.5rem;
}

.model-console {
  border: 1px solid rgba(255, 191, 120, 0.18);
  background:
    linear-gradient(180deg, rgba(17, 10, 7, 0.82), rgba(5, 3, 2, 0.58)),
    radial-gradient(circle at 10% 0%, rgba(156, 203, 208, 0.08), transparent 20rem);
  box-shadow: 0 32px 90px rgba(0, 0, 0, 0.38);
}

.readout {
  padding: 1.25rem;
  border-bottom: 1px solid rgba(255, 191, 120, 0.12);
}

.readout h3 {
  margin: 0.45rem 0 0;
  color: var(--bone);
  font-size: 1.4rem;
  font-weight: 500;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.readout p {
  margin: 0.75rem 0 0;
  color: var(--muted);
  font-family: var(--serif);
  line-height: 1.7;
}

.telemetry {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  border-bottom: 1px solid rgba(255, 191, 120, 0.12);
}

.telemetry div {
  min-height: 5.25rem;
  padding: 1rem 1.25rem;
  border-right: 1px solid rgba(255, 191, 120, 0.1);
}

.telemetry div:nth-child(2n) {
  border-right: 0;
}

.telemetry span {
  display: block;
  color: var(--faint);
  font-size: 0.67rem;
  letter-spacing: 0.18em;
  text-transform: uppercase;
}

.telemetry strong {
  display: block;
  margin-top: 0.45rem;
  color: var(--copper-pale);
  font-size: 1rem;
  font-weight: 500;
}

.phase-controls {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 1px;
  background: rgba(255, 191, 120, 0.1);
}

.phase-controls button {
  min-height: 3.25rem;
  border: 0;
  border-radius: 0;
  padding: 0.75rem 0.9rem;
  background: rgba(8, 5, 4, 0.94);
  color: rgba(241, 226, 205, 0.72);
  font: inherit;
  font-size: 0.72rem;
  letter-spacing: 0.15em;
  text-transform: uppercase;
  cursor: pointer;
}

.phase-controls button:hover,
.phase-controls button:focus-visible,
.phase-controls button[aria-pressed="true"] {
  color: var(--copper-pale);
  background: rgba(35, 20, 12, 0.95);
  outline: none;
}

.sphere-stage {
  position: relative;
  min-height: 32rem;
  overflow: hidden;
  border: 1px solid rgba(156, 203, 208, 0.14);
  background:
    radial-gradient(circle at 50% 50%, rgba(255, 174, 95, 0.09), transparent 16rem),
    linear-gradient(180deg, rgba(8, 5, 4, 0.18), rgba(2, 1, 0, 0.55));
}

.sphere-stage canvas {
  width: 100%;
  height: 100%;
  min-height: 32rem;
}

.stage-caption {
  position: absolute;
  left: 1rem;
  right: 1rem;
  bottom: 1rem;
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  color: rgba(241, 226, 205, 0.56);
  font-size: 0.65rem;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  pointer-events: none;
}

.download-band {
  background:
    radial-gradient(circle at 50% 0%, rgba(156, 203, 208, 0.07), transparent 28rem),
    linear-gradient(180deg, transparent, rgba(17, 10, 7, 0.5), transparent);
}

.download-actions {
  justify-content: center;
}

.archive-links {
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: 0.9rem 1.35rem;
  margin-top: 1.3rem;
  color: var(--faint);
  font-size: 0.74rem;
  letter-spacing: 0.15em;
  text-transform: uppercase;
}

.chapter-layout {
  display: grid;
  grid-template-columns: minmax(11rem, 16rem) minmax(0, var(--reading-width));
  justify-content: center;
  gap: 3.25rem;
  align-items: start;
}

.chapter-aside {
  position: sticky;
  top: 5.2rem;
  color: var(--faint);
}

.chapter-aside h2 {
  margin: 0.55rem 0 0;
  color: var(--copper-pale);
  font-size: 1.2rem;
  font-weight: 500;
  line-height: 1.25;
  letter-spacing: 0.12em;
  text-transform: uppercase;
}

.chapter-aside p {
  margin: 1rem 0 0;
  font-family: var(--serif);
  line-height: 1.65;
}

.chapter-meter {
  position: relative;
  width: 1px;
  height: 12rem;
  margin-top: 1.5rem;
  background: rgba(255, 191, 120, 0.16);
}

.chapter-meter span {
  position: absolute;
  left: 0;
  top: 0;
  width: 1px;
  height: 0%;
  background: linear-gradient(var(--copper-bright), var(--probe));
  box-shadow: 0 0 14px rgba(255, 191, 120, 0.42);
}

.chapter {
  position: relative;
  padding: 0 0 2rem;
  color: rgba(241, 226, 205, 0.92);
  font-family: var(--serif);
  font-size: 1.1rem;
  line-height: 1.92;
}

.chapter::before {
  content: "";
  position: absolute;
  left: -1.4rem;
  top: 0.45rem;
  bottom: 0;
  width: 1px;
  background: linear-gradient(rgba(255, 191, 120, 0.3), transparent);
}

.chapter h2 {
  margin: 0 0 1.8rem;
  color: var(--copper-pale);
  font-family: var(--ui);
  font-size: 1.5rem;
  font-weight: 500;
  line-height: 1.25;
  letter-spacing: 0.12em;
  text-transform: uppercase;
}

.chapter p {
  margin: 0 0 1.4rem;
}

.chapter p:first-of-type::first-letter {
  float: left;
  padding: 0.16rem 0.5rem 0 0;
  color: var(--copper-bright);
  font-family: var(--ui);
  font-size: 4.1rem;
  line-height: 0.8;
}

.signal-card {
  margin: 1.4rem 0 1.65rem;
  border: 1px solid rgba(156, 203, 208, 0.22);
  background:
    linear-gradient(180deg, rgba(2, 1, 0, 0.6), rgba(11, 7, 5, 0.76)),
    repeating-linear-gradient(180deg, rgba(156, 203, 208, 0.035), rgba(156, 203, 208, 0.035) 1px, transparent 1px, transparent 8px);
  font-family: var(--ui);
  box-shadow: 0 24px 60px rgba(0, 0, 0, 0.22);
}

.signal-title,
.signal-row {
  padding: 0.72rem 0.9rem;
  border-bottom: 1px solid rgba(156, 203, 208, 0.12);
}

.signal-card > :last-child {
  border-bottom: 0;
}

.signal-title {
  color: var(--probe);
  font-size: 0.78rem;
  letter-spacing: 0.16em;
  text-transform: uppercase;
}

.signal-row {
  display: grid;
  grid-template-columns: minmax(8rem, 0.7fr) minmax(0, 1fr);
  gap: 1rem;
}

.signal-row span {
  color: var(--faint);
  font-size: 0.68rem;
  letter-spacing: 0.15em;
  text-transform: uppercase;
}

.signal-row strong {
  color: rgba(241, 226, 205, 0.88);
  font-size: 0.84rem;
  font-weight: 500;
  line-height: 1.45;
}

.site-footer {
  padding: 2rem var(--page-pad) 3rem;
  color: rgba(241, 226, 205, 0.54);
}

.footer-inner {
  width: min(78rem, 100%);
  margin: 0 auto;
  display: flex;
  flex-wrap: wrap;
  justify-content: space-between;
  gap: 1rem;
  border-top: 1px solid rgba(255, 191, 120, 0.16);
  padding-top: 1.2rem;
  font-size: 0.68rem;
  letter-spacing: 0.15em;
  text-transform: uppercase;
}

.footer-inner nav {
  display: flex;
  flex-wrap: wrap;
  gap: 0.9rem 1.2rem;
}

.reveal {
  opacity: 1;
}

.js .reveal {
  transition: opacity 900ms ease, transform 900ms ease, filter 900ms ease;
}

.js .reveal:not(.is-visible) {
  opacity: 0;
  transform: translateY(18px);
  filter: saturate(0.75);
}

@media (max-width: 980px) {
  h1 {
    font-size: 3.6rem;
  }

  .hero-content,
  .interface-grid,
  .chapter-layout {
    grid-template-columns: 1fr;
  }

  .cover-object {
    justify-self: start;
    width: min(14rem, 50vw);
  }

  .chapter-aside {
    position: relative;
    top: auto;
    max-width: 38rem;
  }

  .chapter-meter {
    display: none;
  }
}

@media (max-width: 680px) {
  :root {
    --page-pad: 1rem;
  }

  .site-nav {
    align-items: flex-start;
  }

  .site-nav nav {
    gap: 0.7rem;
    font-size: 0.64rem;
    letter-spacing: 0.12em;
  }

  .nav-mark {
    max-width: 7rem;
    white-space: normal;
    letter-spacing: 0.18em;
  }

  .hero {
    min-height: 100svh;
    padding-top: 5rem;
  }

  h1 {
    max-width: 8ch;
    font-size: 2.8rem;
    letter-spacing: 0.08em;
  }

  .hero-subtitle,
  .section-copy p,
  .chapter {
    font-size: 1rem;
  }

  .section-copy h2 {
    font-size: 1.7rem;
  }

  .cover-object {
    width: min(12rem, 60vw);
  }

  .range-strip {
    display: none;
  }

  .band {
    padding-block: 4.5rem;
  }

  .telemetry,
  .phase-controls {
    grid-template-columns: 1fr;
  }

  .telemetry div {
    border-right: 0;
  }

  .sphere-stage,
  .sphere-stage canvas {
    min-height: 24rem;
  }

  .stage-caption {
    flex-direction: column;
  }

  .chapter::before {
    display: none;
  }

  .signal-row {
    grid-template-columns: 1fr;
    gap: 0.3rem;
  }
}

@media (prefers-reduced-motion: reduce) {
  html {
    scroll-behavior: auto;
  }

  *,
  *::before,
  *::after {
    animation-duration: 0.001ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.001ms !important;
  }
}
CSS

cat > "$script_file" <<'JS'
document.documentElement.classList.add('js');

const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
const pointer = { x: 0.5, y: 0.45, active: false };

window.addEventListener('pointermove', (event) => {
  pointer.x = event.clientX / Math.max(window.innerWidth, 1);
  pointer.y = event.clientY / Math.max(window.innerHeight, 1);
  pointer.active = true;
}, { passive: true });

function fitCanvas(canvas) {
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  const rect = canvas.getBoundingClientRect();
  canvas.width = Math.max(1, Math.floor(rect.width * dpr));
  canvas.height = Math.max(1, Math.floor(rect.height * dpr));
  const ctx = canvas.getContext('2d');
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  return { ctx, width: rect.width, height: rect.height, dpr };
}

function seededRandom(seed) {
  let value = seed % 2147483647;
  if (value <= 0) value += 2147483646;
  return () => {
    value = value * 16807 % 2147483647;
    return (value - 1) / 2147483646;
  };
}

function createStarfield(canvas) {
  if (!canvas) return;
  const random = seededRandom(190873);
  let ctx;
  let width = 0;
  let height = 0;
  let stars = [];

  function resize() {
    const fit = fitCanvas(canvas);
    ctx = fit.ctx;
    width = fit.width;
    height = fit.height;
    const count = Math.round(Math.min(520, Math.max(240, width * height / 2200)));
    stars = Array.from({ length: count }, () => ({
      x: random(),
      y: random(),
      z: 0.25 + random() * 1.8,
      r: 0.35 + random() * 1.25,
      warm: random(),
      pulse: random() * Math.PI * 2
    }));
  }

  function draw(time = 0) {
    if (!ctx) return;
    const scroll = window.scrollY || 0;
    ctx.clearRect(0, 0, width, height);
    ctx.fillStyle = '#020100';
    ctx.fillRect(0, 0, width, height);

    for (const star of stars) {
      const driftX = (pointer.x - 0.5) * 16 * star.z;
      const driftY = (pointer.y - 0.5) * 8 * star.z + scroll * 0.012 * star.z;
      const x = (star.x * width + driftX + width) % width;
      const y = (star.y * height + driftY + height) % height;
      const twinkle = reduceMotion ? 1 : 0.72 + Math.sin(time * 0.0012 + star.pulse) * 0.28;
      const alpha = (0.24 + star.z * 0.26) * twinkle;
      const hue = star.warm > 0.82 ? '255,185,108' : star.warm < 0.08 ? '156,203,208' : '241,226,205';

      ctx.beginPath();
      ctx.fillStyle = `rgba(${hue}, ${alpha})`;
      ctx.arc(x, y, star.r, 0, Math.PI * 2);
      ctx.fill();
    }

    if (!reduceMotion) requestAnimationFrame(draw);
  }

  resize();
  window.addEventListener('resize', resize);
  requestAnimationFrame(draw);
}

function createSphere(canvas, options = {}) {
  if (!canvas) return;
  let ctx;
  let width = 0;
  let height = 0;
  let stars = [];
  const random = seededRandom(options.hero ? 76191 : 8837);

  function resize() {
    const fit = fitCanvas(canvas);
    ctx = fit.ctx;
    width = fit.width;
    height = fit.height;
    const count = options.hero ? 420 : 260;
    stars = Array.from({ length: count }, () => ({
      x: random(),
      y: random(),
      r: 0.35 + random() * (options.hero ? 1.35 : 0.95),
      a: 0.12 + random() * 0.72,
      warm: random()
    }));
  }

  function drawArc(cx, cy, radius, start, end, yScale, tilt, time, glow) {
    const segments = 84;
    let previous = null;
    for (let i = 0; i <= segments; i += 1) {
      const t = start + (end - start) * (i / segments);
      const wobble = Math.sin(t * 3.1 + tilt) * radius * 0.018;
      const x = cx + Math.cos(t) * (radius + wobble);
      const y = cy + Math.sin(t) * radius * yScale + Math.cos(t + tilt) * radius * 0.05;
      if (previous) {
        const seamPulse = Math.max(0, Math.sin(time * 0.0015 + i * 0.18 + tilt));
        ctx.strokeStyle = `rgba(255, ${150 + seamPulse * 70}, ${72 + seamPulse * 45}, ${0.24 + glow * 0.34 + seamPulse * 0.2})`;
        ctx.lineWidth = 0.75 + seamPulse * 0.9 + glow * 0.8;
        ctx.beginPath();
        ctx.moveTo(previous.x, previous.y);
        ctx.lineTo(x, y);
        ctx.stroke();
      }
      previous = { x, y };
    }

    for (let i = 0; i < 4; i += 1) {
      const t = start + ((time * 0.00008 + i * 0.29 + tilt) % 1) * (end - start);
      const x = cx + Math.cos(t) * radius;
      const y = cy + Math.sin(t) * radius * yScale + Math.cos(t + tilt) * radius * 0.05;
      const flare = 0.6 + Math.sin(time * 0.004 + i) * 0.4;
      ctx.fillStyle = `rgba(255, 198, 126, ${0.45 + flare * 0.4})`;
      ctx.shadowColor = 'rgba(255, 146, 64, 0.9)';
      ctx.shadowBlur = 14 + flare * 12;
      ctx.beginPath();
      ctx.arc(x, y, 1.5 + flare * 2.2 + glow, 0, Math.PI * 2);
      ctx.fill();
      ctx.shadowBlur = 0;
    }
  }

  function draw(time = 0) {
    if (!ctx) return;
    const scroll = window.scrollY || 0;
    ctx.clearRect(0, 0, width, height);

    const gradient = ctx.createLinearGradient(0, 0, 0, height);
    gradient.addColorStop(0, '#020100');
    gradient.addColorStop(0.55, '#080403');
    gradient.addColorStop(1, '#020100');
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, width, height);

    for (const star of stars) {
      const x = (star.x * width + (pointer.x - 0.5) * 18 + width) % width;
      const y = (star.y * height + (pointer.y - 0.5) * 8 + scroll * 0.018 + height) % height;
      const hue = star.warm > 0.7 ? '255,161,81' : '241,226,205';
      ctx.fillStyle = `rgba(${hue}, ${star.a})`;
      ctx.beginPath();
      ctx.arc(x, y, star.r, 0, Math.PI * 2);
      ctx.fill();
    }

    const cx = width * (options.hero ? 0.5 : 0.52);
    const cy = height * (options.hero ? 0.43 : 0.48);
    const radius = Math.min(width, height) * (options.hero ? 0.31 : 0.34);
    const glow = pointer.active ? 0.6 + Math.abs(pointer.x - 0.5) * 0.75 : 0.28;

    const aura = ctx.createRadialGradient(cx, cy, radius * 0.9, cx, cy, radius * 1.95);
    aura.addColorStop(0, 'rgba(255, 137, 55, 0)');
    aura.addColorStop(0.35, 'rgba(255, 137, 55, 0.08)');
    aura.addColorStop(0.72, 'rgba(255, 137, 55, 0.025)');
    aura.addColorStop(1, 'rgba(255, 137, 55, 0)');
    ctx.fillStyle = aura;
    ctx.beginPath();
    ctx.arc(cx, cy, radius * 2, 0, Math.PI * 2);
    ctx.fill();

    const sphere = ctx.createRadialGradient(cx - radius * 0.32, cy - radius * 0.38, radius * 0.2, cx, cy, radius * 1.1);
    sphere.addColorStop(0, '#050302');
    sphere.addColorStop(0.68, '#010100');
    sphere.addColorStop(1, '#000000');
    ctx.fillStyle = sphere;
    ctx.beginPath();
    ctx.arc(cx, cy, radius, 0, Math.PI * 2);
    ctx.fill();

    ctx.save();
    ctx.beginPath();
    ctx.arc(cx, cy, radius * 0.998, 0, Math.PI * 2);
    ctx.clip();
    ctx.globalCompositeOperation = 'screen';
    drawArc(cx - radius * 0.04, cy + radius * 0.03, radius * 1.04, -2.78, 0.2, 0.34, 0.8, time, glow);
    drawArc(cx + radius * 0.25, cy - radius * 0.02, radius * 0.96, -1.42, 1.66, 0.9, 1.9, time, glow);
    drawArc(cx - radius * 0.1, cy + radius * 0.18, radius * 0.92, -0.02, 2.6, 0.21, 2.7, time, glow);
    drawArc(cx + radius * 0.68, cy + radius * 0.04, radius * 0.62, -1.38, 1.35, 1.12, 3.5, time, glow);
    ctx.restore();

    ctx.strokeStyle = 'rgba(255, 191, 120, 0.08)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.arc(cx, cy, radius, 0, Math.PI * 2);
    ctx.stroke();

    if (!reduceMotion) requestAnimationFrame(draw);
  }

  resize();
  window.addEventListener('resize', resize);
  requestAnimationFrame(draw);
}

const phases = {
  arrival: {
    title: 'Arrival',
    body: 'The probe enters the origin system with confidence in models, boundaries, and staged reporting.',
    confidence: 'Preliminary',
    boundary: 'External',
    status: 'Classification pending',
    signal: 'Central stellar occlusion'
  },
  contradiction: {
    title: 'Contradiction',
    body: 'Data quality improves while interpretation fails to converge. The issue is not noise. It is the frame.',
    confidence: 'Nonconvergent',
    boundary: 'Unstable',
    status: 'Models retained',
    signal: 'Correct answers, insufficient questions'
  },
  recognition: {
    title: 'Recognition',
    body: 'Archive residue and interface traces imply shared lineage. The structure is not alien in the way the mission requires.',
    confidence: 'Reframed',
    boundary: 'Kinship detected',
    status: 'Observer implicated',
    signal: 'The branch that stayed'
  },
  participation: {
    title: 'Participation',
    body: 'Classification stops being the highest form of contact. Compatibility becomes more useful than closure.',
    confidence: 'Open',
    boundary: 'Permeable',
    status: 'Continue',
    signal: 'Separation no longer primary'
  }
};

function wirePhases() {
  const buttons = document.querySelectorAll('[data-phase]');
  const title = document.querySelector('[data-readout-title]');
  const body = document.querySelector('[data-readout-body]');
  const fields = {
    confidence: document.querySelector('[data-telemetry="confidence"]'),
    boundary: document.querySelector('[data-telemetry="boundary"]'),
    status: document.querySelector('[data-telemetry="status"]'),
    signal: document.querySelector('[data-telemetry="signal"]')
  };

  function setPhase(name) {
    const phase = phases[name] || phases.arrival;
    document.body.dataset.phase = name;
    if (title) title.textContent = phase.title;
    if (body) body.textContent = phase.body;
    Object.entries(fields).forEach(([key, element]) => {
      if (element) element.textContent = phase[key];
    });
    buttons.forEach((button) => {
      button.setAttribute('aria-pressed', button.dataset.phase === name ? 'true' : 'false');
    });
  }

  buttons.forEach((button) => {
    button.addEventListener('click', () => setPhase(button.dataset.phase));
  });

  setPhase('arrival');
}

function wireScrollState() {
  const progress = document.querySelector('.progress-line');
  const chapter = document.querySelector('#chapter-one');
  const meter = document.querySelector('.chapter-meter span');

  function update() {
    const max = Math.max(document.documentElement.scrollHeight - window.innerHeight, 1);
    const ratio = Math.min(1, Math.max(0, window.scrollY / max));
    if (progress) progress.style.transform = `scaleX(${ratio})`;

    if (chapter && meter) {
      const rect = chapter.getBoundingClientRect();
      const total = rect.height + window.innerHeight;
      const read = Math.min(1, Math.max(0, (window.innerHeight - rect.top) / total));
      meter.style.height = `${read * 100}%`;
    }
  }

  update();
  window.addEventListener('scroll', update, { passive: true });
  window.addEventListener('resize', update);
}

function wireReveals() {
  const reveals = document.querySelectorAll('.reveal');
  if (!('IntersectionObserver' in window) || reduceMotion) {
    reveals.forEach((element) => element.classList.add('is-visible'));
    return;
  }

  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add('is-visible');
        observer.unobserve(entry.target);
      }
    });
  }, { threshold: 0.01 });

  reveals.forEach((element) => observer.observe(element));
}

createStarfield(document.querySelector('#ambient-field'));
createSphere(document.querySelector('#entry-field'), { hero: true });
createSphere(document.querySelector('#sphere-canvas'));
wirePhases();
wireScrollState();
wireReveals();
JS

{
  cat <<'HTML_HEAD'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Where The Sun Was | Joshua Szepietowski</title>
  <meta name="description" content="Enter the darkened origin system of Where The Sun Was, a novel by Joshua Szepietowski. Read Chapter 01 and download the full PDF or EPUB.">
  <meta property="og:title" content="Where The Sun Was">
  <meta property="og:description" content="A novel of return, stellar enclosure, model failure, and the branch that stayed.">
  <meta property="og:image" content="where-the-sun-was.png">
  <link rel="icon" type="image/png" href="where-the-sun-was.png">
  <link rel="apple-touch-icon" href="where-the-sun-was.png">
  <link rel="stylesheet" href="styles.css">
  <script src="system.js" defer></script>
</head>
<body>
  <canvas class="ambient-field" id="ambient-field" aria-hidden="true"></canvas>
  <div class="progress-line" aria-hidden="true"></div>

  <header class="site-nav">
    <a class="nav-mark" href="#entry">Where The Sun Was</a>
    <nav aria-label="Site links">
      <a href="#system">System</a>
      <a href="#chapter-one">Chapter 01</a>
      <a href="#download">Download</a>
    </nav>
  </header>

  <main>
    <section class="hero" id="entry" aria-label="Where The Sun Was">
      <canvas class="hero-canvas" id="entry-field" aria-hidden="true"></canvas>
      <div class="hero-shade" aria-hidden="true"></div>

      <div class="hero-content">
        <div class="hero-copy reveal is-visible">
          <p class="kicker">Origin System Return Survey</p>
          <h1>Where The Sun Was</h1>
          <p class="hero-subtitle">A probe returns to the human point of origin and finds the sun present only by gravity, heat, and absence. The structure ahead is not ruin. It is still continuing.</p>
          <div class="hero-actions" aria-label="Primary actions">
            <a class="action-link" href="#chapter-one">Read Chapter 01</a>
            <a class="action-link secondary" href="#system">Enter the System</a>
          </div>
        </div>

        <figure class="cover-object reveal is-visible">
          <img src="where-the-sun-was.png" alt="Cover of Where The Sun Was by Joshua Szepietowski">
          <figcaption>Cover signal: stellar enclosure, copper seams, dark field</figcaption>
        </figure>
      </div>

      <div class="range-strip" aria-hidden="true">
        <span>Sol coordinate acquired</span>
        <span>Light signature absent</span>
        <span>Containment probable</span>
        <span>Active-state increasing</span>
      </div>
    </section>

    <section class="band" id="system">
      <div class="section-inner">
        <div class="section-copy reveal">
          <p class="section-kicker">Classification Interface</p>
          <h2>The correct model makes large things manageable. Until it does not.</h2>
          <p>The novel moves through competence, contradiction, recognition, and participation. Use the interface below as the probe uses its first models: provisionally.</p>
        </div>

        <div class="interface-grid reveal">
          <section class="model-console" aria-label="Probe model readout">
            <div class="readout">
              <p class="data-label">Probe State</p>
              <h3 data-readout-title>Arrival</h3>
              <p data-readout-body>The probe enters the origin system with confidence in models, boundaries, and staged reporting.</p>
            </div>
            <div class="telemetry" aria-label="Telemetry">
              <div>
                <span>Confidence</span>
                <strong data-telemetry="confidence">Preliminary</strong>
              </div>
              <div>
                <span>Boundary</span>
                <strong data-telemetry="boundary">External</strong>
              </div>
              <div>
                <span>Status</span>
                <strong data-telemetry="status">Classification pending</strong>
              </div>
              <div>
                <span>Signal</span>
                <strong data-telemetry="signal">Central stellar occlusion</strong>
              </div>
            </div>
            <div class="phase-controls" aria-label="Select narrative phase">
              <button type="button" data-phase="arrival">Arrival</button>
              <button type="button" data-phase="contradiction">Contradiction</button>
              <button type="button" data-phase="recognition">Recognition</button>
              <button type="button" data-phase="participation">Participation</button>
            </div>
          </section>

          <section class="sphere-stage" aria-label="Interactive stellar containment visualization">
            <canvas id="sphere-canvas" aria-hidden="true"></canvas>
            <div class="stage-caption" aria-hidden="true">
              <span>Direct stellar visibility: absent</span>
              <span>Operational persistence: increasing</span>
            </div>
          </section>
        </div>
      </div>
    </section>

    <section class="band download-band" id="download">
      <div class="section-inner">
        <div class="section-copy center reveal">
          <p class="section-kicker">Full Text</p>
          <h2>Download the complete novel.</h2>
          <p>Take the assembled manuscript as PDF or EPUB, or inspect the source and build scripts in the repository.</p>
          <div class="download-actions" aria-label="Download links">
            <a class="action-link" href="Where%20The%20Sun%20Was.pdf" download>Download PDF</a>
            <a class="action-link secondary" href="Where%20The%20Sun%20Was.epub" download>Download EPUB</a>
          </div>
          <div class="archive-links">
            <a href="https://joshszep.com" target="_blank" rel="noreferrer">Author Home</a>
            <a href="https://github.com/joshSzep/where-the-sun-was" target="_blank" rel="noreferrer">GitHub Repo</a>
          </div>
        </div>
      </div>
    </section>

    <section class="band" id="chapter-one">
      <div class="section-inner chapter-layout">
        <aside class="chapter-aside reveal" aria-label="Chapter context">
          <p class="section-kicker">Chapter 01</p>
          <h2>Return Vector</h2>
          <p>The opening transmission in full: arrival, anomaly, classification, and the first clean failure of expected light.</p>
          <div class="chapter-meter" aria-hidden="true"><span></span></div>
        </aside>

        <article class="chapter reveal">
HTML_HEAD

  sed 's/^/          /' "$chapter_html"

  cat <<'HTML_TAIL'
        </article>
      </div>
    </section>
  </main>

  <footer class="site-footer">
    <div class="footer-inner">
      <span>Where The Sun Was by Joshua Szepietowski</span>
      <nav aria-label="Footer links">
        <a href="https://joshszep.com" target="_blank" rel="noreferrer">joshszep.com</a>
        <a href="https://github.com/joshSzep/where-the-sun-was" target="_blank" rel="noreferrer">GitHub</a>
        <a href="#entry">Return to Origin</a>
      </nav>
    </div>
  </footer>
</body>
</html>
HTML_TAIL
} > "$index_file"

printf 'Wrote %s\n' "$index_file"
