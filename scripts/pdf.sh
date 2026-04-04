#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
manuscript_script="$script_dir/manuscript.sh"
manuscript_file="$repo_root/Where The Sun Was.md"
cover_image="$repo_root/where-the-sun-was.png"
output_file="$repo_root/Where The Sun Was.pdf"

for dependency in pandoc pdflatex; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    printf 'Missing required dependency: %s\n' "$dependency" >&2
    exit 1
  fi
done

if [[ ! -x "$manuscript_script" ]]; then
  printf 'Missing manuscript generator: %s\n' "$manuscript_script" >&2
  exit 1
fi

if [[ ! -f "$cover_image" ]]; then
  printf 'Missing cover image: %s\n' "$cover_image" >&2
  exit 1
fi

"$manuscript_script"

if [[ ! -f "$manuscript_file" ]]; then
  printf 'Combined manuscript not found: %s\n' "$manuscript_file" >&2
  exit 1
fi

temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

header_file="$temp_dir/header.tex"
cover_file="$temp_dir/cover.tex"
body_file="$temp_dir/body.md"

cat > "$header_file" <<'EOF'
\usepackage[T1]{fontenc}
\usepackage[utf8]{inputenc}
\usepackage[paperwidth=6in,paperheight=9in,top=0.9in,bottom=0.85in,inner=0.78in,outer=0.78in,footskip=0.42in]{geometry}
\usepackage[sc]{mathpazo}
\usepackage{graphicx}
\usepackage{xcolor}
\usepackage{fancyhdr}
\usepackage{emptypage}
\usepackage{setspace}

\setcounter{secnumdepth}{0}
\setlength{\parindent}{0pt}
\setlength{\parskip}{0.6em}
\setlength{\emergencystretch}{2em}
\linespread{1.1}
\setlength{\headheight}{14pt}
\clubpenalty=10000
\widowpenalty=10000
\displaywidowpenalty=10000
\raggedbottom
\frenchspacing

\pagestyle{fancy}
\fancyhf{}
\fancyhead[C]{\nouppercase{\rightmark}}
\fancyfoot[C]{\thepage}
\renewcommand{\headrulewidth}{0pt}
\renewcommand{\footrulewidth}{0pt}
\renewcommand{\sectionmark}[1]{}
\renewcommand{\subsectionmark}[1]{\markright{#1}}
EOF

cat > "$cover_file" <<EOF
\newgeometry{margin=0in}
\thispagestyle{empty}
\begin{titlepage}
\centering
\includegraphics[width=\paperwidth,height=\paperheight]{$cover_image}
\end{titlepage}
\restoregeometry
\clearpage
\setcounter{page}{1}
EOF

awk '
  function keep_multiline_block(    i) {
    if (block_count < 2) {
      return 0
    }

    for (i = 1; i <= block_count; i++) {
      if (block[i] ~ /^(#|>|\*\*|- |\* |[0-9]+\.)/) {
        return 0
      }
    }

    return 1
  }

  function flush_block(    i) {
    if (block_count == 0) {
      return
    }

    if (keep_multiline_block()) {
      for (i = 1; i <= block_count; i++) {
        if (i < block_count) {
          print block[i] "  "
        } else {
          print block[i]
        }
      }
    } else {
      for (i = 1; i <= block_count; i++) {
        print block[i]
      }
    }

    block_count = 0
  }

  BEGIN {
    state = 0
    first_part = 1
    first_chapter = 1
    block_count = 0
  }

  state == 0 && /^# / {
    state = 1
    next
  }

  state == 1 && /^[[:space:]]*$/ {
    state = 2
    next
  }

  state == 2 && /^A Novel by / {
    state = 3
    next
  }

  state == 3 && /^[[:space:]]*$/ {
    state = 4
    next
  }

  state < 4 {
    next
  }

  /^[[:space:]]*$/ {
    flush_block()
    print ""
    next
  }

  /^## / {
    flush_block()
    if (!first_part) {
      print "\\clearpage"
      print ""
    }
    first_part = 0
    sub(/^## /, "# ")
    print
    next
  }

  /^### / {
    flush_block()
    if (!first_chapter) {
      print "\\clearpage"
      print ""
    }
    first_chapter = 0
    sub(/^### /, "## ")
    print
    next
  }

  {
    block[++block_count] = $0
  }

  END {
    flush_block()
  }
' "$manuscript_file" > "$body_file"

pandoc "$body_file" \
  --standalone \
  --from markdown+raw_tex \
  --to pdf \
  --pdf-engine=pdflatex \
  --include-in-header="$header_file" \
  --include-before-body="$cover_file" \
  --metadata lang="en-US" \
  --variable documentclass=article \
  --output "$output_file"

printf 'Wrote %s\n' "$output_file"