local wezterm = require("wezterm")
local act = wezterm.action
local utils = require("utils")
local config = wezterm.config_builder()
-- default shell is zsh (user's login shell on Mint)
config.default_prog = { "zsh", "-l" }
-- appearance settings
-- Do NOT add "Unifont" to this chain. It looks like a safe last-resort entry
-- and is not: Unifont covers the whole BMP, so wezterm tries it before its
-- fontconfig fallback and it wins entire scripts. Verified by A/B against
-- this file with the entry removed:
--   U+4E00/U+6587 CJK     Noto Serif CJK SC   -> Unifont (16x16 bitmap)
--   U+1780    Khmer      Noto Sans Khmer      -> Unifont
--   U+1000    Myanmar   Noto Serif Myanmar   -> Unifont
--   U+0D4E    Malayalam  Noto Serif Malayalam -> Unifont
-- The original warning,
--   WARN wezterm_font > No fonts contain glyphs for these codepoints: \u{7bb},
-- was fixed by installing apt's fonts-unifont, not by this config: fontconfig
-- picks the font up on its own and `wezterm ls-fonts --codepoints 7bb` then
-- reports unifont_sample.otf. To pin such a codepoint without shadowing
-- whole scripts, scope it with config.font_rules instead of font_with_fallback.
-- The second entry must be the family name fontconfig actually knows. "JetBrains
-- Mono" does not resolve: it matches nothing installed and wezterm silently
-- substitutes its own built-in placeholder, so the whole second tier was
-- drawing tofu. Verified with a single-font config and `ls-fonts --codepoints 0041`:
--   "JetBrains Mono"                -> no font file (built-in placeholder)
--   "JetBrainsMono Nerd Font Mono"  -> JetBrainsMonoNerdFontMono-Regular.ttf
config.font = wezterm.font_with_fallback({
	"CaskaydiaCove NF",
	"JetBrainsMono Nerd Font Mono",
})
config.enable_kitty_keyboard = true
config.animation_fps = 1
config.cursor_blink_ease_in = "Constant"
config.cursor_blink_ease_out = "Constant"
config.font_size = 10.0
config.adjust_window_size_when_changing_font_size = false
config.harfbuzz_features = { "calt=1", "clig=1", "liga=1" }
config.color_scheme = "Catppuccin Mocha"
config.window_padding = { left = 0, right = 0, top = 0, bottom = 0 }
config.initial_cols = 120
config.initial_rows = 40
config.window_decorations = "RESIZE"
config.window_frame = {
	border_left_width = 0,
	border_right_width = 0,
	border_bottom_height = 0,
	border_top_height = 0,
}
config.tab_bar_at_bottom = false
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.tab_max_width = 32
config.inactive_pane_hsb = {
	saturation = 1,
	brightness = 1,
}
config.colors = {
	compose_cursor = "#94e2d5",
	tab_bar = {
		background = "#1e1e2e",

		active_tab = {
			bg_color = "#585b70",
			fg_color = "#f5e0dc",
			intensity = "Bold",
		},

		inactive_tab = {
			bg_color = "#181825",
			fg_color = "#a6adc8",
		},

		inactive_tab_hover = {
			bg_color = "#313244",
			fg_color = "#cdd6f4",
			italic = true,
		},

		new_tab = {
			bg_color = "#1e1e2e",
			fg_color = "#a6adc8",
		},

		new_tab_hover = {
			bg_color = "#313244",
			fg_color = "#cdd6f4",
			italic = true,
		},
	},
}
config.hyperlink_rules = {
	-- Matches: a URL in parens: (URL)
	{
		regex = "\\((\\w+://\\S+)\\)",
		format = "$1",
		highlight = 1,
	},
	-- Matches: a URL in brackets: [URL]
	{
		regex = "\\[(\\w+://\\S+)\\]",
		format = "$1",
		highlight = 1,
	},
	-- Matches: a URL in curly braces: {URL}
	{
		regex = "\\{(\\w+://\\S+)\\}",
		format = "$1",
		highlight = 1,
	},
	-- Matches: a URL in angle brackets: <URL>
	{
		regex = "<(\\w+://\\S+)>",
		format = "$1",
		highlight = 1,
	},
	-- Then handle URLs not wrapped in brackets
	{
		-- Before
		--regex = '\\b\\w+://\\S+[)/a-zA-Z0-9-]+',
		--format = '$0',
		-- After
		regex = "[^(]\\b(\\w+://\\S+[)/a-zA-Z0-9-]+)",
		format = "$1",
		highlight = 1,
	},
	-- implicit mailto link
	{
		regex = "\\b\\w+@[\\w-]+(\\.[\\w-]+)+\\b",
		format = "mailto:$0",
	},
}
table.insert(config.hyperlink_rules, {
	regex = [[["]?([\w][-\w\d]+)(/)([-\w\d\.]+)["]?]],
	format = "https://github.com/$1/$3",
})

-- Extra quick-select patterns (CTRL+SHIFT+Space). These go in the GLOBAL
-- config on purpose, not in QuickSelectArgs on the key binding: QuickSelectArgs
-- .patterns REPLACES wezterm's built-in set (URLs, path fragments, git hashes,
-- IPs, numbers) instead of adding to it, which would narrow what matches rather
-- than expand it. The key binding below therefore sets scope_lines only.
--
-- wezterm compiles this whole list into ONE alternation regex and scans left to
-- right, so the first alternative that matches at a position wins regardless of
-- which pattern "ought" to be longer. Order below is most specific -> least.
-- Concretely: without the ordering, a stack frame is chopped into a path plus a
-- stray ":42", and an ISO timestamp is eaten by file:line and comes back
-- truncated to "2026-09-29T13:04".
--
-- These use [=[ ]=] long strings so the backslashes below are literal. Inside a
-- normal "..." string every \ would need doubling, which is unreadable.
--
-- The separator class in the stack-frame pattern is [/\.] and nothing more.
-- Adding a literal "]" means spelling it "[/\.\]]", and getting that bracket
-- count wrong yields "[/\.\]" -- one bracket, so "\]" reads as an escaped
-- literal, the class swallows the next [...] as a set union, and the separator
-- requirement silently vanishes (a bare "3:4" then matches as a stack frame).
-- The regex still compiles, so only matching real output catches this. A "]" in
-- a path is not worth that footgun.
config.quick_select_patterns = {
	-- UUID, ahead of the dotted and hex-ish patterns below.
	[==[\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b]==],
	-- ISO-8601 / RFC3339, plus a bare YYYY-MM-DD.
	[==[(?<![\w])\d{4}-\d{2}-\d{2}(?:[T ]\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?(?:Z|[+-]\d{2}:?\d{2})?)?(?![\w])]==],
	-- host:port before bare IPv4: with a port is the more useful unit, and you
	-- cannot get both, because one match consumes the text.
	[==[(?<![\w.])(?:[\w-]+\.)+[\w-]+:\d{2,5}(?![\w])]==],
	[==[(?<![\w.])(?:\d{1,3}\.){3}\d{1,3}(?![\w.])]==],
	-- Stack frame: path + :line[:col]. Precedes the plain path pattern below.
	[==[(?<![\w])[\w@.+-]+[/\.][\w@.+/-]*:\d+(?::\d+)?(?![\w])]==],
	-- File paths: anything containing a slash.
	[==[(?<![\w/])(?:~|\.{1,2})?/?(?:[\w@.+-]+/)+[\w@.+-]*[\w+-]]==],
	-- Bare filename with an extension. >=2 char extension so "e.g" is not one.
	[==[(?<![\w/.\-])[\w-]+\.[A-Za-z][\w+-]{1,9}\b]==],
	-- KEY=value. Uppercase-only on purpose: that is what separates EDITOR=nvim
	-- from a password=hunter2 sitting in your shell history.
	[==[(?<![\w$])[A-Z_][A-Z0-9_]*=[^\s'"]+]==],
	-- Error codes.
	[==[(?<![\w])E\d{3,5}(?![\w])]==],
	[==[(?<![\w])ERR_[A-Z0-9_]+(?![\w])]==],
	[==[(?<![\w])error\[[A-Za-z]\d+\]]==],
	[==[(?<![\w])error TS\d+]==],
	[==[(?<![\w])(?:panic|FATAL|fatal|FAILED)\b]==],
	-- Quoted strings and backticked commands.
	[==["(?:[^"\\\n]|\\.)*"]==],
	[==['(?:[^'\\\n]|\\.)*']==],
	[==[`[^`\n]*`]==],
	-- Command invocation containing at least one flag. The trailing-argument
	-- class excludes quotes so `git commit -m 'fix: thing'` is not swallowed up
	-- to "git commit -m 'fix:" -- the quoted pattern takes the remainder.
	[==[(?<![\w/])[\w.-]+(?: +[\w./-]+)*(?: +-{1,2}[\w-]+)+(?: +[^\s'"]+)*]==],
}


-- show which key table is active in the status area
---@diagnostic disable-next-line: unused-local
wezterm.on("update-right-status", function(window, pane)
	local name = window:active_key_table()
	if name then
		name = "TABLE: " .. name
	elseif window:leader_is_active() then
		name = "LEADER"
	end
	window:set_right_status(name or "")
end)

-- Helper function to move panes between tabs
-- Heuristic: fetches the last 5 lines of pane output and scans backward
-- for a shell prompt line (lines ending with $, #, or > followed by a command).
-- If no prompt marker is found, returns the last non-empty, non-prompt line.
-- Returns the first 40 chars of the identified command.
local function get_pane_last_command(pane_id)
	local success, stdout = wezterm.run_child_process({
		"wezterm",
		"cli",
		"get-text",
		"--pane-id",
		tostring(pane_id),
		"--start-line",
		"-5",
	})
	if not success or not stdout then
		return nil
	end
	local lines = {}
	for line in stdout:gmatch("[^\r\n]+") do
		if line:match("%S") then
			table.insert(lines, line)
		end
	end
	for i = #lines, 1, -1 do
		local line = lines[i]
		local cmd = line:match("[%$#>]%s+(.+)$")
		if cmd then
			return cmd:gsub("^%s+", ""):sub(1, 40)
		end
		if not line:match("^%s*$") and not line:match("^[>%$#]") then
			return line:gsub("^%s+", ""):sub(1, 40)
		end
	end
	return nil
end

local function show_move_pane_selector(window, pane, direction)
	wezterm.log_info("show_move_pane_selector called with direction: " .. direction)

	local direction_map = {
		Left = "left",
		Right = "right",
		Up = "top",
		Down = "bottom",
	}
	local cli_direction = direction_map[direction] or direction:lower()

	local success, stdout, stderr = wezterm.run_child_process({
		"wezterm",
		"cli",
		"list",
		"--format",
		"json",
	})

	wezterm.log_info("list panes success: " .. tostring(success))
	-- tostring(): run_child_process returns a nil stdout on failure, and
	-- concatenating nil raises, which would abort before the guard below and
	-- make the toast unreachable. Verified in lua5.1:
	--   pcall(function() return "x" .. nil end)          -> false, "attempt to concatenate"
	--   pcall(function() return "x" .. tostring(nil) end) -> true
	wezterm.log_info("list panes stdout: " .. tostring(stdout))

	if not success then
		window:toast_notification("Failed to list panes: " .. (stderr or "unknown error"))
		return
	end

	local panes = wezterm.json_parse(stdout) or {}
	wezterm.log_info("parsed panes count: " .. #panes)
	local choices = {}

	for _, p in ipairs(panes) do
		if p.pane_id ~= pane:pane_id() then
			local _, cwd = utils.split_from_url(p.cwd or "file://")
			local dir_display = utils.convert_home_dir(cwd)
			local size_str = string.format("%dx%d", p.size.cols, p.size.rows)
			local tab_title = p.tab_title or ("Tab " .. p.tab_id)
			local last_cmd = get_pane_last_command(p.pane_id)
			local label
			if last_cmd and last_cmd ~= "" then
				label = string.format("#%d | %s | %s | %s | %s", p.pane_id, tab_title, dir_display, size_str, last_cmd)
			else
				label = string.format(
					"#%d | %s | %s | %s | %s",
					p.pane_id,
					tab_title,
					dir_display,
					size_str,
					p.title or "shell"
				)
			end
			table.insert(choices, {
				id = tostring(p.pane_id),
				label = label,
			})
		end
	end

	if #choices == 0 then
		window:toast_notification("No other panes available to move")
		return
	end

	table.sort(choices, function(a, b)
		return tonumber(a.id) < tonumber(b.id)
	end)

	wezterm.log_info("Calling InputSelector with " .. #choices .. " choices")
	window:perform_action(
		act.InputSelector({
			title = "Move Pane - Split " .. direction,
			choices = choices,
			fuzzy = true,
			action = wezterm.action_callback(function(inner_window, inner_pane, pane_id)
				if not pane_id then
					return
				end

				local cli_direction = ({
					Up = "top",
					Down = "bottom",
					Left = "left",
					Right = "right",
				})[direction]

				local move_success, move_stdout, move_stderr = wezterm.run_child_process({
					"wezterm",
					"cli",
					"split-pane",
					"--move-pane-id",
					pane_id,
					"--" .. cli_direction,
					"--percent",
					"50",
				})

				if not move_success then
					window:toast_notification("Failed to move pane: " .. (move_stderr or "unknown error"))
				end
			end),
		}),
		pane
	)
end

-- Move pane events
wezterm.on("move-pane-split-left", function(window, pane)
	show_move_pane_selector(window, pane, "Left")
end)

wezterm.on("move-pane-split-down", function(window, pane)
	show_move_pane_selector(window, pane, "Down")
end)

wezterm.on("move-pane-split-up", function(window, pane)
	show_move_pane_selector(window, pane, "Up")
end)

wezterm.on("move-pane-split-right", function(window, pane)
	show_move_pane_selector(window, pane, "Right")
end)

-- Tangent capture: run the script that finds the running nvim and asks it to
-- open its capture float. background_child_process() rather than
-- SpawnCommand -- the script talks to an editor that is already up and returns
-- immediately, so there is nothing to wait for and no shell to involve.
wezterm.on("tangent-capture", function()
	wezterm.background_child_process({
		(os.getenv("HOME") or "") .. "/.local/bin/nvim-tangent-capture",
	})
end)

-- Keybinds
config.leader = { key = "Space", mods = "CTRL", timeout_milliseconds = 4294967295 }
-- Main key assignments
config.keys = {
	-- Force the legacy Delete sequence (ESC[3~) regardless of kitty protocol.
	-- Under enable_kitty_keyboard = true (line 26), Delete is encoded as
	-- CSI 3 ~ — zsh/readline parse only the trailing `~` as a literal char
	-- and echo it instead of deleting. This binding supersedes the protocol
	-- encoding for the bare Delete key. See wezterm/wezterm#6940.
	{ key = "Delete", action = act.SendString("\x1b[3~") },
	-- Also fix Home/End for the same reason — kitty protocol encodes them as
	-- CSI 1 ~ and CSI 4 ~, which readline misreads. Send legacy sequences.
	{ key = "Home", action = act.SendString("\x1b[H") },
	{ key = "End", action = act.SendString("\x1b[F") },
  -- Windows
  { key = '%',
    mods = 'LEADER',
    action = wezterm.action_callback(function(win, pane)
      local mux_win = win:mux_window()
      local tabs = mux_win:tabs()
      local total_panes = 0
      for _, tab in ipairs(tabs) do
        total_panes = total_panes + #tab:panes()
      end
      if total_panes > 1 then
        pane:move_to_new_window()
      end
    end),
    },
	-- Tabs
	{ key = "c", mods = "LEADER", action = act.SpawnTab("CurrentPaneDomain") },
	{ key = "&", mods = "LEADER", action = act.CloseCurrentTab({ confirm = true }) },
	{ key = "Tab", mods = "CTRL", action = act.ActivateTabRelative(1) },
	{ key = "Tab", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(-1) },
	-- Panes
	{
		key = "!",
		mods = "LEADER|SHIFT",
		---@diagnostic disable-next-line: unused-local
		action = wezterm.action_callback(function(win, pane)
			---@diagnostic disable-next-line: unused-local
			local tab, window = pane:move_to_new_tab()
		end),
	},
	{ key = "\\", mods = "LEADER", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "-", mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
	{ key = "h", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
	{ key = "j", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
	{ key = "k", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
	{ key = "l", mods = "LEADER", action = act.ActivatePaneDirection("Right") },
	{ key = "o", mods = "LEADER", action = act.ActivatePaneDirection("Next") },
	{ key = "x", mods = "LEADER", action = act.CloseCurrentPane({ confirm = true }) },
	{ key = "+", mods = "LEADER|ALT|SHIFT", action = "IncreaseFontSize" },
	{ key = "=", mods = "LEADER|ALT", action = "ResetFontSize" },
	{ key = "-", mods = "LEADER|ALT", action = "DecreaseFontSize" },
	-- launchers
	{ key = "a", mods = "LEADER", action = act.ShowLauncher },
	{ key = "t", mods = "LEADER", action = act.ShowTabNavigator },
	{ key = "T", mods = "LEADER|SHIFT", action = act.EmitEvent("tangent-capture") },
	-- Copy mode
	{ key = "[", mods = "LEADER", action = act.ActivateCopyMode },
	{ key = "]", mods = "LEADER", action = act.CopyTo("ClipboardAndPrimarySelection") },
	-- Quick select. This is wezterm's default binding (plain QuickSelect, 1000
	-- lines of scope), now scoped wider and drawing on the extra patterns in
	-- config.quick_select_patterns above. Deliberately no `patterns` key here:
	-- that field replaces wezterm's built-ins rather than adding to them.
	--
	-- Typing a match's lowercase label copies it; the UPPERCASE label copies AND
	-- pastes. That is stock QuickSelect behaviour, not something set here.
	{ key = "Space", mods = "CTRL|SHIFT", action = act.QuickSelectArgs({ scope_lines = 5000 }) },
	-- Zoom
	{ key = "f", mods = "LEADER", action = act.TogglePaneZoomState },
	-- edit tab name
	{
		key = "e",
		mods = "LEADER",
		action = act.PromptInputLine({
			description = "Enter new name for tab",
			action = wezterm.action_callback(function(window, pane, line)
				-- line will be `nil` if they hit escape without entering anything
				-- An empty string if they just hit enter
				-- Or the actual line of the text they wrote
				if line then
					window:active_tab():set_title(line)
				end
			end),
		}),
	},
	-- CTRL+Space, followed by 'r' will put us in resize-pane
	-- mode until we cancel that mode.
	{
		key = "r",
		mods = "LEADER",
		action = act.ActivateKeyTable({
			name = "resize_pane",
			one_shot = false,
		}),
	},
	-- CTRL+Space followed by 'a' will put us in activate_pane
	-- mode until we press some other key or until 1 second passes
	-- {
	-- 	key = "a",
	-- 	mods = "LEADER",
	-- 	action = act.ActivateKeyTable({
	-- 		name = "activate_pane",
	-- 		timeout_milliseconds = 1000,
	-- 	}),
	-- },
	{
		key = ".", -- Pause Mode
		mods = "LEADER",
		action = act.Multiple({
			act.ScrollByLine(-1),
			act.ActivateCopyMode,
			act.ClearSelection,
		}),
	},
	{
		key = "s",
		mods = "LEADER",
		action = act.PaneSelect({
			alphabet = "1234567890",
		}),
	},
	{
		key = "m",
		mods = "LEADER",
		action = act.ActivateKeyTable({
			name = "move_pane_direction",
			one_shot = false,
		}),
	},
	-- Rotate panes
	{ key = "}", mods = "LEADER|SHIFT", action = act.RotatePanes("Clockwise") },
	{ key = "{", mods = "LEADER|SHIFT", action = act.RotatePanes("CounterClockwise") },
}

-- Pane resize
config.key_tables = {
	resize_pane = {
		{ key = "h", action = act.AdjustPaneSize({ "Left", 3 }) },
		{ key = "j", action = act.AdjustPaneSize({ "Down", 3 }) },
		{ key = "k", action = act.AdjustPaneSize({ "Up", 3 }) },
		{ key = "l", action = act.AdjustPaneSize({ "Right", 3 }) },
		-- Esc or leader again to exit leader mode
		{ key = "Space", mods = "CTRL", action = "PopKeyTable" }, -- Exit leader
		{ key = "Escape", action = "PopKeyTable" },
	},
	move_pane_direction = {
		{ key = "h", action = act.EmitEvent("move-pane-split-left") },
		{ key = "j", action = act.EmitEvent("move-pane-split-down") },
		{ key = "k", action = act.EmitEvent("move-pane-split-up") },
		{ key = "l", action = act.EmitEvent("move-pane-split-right") },
		{ key = "Escape", action = "PopKeyTable" },
		{ key = "Space", mods = "CTRL", action = "PopKeyTable" },
	},
}

-- Local overrides. wezterm auto-loads only wezterm.lua, so config.lua sits here
-- unused unless something requires it -- which is why it went dead for so long:
-- it looked configured, and set the window transparency that never appeared.
-- Applied last so these win over anything set above.
--
-- Copied key by key rather than deep-merged, because it is two flat scalars and
-- a merge helper would be more code than the thing it merges. Adding a key to
-- config.lua is all that is needed to have it take effect here.
for key, value in pairs(require("config")) do
	config[key] = value
end

return config
