# review-pro CLI demo — rendered by scripts/record-demo.sh (do not run vhs
# directly; the script builds the CLI and provides the sandboxed HOME, the
# `review-pro` PATH shim, and the throwaway repo this tape assumes).
#
#   ./scripts/record-demo.sh
#
# Two scenes, separated by a hidden `clear` so each stays readable at this
# window size. Palette matches the site (docs/site.css): oat-cream paper,
# deep pine accent.

Output assets/demo.gif

Require review-pro

Set Shell bash
Set FontFamily "Menlo"
Set FontSize 19
Set Width 1260
Set Height 540
Set Padding 28
Set TypingSpeed 32ms
Set Framerate 24

Set Theme { "background": "#dfd6ca", "foreground": "#2f241c", "cursor": "#12623e", "selection": "#c9bfae", "black": "#2f241c", "red": "#8c2f2f", "green": "#12623e", "yellow": "#7d5f16", "blue": "#2a5b7a", "magenta": "#6b3f6b", "cyan": "#1c6a63", "white": "#f7f1e8", "brightBlack": "#594e43", "brightRed": "#a33b3b", "brightGreen": "#177a4d", "brightYellow": "#94721c", "brightBlue": "#356f94", "brightMagenta": "#7f4c7f", "brightWhite": "#f7f1e8" }

Hide
Type "PS1='$ '" Enter
Type "clear" Enter
Show

Sleep 800ms

# --- Scene 1: install the core, then the stack packs for this repo ---

Type "review-pro init --target claude-code --no-stacks"
Sleep 400ms
Enter
Sleep 2.8s

Type "review-pro add typescript-react"
Sleep 300ms
Enter
Sleep 1.7s

Type "review-pro add nextjs"
Sleep 300ms
Enter
Sleep 2.4s

Hide
Type "clear" Enter
Show
Sleep 500ms

# --- Scene 2: the catalog, and a health check ---

Type "review-pro list"
Sleep 300ms
Enter
Sleep 4.5s

Type "review-pro doctor"
Sleep 300ms
Enter
Sleep 2.2s

Type "# restart your agent tool, then invoke the review-pro skill"
Sleep 2.4s
Enter
Sleep 1.6s
