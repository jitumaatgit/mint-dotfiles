-- Path helpers for the move-pane selector in wezterm.lua.
--
-- Everything here is live code: wezterm.lua calls convert_home_dir and
-- split_from_url, and split_from_url calls convert_useful_path. The former
-- merge_tables/merge_lists/exists helpers were removed as dead -- grep found no
-- callers, only one commented-out reference in wezterm.lua, now gone too.
local M = {}

-- Last path component only. Returns exactly ONE value on purpose: a bare
-- `return string.gsub(...)` also returns the substitution count, and that second
-- value propagates through convert_useful_path into any caller that does
-- `return f(...)`, silently turning a 1-tuple into a 2-tuple.
function M.basename(s)
	return s:match("([^/\\]*)$") or s
end

-- Leading $HOME rewritten to "~". Deliberately a plain string comparison rather
-- than a gsub: $HOME is user data, and fed in as a Lua *pattern* any
-- metacharacter in it matches something else. With HOME=/home/a.b the pattern
-- "^/home/a.b/" also matched /home/axb/y and rewrote that to "~/y", which is
-- silently wrong rather than an error, so nothing ever noticed.
function M.convert_home_dir(path)
	local home = os.getenv("HOME") or os.getenv("USERPROFILE")
	if not home or home == "" or path:sub(1, #home) ~= home then
		return path
	end
	-- Require the trailing slash so a bare $HOME stays absolute instead of
	-- collapsing to a lone "~", and so /home/mint2 is not treated as inside.
	if path:sub(#home + 1, #home + 1) == "/" then
		return "~/" .. path:sub(#home + 2)
	end
	return path
end

function M.convert_useful_path(dir)
	return M.basename(M.convert_home_dir(dir))
end

-- "file://host/some/dir" -> "host", "dir". The wezterm cli emits cwd as a URL,
-- so the move-pane selector has to strip the scheme before showing a path.
function M.split_from_url(dir)
	local cwd = ""
	local hostname = ""
	local cwd_uri = dir:sub(8)
	local slash = cwd_uri:find("/")
	if slash then
		hostname = cwd_uri:sub(1, slash - 1)
		-- Drop the domain, keep the first label: host.example.com -> host
		local dot = hostname:find("[.]")
		if dot then
			hostname = hostname:sub(1, dot - 1)
		end
		cwd = M.convert_useful_path(cwd_uri:sub(slash))
	end
	return hostname, cwd
end

return M
