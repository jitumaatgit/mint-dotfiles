-- Set vim.g.sqlite_clib_path for sqlite.lua (yanky's sqlite ring storage).
-- Probes the HM-provided sqlite first (always present after switch), then
-- common system paths. First readable wins; if none match, sqlite.lua
-- falls back to its own ffi.C lookup.
local candidates = {
  "/home/mint/.nix-profile/lib/libsqlite3.so",
  "/usr/lib/libsqlite3.so",
  "/usr/lib/x86_64-linux-gnu/libsqlite3.so",
  "/lib64/libsqlite3.so",
  "/usr/lib64/libsqlite3.so",
}
for _, p in ipairs(candidates) do
  if vim.fn.filereadable(p) == 1 then
    vim.g.sqlite_clib_path = p
    break
  end
end
