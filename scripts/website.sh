#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)

source_markdown="$repo_root/Where The Sun Was.md"
cover_image="$repo_root/where-the-sun-was.png"
pdf_file="$repo_root/Where The Sun Was.pdf"
website_dir="$repo_root/website"
website_cover="$website_dir/where-the-sun-was.png"
website_pdf="$website_dir/Where The Sun Was.pdf"
index_file="$website_dir/index.html"

for required_file in "$source_markdown" "$cover_image" "$pdf_file"; do
  if [[ ! -f "$required_file" ]]; then
    printf 'Missing required file: %s\n' "$required_file" >&2
    exit 1
  fi
done

rm -rf "$website_dir"
mkdir -p "$website_dir"

cp "$cover_image" "$website_cover"
cp "$pdf_file" "$website_pdf"

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

  BEGIN {
    paragraph = ""
  }

  /^[[:space:]]*$/ {
    flush_paragraph()
    next
  }

  /^### / {
    flush_paragraph()
    line = $0
    sub(/^### /, "", line)
    print "<h2>" inline_format(trim(line)) "</h2>"
    next
  }

  /^## / {
    flush_paragraph()
    line = $0
    sub(/^## /, "", line)
    print "<h1>" inline_format(trim(line)) "</h1>"
    next
  }

  /^# / {
    flush_paragraph()
    line = $0
    sub(/^# /, "", line)
    print "<h1>" inline_format(trim(line)) "</h1>"
    next
  }

  /^> / {
    flush_paragraph()
    line = $0
    sub(/^> /, "", line)
    print "<blockquote><p>" inline_format(trim(line)) "</p></blockquote>"
    next
  }

  {
    line = trim($0)

    if (paragraph == "") {
      paragraph = line
    } else {
      paragraph = paragraph " " line
    }
  }

  END {
    flush_paragraph()
  }
' "$chapter_markdown" > "$chapter_html"

