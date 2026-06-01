local ok, git = pcall(require, "git")

if ok then
  git:setup {
    order = 1500,
  }
end
