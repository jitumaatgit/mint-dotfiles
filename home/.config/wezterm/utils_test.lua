-- Self-check for utils.lua. Run directly with `lua5.1 utils_test.lua`, or via
-- ./smoke.sh at the repo root, which is the path that actually gets run.
--
-- Every case here is a regression test for a bug that shipped: the arity checks
-- pin the string.gsub second-return-value leak, and the metacharacter case pins
-- unescaped $HOME being used as a gsub pattern. Revert utils.lua to the old
-- version and two of these fail.
local here = arg[0]:match("^(.*)[/\\][^/\\]*$") or "."
package.path = here .. "/?.lua;" .. package.path
local u = require("utils")

local failed = 0
local function check(what, got, want)
	if got ~= want then
		failed = failed + 1
		print(("FAIL  %s\n        got  %s\n        want %s"):format(what, tostring(got), tostring(want)))
	else
		print("ok    " .. what)
	end
end

print("-- basename")
check("strips directories", u.basename("/a/b/c.lua"), "c.lua")
check("passes a bare name through", u.basename("c.lua"), "c.lua")
check("handles a relative path", u.basename("a/b"), "b")
check("returns exactly one value", select("#", u.basename("/a/b/c.lua")), 1)
check("convert_useful_path returns one value", select("#", u.convert_useful_path("/a/b/c.lua")), 1)

print("-- convert_home_dir")
local real_home = os.getenv("HOME")
check("rewrites a path under $HOME", u.convert_home_dir(real_home .. "/notes"), "~/notes")
check("leaves $HOME itself absolute", u.convert_home_dir(real_home), real_home)
check("leaves a sibling prefix alone", u.convert_home_dir(real_home .. "2/x"), real_home .. "2/x")
check("leaves an unrelated path alone", u.convert_home_dir("/etc/passwd"), "/etc/passwd")

-- A $HOME containing a Lua pattern metacharacter must not over-match. Under the
-- old gsub implementation HOME=/home/a.b turned /home/axb/y into "~/y".
-- Swapping os.getenv is the point of this block: the metacharacter case is only
-- testable with a doctored $HOME.
-- luacheck: push ignore 122
local saved = os.getenv
os.getenv = function()
	return "/home/a.b"
end
check("metacharacter in $HOME does not over-match", u.convert_home_dir("/home/axb/y"), "/home/axb/y")
check("metacharacter in $HOME still matches itself", u.convert_home_dir("/home/a.b/y"), "~/y")
os.getenv = saved
-- luacheck: pop
-- Real shape from `wezterm cli list --format json`, captured from a live
-- wezterm: "file://<hostname>/<absolute path>", never a trailing slash. Not
-- testing the trailing-slash form on purpose: it is unreachable from wezterm,
-- and handling it would be code for a case that cannot arrive.
local host, dir = u.split_from_url("file://mintbook/home/mint")
check("hostname of a bare-host URL", host, "mintbook")
check("last component of $HOME", dir, "mint")
local host2, dir2 = u.split_from_url("file://host.example.com/home/mint/notes")
check("strips the domain to the first label", host2, "host")
check("last component of a deeper path", dir2, "notes")
local host3, dir3 = u.split_from_url("file:///home/mint/notes")
check("empty hostname for a hostless URL", host3, "")
check("path still resolves", dir3, "notes")

print(failed == 0 and "\nAll utils checks passed." or ("\n" .. failed .. " check(s) FAILED."))
os.exit(failed == 0 and 0 or 1)