{
  cat <<'HTML_HEAD'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Where The Sun Was</title>
  <meta name="description" content="A quiet transmission from a darkened origin system. Read the first chapter of Where The Sun Was by Joshua Szepietowski.">
  <style>
    :root {
      --bg: #050404;
      --bg-soft: #0d0907;
      --panel: rgba(17, 12, 10, 0.64);
      --panel-strong: rgba(20, 14, 11, 0.82);
      --text: #efe5d3;
      --text-soft: rgba(239, 229, 211, 0.76);
      --line: rgba(230, 174, 106, 0.22);
      --gold: #e2b06f;
      --gold-bright: #ffd7a3;
      --shadow: rgba(0, 0, 0, 0.5);
      --reading-width: min(42rem, calc(100vw - 2.5rem));
      --ui-font: "Avenir Next", "Segoe UI", "Helvetica Neue", Helvetica, Arial, sans-serif;
      --reading-font: Iowan Old Style, Palatino, "Palatino Linotype", "Book Antiqua", Georgia, serif;
    }

    * {
      box-sizing: border-box;
    }

    html {
      scroll-behavior: smooth;
    }

    body {
      margin: 0;
      min-height: 100vh;
      color: var(--text);
      background:
        radial-gradient(circle at top, rgba(225, 168, 92, 0.14), transparent 36%),
        radial-gradient(circle at 20% 20%, rgba(255, 212, 153, 0.05), transparent 22%),
        linear-gradient(180deg, #040303 0%, #090605 32%, #050404 100%);
      font-family: var(--ui-font);
      overflow-x: hidden;
    }

    body::before {
      content: "";
      position: fixed;
      inset: 0;
      pointer-events: none;
      opacity: 0.08;
      background-image:
        linear-gradient(rgba(255, 208, 147, 0.06) 1px, transparent 1px),
        linear-gradient(90deg, rgba(255, 208, 147, 0.04) 1px, transparent 1px);
      background-size: 3px 3px, 3px 3px;
      mix-blend-mode: screen;
    }

    a {
      color: inherit;
      text-decoration-color: rgba(226, 176, 111, 0.5);
      text-underline-offset: 0.22em;
    }

    a:hover {
      text-decoration-color: rgba(255, 215, 163, 0.92);
    }

    #starfield {
      position: fixed;
      inset: 0;
      width: 100%;
      height: 100%;
      z-index: -3;
      opacity: 0.9;
    }

    .aura {
      position: fixed;
      inset: -10vh -10vw auto;
      height: 60vh;
      background: radial-gradient(circle at 50% 0%, rgba(255, 198, 126, 0.18), rgba(255, 198, 126, 0.02) 36%, transparent 68%);
      filter: blur(24px);
      z-index: -2;
      pointer-events: none;
      transform: translateY(calc(var(--scroll, 0px) * 0.08));
    }

    .page {
      position: relative;
      z-index: 1;
    }

    .hero {
      min-height: 100vh;
      display: grid;
      place-items: center;
      padding: 3rem 1.25rem 4rem;
    }

    .hero-inner {
      width: min(72rem, 100%);
      display: grid;
      gap: 1.75rem;
      justify-items: center;
      text-align: center;
    }

    .eyebrow {
      margin: 0;
      letter-spacing: 0.36em;
      text-transform: uppercase;
      font-size: 0.76rem;
      color: var(--text-soft);
      opacity: 0.86;
    }

    .cover-frame {
      position: relative;
      width: min(28rem, 78vw);
      border-radius: 1.25rem;
      overflow: hidden;
      box-shadow:
        0 28px 80px rgba(0, 0, 0, 0.66),
        0 0 0 1px rgba(226, 176, 111, 0.14);
      transform: translateY(calc(var(--scroll, 0px) * -0.02));
      animation: drift 13s ease-in-out infinite;
      background: rgba(0, 0, 0, 0.25);
    }

    .cover-frame::before {
      content: "";
      position: absolute;
      inset: -18%;
      background: radial-gradient(circle, rgba(255, 201, 129, 0.18), transparent 55%);
      pointer-events: none;
      filter: blur(28px);
    }

    .cover-frame img {
      position: relative;
      display: block;
      width: 100%;
      height: auto;
    }

    .title-block {
      display: grid;
      gap: 0.6rem;
      align-items: center;
      justify-items: center;
    }

    .title-block h1 {
      margin: 0;
      font-size: clamp(2.35rem, 5.6vw, 5.4rem);
      font-weight: 500;
      letter-spacing: 0.14em;
      text-transform: uppercase;
      line-height: 0.96;
      text-wrap: balance;
    }

    .title-block p {
      margin: 0;
      color: var(--text-soft);
      font-size: clamp(0.9rem, 1.5vw, 1.1rem);
      letter-spacing: 0.2em;
      text-transform: uppercase;
    }

    .transmission {
      width: min(38rem, calc(100vw - 3rem));
      padding: 1rem 1.2rem;
      border: 1px solid var(--line);
      border-radius: 999px;
      background: linear-gradient(180deg, rgba(20, 15, 12, 0.58), rgba(12, 9, 8, 0.36));
      color: var(--text-soft);
      font-size: 0.92rem;
      letter-spacing: 0.03em;
      line-height: 1.8;
      backdrop-filter: blur(8px);
    }

    .hero-links {
      display: flex;
      flex-wrap: wrap;
      justify-content: center;
      gap: 1rem 1.5rem;
      font-size: 0.82rem;
      letter-spacing: 0.18em;
      text-transform: uppercase;
      color: var(--text-soft);
    }

    .section {
      width: min(76rem, 100%);
      margin: 0 auto;
      padding: 0 1.25rem 5rem;
    }

    .section-heading {
      display: grid;
      gap: 0.55rem;
      justify-items: center;
      text-align: center;
      margin-bottom: 2.2rem;
    }

    .section-heading span {
      text-transform: uppercase;
      letter-spacing: 0.28em;
      font-size: 0.72rem;
      color: var(--gold);
    }

    .section-heading h2 {
      margin: 0;
      font-size: clamp(1.5rem, 3vw, 2.4rem);
      font-weight: 500;
      letter-spacing: 0.08em;
      text-transform: uppercase;
    }

    .section-heading p {
      margin: 0;
      width: min(32rem, 100%);
      color: var(--text-soft);
      line-height: 1.75;
    }

    .reading-shell {
      position: relative;
      padding: 2.75rem 1.35rem;
      border: 1px solid rgba(226, 176, 111, 0.16);
      border-radius: 1.75rem;
      background:
        linear-gradient(180deg, rgba(18, 12, 10, 0.78), rgba(11, 8, 7, 0.58)),
        radial-gradient(circle at top, rgba(255, 214, 159, 0.05), transparent 45%);
      box-shadow: 0 32px 70px rgba(0, 0, 0, 0.34);
      overflow: hidden;
    }

    .reading-shell::before {
      content: "";
      position: absolute;
      inset: 0;
      background: linear-gradient(180deg, rgba(255, 216, 165, 0.02), transparent 22%, transparent 78%, rgba(255, 216, 165, 0.03));
      pointer-events: none;
    }

    .reading-column {
      position: relative;
      width: var(--reading-width);
      margin: 0 auto;
      font-family: var(--reading-font);
      color: rgba(246, 235, 219, 0.92);
      font-size: clamp(1.04rem, 1.24vw, 1.16rem);
      line-height: 1.9;
    }

    .reading-column h1,
    .reading-column h2,
    .reading-column h3,
    .reading-column h4 {
      font-family: var(--ui-font);
      font-weight: 500;
      letter-spacing: 0.12em;
      text-transform: uppercase;
      line-height: 1.2;
      color: var(--gold-bright);
    }

    .reading-column h1,
    .reading-column h2 {
      margin: 0 0 1.6rem;
      font-size: clamp(1.28rem, 2vw, 1.7rem);
    }

    .reading-column p {
      margin: 0 0 1.35rem;
      text-wrap: pretty;
    }

    .reading-column strong {
      color: var(--gold-bright);
      font-weight: 600;
    }

    .reading-column em {
      color: rgba(255, 227, 191, 0.96);
    }

    .download {
      padding-top: 1rem;
    }

    .download-card {
      width: min(42rem, 100%);
      margin: 0 auto;
      padding: 1.5rem 1.4rem;
      border-radius: 1.4rem;
      border: 1px solid rgba(226, 176, 111, 0.17);
      background: linear-gradient(180deg, rgba(16, 11, 9, 0.78), rgba(10, 8, 7, 0.54));
      text-align: center;
      box-shadow: 0 20px 60px rgba(0, 0, 0, 0.28);
    }

    .download-card p {
      margin: 0;
      color: var(--text-soft);
      line-height: 1.8;
    }

    .download-card a {
      display: inline-block;
      margin-top: 0.9rem;
      font-size: 0.95rem;
      letter-spacing: 0.16em;
      text-transform: uppercase;
      color: var(--gold-bright);
    }

    footer {
      padding: 1.5rem 1.25rem 3rem;
    }

    .footer-inner {
      width: min(74rem, 100%);
      margin: 0 auto;
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      justify-content: space-between;
      gap: 0.9rem 1.5rem;
      color: var(--text-soft);
      font-size: 0.78rem;
      letter-spacing: 0.16em;
      text-transform: uppercase;
    }

    .footer-inner nav {
      display: flex;
      flex-wrap: wrap;
      gap: 0.9rem 1.25rem;
    }

    .reveal {
      opacity: 1;
      transform: translateY(0);
    }

    .js .reveal {
      transition: opacity 900ms ease, transform 900ms ease, filter 900ms ease;
      will-change: opacity, transform, filter;
    }

    .js .reveal:not(.visible) {
      opacity: 0.88;
      transform: translateY(10px);
      filter: saturate(0.9);
    }

    .js .reveal.visible {
      opacity: 1;
      transform: translateY(0);
      filter: none;
    }

    @keyframes drift {
      0%, 100% {
        transform: translate3d(0, 0, 0);
      }
      50% {
        transform: translate3d(0, -10px, 0);
      }
    }

    @media (max-width: 720px) {
      .hero {
        padding-top: 2rem;
      }

      .transmission {
        border-radius: 1.25rem;
      }

      .reading-shell {
        padding: 2rem 1rem;
      }

      .footer-inner {
        justify-content: center;
        text-align: center;
      }
    }

    @media (prefers-reduced-motion: reduce) {
      html {
        scroll-behavior: auto;
      }

      .cover-frame,
      .reveal {
        animation: none;
        transition: none;
      }
    }
  </style>
</head>
<body>
  <canvas id="starfield" aria-hidden="true"></canvas>
  <div class="aura" aria-hidden="true"></div>

  <div class="page">
    <section class="hero reveal visible" id="top">
      <div class="hero-inner">
        <p class="eyebrow">A Quiet Transmission</p>

        <div class="cover-frame">
          <img src="where-the-sun-was.png" alt="Cover of Where The Sun Was by Joshua Szepietowski">
        </div>

        <div class="title-block">
          <h1>Where The Sun Was</h1>
          <p>Joshua Szepietowski</p>
        </div>

        <div class="transmission">
          A novel of return, enclosure, and the branch that stayed. Begin with the first transmission.
        </div>

        <div class="hero-links">
          <a href="#chapter-one">Read Chapter 01</a>
          <a href="#download">Download the Novel</a>
        </div>
      </div>
    </section>

    <main>
      <section class="section reveal visible" id="chapter-one">
        <header class="section-heading">
          <span>Chapter 01</span>
          <h2>Return Vector</h2>
          <p>The opening chapter, rendered in full from the manuscript.</p>
        </header>

        <div class="reading-shell">
          <article class="reading-column">
HTML_HEAD

  cat "$chapter_html"

  cat <<'HTML_TAIL'
          </article>
        </div>
      </section>

      <section class="section download reveal visible" id="download">
        <header class="section-heading">
          <span>Full Text</span>
          <h2>The Complete Novel</h2>
          <p>Download the assembled manuscript as a PDF.</p>
        </header>

        <div class="download-card">
          <p>The full work is available as a single document for offline reading.</p>
          <a href="Where The Sun Was.pdf" download>Download Where The Sun Was.pdf</a>
        </div>
      </section>
    </main>

    <footer>
      <div class="footer-inner">
        <div>Where The Sun Was</div>
        <nav>
          <a href="https://joshszep.com" target="_blank" rel="noreferrer">joshszep.com</a>
          <a href="https://github.com/joshSzep/where-the-sun-was" target="_blank" rel="noreferrer">GitHub</a>
        </nav>
      </div>
    </footer>
  </div>

  <script>
    (function () {
      document.documentElement.classList.add('js');

      const root = document.documentElement;
      const revealItems = Array.from(document.querySelectorAll('.reveal'));
      const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

      const setScroll = () => {
        root.style.setProperty('--scroll', `${window.scrollY}px`);
      };

      setScroll();

      if (!reducedMotion) {
        let ticking = false;
        window.addEventListener('scroll', () => {
          if (ticking) {
            return;
          }

          ticking = true;
          window.requestAnimationFrame(() => {
            setScroll();
            ticking = false;
          });
        }, { passive: true });
      }

      if ('IntersectionObserver' in window) {
        const observer = new IntersectionObserver((entries) => {
          entries.forEach((entry) => {
            if (entry.isIntersecting) {
              entry.target.classList.add('visible');
            }
          });
        }, {
          threshold: 0.12,
          rootMargin: '0px 0px -8% 0px'
        });

        revealItems.forEach((item) => observer.observe(item));
      } else {
        revealItems.forEach((item) => item.classList.add('visible'));
      }

      const canvas = document.getElementById('starfield');

      if (!canvas || reducedMotion) {
        return;
      }

      const context = canvas.getContext('2d');
      if (!context) {
        return;
      }

      let animationFrame = 0;
      let width = 0;
      let height = 0;
      let stars = [];
      const starCount = 110;

      function makeStars() {
        stars = Array.from({ length: starCount }, () => ({
          x: Math.random() * width,
          y: Math.random() * height,
          z: 0.2 + Math.random() * 0.8,
          size: 0.4 + Math.random() * 1.6,
          alpha: 0.12 + Math.random() * 0.6,
          drift: 0.04 + Math.random() * 0.22,
          pulse: Math.random() * Math.PI * 2
        }));
      }

      function resize() {
        const ratio = Math.min(window.devicePixelRatio || 1, 2);
        width = window.innerWidth;
        height = window.innerHeight;
        canvas.width = Math.floor(width * ratio);
        canvas.height = Math.floor(height * ratio);
        canvas.style.width = `${width}px`;
        canvas.style.height = `${height}px`;
        context.setTransform(ratio, 0, 0, ratio, 0, 0);
        makeStars();
      }

      function draw(time) {
        context.clearRect(0, 0, width, height);
        context.fillStyle = 'rgba(5, 4, 4, 0.2)';
        context.fillRect(0, 0, width, height);

        for (const star of stars) {
          star.y += star.drift * star.z;
          if (star.y > height + 2) {
            star.y = -2;
            star.x = Math.random() * width;
          }

          const pulse = 0.55 + Math.sin(time * 0.00045 + star.pulse) * 0.45;
          const alpha = Math.max(0.04, star.alpha * pulse);
          context.beginPath();
          context.fillStyle = `rgba(255, 206, 145, ${alpha})`;
          context.arc(star.x, star.y, star.size * star.z, 0, Math.PI * 2);
          context.fill();
        }

        animationFrame = window.requestAnimationFrame(draw);
      }

      resize();
      window.addEventListener('resize', resize);
      animationFrame = window.requestAnimationFrame(draw);

      window.addEventListener('beforeunload', () => {
        if (animationFrame) {
          window.cancelAnimationFrame(animationFrame);
        }
      });
    }());
  </script>
</body>
</html>
HTML_TAIL
} > "$index_file"

printf 'Wrote %s\n' "$index_file"