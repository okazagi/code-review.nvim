local M = {}

M.config = {
  notes_dir = vim.fn.stdpath("data") .. "/code-review-notes",
  sign_text = ">>",
  sign_hl = "DiagnosticInfo",
  note_width = 0.4, -- fraction of screen width
}

local ns = vim.api.nvim_create_namespace("code_review")
local sign_group = "CodeReviewSigns"
local state = {} -- per-tab state: { source_buf, notes_buf, source_win, notes_win }

--- Get a stable key for a file's notes (based on absolute path).
local function notes_path_for(filepath)
  -- Resolve to absolute canonical path to prevent traversal
  local resolved = vim.fn.resolve(vim.fn.fnamemodify(filepath, ":p"))
  -- Strip null bytes
  resolved = resolved:gsub("%z", "")
  -- Replace path separators and other problematic characters with safe encoding
  local escaped = resolved:gsub("[^%w%-_.]", function(c)
    return string.format("=%02X", string.byte(c))
  end)
  -- Truncate to avoid filesystem name length limits (255 bytes typical)
  if #escaped > 240 then
    local hash = vim.fn.sha256(resolved)
    escaped = escaped:sub(1, 200) .. "_" .. hash:sub(1, 16)
  end
  return M.config.notes_dir .. "/" .. escaped .. ".md"
end

--- Parse notes buffer and return a table of { line = <source_line>, row = <notes_row> }.
local function parse_links(notes_buf)
  local lines = vim.api.nvim_buf_get_lines(notes_buf, 0, -1, false)
  local links = {}
  for row, text in ipairs(lines) do
    local ln = text:match("^%[L(%d+)%]")
    if ln then
      table.insert(links, { line = tonumber(ln), row = row })
    end
  end
  return links
end

--- Place signs in the source buffer for every linked line.
local function refresh_signs(source_buf, notes_buf)
  vim.fn.sign_unplace(sign_group, { buffer = source_buf })
  local links = parse_links(notes_buf)
  for _, link in ipairs(links) do
    local line_count = vim.api.nvim_buf_line_count(source_buf)
    if link.line >= 1 and link.line <= line_count then
      vim.fn.sign_place(0, sign_group, "CodeReviewNote", source_buf, { lnum = link.line, priority = 10 })
    end
  end
end

--- Jump the source window to the line referenced by the current notes line.
--- Only syncs when the cursor is directly on a [L<n>] tag line.
local function sync_cursor_to_source()
  local tab = vim.api.nvim_get_current_tabpage()
  local s = state[tab]
  if not s then return end

  local row = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_buf_get_lines(s.notes_buf, row - 1, row, false)[1]
  if not line then return end

  local ln = line:match("^%[L(%d+)%]")
  if ln then
    local target = tonumber(ln)
    local line_count = vim.api.nvim_buf_line_count(s.source_buf)
    if target >= 1 and target <= line_count then
      vim.api.nvim_win_set_cursor(s.source_win, { target, 0 })
    end
  end
end

--- Insert a link tag at the cursor in the notes buffer.
function M.link_line()
  local tab = vim.api.nvim_get_current_tabpage()
  local s = state[tab]
  if not s then
    vim.notify("Code review session not active", vim.log.levels.WARN)
    return
  end

  -- Get current line number from the source window
  local source_line = vim.api.nvim_win_get_cursor(s.source_win)[1]

  -- Get the source code text for context
  local source_lines = vim.api.nvim_buf_get_lines(s.source_buf, source_line - 1, source_line, false)
  local code_preview = ""
  if #source_lines > 0 then
    code_preview = source_lines[1]:sub(1, 60):gsub("`", "'")
    if #source_lines[1] > 60 then code_preview = code_preview .. "..." end
  end

  -- Insert the tag at current cursor position in notes buffer
  local notes_row = vim.api.nvim_win_get_cursor(s.notes_win)[1]
  local tag_line = string.format("[L%d] `%s`", source_line, code_preview)
  vim.api.nvim_buf_set_lines(s.notes_buf, notes_row - 1, notes_row - 1, false, { tag_line, "" })
  vim.api.nvim_win_set_cursor(s.notes_win, { notes_row + 1, 0 })

  refresh_signs(s.source_buf, s.notes_buf)
