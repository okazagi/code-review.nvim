# code-review.nvim

A Neovim plugin for reviewing code with linked notes. Split your window with code on the left and a markdown notes buffer on the right, where each note is linked to a specific source line.

## Features

- Split view: source code (left) + markdown notes (right)
- Link notes to specific line numbers with `[L42]` tags
- Signs in the gutter show which lines have notes
- Cursor sync: moving through notes scrolls the source to the relevant line
- Notes persist to disk per file
- Quickfix list of all notes for easy navigation

## Installation (LazyVim)

Add to your LazyVim plugin specs (e.g., `~/.config/nvim/lua/plugins/code-review.lua`):

```lua
return {
  {
    "asadehaan/code-review.nvim",
    cmd = { "CodeReviewOpen", "CodeReviewClose", "CodeReviewLink", "CodeReviewGoto", "CodeReviewList" },
    keys = {
      { "<leader>co", desc = "Code Review: Open" },
      { "<leader>cc", desc = "Code Review: Close" },
      { "<leader>cl", desc = "Code Review: Link line" },
      { "<leader>cg", desc = "Code Review: Goto source" },
      { "<leader>cn", desc = "Code Review: List notes" },
    },
    opts = {},
  },
}
```

For local development, point to the local path instead:

```lua
return {
  {
    dir = "~/project-hub/vimcode-review",
    cmd = { "CodeReviewOpen", "CodeReviewClose", "CodeReviewLink", "CodeReviewGoto", "CodeReviewList" },
    keys = {
      { "<leader>co", desc = "Code Review: Open" },
      { "<leader>cc", desc = "Code Review: Close" },
      { "<leader>cl", desc = "Code Review: Link line" },
      { "<leader>cg", desc = "Code Review: Goto source" },
      { "<leader>cn", desc = "Code Review: List notes" },
    },
    opts = {},
  },
}
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
