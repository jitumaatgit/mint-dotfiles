local M = {}

local function vault_path()
  local client = require("obsidian").get_client()
  return tostring(client.dir)
end
local function daily_notes_path()
  return vault_path() .. "/docs/30-dailynotes"
end
local function weekly_notes_path()
  return daily_notes_path() .. "/weeklynotes"
end

local JD_UNIX_EPOCH = 2440588
local SECONDS_PER_DAY = 86400

local function julian_day(y, m, d)
local a = math.floor((14 - m) / 12)
local y_adj = y + 4800 - a
local m_adj = m + 12 * a - 3
return d + math.floor((153 * m_adj + 2) / 5) + 365 * y_adj + math.floor(y_adj / 4) - math.floor(y_adj / 100) + math.floor(y_adj / 400) - 32045
end

local function jd_to_unix(jd)
  return (jd - JD_UNIX_EPOCH) * SECONDS_PER_DAY + 43200
end

local function unix_to_jd(t)
  return math.floor(t / SECONDS_PER_DAY) + JD_UNIX_EPOCH
end

local function jd_to_date(jd)
local d = os.date("*t", jd_to_unix(jd))
return { year = d.year, month = d.month, day = d.day }
end

local function get_iso_week_data(date)
  local jd = julian_day(date.year, date.month, date.day)
  local weekday = (jd + 1) % 7
  local sunday = jd - weekday
  local sunday_year = jd_to_date(sunday).year
  local jan1 = julian_day(sunday_year, 1, 1)
  local jan1_wd = (jan1 + 1) % 7
  local first_sunday = jan1 + ((7 - jan1_wd) % 7)

  local yr, week
  if sunday < first_sunday then
    yr = sunday_year - 1
    week = 52
  else
    yr = sunday_year
    week = math.floor((sunday - first_sunday) / 7) + 1
    if week > 52 then
      week = 52
    end
  end

  return {
    year = yr,
    week = week,
    sunday_jd = sunday,
  }
end

local function format_date(d)
	return string.format("%04d-%02d-%02d", d.year, d.month, d.day)
end

local function get_day_name(d)
local days = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }
local t = os.time(d)
if not t then return "Unknown" end
return days[os.date("*t", t).wday]
end

local function get_week_dates(iso_data)
	local dates = {}
	for i = 0, 6 do
		local d = jd_to_date(iso_data.sunday_jd + i)
		table.insert(dates, {
			date = d,
			date_str = format_date(d),
			day_name = get_day_name(d),
		})
	end
	return dates
end

local function get_daily_note_path(d)
	local year = string.format("%04d", d.year)
	local month = string.format("%02d", d.month)
	return string.format("%s/%s/%s/%s.md", daily_notes_path(), year, month, format_date(d))
end

local function extract_section(content, section_name)
	local pattern = "## " .. section_name .. "\n(.-)\n## "
	local match = content:match(pattern)
	if not match then
		pattern = "## " .. section_name .. "\n(.*)$"
		match = content:match(pattern)
	end
	return match and match:gsub("^%s+", ""):gsub("%s+$", "") or nil
end

local function extract_sleep(content)
	local sleep = content:match("%*%*Hours of Sleep:%*%*%s*(%d+%.?%d*)")
	return sleep and tonumber(sleep) or nil
end

local function extract_energy_avg(content)
	local total = 0
	local count = 0
	for focus in content:gmatch("%*%*f(%d+%.?%d*)%*%*") do
		total = total + tonumber(focus)
		count = count + 1
	end
	if count > 0 then
		return total / count
	end
	return nil
end

local function extract_mood_avg(content)
	local total = 0
	local count = 0
	for mood in content:gmatch("%*%*m(%d+%.?%d*)%*%*") do
		total = total + tonumber(mood)
		count = count + 1
	end
	if count > 0 then
		return total / count
	end
	return nil
end

local function read_daily_note(path)
	local file = io.open(path, "r")
	if not file then return nil end
	local content = file:read("*a")
	file:close()
	return content
end

local function ensure_dir(path)
  vim.fn.mkdir(path, "p")
end