end

--- Open review mode: split window with code left, notes right.
function M.open()
  local source_buf = vim.api.nvim_get_current_buf()
  local filepath = vim.api.nvim_buf_get_name(source_buf)
  if filepath == "" then
    vim.notify("Buffer has no file name", vim.log.levels.ERROR)
    return
  end
  filepath = vim.fn.fnamemodify(filepath, ":p")

  -- Ensure notes directory exists
  vim.fn.mkdir(M.config.notes_dir, "p")

  local npath = notes_path_for(filepath)
  local source_win = vim.api.nvim_get_current_win()

  -- Calculate width
  local total_width = vim.o.columns
  local note_cols = math.floor(total_width * M.config.note_width)

  -- Open notes split on the right
  vim.cmd("botright vsplit " .. vim.fn.fnameescape(npath))
  local notes_win = vim.api.nvim_get_current_win()
  local notes_buf = vim.api.nvim_get_current_buf()

  vim.api.nvim_win_set_width(notes_win, note_cols)

  -- Configure notes buffer
  vim.bo[notes_buf].filetype = "markdown"
  vim.wo[notes_win].wrap = true
  vim.wo[notes_win].linebreak = true
  vim.wo[notes_win].number = true
  vim.wo[notes_win].relativenumber = false

  -- Configure source window
  vim.wo[source_win].number = true
  vim.wo[source_win].signcolumn = "yes"

  -- If notes file is new/empty, add a header
  if vim.api.nvim_buf_line_count(notes_buf) <= 1 and vim.api.nvim_buf_get_lines(notes_buf, 0, 1, false)[1] == "" then
    local fname = vim.fn.fnamemodify(filepath, ":t")
    local header = {
      "# Code Review: " .. fname,
      "",
      "<!-- Use <leader>cl to link a note to a source line -->",
      "<!-- Tags look like [L42] and connect to line 42 -->",
      "",
    }
    vim.api.nvim_buf_set_lines(notes_buf, 0, -1, false, header)
  end

  -- Store state
  local tab = vim.api.nvim_get_current_tabpage()
  state[tab] = {
    source_buf = source_buf,
    notes_buf = notes_buf,
    source_win = source_win,
    notes_win = notes_win,
    filepath = filepath,
  }

  -- Place signs for existing links
  refresh_signs(source_buf, notes_buf)

  -- Auto-refresh signs when notes buffer changes
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = notes_buf,
    callback = function()
      local s = state[tab]
      if s and vim.api.nvim_buf_is_valid(s.source_buf) then
        refresh_signs(s.source_buf, s.notes_buf)
      end
    end,
  })

  -- Sync source cursor when moving in notes
  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = notes_buf,
    callback = function()
      local s = state[tab]
      if s and vim.api.nvim_win_is_valid(s.source_win) then
        sync_cursor_to_source()
      end
    end,
  })

  -- Clean up state when either window closes
  vim.api.nvim_create_autocmd("WinClosed", {
    callback = function(ev)
      local closed_win = tonumber(ev.match)
      local s = state[tab]
      if s and (closed_win == s.source_win or closed_win == s.notes_win) then
        if vim.api.nvim_buf_is_valid(s.source_buf) then
          vim.fn.sign_unplace(sign_group, { buffer = s.source_buf })
        end
        state[tab] = nil
        return true -- delete this autocmd
      end
    end,
  })

  -- Focus the notes window for writing
  vim.api.nvim_set_current_win(notes_win)
  vim.notify("Code review started. <leader>cl to link a note to a line.", vim.log.levels.INFO)
