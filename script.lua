
• -- ╔══════════════════════════════════════════════════════════════╗
  -- ║              VISIBLE SNIPER  //  BY KING                     ║
  -- ║              VISIBLE.VS  //  SAB CODE SNIPER                 ║
  -- ╚══════════════════════════════════════════════════════════════╝

  local cloneref    = cloneref or function(o) return o end
  local Players     = cloneref(game:GetService("Players"))
  local RepStore    = cloneref(game:GetService("ReplicatedStorage"))
  local RunService  = cloneref(game:GetService("RunService"))
  local UIS         = cloneref(game:GetService("UserInputService"))
  local HttpService = cloneref(game:GetService("HttpService"))
  local TweenSvc    = cloneref(game:GetService("TweenService"))
  local SoundSvc    = cloneref(game:GetService("SoundService"))

  local LP        = Players.LocalPlayer
  local PGui      = LP:WaitForChild("PlayerGui")

  if getgenv and getgenv().VS_Stop then pcall(getgenv().VS_Stop) end

  -- ══════════════════════════════════════════════════════════════
  -- CONFIG
  -- ══════════════════════════════════════════════════════════════
  local CFG_FILE = "visible_sniper_cfg.json"
  local cfg = {
      enabled      = true,
      mode         = 3,      -- 1=Paste Only, 2=Auto Type, 3=Full Auto
      autoSubmit   = true,
      riddleAI     = true,
      retypeInvalid= false,
      audio        = true,
      submitAfter  = 1,
      submitDelay  = 0.0,
      uiScale      = 1.0,
      historyMax   = 15,
  }
  pcall(function()
      if type(isfile)=="function" and isfile(CFG_FILE) then
          local d = HttpService:JSONDecode(readfile(CFG_FILE))
          if type(d)=="table" then
              for k,v in pairs(d) do
                  if cfg[k]~=nil and type(v)==type(cfg[k]) then cfg[k]=v end
              end
          end
      end
  end)
  local function saveCfg()
      if type(writefile)~="function" then return end
      pcall(function() writefile(CFG_FILE, HttpService:JSONEncode(cfg)) end)
  end

  -- ══════════════════════════════════════════════════════════════
  -- STATE
  -- ══════════════════════════════════════════════════════════════
  local _seen             = {}
  local _capturedParts    = {}
  local _lastBox          = nil
  local _lastWatchedBox   = nil
  local _boxTextConn      = nil
  local _boxAncConn       = nil
  local _lastNonBlank     = ""
  local _pendingText      = nil
  local _pendingBox       = nil
  local _pendingUntil     = 0
  local _pendingToken     = 0
  local _lastStatusMsg    = nil
  local _history          = {}
  local _solving          = false
  local _riddleSeq        = 0
  local _lastTypedSeq     = 0
  local _collectBuf       = {}
  local _remoteHooked     = false

  local getupvalues = (debug and debug.getupvalues) or getupvalues
  local getconns    = getconnections or (debug and debug.getconnections)
  local setupv      = (debug and debug.setupvalue) or setupvalue
  local httpReq     = (syn and syn.request) or (http and http.request) or request or http_request

  -- Forward declarations
  local setStatus, flashCode, appendToBox
  local rememberPending, clearPending, handleFeedback
  local clearCapture, updateHistoryUI, addHistory
  local logLine

  -- ══════════════════════════════════════════════════════════════
  -- COLORS & THEME
  -- ══════════════════════════════════════════════════════════════
  local T = {
      BG0     = Color3.fromRGB(5,   8,  10),
      BG1     = Color3.fromRGB(8,  14,  16),
      BG2     = Color3.fromRGB(12, 20,  22),
      BG3     = Color3.fromRGB(6,  16,  18),
      Card    = Color3.fromRGB(10, 18,  20),
      Accent  = Color3.fromRGB(0, 255, 180),
      AccentD = Color3.fromRGB(0,  80,  60),
      AccentG = Color3.fromRGB(0, 160, 120),
      Text    = Color3.fromRGB(180, 255, 230),
      Dim     = Color3.fromRGB(60, 120, 100),
      White   = Color3.fromRGB(220, 255, 245),
      Green   = Color3.fromRGB(0,  255, 140),
      Red     = Color3.fromRGB(255,  50,  80),
      Gold    = Color3.fromRGB(255, 210,  50),
      Purple  = Color3.fromRGB(160,  60, 255),
  }
  local TI = {
      Fast = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
      Med  = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
  }

  -- ══════════════════════════════════════════════════════════════
  -- GUI HELPERS
  -- ══════════════════════════════════════════════════════════════
  local function corner(p, r)
      local c = Instance.new("UICorner")
      c.CornerRadius = UDim.new(0, r or 8)
      c.Parent = p
      return c
  end
  local function stroke(p, col, th, tr)
      local s = Instance.new("UIStroke")
      s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
      s.Color = col or T.Accent
      s.Thickness = th or 1
      s.Transparency = tr or 0
      s.Parent = p
      return s
  end
  local function lbl(parent, name, text, size, pos, ts, col, font)
      local l = Instance.new("TextLabel")
      l.Name = name
      l.Size = size
      l.Position = pos
      l.BackgroundTransparency = 1
      l.Text = text
      l.TextSize = ts or 12
      l.TextColor3 = col or T.Text
      l.Font = font or Enum.Font.GothamMedium
      l.TextXAlignment = Enum.TextXAlignment.Left
      l.TextYAlignment = Enum.TextYAlignment.Center
      l.Parent = parent
      return l
  end
  local function tw(obj, info, props)
      TweenSvc:Create(obj, info, props):Play()
  end

  -- Angular corner bracket decoration
  local function addBrackets(frame, col)
      col = col or T.Accent
      local sz = 10
      local th = 2
      local positions = {
          {UDim2.new(0,0,0,0),    UDim2.new(0,sz,0,th),  UDim2.new(0,0,0,0)},
          {UDim2.new(0,0,0,0),    UDim2.new(0,th,0,sz),  UDim2.new(0,0,0,0)},
          {UDim2.new(1,-sz,0,0),  UDim2.new(0,sz,0,th),  UDim2.new(1,-sz,0,0)},
          {UDim2.new(1,-th,0,0),  UDim2.new(0,th,0,sz),  UDim2.new(1,-th,0,0)},
          {UDim2.new(0,0,1,-th),  UDim2.new(0,sz,0,th),  UDim2.new(0,0,1,-th)},
          {UDim2.new(0,0,1,-sz),  UDim2.new(0,th,0,sz),  UDim2.new(0,0,1,-sz)},
          {UDim2.new(1,-sz,1,-th),UDim2.new(0,sz,0,th),  UDim2.new(1,-sz,1,-th)},
          {UDim2.new(1,-th,1,-sz),UDim2.new(0,th,0,sz),  UDim2.new(1,-th,1,-sz)},
      }
      for _, p in ipairs(positions) do
          local f = Instance.new("Frame")
          f.Size = p[2]
          f.Position = p[1]
          f.BackgroundColor3 = col
          f.BackgroundTransparency = 0.2
          f.BorderSizePixel = 0
          f.ZIndex = 10
          f.Parent = frame
      end
  end

  -- ══════════════════════════════════════════════════════════════
  -- CLEANUP OLD GUI
  -- ══════════════════════════════════════════════════════════════
  for _, n in
  ipairs({"VisibleSniperUI","SABSniperV3","CyberCodeSniperUI","ACECodeSniperUI","SpyderHubGui","SDLCPaste","el1teAutoCod
  e"}) do
      pcall(function()
          local g = game.CoreGui:FindFirstChild(n)
          if g then g:Destroy() end
      end)
      local g = PGui:FindFirstChild(n)
      if g then g:Destroy() end
  end

  -- ══════════════════════════════════════════════════════════════
  -- AUDIO
  -- ══════════════════════════════════════════════════════════════
  local alertSound = Instance.new("Sound")
  alertSound.SoundId = "rbxassetid://9119713951"
  alertSound.Volume = 0.7
  alertSound.Parent = SoundSvc

  local function playAlert()
      if not cfg.audio then return end
      pcall(function() alertSound:Stop(); alertSound:Play() end)
  end

  -- ══════════════════════════════════════════════════════════════
  -- RIDDLE SOLVER
  -- ══════════════════════════════════════════════════════════════
  local RIDDLE_URL   = "https://sab-riddle-solver.xyrcheatz.workers.dev"
  local RIDDLE_TOKEN = "0facce8d7ac3a4b6fc4b6ae068b3b219883009780cb2ca31"

  local RIDDLE_TABLE = {
      ["what has keys but no locks"]                          = "piano",
      ["tall when young short when old"]                      = "candle",
      ["has hands but cant clap"]                             = "clock",
      ["speaks without a mouth"]                              = "echo",
      ["runs but has no legs"]                                = "river",
      ["the more you take the more you leave behind"]         = "footsteps",
      ["what has teeth but cannot bite"]                      = "comb",
      ["what gets wetter the more it dries"]                  = "towel",
      ["what can travel around the world without moving"]     = "stamp",
      ["what has an eye but cannot see"]                      = "needle",
      ["what breaks when you say it"]                         = "silence",
      ["what has a head and a tail but no body"]              = "coin",
      ["the more you have the less you see"]                  = "darkness",
      ["what comes once in a minute twice in a moment"]       = "m",
      ["what has many keys but cant open a single lock"]      = "piano",
      ["what goes up but never comes down"]                   = "age",
      ["what can you catch but not throw"]                    = "cold",
      ["what has a face but no eyes"]                         = "clock",
      ["what gets bigger the more you take away"]             = "hole",
      ["i have cities but no houses"]                         = "map",
  }

  local function solveLocal(text)
      local lower = text:lower():gsub("[^%a%s]",""):match("^%s*(.-)%s*$")
      for phrase, answer in pairs(RIDDLE_TABLE) do
          if lower:find(phrase, 1, true) then
              return answer
          end
      end
      return nil
  end

  local function aiPost(path, body)
      if not httpReq then return nil end
      local ok, res = pcall(httpReq, {
          Url     = RIDDLE_URL .. path,
          Method  = "POST",
          Headers = {
              ["Content-Type"]  = "application/json",
              ["Authorization"] = "Bearer " .. RIDDLE_TOKEN,
          },
          Body = HttpService:JSONEncode(body),
      })
      if not ok or type(res)~="table" then return nil end
      local raw = res.Body or res.body
      if type(raw)~="string" then return nil end
      local okd, data = pcall(function() return HttpService:JSONDecode(raw) end)
      return (okd and type(data)=="table") and data or nil
  end

  local function solveRiddle(message, seq)
      if _solving then return end
      _solving = true
      setStatus("Riddle detected — solving...", T.Gold)

      local localAns = solveLocal(message)
      if localAns then
          _solving = false
          RIDDLE_TABLE[message:lower():sub(1,80)] = localAns
          setStatus("Local solve: " .. localAns, T.Green)
          logLine("RIDDLE LOCAL: " .. message .. " → " .. localAns)
          if seq >= _lastTypedSeq then
              _lastTypedSeq = seq
              appendToBox(localAns)
          end
          return
      end

      if not cfg.riddleAI then
          _solving = false
          setStatus("Riddle — AI disabled", T.Dim)
          return
      end

      task.spawn(function()
          setStatus("Asking AI...", T.Gold)
          local data = aiPost("/solve", { message = message, model = "qwen", history = {} })
          _solving = false
          if not cfg.enabled then return end
          local answer = data
              and data.riddle == true
              and type(data.answers) == "table"
              and data.answers[1]
              and tostring(data.answers[1]):match("^%s*(.-)%s*$")
              or nil
          if answer and #answer > 0 and seq >= _lastTypedSeq then
              _lastTypedSeq = seq
              RIDDLE_TABLE[message:lower():sub(1,80)] = answer
              setStatus("AI solved: " .. answer, T.Green)
              logLine("RIDDLE AI: " .. message .. " → " .. answer)
              appendToBox(answer)
          else
              setStatus("Riddle unsolved", T.Red)
              logLine("RIDDLE FAIL: " .. message)
          end
      end)
  end

  -- ══════════════════════════════════════════════════════════════
  -- SUBMISSION ENGINE
  -- ══════════════════════════════════════════════════════════════
  local function isOurGui(inst)
      local p = inst
      for _ = 1, 10 do
          if not p then break end
          if p.Name == "VisibleSniperUI" then return true end
          p = p.Parent
      end
      return false
  end

  local function isVisChain(inst)
      local cur = inst
      while cur do
          if cur:IsA("GuiObject") and not cur.Visible then return false end
          if cur:IsA("ScreenGui") then return cur.Enabled end
          cur = cur.Parent
      end
      return true
  end

  local function findBoxes(pg)
      local boxes = {}
      for _, gui in ipairs(pg:GetChildren()) do
          if gui:IsA("ScreenGui") and gui.Enabled and not isOurGui(gui) then
              for _, d in ipairs(gui:GetDescendants()) do
                  if d:IsA("TextBox") and not isOurGui(d) then
                      boxes[#boxes+1] = d
                  end
              end
          end
      end
      return boxes
  end

  local function findCodeBtns(pg)
      local btns = {}
      for _, gui in ipairs(pg:GetChildren()) do
          if gui:IsA("ScreenGui") and gui.Enabled and not isOurGui(gui) then
              for _, d in ipairs(gui:GetDescendants()) do
                  if (d:IsA("TextButton") or d:IsA("ImageButton")) and not isOurGui(d) then
                      local n  = d.Name:lower()
                      local pn = (d.Parent and d.Parent.Name or ""):lower()
                      if (n:find("code") or n:find("redeem") or pn:find("code") or pn:find("redeem"))
                      and isVisChain(d) then
                          btns[#btns+1] = d
                      end
                  end
              end
          end
      end
      return btns
  end

  local function clickBtn(btn)
      if not btn then return false end
      local anyOk = false
      local function try(fn) local ok = pcall(fn); anyOk = anyOk or ok end
      try(function() btn.MouseButton1Click:Fire() end)
      try(function() btn.Activated:Fire() end)
      if typeof(firesignal)=="function" then
          try(function() firesignal(btn.MouseButton1Click) end)
          try(function() firesignal(btn.Activated) end)
      end
      if typeof(getconns)=="function" then
          try(function()
              local ok,cs = pcall(getconns, btn.MouseButton1Click)
              if ok then for _,c in ipairs(cs) do pcall(function() c:Fire() end) end end
              local ok2,cs2 = pcall(getconns, btn.Activated)
              if ok2 then for _,c in ipairs(cs2) do pcall(function() c:Fire() end) end end
          end)
      end
      if typeof(fireclick)=="function" then try(function() fireclick(btn) end) end
      return anyOk
  end

  local function fireFocusLost(box)
      if not box then return false end
      local anyFired = false
      if typeof(firesignal)=="function" then
          local ok = pcall(firesignal, box.FocusLost, true)
          anyFired = anyFired or ok
      end
      if typeof(getconns)=="function" then
          local ok,cs = pcall(getconns, box.FocusLost)
          if ok and type(cs)=="table" then
              for _,c in ipairs(cs) do
                  local fn; pcall(function() fn = c.Function end)
                  if fn and typeof(getupvalues)=="function" and typeof(setupv)=="function" then
                      local uok,ups = pcall(getupvalues, fn)
                      if uok then
                          for i,v in pairs(ups) do
                              if type(v)=="boolean" and v==true then
                                  pcall(setupv, fn, i, false)
                              end
                          end
                      end
                  end
                  local fok = pcall(function()
                      if c.Enabled~=false then c:Fire(true) end
                  end)
                  anyFired = anyFired or fok
              end
          end
      end
      return anyFired
  end

  -- Auto type simulation (mode 2)
  local function autoType(box, code)
      if not box then return end
      box.Text = ""
      for i = 1, #code do
          box.Text = code:sub(1, i)
          task.wait(0.03)
      end
  end

  -- MAIN SUBMIT FUNCTION
  local function submitCode(code)
      local pg = PGui
      if not pg then return false, "no PlayerGui" end
      if cfg.submitDelay > 0 then task.wait(cfg.submitDelay) end

      -- ── CONFIRMED PATH (from El1te source) ──────────────────
      local ok1 = pcall(function()
          local CodesGui   = pg:WaitForChild("Codes", 2)
          local CodesFrame = CodesGui:WaitForChild("Codes", 2)
          CodesGui.Enabled  = true
          CodesFrame.Visible = true

          local textBox = CodesFrame:WaitForChild("CodeRedeem", 2)
              :WaitForChild("TextBox", 2)
          local confirmBtn = CodesFrame:WaitForChild("Confirm", 2)

          if cfg.mode == 1 then
              -- Paste Only
              textBox.Text = code
              textBox:CaptureFocus()
              playAlert()
              setStatus("PASTED — press Enter to submit", T.Gold)
              logLine("PASTE: " .. code)
              return
          elseif cfg.mode == 2 then
              -- Auto Type
              autoType(textBox, code)
              playAlert()
              setStatus("TYPED — press Enter to submit", T.Gold)
              logLine("TYPED: " .. code)
              return
          else
              -- Full Auto
              textBox.Text = code
              task.wait(0.02)
              -- Fire button all methods simultaneously
              local btn = confirmBtn:FindFirstChildWhichIsA("TextButton") or confirmBtn
              clickBtn(btn)
              fireFocusLost(textBox)
              playAlert()
          end
      end)

      if ok1 and cfg.mode == 3 then
          setStatus("✓ Submitted: " .. code, T.Green)
          logLine("SUBMIT OK (direct): " .. code)
          addHistory(code, true)
          return true, "direct"
      end

      -- ── FALLBACK: Dynamic search ─────────────────────────────
      for _, btn in ipairs(findCodeBtns(pg)) do
          clickBtn(btn)
          task.wait(0.05)
      end
      task.wait(0.15)

      local box = nil
      local deadline = tick() + 2
      while tick() < deadline do
          for _, d in ipairs(findBoxes(pg)) do
              if isVisChain(d) then
                  local n  = d.Name:lower()
                  local pn = (d.Parent and d.Parent.Name or ""):lower()
                  if n:find("code") or pn:find("code") or n:find("redeem") or n:find("input") then
                      box = d; break
                  end
              end
          end
          if not box then
              for _, d in ipairs(findBoxes(pg)) do
                  if isVisChain(d) then box = d; break end
              end
          end
          if box then break end
          task.wait(0.1)
      end

      if not box then
          setStatus("✗ No code box found", T.Red)
          logLine("FAIL: no box — " .. code)
          addHistory(code, false)
          return false, "no box"
      end

      if cfg.mode == 1 then
          box.Text = code
          box:CaptureFocus()
          playAlert()
          setStatus("PASTED — press Enter", T.Gold)
          logLine("PASTE (fallback): " .. code)
          return true, "paste"
      elseif cfg.mode == 2 then
          autoType(box, code)
          playAlert()
          setStatus("TYPED — press Enter", T.Gold)
          logLine("TYPED (fallback): " .. code)
          return true, "type"
      end

      box.Text = code
      task.wait(0.02)

      local redeemBtn = nil
      local rNames = {"submit","redeem","claim","confirm","enter","send","ok","use","go"}
      local p = box.Parent
      for _ = 1, 8 do
          if not p then break end
          for _, d in ipairs(p:GetDescendants()) do
              if (d:IsA("TextButton") or d:IsA("ImageButton")) and not isOurGui(d) and d~=box then
                  local n,t = d.Name:lower(), ""
                  pcall(function() t = d.Text:lower() end)
                  for _, w in ipairs(rNames) do
                      if (n:find(w) or t:find(w)) and isVisChain(d) then
                          redeemBtn = d; break
                      end
                  end
                  if redeemBtn then break end
              end
          end
          if redeemBtn then break end
          p = p.Parent
      end

      if redeemBtn then clickBtn(redeemBtn) end
      fireFocusLost(box)
      playAlert()
      setStatus("✓ Submitted: " .. code, T.Green)
      logLine("SUBMIT OK (fallback): " .. code)
      addHistory(code, true)
      return true, "fallback"
  end

  -- ══════════════════════════════════════════════════════════════
  -- BOX WATCHERS
  -- ══════════════════════════════════════════════════════════════
  local function getCodeBox()
      for _, b in ipairs(findBoxes(PGui)) do
          if isVisChain(b) then return b end
      end
      return nil
  end

  local function clearBoxWatchers()
      if _boxTextConn then pcall(function() _boxTextConn:Disconnect() end) end
      if _boxAncConn  then pcall(function() _boxAncConn:Disconnect()  end) end
      _boxTextConn = nil; _boxAncConn = nil; _lastWatchedBox = nil
  end

  local function watchBox(box)
      if not box or _lastWatchedBox == box then return end
      clearBoxWatchers()
      _lastWatchedBox = box
      if box.Text ~= "" then _lastNonBlank = box.Text end
      _boxTextConn = box:GetPropertyChangedSignal("Text"):Connect(function()
          if box.Text == "" then _capturedParts = {}
          else _lastNonBlank = box.Text end
      end)
      _boxAncConn = box.AncestryChanged:Connect(function(_, parent)
          if not parent then _capturedParts = {}; clearBoxWatchers() end
      end)
  end

  clearCapture = function() _capturedParts = {} end

  -- ══════════════════════════════════════════════════════════════
  -- PENDING / RETYPE
  -- ══════════════════════════════════════════════════════════════
  clearPending = function()
      _pendingToken += 1
      _pendingText  = nil
      _pendingBox   = nil
      _pendingUntil = 0
  end

  rememberPending = function(box, text, replace)
      if not cfg.retypeInvalid or not text or text=="" then return end
      if not replace and _pendingText and os.clock()<=_pendingUntil then return end
      _pendingToken += 1
      local token = _pendingToken
      _pendingText  = text
      _pendingBox   = box
      _pendingUntil = os.clock() + 8
      task.delay(8, function()
          if token == _pendingToken then clearPending() end
      end)
  end

  local function restorePending(box, text)
      if not cfg.retypeInvalid or not text or text=="" then return false end
      RunService.Heartbeat:Wait()
      local b = getCodeBox() or box
      if not b or not isVisChain(b) then return false end
      local ok = pcall(function() b.Text = text end)
      if ok then _lastBox = b; watchBox(b) end
      return ok
  end

  handleFeedback = function(text, obj)
      if not cfg.retypeInvalid or not _pendingText then return end
      if os.clock() > _pendingUntil then clearPending(); return end
      if obj and obj:IsDescendantOf(game.CoreGui:FindFirstChild("VisibleSniperUI") or Instance.new("Folder")) then
  return end
      local lower = tostring(text or ""):lower()
      local rejected = lower:find("invalid") or lower:find("expired")
          or lower:find("already") or lower:find("not found")
          or lower:find("doesn't exist") or lower:find("rejected")
      if not rejected then return end
      local pt, pb = _pendingText, _pendingBox
      local restored = restorePending(pb, pt)
      clearPending()
      if restored then
          setStatus("Invalid — repasted: " .. pt, T.Gold)
          logLine("RETYPE: " .. pt)
          addHistory(pt, false)
      end
  end

  -- ══════════════════════════════════════════════════════════════
  -- APPEND TO BOX
  -- ══════════════════════════════════════════════════════════════
  function appendToBox(text)
      if not text or text=="" then return end
      if _lastWatchedBox and not isVisChain(_lastWatchedBox) then
          _capturedParts = {}; clearBoxWatchers()
      end

      local box = getCodeBox()
      _capturedParts[#_capturedParts+1] = text
      local combined = table.concat(_capturedParts)
      local count    = #_capturedParts

      if box then
          _lastBox = box; watchBox(box)
          box.Text = combined
          local focused = UIS:GetFocusedTextBox() == box
          if focused then
              pcall(function()
                  box.CursorPosition = #combined+1
                  box.SelectionStart  = #combined+1
              end)
          end
      else
          setStatus("Captured — searching panel...", T.Gold)
          logLine("CAPTURED (no box): " .. combined)
      end

      flashCode(combined, T.Accent)
      setStatus(string.format("Captured %d/%d — %s", count, cfg.submitAfter, combined), T.Accent)

      if count >= cfg.submitAfter then
          _capturedParts = {}
          rememberPending(box, combined, true)
          task.spawn(function()
              local ok, msg = submitCode(combined)
              if not ok then
                  local restored = restorePending(box, combined)
                  clearPending()
                  if restored then
                      setStatus("✗ Invalid — repasted: " .. combined, T.Gold)
                      addHistory(combined, false)
                  else
                      setStatus("✗ Failed: " .. tostring(msg), T.Red)
                      addHistory(combined, false)
                  end
              end
          end)
      end
  end

  -- Feedback watcher
  local function watchFeedback(obj)
      if not (obj:IsA("TextLabel") or obj:IsA("TextButton")) then return end
      handleFeedback(obj.Text or "", obj)
      obj:GetPropertyChangedSignal("Text"):Connect(function()
          handleFeedback(obj.Text or "", obj)
      end)
  end
  for _, obj in ipairs(PGui:GetDescendants()) do watchFeedback(obj) end
  PGui.DescendantAdded:Connect(function(obj) task.wait(0.04); watchFeedback(obj) end)

  UIS.TextBoxFocused:Connect(function(box)
      if box:IsDescendantOf(game.CoreGui) then return end
      _lastBox = box; watchBox(box)
  end)

  -- ══════════════════════════════════════════════════════════════
  -- REMOTE RESOLVER
  -- ══════════════════════════════════════════════════════════════
  local function resolveNotifyRemote()
      if _G.PhiNotifyRemote then return _G.PhiNotifyRemote end

      local getinfo = debug and (debug.getinfo or debug.info)

      local function checkRemote(d)
          if not d:IsA("RemoteEvent") then return nil end
          local low = d.Name:lower()
          if low:find("notif") or low:find("announce") or low:find("message")
          or low:find("chat")  or low:find("global")   or low:find("broadcast") then
              return d
          end
          if getgc and getinfo and getconnections then
              local ok,cs = pcall(getconnections, d.OnClientEvent)
              if ok and cs then
                  for _,c in ipairs(cs) do
                      local f,fn = pcall(function() return c.Function end)
                      if f and type(fn)=="function" then
                          local i,info = pcall(getinfo, fn)
                          if i then
                              local src = tostring(info.short_src or info.source or "")
                              if src:find("Notification",1,true) or src:find("Announce",1,true) then
                                  return d
                              end
                          end
                      end
                  end
              end
          end
          return nil
      end

      -- Try known Net path first
      local ok, Net = pcall(function()
          return RepStore:WaitForChild("Packages", 3):WaitForChild("Net", 3)
      end)
      if ok and Net then
          for _, d in ipairs(Net:GetDescendants()) do
              local r = checkRemote(d)
              if r then return r end
          end
      end

      -- Broad scan all of ReplicatedStorage
      for _, d in ipairs(RepStore:GetDescendants()) do
          local r = checkRemote(d)
          if r then return r end
      end

      return nil
  end

  -- Strip rich text tags
  local function stripRich(text)
      if type(text)~="string" then return tostring(text) end
      return (text:gsub("<[^>]->",""))
  end

  -- On announcement received
  local function onAnnouncement(...)
      local raw  = stripRich(tostring((...) or ""))
      local text = raw:match("^%s*(.-)%s*$") or ""
      if text=="" then return end

      logLine("ANNOUNCE: " .. text)

      -- Multi-word = riddle
      if text:find("%s") then
          if cfg.riddleAI or solveLocal(text) then
              _riddleSeq += 1
              solveRiddle(text, _riddleSeq)
          end
          return
      end

      -- Single word = direct code
      local word = text:match("^[%w_%-]+$")
      if not word or #word < 2 then return end

      if _seen[word] then return end
      _seen[word] = true
      task.delay(1.5, function() _seen[word] = nil end)

      appendToBox(word)
  end

  -- TopNotification label watcher (backup)
  local function hookTopNotification()
      local function watchLabel(obj)
          if not (obj:IsA("TextLabel") or obj:IsA("TextButton")) then return end
          obj:GetPropertyChangedSignal("Text"):Connect(function()
              if not cfg.enabled then return end
              local t = stripRich(obj.Text or "")
              if t ~= "" then
                  pcall(onAnnouncement, t)
              end
          end)
      end
      local function hookContainer(c)
          if not c then return end
          for _, d in ipairs(c:GetDescendants()) do watchLabel(d) end
          c.DescendantAdded:Connect(function(d)
              task.wait(0.03)
              watchLabel(d)
              if d:IsA("TextLabel") then
                  local t = stripRich(d.Text or "")
                  if t~="" then pcall(onAnnouncement, t) end
              end
          end)
      end
      local tn = PGui:FindFirstChild("TopNotification")
      if tn then hookContainer(tn) end
      PGui.ChildAdded:Connect(function(c)
          if c.Name == "TopNotification" then hookContainer(c) end
      end)
  end
  hookTopNotification()

  -- TextChatService fallback
  pcall(function()
      local tcs = game:GetService("TextChatService")
      if tcs and tcs.MessageReceived then
          tcs.MessageReceived:Connect(function(msg)
              if not cfg.enabled or not msg then return end
              pcall(onAnnouncement, msg.Text or "")
          end)
      end
  end)

  -- ══════════════════════════════════════════════════════════════
  -- MAIN GUI
  -- ══════════════════════════════════════════════════════════════
  local GUI = Instance.new("ScreenGui")
  GUI.Name = "VisibleSniperUI"
  GUI.ResetOnSpawn = false
  GUI.IgnoreGuiInset = true
  GUI.DisplayOrder = 999
  if not pcall(function() GUI.Parent = game.CoreGui end) then
      GUI.Parent = PGui
  end

  local WIN_W = 520
  local WIN_H = 420

  local Win = Instance.new("Frame")
  Win.Name = "Win"
  Win.Size = UDim2.fromOffset(WIN_W, WIN_H)
  Win.Position = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)
  Win.BackgroundColor3 = T.BG0
  Win.BorderSizePixel = 0
  Win.ClipsDescendants = false
  Win.Parent = GUI
  corner(Win, 6)
  stroke(Win, T.Accent, 1.5, 0.1)
  addBrackets(Win, T.Accent)

  local UIScale = Instance.new("UIScale")
  UIScale.Scale = cfg.uiScale
  UIScale.Parent = Win

  -- Subtle scanline overlay
  local scanlines = Instance.new("Frame")
  scanlines.Size = UDim2.new(1,0,1,0)
  scanlines.BackgroundTransparency = 1
  scanlines.ZIndex = 2
  scanlines.ClipsDescendants = true
  scanlines.Parent = Win
  for i = 1, 20 do
      local sl = Instance.new("Frame")
      sl.Size = UDim2.new(1,0,0,1)
      sl.Position = UDim2.new(0,0, i/20, 0)
      sl.BackgroundColor3 = T.Accent
      sl.BackgroundTransparency = 0.96
      sl.BorderSizePixel = 0
      sl.ZIndex = 2
      sl.Parent = scanlines
  end

  -- ── HEADER ──────────────────────────────────────────────────
  local Header = Instance.new("Frame")
  Header.Size = UDim2.new(1,0,0,64)
  Header.BackgroundColor3 = T.BG1
  Header.BorderSizePixel = 0
  Header.ZIndex = 3
  Header.Active = true
  Header.Parent = Win
  corner(Header, 6)

  -- Bottom fill to square off header bottom
  local HFill = Instance.new("Frame")
  HFill.Size = UDim2.new(1,0,0,8)
  HFill.Position = UDim2.new(0,0,1,-8)
  HFill.BackgroundColor3 = T.BG1
  HFill.BorderSizePixel = 0
  HFill.ZIndex = 3
  HFill.Parent = Header

  local HDivider = Instance.new("Frame")
  HDivider.Size = UDim2.new(1,0,0,1)
  HDivider.Position = UDim2.new(0,0,1,0)
  HDivider.BackgroundColor3 = T.Accent
  HDivider.BackgroundTransparency = 0.4
  HDivider.BorderSizePixel = 0
  HDivider.ZIndex = 4
  HDivider.Parent = Header

  -- Crosshair icon (text symbol)
  local CrossIcon = Instance.new("TextLabel")
  CrossIcon.Size = UDim2.fromOffset(40, 40)
  CrossIcon.Position = UDim2.fromOffset(12, 12)
  CrossIcon.BackgroundTransparency = 1
  CrossIcon.Text = "◈"
  CrossIcon.TextSize = 28
  CrossIcon.TextColor3 = T.Accent
  CrossIcon.Font = Enum.Font.GothamBold
  CrossIcon.ZIndex = 4
  CrossIcon.Parent = Header

  -- Title
  local TitleLbl = Instance.new("TextLabel")
  TitleLbl.Size = UDim2.fromOffset(240, 30)
  TitleLbl.Position = UDim2.fromOffset(54, 8)
  TitleLbl.BackgroundTransparency = 1
  TitleLbl.Text = "VISIBLE SNIPER"
  TitleLbl.TextSize = 22
  TitleLbl.TextColor3 = T.Accent
  TitleLbl.Font = Enum.Font.GothamBlack
  TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
  TitleLbl.ZIndex = 4
  TitleLbl.Parent = Header

  -- Subtitle
  local SubLbl = Instance.new("TextLabel")
  SubLbl.Size = UDim2.fromOffset(240, 18)
  SubLbl.Position = UDim2.fromOffset(54, 36)
  SubLbl.BackgroundTransparency = 1
  SubLbl.Text = "by KING  ///  VISIBLE.VS"
  SubLbl.TextSize = 10
  SubLbl.TextColor3 = T.Dim
  SubLbl.Font = Enum.Font.GothamBold
  SubLbl.TextXAlignment = Enum.TextXAlignment.Left
  SubLbl.ZIndex = 4
  SubLbl.Parent = Header

  -- FPS pill
  local FpsPill = Instance.new("TextLabel")
  FpsPill.Size = UDim2.fromOffset(72, 24)
  FpsPill.Position = UDim2.new(1,-230,0.5,-12)
  FpsPill.BackgroundColor3 = T.BG2
  FpsPill.BorderSizePixel = 0
  FpsPill.Text = "FPS --"
  FpsPill.TextSize = 11
  FpsPill.TextColor3 = T.Dim
  FpsPill.Font = Enum.Font.GothamBold
  FpsPill.TextXAlignment = Enum.TextXAlignment.Center
  FpsPill.ZIndex = 4
  FpsPill.Parent = Header
  corner(FpsPill, 5)
  stroke(FpsPill, T.AccentD, 1, 0.3)

  -- Ping pill
  local PingPill = Instance.new("TextLabel")
  PingPill.Size = UDim2.fromOffset(88, 24)
  PingPill.Position = UDim2.new(1,-150,0.5,-12)
  PingPill.BackgroundColor3 = T.BG2
  PingPill.BorderSizePixel = 0
  PingPill.Text = "PING --"
  PingPill.TextSize = 11
  PingPill.TextColor3 = T.Dim
  PingPill.Font = Enum.Font.GothamBold
  PingPill.TextXAlignment = Enum.TextXAlignment.Center
  PingPill.ZIndex = 4
  PingPill.Parent = Header
  corner(PingPill, 5)
  stroke(PingPill, T.AccentD, 1, 0.3)

  -- Master toggle
  local ToggleBtn = Instance.new("TextButton")
  ToggleBtn.Size = UDim2.fromOffset(48, 24)
  ToggleBtn.Position = UDim2.new(1,-54,0.5,-12)
  ToggleBtn.BackgroundColor3 = cfg.enabled and T.Accent or T.BG2
  ToggleBtn.BorderSizePixel = 0
  ToggleBtn.AutoButtonColor = false
  ToggleBtn.Text = ""
  ToggleBtn.ZIndex = 5
  ToggleBtn.Parent = Header
  corner(ToggleBtn, 12)
  local ToggleStroke = stroke(ToggleBtn, T.Accent, 1.5, 0.2)
  local ToggleKnob = Instance.new("Frame")
  ToggleKnob.Size = UDim2.fromOffset(20,20)
  ToggleKnob.Position = cfg.enabled and UDim2.new(1,-22,0.5,-10) or UDim2.new(0,2,0.5,-10)
  ToggleKnob.BackgroundColor3 = cfg.enabled and T.BG0 or T.AccentD
  ToggleKnob.BorderSizePixel = 0
  ToggleKnob.ZIndex = 6
  ToggleKnob.Parent = ToggleBtn
  corner(ToggleKnob, 10)

  -- ── SIDEBAR ─────────────────────────────────────────────────
  local Sidebar = Instance.new("Frame")
  Sidebar.Size = UDim2.new(0,110,1,-66)
  Sidebar.Position = UDim2.fromOffset(0,65)
  Sidebar.BackgroundColor3 = T.BG1
  Sidebar.BorderSizePixel = 0
  Sidebar.ZIndex = 3
  Sidebar.Parent = Win

  local SBLayout = Instance.new("UIListLayout")
  SBLayout.Padding = UDim.new(0,2)
  SBLayout.SortOrder = Enum.SortOrder.LayoutOrder
  SBLayout.FillDirection = Enum.FillDirection.Vertical
  SBLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
  SBLayout.VerticalAlignment = Enum.VerticalAlignment.Top
  SBLayout.Parent = Sidebar

  local SBPad = Instance.new("UIPadding")
  SBPad.PaddingTop = UDim.new(0,8)
  SBPad.PaddingLeft = UDim.new(0,6)
  SBPad.PaddingRight = UDim.new(0,6)
  SBPad.Parent = Sidebar

  -- Right border on sidebar
  local SBBorder = Instance.new("Frame")
  SBBorder.Size = UDim2.new(0,1,1,0)
  SBBorder.Position = UDim2.new(1,-1,0,0)
  SBBorder.BackgroundColor3 = T.Accent
  SBBorder.BackgroundTransparency = 0.6
  SBBorder.BorderSizePixel = 0
  SBBorder.ZIndex = 4
  SBBorder.Parent = Sidebar

  -- Branding at bottom of sidebar
  local BrandLbl = Instance.new("TextLabel")
  BrandLbl.Size = UDim2.new(1,0,0,40)
  BrandLbl.Position = UDim2.new(0,0,1,-48)
  BrandLbl.BackgroundTransparency = 1
  BrandLbl.Text = "VISIBLE.VS\n// BY KING"
  BrandLbl.TextSize = 9
  BrandLbl.TextColor3 = T.Dim
  BrandLbl.Font = Enum.Font.GothamBold
  BrandLbl.TextXAlignment = Enum.TextXAlignment.Center
  BrandLbl.TextYAlignment = Enum.TextYAlignment.Bottom
  BrandLbl.ZIndex = 4
  BrandLbl.Parent = Sidebar

  -- Tab buttons
  local tabNames = {"◈  MAIN", "⚡  CAPTURE", "📋  HISTORY", "⚙  SETTINGS"}
  local tabBtns  = {}
  local activeTab = 1

  local function makeTabBtn(name, order)
      local btn = Instance.new("TextButton")
      btn.Size = UDim2.new(1,0,0,34)
      btn.BackgroundColor3 = order==1 and T.AccentD or T.BG1
      btn.BorderSizePixel = 0
      btn.AutoButtonColor = false
      btn.Text = name
      btn.TextSize = 10
      btn.TextColor3 = order==1 and T.Accent or T.Dim
      btn.Font = Enum.Font.GothamBold
      btn.TextXAlignment = Enum.TextXAlignment.Left
      btn.LayoutOrder = order
      btn.ZIndex = 4
      btn.Parent = Sidebar
      corner(btn, 6)
      local pad = Instance.new("UIPadding")
      pad.PaddingLeft = UDim.new(0,10)
      pad.Parent = btn

      -- Active indicator bar
      local bar = Instance.new("Frame")
      bar.Size = UDim2.new(0,3,1,-8)
      bar.Position = UDim2.new(1,-3,0,4)
      bar.BackgroundColor3 = T.Accent
      bar.BackgroundTransparency = order==1 and 0 or 1
      bar.BorderSizePixel = 0
      bar.ZIndex = 5
      bar.Parent = btn
      corner(bar, 2)

      btn:SetAttribute("Bar", bar.Name)
      tabBtns[order] = {btn=btn, bar=bar}
      return btn
  end

  for i, name in ipairs(tabNames) do makeTabBtn(name, i) end

  -- ── CONTENT AREA ────────────────────────────────────────────
  local Content = Instance.new("Frame")
  Content.Size = UDim2.new(1,-112,1,-66)
  Content.Position = UDim2.fromOffset(112,65)
  Content.BackgroundTransparency = 1
  Content.ZIndex = 3
  Content.Parent = Win

  -- Helper: make a page
  local function makePage(visible)
      local p = Instance.new("Frame")
      p.Size = UDim2.new(1,0,1,0)
      p.BackgroundTransparency = 1
      p.Visible = visible or false
      p.Parent = Content
      local pad = Instance.new("UIPadding")
      pad.PaddingLeft   = UDim.new(0,10)
      pad.PaddingRight  = UDim.new(0,10)
      pad.PaddingTop    = UDim.new(0,10)
      pad.PaddingBottom = UDim.new(0,10)
      pad.Parent = p
      local layout = Instance.new("UIListLayout")
      layout.Padding = UDim.new(0,6)
      layout.SortOrder = Enum.SortOrder.LayoutOrder
      layout.FillDirection = Enum.FillDirection.Vertical
      layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
      layout.Parent = p
      return p
  end

  local Page1 = makePage(true)   -- Main
  local Page2 = makePage(false)  -- Capture
  local Page3 = makePage(false)  -- History
  local Page4 = makePage(false)  -- Settings

  local pages = {Page1, Page2, Page3, Page4}

  -- Switch tabs
  local function setTab(idx)
      activeTab = idx
      for i, p in ipairs(pages) do p.Visible = (i==idx) end
      for i, t in ipairs(tabBtns) do
          local on = (i==idx)
          tw(t.btn, TI.Fast, {BackgroundColor3 = on and T.AccentD or T.BG1})
          t.btn.TextColor3 = on and T.Accent or T.Dim
          t.bar.BackgroundTransparency = on and 0 or 1
      end
  end

  for i, t in ipairs(tabBtns) do
      local idx = i
      t.btn.Activated:Connect(function() setTab(idx) end)
      t.btn.MouseButton1Click:Connect(function() setTab(idx) end)
  end

  -- ── CARD HELPER ─────────────────────────────────────────────
  local function makeCard(parent, h, order)
      local f = Instance.new("Frame")
      f.Size = UDim2.new(1,0,0,h)
      f.BackgroundColor3 = T.Card
      f.BackgroundTransparency = 0.3
      f.BorderSizePixel = 0
      f.LayoutOrder = order or 0
      f.Parent = parent
      corner(f, 7)
      stroke(f, T.AccentD, 1, 0.4)
      return f
  end

  -- Toggle helper
  local function makeToggle(parent, startState, onChange)
      local track = Instance.new("Frame")
      track.Size = UDim2.fromOffset(42,20)
      track.AnchorPoint = Vector2.new(1,0.5)
      track.Position = UDim2.new(1,-8,0.5,0)
      track.BackgroundColor3 = startState and T.Accent or T.BG2
      track.BorderSizePixel = 0
      track.ZIndex = 5
      track.Parent = parent
      corner(track, 10)
      local knob = Instance.new("Frame")
      knob.Size = UDim2.fromOffset(16,16)
      knob.Position = startState and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8)
      knob.BackgroundColor3 = startState and T.BG0 or T.Dim
      knob.BorderSizePixel = 0
      knob.ZIndex = 6
      knob.Parent = track
      corner(knob, 8)
      local state = startState
      local btn = Instance.new("TextButton")
      btn.Size = UDim2.new(1,0,1,0)
      btn.BackgroundTransparency = 1
      btn.Text = ""
      btn.ZIndex = 7
      btn.Parent = parent
      local lastT = 0
      local function flip()
          if tick()-lastT < 0.15 then return end
          lastT = tick()
          state = not state
          tw(track, TI.Fast, {BackgroundColor3 = state and T.Accent or T.BG2})
          tw(knob, TI.Fast, {
              Position = state and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8),
              BackgroundColor3 = state and T.BG0 or T.Dim
          })
          if onChange then onChange(state) end
      end
      btn.Activated:Connect(flip)
      btn.MouseButton1Click:Connect(flip)
      return track, knob, function() return state end
  end

  -- Row helper
  local function makeRow(parent, labelText, order)
      local card = makeCard(parent, 38, order)
      card.Active = true
      lbl(card, "L", labelText, UDim2.new(1,-120,1,0), UDim2.fromOffset(12,0), 11, T.Text)
      return card
  end

  -- ── PAGE 1: MAIN ─────────────────────────────────────────────

  -- Status card
  local StatusCard = makeCard(Page1, 46, 0)
  local StatusDot = Instance.new("Frame")
  StatusDot.Size = UDim2.fromOffset(8,8)
  StatusDot.Position = UDim2.fromOffset(12,19)
  StatusDot.BackgroundColor3 = T.Dim
  StatusDot.BorderSizePixel = 0
  StatusDot.ZIndex = 5
  StatusDot.Parent = StatusCard
  corner(StatusDot, 4)

  local StatusLbl = lbl(StatusCard, "Status", "Initializing...",
      UDim2.new(1,-30,0,20), UDim2.fromOffset(26,4), 11, T.Dim)
  StatusLbl.ZIndex = 5

  local CodeLbl = lbl(StatusCard, "Code", "—",
      UDim2.new(1,-30,0,18), UDim2.fromOffset(26,24), 16, T.Accent, Enum.Font.GothamBlack)
  CodeLbl.ZIndex = 5

  -- Mode cycler
  local ModeCard = makeCard(Page1, 38, 1)
  lbl(ModeCard, "L", "Submission Mode", UDim2.fromOffset(150,38), UDim2.fromOffset(12,0), 11, T.Text)
  local modeNames = {"PASTE ONLY", "AUTO TYPE", "FULL AUTO"}
  local ModeLbl = lbl(ModeCard, "M", "◄  " .. modeNames[cfg.mode] .. "  ►",
      UDim2.fromOffset(150,38), UDim2.new(1,-160,0,0), 11, T.Accent, Enum.Font.GothamBold)
  ModeLbl.TextXAlignment = Enum.TextXAlignment.Right
  local ModeBtn = Instance.new("TextButton")
  ModeBtn.Size = UDim2.fromOffset(150,38)
  ModeBtn.Position = UDim2.new(1,-158,0,0)
  ModeBtn.BackgroundTransparency = 1
  ModeBtn.Text = ""
  ModeBtn.ZIndex = 5
  ModeBtn.Parent = ModeCard
  ModeBtn.Activated:Connect(function()
      cfg.mode = (cfg.mode % 3) + 1
      ModeLbl.Text = "◄  " .. modeNames[cfg.mode] .. "  ►"
      ModeLbl.TextColor3 = cfg.mode==3 and T.Green or cfg.mode==2 and T.Gold or T.Accent
      saveCfg()
  end)

  -- Auto submit toggle
  local AutoRow = makeRow(Page1, "Auto Submit", 2)
  makeToggle(AutoRow, cfg.autoSubmit, function(v)
      cfg.autoSubmit = v; saveCfg()
  end)

  -- Riddle solver toggle
  local RiddleRow = makeRow(Page1, "Riddle Solver (AI)", 3)
  makeToggle(RiddleRow, cfg.riddleAI, function(v)
      cfg.riddleAI = v; saveCfg()
  end)

  -- Retype invalid toggle
  local RetypeRow = makeRow(Page1, "Retype Invalid", 4)
  makeToggle(RetypeRow, cfg.retypeInvalid, function(v)
      cfg.retypeInvalid = v; saveCfg()
  end)

  -- Remote status pill
  local RemotePill = Instance.new("TextLabel")
  RemotePill.Size = UDim2.new(1,0,0,24)
  RemotePill.BackgroundColor3 = T.BG2
  RemotePill.BorderSizePixel = 0
  RemotePill.Text = "⚡ Hooking remote..."
  RemotePill.TextSize = 10
  RemotePill.TextColor3 = T.Dim
  RemotePill.Font = Enum.Font.GothamBold
  RemotePill.TextXAlignment = Enum.TextXAlignment.Center
  RemotePill.LayoutOrder = 5
  RemotePill.Parent = Page1
  corner(RemotePill, 6)
  stroke(RemotePill, T.AccentD, 1, 0.5)

  -- ── PAGE 2: CAPTURE ──────────────────────────────────────────

  -- Submit after stepper
  local AfterCard = makeCard(Page2, 48, 0)
  lbl(AfterCard, "L", "Submit After (messages)", UDim2.fromOffset(180,48), UDim2.fromOffset(12,0), 11, T.Text)
  local StepFrame = Instance.new("Frame")
  StepFrame.Size = UDim2.fromOffset(100,30)
  StepFrame.Position = UDim2.new(1,-108,0.5,-15)
  StepFrame.BackgroundColor3 = T.BG2
  StepFrame.BorderSizePixel = 0
  StepFrame.Parent = AfterCard
  corner(StepFrame, 6)
  stroke(StepFrame, T.AccentD, 1, 0.5)

  local function stepBtn(parent, txt, pos)
      local b = Instance.new("TextButton")
      b.Size = UDim2.fromOffset(26,24)
      b.Position = pos
      b.BackgroundColor3 = T.BG3
      b.BorderSizePixel = 0
      b.AutoButtonColor = false
      b.Text = txt
      b.TextSize = 16
      b.TextColor3 = T.Accent
      b.Font = Enum.Font.GothamBold
      b.Parent = parent
      corner(b, 5)
      return b
  end

  local BtnMinus = stepBtn(StepFrame, "−", UDim2.fromOffset(2,3))
  local StepCount = lbl(StepFrame, "V", tostring(cfg.submitAfter),
      UDim2.fromOffset(38,24), UDim2.fromOffset(30,3), 16, T.White, Enum.Font.GothamBlack)
  StepCount.TextXAlignment = Enum.TextXAlignment.Center
  local BtnPlus = stepBtn(StepFrame, "+", UDim2.fromOffset(70,3))

  BtnMinus.Activated:Connect(function()
      cfg.submitAfter = math.max(1, cfg.submitAfter-1)
      StepCount.Text = tostring(cfg.submitAfter)
      clearCapture(); saveCfg()
  end)
  BtnPlus.Activated:Connect(function()
      cfg.submitAfter = cfg.submitAfter+1
      StepCount.Text = tostring(cfg.submitAfter)
      clearCapture(); saveCfg()
  end)

  -- Submit delay
  local DelayCard = makeCard(Page2, 38, 1)
  lbl(DelayCard, "L", "Submit Delay (s)", UDim2.fromOffset(150,38), UDim2.fromOffset(12,0), 11, T.Text)
  local DelayBox = Instance.new("TextBox")
  DelayBox.Size = UDim2.fromOffset(70,24)
  DelayBox.Position = UDim2.new(1,-78,0.5,-12)
  DelayBox.BackgroundColor3 = T.BG2
  DelayBox.BorderSizePixel = 0
  DelayBox.Text = string.format("%.2f", cfg.submitDelay)
  DelayBox.TextSize = 13
  DelayBox.TextColor3 = T.White
  DelayBox.Font = Enum.Font.GothamBold
  DelayBox.TextXAlignment = Enum.TextXAlignment.Center
  DelayBox.ClearTextOnFocus = false
  DelayBox.Parent = DelayCard
  corner(DelayBox, 6)
  stroke(DelayBox, T.AccentD, 1, 0.4)
  DelayBox.FocusLost:Connect(function()
      local v = tonumber(DelayBox.Text)
      if v and v >= 0 then cfg.submitDelay = v; saveCfg()
      else DelayBox.Text = string.format("%.2f", cfg.submitDelay) end
  end)

  -- Manual input
  local ManualCard = makeCard(Page2, 44, 2)
  lbl(ManualCard, "L", "Manual Code", UDim2.fromOffset(90,44), UDim2.fromOffset(12,0), 11, T.Gold)
  local ManualBox = Instance.new("TextBox")
  ManualBox.Size = UDim2.new(1,-130,0,28)
  ManualBox.Position = UDim2.fromOffset(104,8)
  ManualBox.BackgroundColor3 = T.BG2
  ManualBox.BorderSizePixel = 0
  ManualBox.PlaceholderText = "enter code..."
  ManualBox.PlaceholderColor3 = T.Dim
  ManualBox.Text = ""
  ManualBox.TextSize = 12
  ManualBox.TextColor3 = T.White
  ManualBox.Font = Enum.Font.GothamBold
  ManualBox.ClearTextOnFocus = false
  ManualBox.Parent = ManualCard
  corner(ManualBox, 6)
  stroke(ManualBox, T.Gold, 1, 0.5)

  local ManualSend = Instance.new("TextButton")
  ManualSend.Size = UDim2.fromOffset(52,28)
  ManualSend.Position = UDim2.new(1,-58,0.5,-14)
  ManualSend.BackgroundColor3 = T.AccentG
  ManualSend.BorderSizePixel = 0
  ManualSend.AutoButtonColor = false
  ManualSend.Text = "SEND"
  ManualSend.TextSize = 11
  ManualSend.TextColor3 = T.BG0
  ManualSend.Font = Enum.Font.GothamBold
  ManualSend.Parent = ManualCard
  corner(ManualSend, 6)
  ManualSend.Activated:Connect(function()
      local code = ManualBox.Text:match("^%s*(.-)%s*$")
      if code ~= "" then
          appendToBox(code)
          ManualBox.Text = ""
      end
  end)

  -- Capture log
  local CapLogCard = makeCard(Page2, 120, 3)
  lbl(CapLogCard, "H", "CAPTURE LOG", UDim2.fromOffset(120,20), UDim2.fromOffset(12,4), 9, T.Dim, Enum.Font.GothamBold)
  local CapScroll = Instance.new("ScrollingFrame")
  CapScroll.Size = UDim2.new(1,-16,1,-28)
  CapScroll.Position = UDim2.fromOffset(8,24)
  CapScroll.BackgroundColor3 = T.BG3
  CapScroll.BackgroundTransparency = 0.3
  CapScroll.BorderSizePixel = 0
  CapScroll.ScrollBarThickness = 3
  CapScroll.ScrollBarImageColor3 = T.AccentD
  CapScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
  CapScroll.CanvasSize = UDim2.new(0,0,0,0)
  CapScroll.Parent = CapLogCard
  corner(CapScroll, 5)

  local CapLayout = Instance.new("UIListLayout")
  CapLayout.Padding = UDim.new(0,2)
  CapLayout.SortOrder = Enum.SortOrder.LayoutOrder
  CapLayout.Parent = CapScroll

  local CapPad = Instance.new("UIPadding")
  CapPad.PaddingLeft   = UDim.new(0,4)
  CapPad.PaddingRight  = UDim.new(0,4)
  CapPad.PaddingTop    = UDim.new(0,3)
  CapPad.PaddingBottom = UDim.new(0,3)
  CapPad.Parent = CapScroll

  local _capLogOrder = 0
  function logLine(text)
      _capLogOrder += 1
      local row = Instance.new("TextLabel")
      row.Size = UDim2.new(1,0,0,16)
      row.BackgroundTransparency = 1
      row.Text = "> " .. tostring(text)
      row.TextSize = 10
      row.Font = Enum.Font.Code
      row.TextColor3 = T.Dim
      row.TextXAlignment = Enum.TextXAlignment.Left
      row.LayoutOrder = _capLogOrder
      row.ZIndex = 5
      row.Parent = CapScroll
      task.defer(function()
          CapScroll.CanvasPosition = Vector2.new(0, math.huge)
      end)
      -- Trim old entries
      local children = CapScroll:GetChildren()
      local labels = {}
      for _, c in ipairs(children) do
          if c:IsA("TextLabel") then labels[#labels+1] = c end
      end
      if #labels > 50 then labels[1]:Destroy() end
  end

  -- ── PAGE 3: HISTORY ──────────────────────────────────────────
  local HistHeader = Instance.new("Frame")
  HistHeader.Size = UDim2.new(1,0,0,28)
  HistHeader.BackgroundTransparency = 1
  HistHeader.LayoutOrder = 0
  HistHeader.Parent = Page3

  lbl(HistHeader, "L", "CODE HISTORY",
      UDim2.fromOffset(120,28), UDim2.fromOffset(0,0), 11, T.Dim, Enum.Font.GothamBold)

  local ClearHistBtn = Instance.new("TextButton")
  ClearHistBtn.Size = UDim2.fromOffset(60,22)
  ClearHistBtn.Position = UDim2.new(1,-60,0,3)
  ClearHistBtn.BackgroundColor3 = T.BG2
  ClearHistBtn.BorderSizePixel = 0
  ClearHistBtn.AutoButtonColor = false
  ClearHistBtn.Text = "CLEAR"
  ClearHistBtn.TextSize = 10
  ClearHistBtn.TextColor3 = T.Dim
  ClearHistBtn.Font = Enum.Font.GothamBold
  ClearHistBtn.Parent = HistHeader
  corner(ClearHistBtn, 5)
  stroke(ClearHistBtn, T.AccentD, 1, 0.5)

  local HistScroll = Instance.new("ScrollingFrame")
  HistScroll.Size = UDim2.new(1,0,1,-36)
  HistScroll.Position = UDim2.fromOffset(0,34)
  HistScroll.BackgroundColor3 = T.BG1
  HistScroll.BackgroundTransparency = 0.3
  HistScroll.BorderSizePixel = 0
  HistScroll.ScrollBarThickness = 3
  HistScroll.ScrollBarImageColor3 = T.AccentD
  HistScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
  HistScroll.CanvasSize = UDim2.new(0,0,0,0)
  HistScroll.LayoutOrder = 1
  HistScroll.Parent = Page3
  corner(HistScroll, 7)
  stroke(HistScroll, T.AccentD, 1, 0.5)

  local HistLayout = Instance.new("UIListLayout")
  HistLayout.Padding = UDim.new(0,3)
  HistLayout.SortOrder = Enum.SortOrder.LayoutOrder
  HistLayout.Parent = HistScroll

  local HistPad = Instance.new("UIPadding")
  HistPad.PaddingLeft   = UDim.new(0,6)
  HistPad.PaddingRight  = UDim.new(0,6)
  HistPad.PaddingTop    = UDim.new(0,5)
  HistPad.PaddingBottom = UDim.new(0,5)
  HistPad.Parent = HistScroll

  local _histOrder = 0

  updateHistoryUI = function()
      for _, c in ipairs(HistScroll:GetChildren()) do
          if c:IsA("Frame") then c:Destroy() end
      end
      _histOrder = 0
      for i = #_history, math.max(1, #_history - cfg.historyMax + 1), -1 do
          local entry = _history[i]
          _histOrder += 1
          local row = Instance.new("Frame")
          row.Size = UDim2.new(1,0,0,26)
          row.BackgroundColor3 = entry.success and Color3.fromRGB(0,30,20) or Color3.fromRGB(30,5,10)
          row.BackgroundTransparency = 0.5
          row.BorderSizePixel = 0
          row.LayoutOrder = _histOrder
          row.Parent = HistScroll
          corner(row, 5)
          stroke(row, entry.success and T.Green or T.Red, 1, 0.7)

          local tLbl = lbl(row, "T", entry.time,
              UDim2.fromOffset(56,26), UDim2.fromOffset(6,0), 9, T.Dim)
          local cLbl = lbl(row, "C", entry.code,
              UDim2.new(1,-100,1,0), UDim2.fromOffset(64,0),
              12, entry.success and T.Green or T.Red, Enum.Font.GothamBold)
          local sLbl = lbl(row, "S", entry.success and "✓" or "✗",
              UDim2.fromOffset(20,26), UDim2.new(1,-22,0,0),
              13, entry.success and T.Green or T.Red, Enum.Font.GothamBold)
          sLbl.TextXAlignment = Enum.TextXAlignment.Center
      end
  end

  addHistory = function(code, success)
      local t = os.date and os.date("%H:%M:%S") or "??"
      table.insert(_history, {code=code, success=success, time=t})
      if #_history > cfg.historyMax then table.remove(_history,1) end
      updateHistoryUI()
      logLine((success and "OK" or "FAIL") .. ": " .. code)
  end

  ClearHistBtn.Activated:Connect(function()
      _history = {}
      updateHistoryUI()
  end)

  -- ── PAGE 4: SETTINGS ─────────────────────────────────────────

  -- Audio toggle
  local AudioRow = makeRow(Page4, "Sound Alert", 0)
  makeToggle(AudioRow, cfg.audio, function(v)
      cfg.audio = v; saveCfg()
  end)

  -- UI Scale
  local ScaleCard = makeCard(Page4, 38, 1)
  lbl(ScaleCard, "L", "UI Scale", UDim2.fromOffset(120,38), UDim2.fromOffset(12,0), 11, T.Text)
  local ScaleBox = Instance.new("TextBox")
  ScaleBox.Size = UDim2.fromOffset(70,24)
  ScaleBox.Position = UDim2.new(1,-78,0.5,-12)
  ScaleBox.BackgroundColor3 = T.BG2
  ScaleBox.BorderSizePixel = 0
  ScaleBox.Text = string.format("%.1f", cfg.uiScale)
  ScaleBox.TextSize = 13
  ScaleBox.TextColor3 = T.White
  ScaleBox.Font = Enum.Font.GothamBold
  ScaleBox.TextXAlignment = Enum.TextXAlignment.Center
  ScaleBox.ClearTextOnFocus = false
  ScaleBox.Parent = ScaleCard
  corner(ScaleBox, 6)
  stroke(ScaleBox, T.AccentD, 1, 0.4)
  ScaleBox.FocusLost:Connect(function()
      local v = tonumber(ScaleBox.Text)
      if v and v>=0.5 and v<=2.0 then
          cfg.uiScale = v
          UIScale.Scale = v
          saveCfg()
      else
          ScaleBox.Text = string.format("%.1f", cfg.uiScale)
      end
  end)

  -- Reset config
  local ResetCard = makeCard(Page4, 38, 2)
  local ResetBtn = Instance.new("TextButton")
  ResetBtn.Size = UDim2.new(1,0,1,0)
  ResetBtn.BackgroundTransparency = 1
  ResetBtn.Text = "⟳  RESET CONFIG"
  ResetBtn.TextSize = 11
  ResetBtn.TextColor3 = T.Red
  ResetBtn.Font = Enum.Font.GothamBold
  ResetBtn.ZIndex = 5
  ResetBtn.Parent = ResetCard
  ResetBtn.Activated:Connect(function()
      if type(delfile)=="function" then pcall(delfile, CFG_FILE) end
      ResetBtn.TextColor3 = T.Green
      ResetBtn.Text = "✓  CONFIG RESET"
      task.delay(2, function() ResetBtn.TextColor3=T.Red; ResetBtn.Text="⟳  RESET CONFIG" end)
  end)

  -- Version/info card
  local InfoCard = makeCard(Page4, 48, 3)
  lbl(InfoCard, "N", "VISIBLE SNIPER",
      UDim2.new(1,0,0,24), UDim2.fromOffset(12,4), 13, T.Accent, Enum.Font.GothamBlack)
  lbl(InfoCard, "S", "by KING  //  VISIBLE.VS  //  SAB Code Sniper",
      UDim2.new(1,0,0,18), UDim2.fromOffset(12,26), 9, T.Dim, Enum.Font.Gotham)

  -- ══════════════════════════════════════════════════════════════
  -- STATUS / FLASH FUNCTIONS
  -- ══════════════════════════════════════════════════════════════
  function setStatus(msg, col)
      col = col or T.Dim
      if msg == _lastStatusMsg then return end
      _lastStatusMsg = msg
      StatusLbl.Text = msg
      StatusLbl.TextColor3 = col
      StatusDot.BackgroundColor3 = col
  end

  function flashCode(code, col)
      if not code or code=="" then return end
      col = col or T.Accent
      CodeLbl.Text = code
      tw(CodeLbl, TI.Fast, {TextColor3=col})
      task.delay(0.8, function()
          tw(CodeLbl, TweenInfo.new(0.6), {TextColor3=T.Dim})
      end)
  end

  -- ══════════════════════════════════════════════════════════════
  -- MASTER TOGGLE
  -- ══════════════════════════════════════════════════════════════
  local lastToggle = 0
  local function doToggle()
      if tick()-lastToggle < 0.15 then return end
      lastToggle = tick()
      cfg.enabled = not cfg.enabled
      if not cfg.enabled then clearCapture() end
      saveCfg()
      local on = cfg.enabled
      tw(ToggleBtn, TI.Fast, {BackgroundColor3 = on and T.Accent or T.BG2})
      tw(ToggleKnob, TI.Fast, {
          Position = on and UDim2.new(1,-22,0.5,-10) or UDim2.new(0,2,0.5,-10),
          BackgroundColor3 = on and T.BG0 or T.AccentD
      })
      ToggleStroke.Transparency = on and 0.2 or 0.6
      setStatus(on and "Sniper active — scanning" or "Sniper paused", on and T.Green or T.Red)
      logLine(on and "ENABLED" or "DISABLED")
  end
  ToggleBtn.Activated:Connect(doToggle)
  ToggleBtn.MouseButton1Click:Connect(doToggle)

  -- ══════════════════════════════════════════════════════════════
  -- DRAGGING
  -- ══════════════════════════════════════════════════════════════
  do
      local dragging, dragInput, dragStart, startPos, moved = false,nil,nil,nil,false
      Header.InputBegan:Connect(function(input)
          if input.UserInputType ~= Enum.UserInputType.MouseButton1
          and input.UserInputType ~= Enum.UserInputType.Touch then return end
          local bp = ToggleBtn.AbsolutePosition
          local bs = ToggleBtn.AbsoluteSize
          if input.Position.X >= bp.X-8 and input.Position.X <= bp.X+bs.X+8
          and input.Position.Y >= bp.Y-8 and input.Position.Y <= bp.Y+bs.Y+8 then return end
          dragging=true; dragInput=input
          dragStart = Vector2.new(input.Position.X, input.Position.Y)
          startPos = Win.Position; moved=false
          input.Changed:Connect(function()
              if input.UserInputState==Enum.UserInputState.End
              or input.UserInputState==Enum.UserInputState.Cancel then
                  dragging=false; dragInput=nil
              end
          end)
      end)
      UIS.InputChanged:Connect(function(input)
          if not dragging or not dragInput then return end
          local isMouse = dragInput.UserInputType==Enum.UserInputType.MouseButton1
              and input.UserInputType==Enum.UserInputType.MouseMovement
          local isTouch = dragInput.UserInputType==Enum.UserInputType.Touch
              and input==dragInput
          if not isMouse and not isTouch then return end
          local cur = Vector2.new(input.Position.X, input.Position.Y)
          local d   = cur - dragStart
          if not moved and d.Magnitude < 4 then return end
          moved = true
          Win.Position = UDim2.new(
              startPos.X.Scale, startPos.X.Offset + d.X,
              startPos.Y.Scale, startPos.Y.Offset + d.Y)
      end)
  end

  -- ══════════════════════════════════════════════════════════════
  -- FPS COUNTER
  -- ══════════════════════════════════════════════════════════════
  local fpsBuf, fpsFlush = {}, 0
  RunService.RenderStepped:Connect(function(dt)
      if dt > 0 then fpsBuf[#fpsBuf+1] = 1/dt end
      fpsFlush += dt
      if fpsFlush >= 0.35 and #fpsBuf > 0 then
          fpsFlush = 0
          local sum = 0
          for i=1,#fpsBuf do sum += fpsBuf[i] end
          local avg = math.round(sum/#fpsBuf)
          fpsBuf = {}
          FpsPill.Text = "FPS " .. avg
          FpsPill.TextColor3 = avg>=55 and T.Green or avg>=30 and T.Gold or T.Red
      end
  end)

  -- PING COUNTER
  local pingAccum = 0
  RunService.Heartbeat:Connect(function(dt)
      pingAccum += dt
      if pingAccum < 2 then return end
      pingAccum = 0
      local ok, val = pcall(function()
          return math.round(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
      end)
      if ok and type(val)=="number" then
          PingPill.Text = "PING " .. val .. "ms"
          PingPill.TextColor3 = val<=80 and T.Green or val<=180 and T.Gold or T.Red
      end
  end)

  -- FPS cap
  if setfpscap then pcall(setfpscap, 60) end

  -- ══════════════════════════════════════════════════════════════
  -- OVERHEAD BILLBOARD TAG
  -- ══════════════════════════════════════════════════════════════
  local function addBillboard()
      local character = LP.Character or LP.CharacterAdded:Wait()
      local head = character:WaitForChild("Head", 5)
      if not head then return end

      -- Remove old
      local old = head:FindFirstChild("VS_Billboard")
      if old then old:Destroy() end

      local bb = Instance.new("BillboardGui")
      bb.Name = "VS_Billboard"
      bb.Size = UDim2.fromOffset(110, 30)
      bb.StudsOffset = Vector3.new(0, 2.8, 0)
      bb.AlwaysOnTop = false
      bb.ResetOnSpawn = false
      bb.Parent = head

      local bg = Instance.new("Frame")
      bg.Size = UDim2.new(1,0,1,0)
      bg.BackgroundColor3 = T.BG0
      bg.BackgroundTransparency = 0.25
      bg.BorderSizePixel = 0
      bg.Parent = bb
      corner(bg, 5)
      stroke(bg, T.Accent, 1.5, 0.1)

      local tagLbl = Instance.new("TextLabel")
      tagLbl.Size = UDim2.new(1,0,1,0)
      tagLbl.BackgroundTransparency = 1
      tagLbl.Text = "⚡ VISIBLE.VS"
      tagLbl.TextSize = 12
      tagLbl.TextColor3 = T.Accent
      tagLbl.Font = Enum.Font.GothamBlack
      tagLbl.TextXAlignment = Enum.TextXAlignment.Center
      tagLbl.TextYAlignment = Enum.TextYAlignment.Center
      tagLbl.Parent = bg

      -- Subtle pulse animation
      task.spawn(function()
          while tagLbl.Parent do
              tw(tagLbl, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                  {TextTransparency = 0.4})
              task.wait(1)
              tw(tagLbl, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                  {TextTransparency = 0})
              task.wait(1)
          end
      end)
  end

  task.spawn(addBillboard)
  LP.CharacterAdded:Connect(function()
      task.wait(1)
      addBillboard()
  end)

  -- ══════════════════════════════════════════════════════════════
  -- HOOK REMOTE & START
  -- ══════════════════════════════════════════════════════════════
  local listenConn

  task.spawn(function()
      setStatus("Hooking announcement remote...", T.Gold)
      RemotePill.Text = "⚡ Searching remote..."

      local remote = resolveNotifyRemote()

      if remote then
          if getgenv then
              local prev = getgenv().VS_NotifyConn
              if prev then pcall(function() prev:Disconnect() end) end
          end

          listenConn = remote.OnClientEvent:Connect(function(...)
              if not cfg.enabled then return end
              pcall(onAnnouncement, ...)
          end)

          if getgenv then getgenv().VS_NotifyConn = listenConn end

          _remoteHooked = true
          RemotePill.Text = "⚡ Remote hooked: " .. remote.Name
          RemotePill.TextColor3 = T.Green
          stroke(RemotePill, T.Green, 1, 0.3)
          setStatus("Remote hooked ✓ — ready", T.Green)
          logLine("Remote hooked: " .. remote.Name)
      else
          RemotePill.Text = "⚠ Remote not found — label watcher active"
          RemotePill.TextColor3 = T.Gold
          setStatus("Fallback mode — label watching", T.Gold)
          logLine("Remote not found, using label watcher")
      end
  end)

  -- ══════════════════════════════════════════════════════════════
  -- CLEANUP / STOP
  -- ══════════════════════════════════════════════════════════════
  if getgenv then
      getgenv().VS_Stop = function()
          if listenConn then pcall(function() listenConn:Disconnect() end) end
          if getgenv().VS_NotifyConn then
              pcall(function() getgenv().VS_NotifyConn:Disconnect() end)
          end
          -- Remove billboard
          pcall(function()
              local char = LP.Character
              if char then
                  local head = char:FindFirstChild("Head")
                  if head then
                      local bb = head:FindFirstChild("VS_Billboard")
                      if bb then bb:Destroy() end
                  end
              end
          end)
          if GUI then pcall(function() GUI:Destroy() end) end
          print("[VISIBLE SNIPER] Stopped.")
      end
  end

  setStatus(cfg.enabled and "Ready — waiting for codes" or "Paused", cfg.enabled and T.Green or T.Red)
  logLine("VISIBLE SNIPER loaded — by KING // VISIBLE.VS")
  print("[VISIBLE SNIPER] Loaded. By KING // VISIBLE.VS")
