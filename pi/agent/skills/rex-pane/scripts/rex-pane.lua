-- Launch interactive Pi in a Rex tab, wait on OSC 7501 program_status events
-- (plus process-exit fallback), verify session JSONL settlement, and optionally
-- close the finished tab.

if os.getenv("REX_PANE_CHILD") == "1" then
  error("nested rex-pane execution is forbidden inside a delegated pane", 0)
end

local args = rex.args or {}
local host = args.host or "mac"
local cwd = assert(args.cwd, "cwd is required")
local prompt = assert(args.prompt, "prompt is required")
local pi_session_id = assert(args.pi_session_id, "pi_session_id is required")
local session_file = args.session_file or ""
local label = args.label or ("pi:" .. pi_session_id:sub(1, 8))
local extractor = assert(args.extractor, "extractor path is required")
local baseline_lines = tonumber(args.baseline_lines) or 0
local keep_open = args.keep_open == true
local timeout_sec = tonumber(args.timeout_sec) or 3600

local cmd = {
  "zsh",
  "-lc",
  'export PATH="$HOME/.local/bin:$HOME/.nvm/current/bin:/opt/homebrew/bin:$PATH" PI_PROGRAM_STATUS=1 REX_PANE_CHILD=1; command -v pi >/dev/null 2>&1 || for d in "$HOME"/.nvm/versions/node/*/bin; do [ -x "$d/pi" ] && PATH="$d:$PATH"; done; cd -- "$1" && shift && exec pi "$@"',
  "rex-pane",
  cwd,
}
if session_file ~= "" then
  table.insert(cmd, "--session")
  table.insert(cmd, session_file)
else
  table.insert(cmd, "--session-id")
  table.insert(cmd, pi_session_id)
end
table.insert(cmd, "--name")
table.insert(cmd, label)
if args.model and args.model ~= "" then
  table.insert(cmd, "--model")
  table.insert(cmd, args.model)
end
if args.thinking and args.thinking ~= "" then
  table.insert(cmd, "--thinking")
  table.insert(cmd, args.thinking)
end
table.insert(cmd, "--")
table.insert(cmd, prompt)

local win, err = rex.session.new_window{
  window_label = label,
  focus = false,
  layout = rex.layout.block{
    flavor = "com.superlogical.terminal.shell",
    label = label,
    options = {
      command = cmd,
      exit = { on_completion = false },
    },
  },
}
if err ~= nil then
  error("new_window failed: " .. tostring(err), 0)
end

local wid = win.window_id
local bid = win.block_ids[1]

local function capture_screen()
  local res = rex.block.call("com.superlogical.terminal", "format", {
    block_id = bid,
    format = "text",
    trim = true,
    unwrap = true,
    max_bytes = 65536,
  })
  return (res and res.content) or ""
end

local function inspect_session()
  local argv = {
    "python3",
    extractor,
    "--extract-session",
    "--host",
    host,
    "--session-id",
    pi_session_id,
    "--baseline-lines",
    tostring(baseline_lines),
  }
  if session_file ~= "" then
    table.insert(argv, "--baseline-file")
    table.insert(argv, session_file)
  end
  local r, exec_err = rex.exec(argv, { timeout = 25 })
  if not r or not r.ok or r.stdout == "" then
    return nil, (exec_err or (r and r.stderr) or "session extract failed")
  end
  local ok_dec, data = pcall(rex.json.decode, r.stdout)
  if not ok_dec then
    return nil, "invalid JSON from session extractor"
  end
  return data, nil
end

local function finish(ok, state, extra)
  local keep = keep_open or (not ok)
  if not keep then
    rex.session.close_window{ window_id = wid }
  end
  local out = {
    ok = ok,
    state = state,
    host = host,
    rex_session_id = rex.session_id,
    window_id = wid,
    block_id = bid,
    pi_session_id = pi_session_id,
    kept_open = keep,
  }
  if extra then
    for k, v in pairs(extra) do
      out[k] = v
    end
  end
  return out
end

local started = os.time()
local last_checked_lines = baseline_lines

local function find_root_record(ps)
  local records = ps and ps.records
  if type(records) ~= "table" then
    return nil
  end
  if type(records[""]) == "table" then
    return records[""]
  end
  for _, rec in ipairs(records) do
    if type(rec) == "table" and (rec.id == nil or rec.id == "") then
      return rec
    end
  end
  return nil