local function calculate_week_stats(week_dates)
	local total_sleep = 0
	local sleep_count = 0
	local total_energy = 0
	local energy_count = 0
	local total_mood = 0
	local mood_count = 0

	for _, d in ipairs(week_dates) do
		local path = get_daily_note_path(d.date)
		local content = read_daily_note(path)
		if content then
			local sleep = extract_sleep(content)
			if sleep then
				total_sleep = total_sleep + sleep
				sleep_count = sleep_count + 1
			end
			local energy = extract_energy_avg(content)
			if energy then
				total_energy = total_energy + energy
				energy_count = energy_count + 1
			end
			local mood = extract_mood_avg(content)
			if mood then
				total_mood = total_mood + mood
				mood_count = mood_count + 1
			end
		end
	end

	local sleep_avg = sleep_count > 0 and (total_sleep / sleep_count) or nil
	local energy_avg = energy_count > 0 and (total_energy / energy_count) or nil
	local mood_avg = mood_count > 0 and (total_mood / mood_count) or nil

	return sleep_avg, energy_avg, mood_avg
end

-- Calculate adjacent week (direction: -1 for prev, +1 for next)
local function get_adjacent_week(iso_data, direction)
  local new_week = iso_data.week + direction
  local new_year = iso_data.year

  if new_week < 1 then
    new_year = new_year - 1
    local dec28_iso = get_iso_week_data({ year = new_year, month = 12, day = 28 })
    new_week = dec28_iso.week
  elseif new_week > 52 then
    local dec28_iso = get_iso_week_data({ year = new_year, month = 12, day = 28 })
    if new_week > dec28_iso.week then
      new_year = new_year + 1
      new_week = 1
    end
  end

  return { year = new_year, week = new_week }
end

local function generate_week_navigation(iso_data)
  local prev_week = get_adjacent_week(iso_data, -1)
  local next_week = get_adjacent_week(iso_data, 1)

  local prev_filename = string.format("%04d-W%02d", prev_week.year, prev_week.week)
  local next_filename = string.format("%04d-W%02d", next_week.year, next_week.week)

  local prev_link = string.format("← [[%s|Week %02d]]", prev_filename, prev_week.week)
  local next_link = string.format("[[%s|Week %02d]] →", next_filename, next_week.week)
  local current = string.format("**Week %d**", iso_data.week)

  return string.format("%s · %s · %s", prev_link, current, next_link)
end

local function get_goals_from_last_week(iso_data)
  local prev = get_adjacent_week(iso_data, -1)
  local path = string.format("%s/%04d/%04d-W%02d.md", weekly_notes_path(), prev.year, prev.year, prev.week)
  local file = io.open(path, "r")
  if not file then return {} end
  local content = file:read("*a")
  file:close()

  local planned = content:match("## Planned Tasks\n(.-)\n## ")
  if not planned then
    planned = content:match("## Planned Tasks\n(.*)$")
  end
  if not planned then return {} end

  local goals = {}
  for line in planned:gmatch("([^\n]+)") do
    local goal = line:match("^### Goal:%s*(.-)%s*$")
    if goal and goal ~= "" then table.insert(goals, goal) end
  end
  return goals
end

