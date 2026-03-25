-- Lazy-load guard: setup() must be called by the user
if vim.g.loaded_code_review then
  return
end
vim.g.loaded_code_review = true
