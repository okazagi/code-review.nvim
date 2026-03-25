# code-review.nvim

A Neovim plugin for reviewing code with linked notes. Split your window with code on the left and a markdown notes buffer on the right, where each note is linked to a specific source line. I just whipped this up with Claude-CLI, so, use at your own risk but it should be good to go. I've never made a plugin before so I'm not sure about the install process, claude wrote the README as well. I'm using it and it's pretty simple and what I need at the moment.

## Features

- Split view: source code (left) + markdown notes (right)
- Link notes to specific line numbers with `[L42]` tags
- Signs in the gutter show which lines have notes
- Cursor sync: moving through notes scrolls the source to the relevant line
- Notes persist to disk per file
- Quickfix list of all notes for easy navigation

## Installation

Install with any Neovim plugin manager, then call `setup()`.

**lazy.nvim:**
```lua
{ "okazagi/code-review.nvim", opts = {} }
```

**Any other plugin manager:**
```lua
require("code-review").setup()
```

**Manual:**
```
git clone https://github.com/okazagi/code-review.nvim
```

## Usage

1. Open a file you want to review
2. `<leader>co` — opens the review split (notes on the right)
3. `<leader>cl` — inserts a `[L<n>]` tag linking to the current source line, with a code preview
4. Write your notes below the tag
5. `<leader>cg` — jump from a tag in notes back to the source line
6. `<leader>cn` — show all linked notes in the quickfix list
7. `<leader>cc` — close the review session (notes auto-save)

## Note Format

Notes are markdown files stored in `~/.local/share/nvim/code-review-notes/`. Each linked note looks like:

```markdown
[L42] `func processRequest(ctx context.Context) error {`
This function doesn't handle the timeout case properly.
```

The `[L42]` tag connects the note to line 42 of the source file. Signs (`>>`) appear in the source gutter on linked lines.

## Configuration

```lua
require("code-review").setup({
  notes_dir = vim.fn.stdpath("data") .. "/code-review-notes", -- where notes are saved
  sign_text = ">>",        -- gutter sign text
  sign_hl = "DiagnosticInfo", -- sign highlight group
  note_width = 0.4,        -- notes panel width (fraction of screen)
})
```

## Commands

| Command | Description |
|---------|-------------|
| `:CodeReviewOpen` | Start a review session |
| `:CodeReviewClose` | Close the session and save notes |
| `:CodeReviewLink` | Link current note position to source line |
| `:CodeReviewGoto` | Jump to source line from a `[L<n>]` tag |
| `:CodeReviewList` | Show all linked notes in quickfix |

---

Built with [Claude Code](https://claude.ai/code) by Anthropic.