local function get_inbox_notes(week_dates)
  local this_week = {}
  local older = {}
  local start_time = os.time(week_dates[1].date)
  local end_time = os.time()

  local glob_result = vim.fn.glob(vault_path() .. "/*.md", false, true)
  for _, filepath in ipairs(glob_result) do
    local stat = vim.loop.fs_stat(filepath)
    if stat then
      local ctime = stat.ctime.sec
      local name = vim.fn.fnamemodify(filepath, ":t:r")
      if ctime >= start_time and ctime <= end_time then
        table.insert(this_week, name)
      elseif ctime < start_time then
        table.insert(older, { name = name, ctime = ctime })
      end
    end
  end

  table.sort(this_week)
  table.sort(older, function(a, b) return a.ctime < b.ctime end)

  local inbox_notes = {}
  local seen = {}
  for _, name in ipairs(this_week) do
    table.insert(inbox_notes, name)
    seen[name] = true
  end
  for i = 1, math.min(5, #older) do
    if not seen[older[i].name] then
      table.insert(inbox_notes, older[i].name)
    end
  end

  table.sort(inbox_notes)
  return inbox_notes
end

local function cache_daily_notes(week_dates)
  local cache = {}
  for _, d in ipairs(week_dates) do
    cache[d.date_str] = read_daily_note(get_daily_note_path(d.date))
  end
  return cache
end

local function add_section_digest(lines, cache, week_dates, section_name)
  for _, d in ipairs(week_dates) do
    local content = cache[d.date_str]
    if content then
      local section = extract_section(content, section_name)
      if section and section ~= "" then
        table.insert(lines, string.format("### %s (%s)", d.day_name, d.date_str))
        table.insert(lines, section)
        table.insert(lines, "")
      end
    end
  end
end

local function generate_weekly_note_content(iso_data, week_dates)
  local lines = {}
  local sleep_avg, energy_avg, mood_avg = calculate_week_stats(week_dates)
  local inbox_notes = get_inbox_notes(week_dates)
  local daily_cache = cache_daily_notes(week_dates)

  table.insert(lines, "---")
  table.insert(lines, string.format('id: "%d-W%02d"', iso_data.year, iso_data.week))
  table.insert(lines, "aliases: []")
  table.insert(lines, "tags: []")
  table.insert(lines, "---")
  table.insert(lines, "")
  table.insert(lines, generate_week_navigation(iso_data))
  table.insert(lines, "")
  table.insert(lines, string.format("# Weekly Note Week %d", iso_data.week))
	table.insert(lines, "")

table.insert(lines, "## Health dashboard")
  table.insert(lines, "")
  table.insert(lines, string.format("Week of %d-W%02d", iso_data.year, iso_data.week))
  if sleep_avg then
    table.insert(lines, string.format("- Sleep avg: %.1f/7 hours", sleep_avg))
  else
    table.insert(lines, "- Sleep avg: _/7 hours")
  end
  table.insert(lines, "- Top 3 completion: _/7 days")
  table.insert(lines, "- Housing applications: _")
  if mood_avg then
    table.insert(lines, string.format("- Mood avg: %.1f/5", mood_avg))
  else
    table.insert(lines, "- Mood avg: _/5")
  end
  if energy_avg then
    table.insert(lines, string.format("- Energy avg: %.1f/10", energy_avg))
  else
    table.insert(lines, "- Energy avg: _/10")
  end
  table.insert(lines, "- Health issues: [Y/N]")
  table.insert(lines, "- Week rating: _/10")
  table.insert(lines, "")

  table.insert(lines, "---")
  table.insert(lines, "## Startup")
  table.insert(lines, "")
  table.insert(lines, "- [ ] move files to appropriate PARA folders.")
  table.insert(lines, "- [ ] clear email inbox")
  table.insert(lines, "- [ ] look ahead and behind 1 week on calendar, edit as needed")
  table.insert(lines, "- [ ] go through this weeks daily notes.")
  table.insert(lines, "- [ ] Set Goals")
  table.insert(lines, "- [ ] Move Items from backlog into todo that will help accomplish goals")
  table.insert(lines, "- [ ] add time sensitive tasks to calendar")
  table.insert(lines, "")

  table.insert(lines, "---")
  table.insert(lines, "## Week at a Glance")
  table.insert(lines, "")

  for _, d in ipairs(week_dates) do
    local link_path = string.format("30-dailynotes/%04d/%02d/%s", d.date.year, d.date.month, d.date_str)
    local link_text = string.format("- [[%s|%s %s]]", link_path, d.day_name, d.date_str)
    table.insert(lines, link_text)
  end
  table.insert(lines, "")

  table.insert(lines, "---")
  table.insert(lines, "## Inbox")
  table.insert(lines, "")
  table.insert(lines, "Notes created this week that need to be PARA filed:")
  table.insert(lines, "")
  if #inbox_notes > 0 then
    for _, note in ipairs(inbox_notes) do
      table.insert(lines, string.format("- [[%s]]", note))
    end
  else
    table.insert(lines, "- (none)")
  end
  table.insert(lines, "")

  table.insert(lines, "---")
  table.insert(lines, "## Tangent Parking Lot")
  table.insert(lines, "")
  add_section_digest(lines, daily_cache, week_dates, "Tangent Parking Lot")

  table.insert(lines, "---")
  table.insert(lines, "## Summary Digest")
  table.insert(lines, "")
  add_section_digest(lines, daily_cache, week_dates, "Summary")

  table.insert(lines, "---")
  table.insert(lines, "## End Of Week Review")
  table.insert(lines, "- What did I get done this week versus what I planned to get done?")
  table.insert(lines, "- What unexpectedly arose this week that blocked my productivity?")
  table.insert(lines, "- What worked well?")
  table.insert(lines, "- Where did I get stuck?")
  table.insert(lines, "- What did I learn?")
  table.insert(lines, "- Am I showing up for the key people in my life (spouses, boss, close friends, close family)?")
  table.insert(lines, "- When did I feel most energized?")
  table.insert(lines, "")

  table.insert(lines, "---")
  table.insert(lines, "## Planned Tasks")
  table.insert(lines, "Actions that will ensure I make progress on my goals")
  table.insert(lines, "")
  local prev_goals = get_goals_from_last_week(iso_data)
  for _, goal in ipairs(prev_goals) do
    table.insert(lines, string.format("### Goal: %s", goal))
    table.insert(lines, "")
  end
  table.insert(lines, "- ")

	return table.concat(lines, "\n")
end

local WEEKLY_NOTE_PATTERN = "^%d%d%d%d%-W%d%d$"

function M.follow_weekly_link()
  local ok, util = pcall(require, "obsidian.util")
  if not ok then
    return false
  end

  local location, _, link_type = util.parse_cursor_link()
  if not location then
    return false
  end

  local is_wiki_link = false
  if type(link_type) == "table" then
    is_wiki_link = link_type.value == "Wiki" or link_type.value == "WikiWithAlias"
  elseif type(link_type) == "string" then
    is_wiki_link = link_type == "Wiki" or link_type == "WikiWithAlias"
  end

  if is_wiki_link and location:match(WEEKLY_NOTE_PATTERN) then
    local year, week = location:match("^(%d%d%d%d)%-W(%d%d)$")
    if year and week then
      M.create_weekly_note({ week = tonumber(week), year = tonumber(year) })
      return true
    end
  end

  return false
end

local function get_iso_data_from_week(year, week)
  local jan1_jd = julian_day(year, 1, 1)
  local jan1_wd = (jan1_jd + 1) % 7
  local first_sunday = jan1_jd + ((7 - jan1_wd) % 7)
  local sunday_jd = first_sunday + (week - 1) * 7
  return {
    year = year,
    week = week,
    sunday_jd = sunday_jd,
  }
end

function M.create_weekly_note(opts)
	local today = os.date("*t")
	local iso_data = get_iso_week_data(today)

  if opts and opts.week and opts.year then
    iso_data = get_iso_data_from_week(tonumber(opts.year), tonumber(opts.week))
  end

	local year_dir = string.format("%s/%04d", weekly_notes_path(), iso_data.year)
	ensure_dir(year_dir)

	local filename = string.format("%04d-W%02d.md", iso_data.year, iso_data.week)
	local filepath = string.format("%s/%s", year_dir, filename)

	local file = io.open(filepath, "r")
	if file then
		file:close()
		vim.cmd("edit " .. filepath)
		return
	end

	local week_dates = get_week_dates(iso_data)
	local content = generate_weekly_note_content(iso_data, week_dates)

	file = io.open(filepath, "w")
	if file then
		file:write(content)
		file:close()
		vim.cmd("edit " .. filepath)
	else
		vim.notify("Failed to create weekly note", vim.log.levels.ERROR)
	end
end

function M.create_weekly_note_for_date(date_str)
	local year, month, day = date_str:match("(%d+)%-(%d+)%-(%d+)")
	if not year then
		vim.notify("Invalid date format. Use YYYY-MM-DD", vim.log.levels.ERROR)
		return
	end

	local date = {
		year = tonumber(year),
		month = tonumber(month),
		day = tonumber(day),
	}

	local iso_data = get_iso_week_data(date)
	M.create_weekly_note({ week = iso_data.week, year = iso_data.year })
end

local function get_current_week_context()
  local bufname = vim.api.nvim_buf_get_name(0)
  local year, week = bufname:match("(%d%d%d%d)%-W(%d%d)%.md$")
  if year and week then
    return { year = tonumber(year), week = tonumber(week) }
  end
  return nil
end

vim.api.nvim_create_user_command("ObsidianWeekly", function(args)
  if args.args and args.args ~= "" then
    M.create_weekly_note_for_date(args.args)
  else
    M.create_weekly_note()
  end
end, { nargs = "?", desc = "Create or open weekly note" })

vim.api.nvim_create_user_command("ObsidianWeeklyPrev", function()
  local context = get_current_week_context()
  local iso_data
  if context then
    iso_data = context
  else
    iso_data = get_iso_week_data(os.date("*t"))
  end
  local prev = get_adjacent_week(iso_data, -1)
  M.create_weekly_note({ week = prev.week, year = prev.year })
end, { desc = "Open previous weekly note" })

vim.api.nvim_create_user_command("ObsidianWeeklyNext", function()
  local context = get_current_week_context()
  local iso_data
  if context then
    iso_data = context
  else
    iso_data = get_iso_week_data(os.date("*t"))
  end
  local next = get_adjacent_week(iso_data, 1)
  M.create_weekly_note({ week = next.week, year = next.year })
end, { desc = "Open next weekly note" })

return M