end

--- Close the review session and save notes.
function M.close()
  local tab = vim.api.nvim_get_current_tabpage()
  local s = state[tab]
  if not s then
    vim.notify("No active review session", vim.log.levels.WARN)
    return
  end

  -- Save notes
  if vim.api.nvim_buf_is_valid(s.notes_buf) and vim.bo[s.notes_buf].modified then
    vim.api.nvim_buf_call(s.notes_buf, function() vim.cmd("write") end)
  end

  -- Clean signs
  if vim.api.nvim_buf_is_valid(s.source_buf) then
    vim.fn.sign_unplace(sign_group, { buffer = s.source_buf })
  end

  -- Close notes window
  if vim.api.nvim_win_is_valid(s.notes_win) then
    vim.api.nvim_win_close(s.notes_win, false)
  end

  state[tab] = nil
  vim.notify("Review session closed", vim.log.levels.INFO)
end

--- Jump from a [L<n>] tag in notes to the corresponding source line.
function M.goto_source()
  local tab = vim.api.nvim_get_current_tabpage()
  local s = state[tab]
  if not s then return end

  local row = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_buf_get_lines(s.notes_buf, row - 1, row, false)[1]
  local ln = line and line:match("^%[L(%d+)%]")
  if ln then
    local target = tonumber(ln)
    vim.api.nvim_set_current_win(s.source_win)
    local line_count = vim.api.nvim_buf_line_count(s.source_buf)
    if target >= 1 and target <= line_count then
      vim.api.nvim_win_set_cursor(s.source_win, { target, 0 })
      vim.cmd("normal! zz")
    end
  end
end

--- List all notes for the current file in a quickfix list.
function M.list_notes()
  local tab = vim.api.nvim_get_current_tabpage()
  local s = state[tab]
  if not s then
    vim.notify("No active review session", vim.log.levels.WARN)
    return
  end

  local links = parse_links(s.notes_buf)
  if #links == 0 then
    vim.notify("No linked notes found", vim.log.levels.INFO)
    return
  end

  local items = {}
  local notes_lines = vim.api.nvim_buf_get_lines(s.notes_buf, 0, -1, false)
  for _, link in ipairs(links) do
    -- Gather note text below the tag
    local text = notes_lines[link.row] or ""
    table.insert(items, {
      bufnr = s.source_buf,
      lnum = link.line,
      text = text,
    })
  end

  vim.fn.setqflist(items, "r")
  vim.fn.setqflist({}, "a", { title = "Code Review Notes" })
  vim.cmd("copen")
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  -- Define the sign
  vim.fn.sign_define("CodeReviewNote", {
    text = M.config.sign_text,
    texthl = M.config.sign_hl,
  })

  -- Commands
  vim.api.nvim_create_user_command("CodeReviewOpen", M.open, { desc = "Start code review session" })
  vim.api.nvim_create_user_command("CodeReviewClose", M.close, { desc = "Close code review session" })
  vim.api.nvim_create_user_command("CodeReviewLink", M.link_line, { desc = "Link note to source line" })
  vim.api.nvim_create_user_command("CodeReviewGoto", M.goto_source, { desc = "Jump to source from note tag" })
  vim.api.nvim_create_user_command("CodeReviewList", M.list_notes, { desc = "List all notes in quickfix" })

  -- Default keymaps
  vim.keymap.set("n", "<leader>co", M.open, { desc = "Code Review: Open" })
  vim.keymap.set("n", "<leader>cc", M.close, { desc = "Code Review: Close" })
  vim.keymap.set("n", "<leader>cl", M.link_line, { desc = "Code Review: Link line" })
  vim.keymap.set("n", "<leader>cg", M.goto_source, { desc = "Code Review: Goto source" })
  vim.keymap.set("n", "<leader>cn", M.list_notes, { desc = "Code Review: List notes" })
end

return M