end

local function check_blocked_session(retry_once)
  local info = inspect_session()
  if not (info and type(info.blocked) == "table") and retry_once then
    rex.sleep(0.2)
    info = inspect_session()
  end
  if info and type(info.blocked) == "table" then
    local b = info.blocked
    return finish(false, "blocked", {
      message = b.message or "waiting on interactive input",
      kind = b.kind or "question",
      reply = (type(b.formatted) == "string" and b.formatted ~= "") and b.formatted or nil,
      screen = capture_screen(),
    })
  end
  return nil
end

local function check_child_exit()
  local proc = rex.block.call("com.superlogical.terminal", "process", { block_id = bid })
  if proc and proc.last_exit ~= nil then
    local code = proc.last_exit.exit_code or 1
    local info = inspect_session()
    if code == 0 and info and info.settled then
      return finish(true, "done", {
        reply = info.reply or "",
        session_file = info.session_file,
        usage = info.usage,
      })
    end
    return finish(false, "exited", {
      exit_code = code,
      message = string.format("pane process exited early with status %d", code),
      reply = info and info.reply or nil,
      screen = capture_screen(),
    })
  end
  return nil
end

local function screen_looks_like_questionnaire(scr)
  if type(scr) ~= "string" or not scr:find("Esc to cancel", 1, true) then
    return false
  end
  return scr:find("Enter to select", 1, true) ~= nil
    or scr:find("to expand", 1, true) ~= nil
    or scr:find("Review your answers", 1, true) ~= nil
end

local function handle_root_record(rec)
  if not rec or not rec.state then
    return nil
  end
  if rec.state == "blocked" then
    return finish(false, "blocked", {
      message = rec.msg or "waiting on interactive input",
      kind = rec.kind,
      screen = capture_screen(),
    })
  end
  if rec.state == "error" then
    local info = inspect_session()
    return finish(false, "error", {
      message = rec.msg or "pi reported an error",
      reply = info and info.reply or nil,
      screen = capture_screen(),
    })
  end
  if rec.state == "done" then
    local info, ext_err = inspect_session()
    if info and info.settled then
      return finish(true, "done", {
        reply = info.reply or "",
        session_file = info.session_file,
        usage = info.usage,
      })
    end
    if (ext_err or (info and not info.settled and #(info.active_bg or {}) == 0)) then
      -- Give filesystem flush a brief moment once before returning to the wait loop.
      rex.sleep(0.35)
      info = inspect_session()
      if info and info.settled then
        return finish(true, "done", {
          reply = info.reply or "",
          session_file = info.session_file,
          usage = info.usage,
        })
      end
    end
    if info and info.total_lines then
      last_checked_lines = info.total_lines
    end
  end
  return nil
end

while true do
  local elapsed = os.time() - started
  if elapsed >= timeout_sec then
    return finish(false, "timeout", {
      message = string.format("timed out after %ds", timeout_sec),
      last_lines = last_checked_lines,
      screen = capture_screen(),
    })
  end

  local wait_slice = math.min(3, math.max(1, timeout_sec - elapsed))
  local ev = rex.wait("block_event", function(e, c)
    if c.block_id ~= bid then
      return false
    end
    if e.name == "program_status_changed" then
      return e.id == nil or e.id == ""
    end
    return e.name == "bell" or e.name == "child_exited"
  end, wait_slice)

  if ev then
    if ev.name == "program_status_changed" and ev.record then
      local res = handle_root_record(ev.record)
      if res then
        return res
      end
    elseif ev.name == "bell" then
      local res = check_blocked_session(true)
      if res then
        return res
      end
    elseif ev.name == "child_exited" then
      local res = check_child_exit()
      if res then
        return res
      end
    end
  else
    -- Poll current program_status and child process health in case a fast turn
    -- settled before rex.wait subscribed or an extension dialog opened without OSC 7501.
    local ps = rex.block.call("com.superlogical.terminal", "program_status", { block_id = bid })
    local root_rec = find_root_record(ps)
    if root_rec then
      local res = handle_root_record(root_rec)
      if res then
        return res
      end
      if root_rec.state == "working" and screen_looks_like_questionnaire(capture_screen()) then
        local q_res = check_blocked_session(false)
        if q_res then
          return q_res
        end
      end
    end

    local exit_res = check_child_exit()
    if exit_res then
      return exit_res
    end
  end
end
