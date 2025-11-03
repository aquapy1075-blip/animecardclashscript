

	local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
	-------------------------------------------------
	-- UI
	-------------------------------------------------
	local Window = Rayfield:CreateWindow({
		Name = "Aqua Hub | Anime Card Clash Script",
		Icon = 114289527320220,
		LoadingTitle = "Anime Card Clash Script",
		LoadingSubtitle = "by Aquane1075",
		Theme = "Default",
		ShowText = "Aqua",
		ConfigurationSaving = {
			Enabled = true,
			FolderName = "AquaHub", -- trùng folder để gọn gàng
			FileName = "UIConfig",
		},
		Discord = {
			Enabled = true, -- Prompt the user to join your Discord server if their executor supports it
			Invite = "", -- The Discord invite code, do not include discord.gg/. E.g. discord.gg/ ABCD would be ABCD
			RememberJoins = true, -- Set this to false to make them join the discord every time they load it up
		},
		KeySystem = false,
	})

	--========================================================--
	-- UI: Quest Tab (Dropdown chọn team + Toggle Auto)
	--========================================================--

	local QuestTab = Window:CreateTab("Quest", 4483362458)

	QuestTab:CreateDropdown({
		Name = "Select Quest Team",
		Options = { "slot_8", "slot_7", "slot_6", "slot_5" },
		CurrentOption = { State.questTeam },
		Flag = "QuestTeamSelect",
		Callback = function(option)
			State.questTeam = option[1]
			print("📦 [Quest] Team set to:", option[1])
		end,
	})

	QuestTab:CreateToggle({
		Name = "Auto Quest (All)",
		CurrentValue = false,
		Flag = "AutoQuestToggle",
		Callback = function(v)
			State.autoEnabledQuest = v
			if v then
				startAutoQuest()
			else
				stopAutoQuest()
			end
		end,
	})

	local HalloweenTab = Window:CreateTab("Halloween", 6035047363)

	HalloweenTab:CreateToggle({
		Name = "Auto Collect Halloween Seeds",
		CurrentValue = false,
		Flag = "CollectSeedsHalloween",
		Callback = function(v)
			State.pickSeed = v
			if v then
				Halloween.pickSeed()
			end
		end,
	})
	HalloweenTab:CreateButton({
		Name = "Teleport to Halloween Shop",
		Callback = function()
			Halloween.teleportToShop()
		end,
	})

	HalloweenTab:CreateToggle({
		Name = "Auto Plant and Claim Seeds",
		CurrentValue = false,
		Flag = "AutoSeedPlanting",
		Callback = function(v)
			State.autoHalloween = v
			if v then
				Halloween.autoFarm()
				task.wait(10)
			end
		end,
	})

	-------------------------------------------------
	-- Storyline Tab (clean version, no labels)
	-------------------------------------------------
	local StorylineTab = Window:CreateTab("Storyline", "swords")
	StorylineTab:CreateSection("Enter Max Retry for Story Mode(No retry = 1 , Default:3)")
	StorylineTab:CreateInput({
		Name = "Number of Retries",
		PlaceholderText = "Ex: 3",
		Flag = "StoryBossMaxRetry",
		Callback = function(text)
			local n = tonumber(tostring(text))
			if not n or n <= 0 then
				Utils.notify("Error", "Please enter a valid number of retries (>=1)", 2)
				return
			end
			State.bossRetry = math.floor(n)
			Utils.notify("Storyline", "Max Retry set to " .. tostring(State.bossRetry))
		end,
	})
	StorylineTab:CreateSection("Select Map and Difficulties for maps)")
	for _, mapKey in ipairs(StorylineData.Maps) do
		StorylineTab:CreateToggle({
			Name = mapKey,
			CurrentValue = State.storylineSelectedMaps[mapKey],
			Flag = "StorylineEnable_" .. mapKey,
			Callback = function(v)
				State.storylineSelectedMaps[mapKey] = v
			end,
		})

		StorylineTab:CreateDropdown({
			Name = "Mode (" .. mapKey .. ")",
			Options = StorylineData.ModeOptions,
			CurrentOption = State.storylineSelectedMode[mapKey],
			MultipleOptions = true,
			Flag = "StorylineMode_" .. mapKey,
			Callback = function(option)
				State.storylineSelectedMode[mapKey] = option
				print(table.concat(option, ", "))
			end,
		})

		StorylineTab:CreateDropdown({
			Name = "Team (" .. mapKey .. ")",
			Options = StorylineData.TeamOptions,
			CurrentOption = State.storylineTeams[mapKey] or "slot_1",
			Flag = "StorylineTeam_" .. mapKey,
			Callback = function(option)
				State.storylineTeams[mapKey] = option[1]
			end,
		})
		StorylineTab:CreateDivider()
	end

	StorylineTab:CreateToggle({
		Name = "Enable Storyline Auto",
		CurrentValue = State.storylineEnabled or false,
		Flag = "EnableStorylineAuto",
		Callback = function(v)
			State.storylineEnabled = v
			if v then
				StorylineController.runAuto()
			else
				StorylineController.stop()
			end
		end,
	})

	-------------------------------------------------
	-- Story Boss Tab
	-------------------------------------------------
	local storyTab = Window:CreateTab("Story Boss", "sword")

	storyTab:CreateSection("Choose Boss and Difficulties")

	for _, b in ipairs(BossData.List) do
		local label = BossData.Names[b.id] or ("Boss " .. b.id)
		-- Toggle chọn boss
		storyTab:CreateToggle({
			Name = label,
			CurrentValue = false,
			Flag = "Boss_" .. b.id,
			Callback = function(state)
				State.selectedBosses[b.id] = state
				if Rayfield and type(Rayfield.Notify) == "function" then
					Rayfield:Notify({
						Title = "Boss Select",
						Content = (state and "✔ " or "✖ ") .. label,
						Duration = 1.5,
					})
				end
			end,
		})

		-- Input chọn mode (multi-mode)
		storyTab:CreateDropdown({
			Name = label .. " | difficulties",
			Options = b.modes,
			CurrentOption = State.bossSelectedModes[b.id] or {},
			MultipleOptions = true,
			Flag = "BossModes_" .. b.id,
			Callback = function(Options)
				State.bossSelectedModes[b.id] = Options
				Utils.notify("Story Boss", label .. " → " .. table.concat(Options, ","), 2)
			end,
		})
		storyTab:CreateDropdown({
			Name = label .. " | Choose Team",
			Options = BossData.TeamOptions,
			CurrentOption = State.bossTeams[b.id],
			Flag = "Team_" .. b.id,
			Callback = function(option)
				local selected = option[1] or "slot_1"
				-- ép kiểu về string để tránh lỗi concatenate
				selected = tostring(selected)
				State.bossTeams[b.id] = selected
				Utils.notify("Team Changed", label .. " → " .. selected, 2)
			end,
		})
		storyTab:CreateDivider()
	end

	storyTab:CreateSection("Fight Boss Selected(Don't enable it when run combine mode)")
	storyTab:CreateToggle({
		Name = "Auto Fight Story Boss",
		CurrentValue = false,
		Flag = "AutoFightStoryBoss",
		Callback = function(state)
			State.autoEnabledBoss = state
			if state then
				BossController.runAuto()
			else
				BossController.stopAuto()
			end
		end,
	})

	-------------------------------------------------
	-- Tower Tab
	-------------------------------------------------

	local towerTab = Window:CreateTab("Battle Tower", "tower-control")
	towerTab:CreateSection("Enter Max Retry(No retry = 1 , Default:3)")
	towerTab:CreateInput({
		Name = "Number of Retries",
		PlaceholderText = "Ex: 3",
		Flag = "BattleTowerMaxRetry",
		Callback = function(text)
			local n = tonumber(tostring(text))
			if not n or n <= 0 then
				Utils.notify("Error", "Please enter a valid number of retries (>=1)", 2)
				return
			end
			State.BtRetry = math.floor(n)
		end,
	})

	towerTab:CreateSection("Select Towers and Waves ")
	local towerWaveDropdowns = {}
	for _, mode in ipairs(TowerData.Modes) do
		local label = TowerData.ModeNames[mode] or mode

		-- Toggle chọn mode để auto đánh
		towerTab:CreateToggle({
			Name = label,
			CurrentValue = false,
			Flag = "TowerMode_" .. mode,
			Callback = function(state)
				State.selectedTowerModes[mode] = state
				if Rayfield and type(Rayfield.Notify) == "function" then
					Rayfield:Notify({
						Title = "Tower",
						Content = (state and "✔ " or "✖ ") .. label .. " selected",
						Duration = 1.5,
					})
				end
			end,
		})

		local dd = towerTab:CreateDropdown({
			Name = label .. " | Select Waves",
			Options = TowerData.Waves[mode],
			CurrentOption = (function()
				local waves = State.towerSelectedWaves[mode] or {}
				local result = {}
				for _, w in ipairs(waves) do
					table.insert(result, tostring(w))
				end
				return result
			end)(),
			MultipleOptions = true,
			Flag = "TowerWaves_" .. mode,
			Callback = function(Options)
				-- Chuyển danh sách string -> số nguyên
				local waves = {}
				for _, w in ipairs(Options) do
					table.insert(waves, tonumber(w))
				end
				State.towerSelectedWaves[mode] = waves

				Utils.notify("Tower", label .. " waves selected: " .. table.concat(Options, ", "), 2)
			end,
		})
		towerWaveDropdowns[mode] = dd
		towerTab:CreateDropdown({
			Name = label .. " | Team Slot",
			Options = TowerData.TeamOptions,
			CurrentOption = { State.towerTeams[mode] },
			Flag = "TowerTeam_" .. mode,
			Callback = function(option)
				local selected = option[1] or "slot_1"
				-- ép kiểu về string để tránh lỗi concatenate
				selected = tostring(selected)
				State.towerTeams[mode] = selected
				Utils.notify("Team Changed", label .. " → " .. selected, 2)
			end,
		})
		towerTab:CreateDivider()
	end
	towerTab:CreateInput({
		Name = "Select waves for all battle towers",
		PlaceholderText = "e.g., 1,2,3",
		Callback = function(text)
			local waves = {}
			for w in string.gmatch(text, "%d+") do
				table.insert(waves, w)
			end
			for mode, dd in pairs(towerWaveDropdowns) do
				dd:Set(waves) -- set waves cho tất cả
			end
		end,
	})

	towerTab:CreateSection("Auto Battle Tower(Don't enable when hybrid mode running)")
	towerTab:CreateToggle({
		Name = "Auto Fight Tower",
		CurrentValue = false,
		Flag = "AutoTower",
		Callback = function(state)
			State.autoEnabledTower = state
			if state then
				TowerController.runAuto()
			else
				TowerController.stopAuto()
			end
		end,
	})
	-------------------------------------------------
	-- Infinite Tower Tab
	-------------------------------------------------
	local InfiniteTab = Window:CreateTab("Infinite Tower", "infinity")

	local modeOptions = {}
	for _, key in ipairs(InfiniteData.Modes) do
		table.insert(modeOptions, InfiniteData.ModeNames[key] or key)
	end

	InfiniteTab:CreateSection("Infinite Tower Setting")
	InfiniteTab:CreateDropdown({
		Name = "Inf Team Slot",
		Options = InfiniteData.TeamOptions,
		CurrentOption = { State.InfinitieTeam or "slot_1" },
		Flag = "InfiniteTeamDropdown",
		Callback = function(option)
			local selected = option[1] or "slot_1"
			State.InfinitieTeam = tostring(selected)
			Utils.notify("INF TOWER", " Set Inf Team: " .. selected, 2)
		end,
	})
	InfiniteTab:CreateDropdown({
		Name = "Mode",
		Options = modeOptions,
		CurrentOption = { InfiniteData.ModeNames[State.selectedInfMode] },
		Flag = "InfiniteModeDropdown",
		Callback = function(option)
			for k, v in pairs(InfiniteData.ModeNames) do
				if v == option[1] then
					State.selectedInfMode = k
					break
				end
			end
			Utils.notify("Inf Tower", "Mode selected: " .. InfiniteData.ModeNames[State.selectedInfMode], 2)
		end,
	})
	InfiniteTab:CreateDivider()
	InfiniteTab:CreateInput({
		Name = "Select Floor to swap:",
		PlaceholderText = "Ex: 100",
		Flag = "FloorToSwap",
		Callback = function(text)
			local floor = tonumber(text)
			State.floorSwap = floor
		end,
	})
	InfiniteTab:CreateDropdown({
		Name = "Choose Team to Swap when reach Floor",
		Options = InfiniteData.TeamOptions,
		CurrentOption = { State.teamSwap or "slot_1" },
		Flag = "InfTeamSwap",
		Callback = function(option)
			local selected = option[1] or "slot_1"
			State.teamSwap = tostring(selected)
			Utils.notify("Inf Tower", "Swap to team" .. selected .. "when reach Floor", 2)
		end,
	})
	InfiniteTab:CreateToggle({
		Name = "Enable Swap Team when reach Floor",
		CurrentValue = State.enabledSwapTeam or false,
		Flag = "AutoSwapTeamInf",
		Callback = function(value)
			State.enabledSwapTeam = value
		end,
	})
	InfiniteTab:CreateDivider()
	InfiniteTab:CreateInput({
		Name = "Select Floor to restart",
		PlaceholderText = "Ex: 100",
		Flag = "FloorToRestart",
		Callback = function(text)
			State.floorRestart = tonumber(text)
		end,
	})
	InfiniteTab:CreateToggle({
		Name = "Enable Restart Inf when reach Floor",
		CurrentValue = State.enabledResetInf,
		Flag = "AutoRestartInf",
		Callback = function(value)
			State.enabledResetInf = value
		end,
	})

	InfiniteTab:CreateSection(" Auto Infnite Tower(Do not enable when hybrid mode is running)")
	InfiniteTab:CreateToggle({
		Name = "Auto Fight Infinite Tower",
		CurrentValue = false,
		Flag = "InfiniteAutoFight",
		Callback = function(value)
			State.autoEnabledInf = value
			if State.autoEnabledInf then
				print("Auto fight started for mode:", InfiniteData.ModeNames[State.selectedInfMode])
				InfTowerController.runAuto()
			else
				InfTowerController.pause()
			end
		end,
	})

	-------------------------------------------------
	-- Global Boss Tab
	-------------------------------------------------
	local globalBossTab = Window:CreateTab("Global Boss", "ghost")
	globalBossTab:CreateSection("Cursed Zone Settings")

	local gradeOrder = { 4, 3, 2, 1, "special" }

	globalBossTab:CreateParagraph({
		Title = "Cursed Zone Info",
		Content = "Automatically detects cursed zones and fight them.\n" .. "Priority: Special -> 1 > 2 > 3 > 4.",
	})

	globalBossTab:CreateSection("Enable Grades")
	for _, grade in ipairs(gradeOrder) do
		local name = (grade == "special") and "Special (Blood Aura)" or ("Grade " .. grade)
		globalBossTab:CreateToggle({
			Name = "Enable " .. name,
			CurrentValue = State.cursedGradeEnabled[grade],
			Flag = "enable_grade_" .. name,
			Callback = function(value)
				State.cursedGradeEnabled[grade] = value
				local icon = (grade == "special" and "🩸") or "💀"
				Utils.notify("Cursed", icon .. " " .. name .. " zones are now " .. (value and "enabled" or "disabled"), 2)
			end,
		})
	end

	globalBossTab:CreateSection("Assign Team for Each Grade")
	for _, grade in ipairs(gradeOrder) do
		local name = (grade == "special") and "Special (Blood Aura)" or ("Grade " .. grade)
		globalBossTab:CreateDropdown({
			Name = name .. " | Team Slot",
			Options = CursedZoneData.TeamOptions,
			CurrentOption = { State.cursedTeams[tostring(grade)] or "slot_1" },
			Flag = "team_grade_" .. name,
			Callback = function(option)
				State.cursedTeams[tostring(grade)] = option[1]
				local icon = (grade == "special" and "🩸") or "💀"
				Utils.notify("Cursed", icon .. " Set " .. name .. " team → " .. option[1], 2)
			end,
		})
	end

	globalBossTab:CreateSection("Auto Cursed Zone")
	globalBossTab:CreateToggle({
		Name = "Auto Fight Cursed Zones",
		CurrentValue = State.autoEnabledCursed,
		Flag = "auto_cursed_zone",
		Callback = function(value)
			State.autoEnabledCursed = value
			if value then
				Utils.notify("Cursed", "💀 Auto Cursed Zone Enabled", 2)
				CursedController.runAuto()
			else
				Utils.notify("Cursed", "🛑 Auto Cursed Zone Disabled", 2)
				CursedController.stopAuto()
			end
		end,
	})
	globalBossTab:CreateSection("Global Boss Setting")
	globalBossTab:CreateDropdown({
		Name = "Team (Boss HP < 75M)",
		Options = GlobalBossData.TeamOptions,
		CurrentOption = { State.globalBossTeamLowHP or "slot_1" },
		Flag = "GbLowHpTeam",
		Callback = function(option)
			local selected = option[1] or "slot_1"
			State.globalBossTeamLowHP = tostring(selected)
			Utils.notify("Global Boss", "Set Low HP Team: " .. selected, 2)
		end,
	})
	globalBossTab:CreateDropdown({
		Name = "Team (Boss HP ≥ 75M)",
		Options = GlobalBossData.TeamOptions,
		CurrentOption = { State.globalBossTeamHighHP or "slot_1" },
		Flag = "GbHighHpTeam",
		Callback = function(option)
			local selected = option[1] or "slot_1"
			State.globalBossTeamHighHP = tostring(selected)
			Utils.notify("Global Boss", "Set High HP Team: " .. selected, 2)
		end,
	})
	globalBossTab:CreateToggle({
		Name = "Auto Global Boss",
		CurrentValue = false,
		Flag = "AutoGlobalBoss",
		Callback = function(value)
			State.autoEnabledGb = value
			if value then
				GlobalBossController.runAuto()
			else
				GlobalBossController.stopAuto()
			end
		end,
	})
	-------------------------------------------------
	-- Hybrid Tab
	-------------------------------------------------

	local combineTab = Window:CreateTab("Hybrid Mode", "combine")

	local Label = combineTab:CreateLabel(
		"Story Boss Cooldown: \n" .. "Battle Tower Cooldown",
		4483362458,
		Color3.fromRGB(14, 128, 149),
		false
	)
	local function updatecooldown()
		while true do
			Label:Set(
				"Story Boss Cooldown: "
					.. Utils.cooldownText("StoryBoss")
					.. "\n Battle Tower Cooldown: "
					.. Utils.cooldownText("BattleTower"),
				4483362458,
				Color3.fromRGB(57, 124, 158),
				false
			)
			task.wait(1)
		end
	end
	combineTab:CreateButton({
		Name = "Press this button to show your cooldowns",
		Callback = function()
			updatecooldown()
		end,
	})

	combineTab:CreateParagraph({
		Title = "🕒 Cooldown Input ",
		Content = [[
		Enter the cooldown time using this format:
		- `xh ym zs` (hours, minutes, seconds)

		Valid examples:
		- 6h → 6 hours          - 30m → 30 minutes
		- 45s → 45 seconds      - 1h20m → 1 hour 20 minutes
		- 2h15m5s or 2H 15M 5S → 2 hours 15 minutes 5 seconds
		- 0 → reset cooldown (ready instantly)
		]],
	})
	combineTab:CreateSection("Set Cooldown Mode")
	combineTab:CreateInput({
		Name = "Set Battle Tower Cooldown",
		PlaceholderText = "Enter (e.g. 6h30m5s or 0)",
		Callback = function(text)
			local seconds = Utils.parseTimeInput(text)
			if seconds >= 0 then
				Utils.setCooldown("BattleTower", seconds)
				if seconds == 0 then
					Utils.notify("Cooldown", "Battle Tower cooldown reset to 0", 2)
				else
					Utils.notify("Cooldown", "Battle Tower cooldown set to " .. text, 2)
				end
			else
				Utils.notify("Error", "Invalid input! Example: 6h30m5s or 0", 2)
			end
		end,
	})

	combineTab:CreateInput({
		Name = "Set Story Boss Cooldown",
		PlaceholderText = "Enter (e.g. 1h30m15s or 0)",
		Callback = function(text)
			local seconds = Utils.parseTimeInput(text)
			if seconds >= 0 then
				Utils.setCooldown("StoryBoss", seconds)
				if seconds == 0 then
					Utils.notify("Cooldown", "StoryBoss cooldown reset to 0", 2)
				else
					Utils.notify("Cooldown", "StoryBoss cooldown set to " .. text, 2)
				end
			else
				Utils.notify("Error", "Invalid input! Example: 1h30m5s or 0", 2)
			end
		end,
	})

	-- Toggle chọn mode ưu tiên
	combineTab:CreateSection("Select Modes")

	for _, mode in ipairs({ "BattleTower", "StoryBoss", "GlobalBoss", "InfTower" }) do
		local m = mode
		combineTab:CreateToggle({
			Name = m,
			CurrentValue = State.combinePriority[m],
			Flag = "Combine" .. m,
			Callback = function(value)
				State.combinePriority[m] = value
				CombineModeController.setPriority(m, value)
			end,
		})
	end
	combineTab:CreateSection("Run Hybrid Mode")
	-- Toggle bật/tắt Combine Mode
	combineTab:CreateToggle({
		Name = "Run Hybrid Mode",
		CurrentValue = State.autoEnabledCombine,
		Flag = "RunCombineMode",
		Callback = function(value)
			State.autoEnabledCombine = value
			if value then
				CombineModeController.run()
			else
				CombineModeController.stop()
			end
		end,
	})
	-------------------------------------------------
	-- Ranked Tab
	-------------------------------------------------
	local rankedTab = Window:CreateTab("Ranked", "crown")
	rankedTab:CreateDropdown({
		Name = "Select Mode Rank",
		Options = { "scaled", "any" },
		CurrentOptions = { State.modeRanked },
		Flag = "ranked_mode",
		Callback = function(option)
			State.modeRanked = option[1]
			Utils.notify("Ranked", "Select mode: " .. option[1], 2)
		end,
	})
	rankedTab:CreateToggle({
		Name = "Show Rank Battle",
		CurrentValue = State.showRanked,
		Flag = "showranktoggle",
		Callback = function(value)
			State.showRanked = value
		end,
	})
	rankedTab:CreateToggle({
		Name = "Auto Selected Ranked",
		CurrentValue = false,
		Flag = "autoRanked",
		Callback = function(value)
			State.autoRanked = value
			if value then
				Ranked.runAuto()
			else
				Ranked.stopAuto()
			end
		end,
	})
	-------------------------------------------------
	-- Raid Tab
	-------------------------------------------------
	local RaidTab = Window:CreateTab("Raid", "castle")
	RaidTab:CreateSection("Auto Raid Minion")
	RaidTab:CreateToggle({
		Name = "🔥 Auto Raid Minion (Infernal + Infernal Demon)",
		CurrentValue = State.autoEnabledMinion,
		Flag = "AutoRaidMinionToggle",
		Callback = function(value)
			State.autoEnabledMinion = value
			if value then
				RaidMinionController.runAuto()
			else
				RaidMinionController.stopAuto()
			end
		end,
	})

	RaidTab:CreateSection("Auto Raid Boss")
	RaidTab:CreateDropdown({
		Name = "🎯 Select Raid Boss",
		Options = { "Creator of Flames", "Sword Deity", "Shadow Dragon", "Eternal Dragon" },
		CurrentOption = State.selectedRaidBoss or "Creator of Flames",
		Flag = "SelectRaidBossDropdown",
		Callback = function(option)
			local selectedName = option.Name or option[1] or tostring(option)
			State.selectedRaidBoss = selectedName
			Utils.notify("Raid Boss", "✅ Selected: " .. selectedName, 2)
		end,
	})

	RaidTab:CreateToggle({
		Name = "🔥 Auto Raid Boss",
		CurrentValue = State.autoEnabledRaid,
		Flag = "AutoRaidBossToggle",
		Callback = function(value)
			State.autoEnabledRaid = value
			if value then
				RaidBossController.runAuto()
			else
				RaidBossController.stopAuto()
			end
		end,
	})

	-------------------------------------------------
	-- Exploration Tab
	-------------------------------------------------
	local explorationTab = Window:CreateTab("Exploration", "ship")

	explorationTab:CreateParagraph({
		Title = "Exploration Card Input",
		Content = [[Valid Cards Name:  Green Bomber:Secret or green_bomber:secret ]],
	})

	for _, mode in ipairs(ExplorationData.Modes) do
		explorationTab:CreateSection("Mode: " .. mode:sub(1, 1):upper() .. mode:sub(2))

		-- Nếu chưa có bảng cho mode thì tạo
		State.explorationCards[mode] = State.explorationCards[mode] or { "", "", "", "" }

		for i = 1, 4 do
			explorationTab:CreateInput({
				Name = string.format("Card %d for %s mode", i, mode),
				PlaceholderText = "e.g. Green Bomber:Secret",
				CurrentValue = State.explorationCards[mode][i] or "",
				Flag = string.format("Card%d_%s", i, mode),
				Callback = function(text)
					-- Đảm bảo luôn có đủ 4 phần tử
					State.explorationCards[mode] = State.explorationCards[mode] or { "", "", "", "" }
					State.explorationCards[mode][i] = Utils.normalizeCardName(text)
					Utils.notify("Exploration", string.format("%s - Card %d saved!", mode, i), 1.5)
				end,
			})
		end

		explorationTab:CreateDivider()
	end

	explorationTab:CreateSection("⚙️ Auto Exploration")
	explorationTab:CreateToggle({
		Name = "Enable Auto Exploration",
		CurrentValue = State.autoEnabledExploration or false,
		Flag = "AutoExplorationToggle",
		Callback = function(state)
			State.autoEnabledExploration = state
			if state then
				ExplorationController.runAuto()
			else
				ExplorationController.stopAuto()
			end
		end,
	})
	-------------------------------------------------
	-- Player TAB
	-------------------------------------------------
	local PlayerTab = Window:CreateTab("Player", "users")

	PlayerTab:CreateSection("Teleport")
	for name, cframe in pairs(locations) do
		PlayerTab:CreateButton({
			Name = name,
			Callback = function()
				Utils.teleport(cframe)
			end,
		})
	end

	PlayerTab:CreateSection("Upgrade")
	PlayerTab:CreateDropdown({
		Name = "Select Upgrade Stat: ",
		Options = UpgradeData.displayName,
		CurrentOption = { State.selectedStat },
		MultipleOptions = false,
		Flag = "selectedStatUpgrade",
		Callback = function(option)
			State.selectedStat = option[1]
			print(State.selectedStat)
		end,
	})
	PlayerTab:CreateToggle({
		Name = "Auto Upgrade Stat Selected",
		CurrentValue = State.autoUpgrade,
		Flag = "autoUpgrade",
		Callback = function(value)
			State.autoUpgrade = value
			autoUpgradePoint()
		end,
	})
	PlayerTab:CreateButton({
		Name = "Reset Upgrade Points",
		Callback = function()
			local args = {
				"base",
			}
			ReplicatedStorage:WaitForChild("shared/network@eventDefinitions")
				:WaitForChild("resetUpgrades")
				:FireServer(unpack(args))
		end,
	})
	PlayerTab:CreateToggle({
		Name = "Auto Upgrade Prestige",
		CurrentValue = false,
		Flag = "autoPrestige",
		Callback = function(value)
			State.autoPrestige = value
			if value then
				local function autoUpgradePrestige()
					while State.autoPrestige do
						local args = { "prestige_luck", 1 }
						Net.upgradePoint:FireServer(unpack(args))
						task.wait(0.25)
					end
				end
				autoUpgradePrestige()
			end
		end,
	})
	PlayerTab:CreateSection("PVP")
	local PlayerListDropdown = PlayerTab:CreateDropdown({
		Name = "Select Player to send battle",
		Options = State.PlayerList,
		CurrentOption = State.selectedPlayer,
		MultipleOptions = false,
		Callback = function(option)
			if option and option[1] then
				State.selectedPlayer = option[1]
			else
				State.selectedPlayer = nil
			end
		end,
	})
	PlayerTab:CreateButton({
		Name = "Refresh Player List",
		Callback = function()
			local playerNames = {}
			for _, player in ipairs(Players:GetPlayers()) do
				table.insert(playerNames, player.Name)
			end

			State.PlayerList = playerNames
			PlayerListDropdown:Refresh(State.PlayerList)
			PlayerListDropdown:Set(LocalPlayer.Name) -- clear selection (đúng cho single dropdown)
		end,
	})
	local function startfightplayer()
		if not State.autofightplayer then
			return
		end
		while State.autofightplayer do
			local name = State.selectedPlayer
			if name and name ~= "" then
				local target = Players:FindFirstChild(name)
				if target then
					Net.fightPlayer:FireServer(target)
				else
					warn("Player không tồn tại hoặc chưa online!")
				end
			else
				warn("Chưa nhập tên player!")
			end
			local popupWait = 0
			while not Utils.isInBattlePopupPresent() and popupWait < 2 do
				if not State.autofightplayer then
					return
				end
				task.wait(0.5)
				popupWait = popupWait + 0.5
			end
			while Utils.isInBattlePopupPresent() do
				if not State.autofightplayer then
					return
				end
				task.wait(0.5)
			end
			task.wait(1)
		end
	end
	PlayerTab:CreateToggle({
		Name = "Auto Fight Selected Player",
		CurrentValue = false,
		Callback = function(value)
			State.autofightplayer = value
			if value then
				startfightplayer()
			end
		end,
	})
	-- Auto Use and Buy
	PlayerTab:CreateSection("Auto Item")

	local stopAutoMoon = false
	local potions = {
		amount = 1,
		autouse = false,
	}
	local function CheckMoonNotify()
		for _, notify in ipairs(react.notifications:GetChildren()) do
			local child4 = notify:FindFirstChild("4")
			if child4 then
				local child3 = child4:FindFirstChild("3")
				if child3 and child3:IsA("TextLabel") then
					local text = child3.Text

					for _, moon in ipairs(State.selectedMoon) do
						if string.find(string.lower(text), string.lower(moon)) then
							return true
						end
					end
				end
			end
		end
		return false
	end

	local function automooncycle()
		if not potions.autouse then
			return
		end

		task.spawn(function()
			while potions.autouse do
				stopAutoMoon = false
				print("[DEBUG] Starting potion roll loop")

				while not stopAutoMoon and potions.autouse do
					Net.useItem:FireServer("moon_cycle_reroll_potion", potions.amount)
					task.wait(0.5)

					if CheckMoonNotify() then
						print("[DEBUG] Stop auto moon because desired moon appeared")
						stopAutoMoon = true
					end
				end

				print("[DEBUG] Waiting 180s before next round")
				task.wait(180)
			end
		end)
	end
	PlayerTab:CreateDropdown({
		Name = "Amount of moon cycle potion",
		Options = { "1", "10", "50", "100", "1000" },
		CurrentOption = { "1" },
		Callback = function(value)
			potions.amount = tonumber(value[1])
		end,
	})
	local MoonOptions = {}
	for _, moon in ipairs(MoonCycleData) do
		table.insert(MoonOptions, moon.DisplayName)
	end
	PlayerTab:CreateDropdown({
		Name = "Select Moons to stop",
		Options = MoonOptions,
		CurrentOption = State.selectedMoon,
		MultipleOptions = true,
		Flag = "MoonDropdown",
		Callback = function(Options)
			State.selectedMoon = Options
		end,
	})
	PlayerTab:CreateToggle({
		Name = "Auto Moon Cycle Potion",
		CurrentValue = false,
		Flag = "AutoMoonCycle",
		Callback = function(value)
			potions.autouse = value
			automooncycle()
		end,
	})
	-- Utilities
	PlayerTab:CreateSection("Utilities")
	local autodismiss = false
	PlayerTab:CreateToggle({
		Name = "Auto Dismiss Reward Popup",
		CurrentValue = false,
		Flag = "AutoDismissToggle",
		Callback = function(value)
			autodismiss = value
			if value then
				EnableDismissReward()
				task.spawn(function()
					while autodismiss do
						task.wait(10)
						local container = rewardsPopup["3"]["2"]
						if #container:GetChildren() < 50 then triggerBtn() end
					end
				end)
			else
				DisableDismisReward()
			end
		end,
	})

	PlayerTab:CreateToggle({
		Name = "Auto Pick Up Floor",
		CurrentValue = false,
		Flag = "AutoPickUpFloorToggle",
		Callback = function(value)
			if value then
				AutoPickUp()
			else
				StopAutoPickUp()
			end
		end,
	})
	PlayerTab:CreateToggle({
		Name = "Auto Ladder",
		CurrentValue = State.autoEnabledLadder,
		Flag = "AutoLadderToggle",
		Callback = function(value)
			if value then
				teleportAndStart()
			else
				stopAuto()
			end
		end,
	})
	PlayerTab:CreateToggle({
		Name = "Auto Claim Daily Quests",
		CurrentValue = State.claimDailyQuest,
		Flag = "ClaimDailyQuestsToggle",
		Callback = function(value)
			if value then
				State.claimDailyQuest = true
				startAutoClaim()
			else
				stopAutoClaim()
			end
		end,
	})

	local activeAllLuckAndCardIndex = false
	local function activeluckandcardindex()
		activeAllLuckAndCardIndex = true
		while activeAllLuckAndCardIndex do
			Net.activateAllLuckIndex:FireServer()
			task.wait(1)
			Net.activeCardIndex:FireServer()
			task.wait(60)
		end
	end
	PlayerTab:CreateToggle({
		Name = "Auto Active All Luck and Card Index",
		CurrentValue = false,
		Flag = "AutoActiveLuckIndex",
		Callback = function(value)
			if value then
				activeluckandcardindex()
			else
				activeAllLuckAndCardIndex = false
			end
		end,
	})
	PlayerTab:CreateButton({
		Name = "Merge All Cards",
		Callback = function()
			Net.mergeCard:FireServer()
		end,
	})
	PlayerTab:CreateButton({
		Name = "Redeem All Code",
		Callback = function()
			RedeemAllCodes()
		end,
	})
	-- Misc Tab --
	local Misc = Window:CreateTab("Misc", "layers")
	Misc:CreateSection("Webhook Config")
	Misc:CreateInput({
		Name = "Discord Webhook URL",
		CurrentValue = "",
		PlaceholderText = "Enter Discord webhook URL",
		RemoveTextAfterFocusLost = true,
		Flag = "WebhookURL",
		Callback = function(text)
			State.discordWebhookURL = text
			Utils.notify("Webhook", "Webhook Url Updated", 2)
		end,
	})

	Misc:CreateButton({
		Name = "Test Webhook",
		Callback = function()
			local msgTable = {
				content = string.format(
					"✅ **Webhook test successful!**\nPlayer: `%s`\nGame: %s\nTime: %s",
					tostring(LocalPlayer and LocalPlayer.Name or "Unknown"),
					tostring(game.PlaceId),
					os.date("%Y-%m-%d %H:%M:%S")
				),
			}

			local payload = HttpService:JSONEncode(msgTable)

			print("[TestWebhook] Sending test message to Discord...")
			local ok, err = pcall(function()
				Utils.sendDiscordMessage(payload)
			end)

			if ok then
				print("[TestWebhook] ✅ Sent! Check your Discord channel.")
			else
				warn("[TestWebhook] ❌ Failed to send:", err)
			end
		end,
	})
	Misc:CreateToggle({
		Name = "Auto Send Webhook when finish all story boss/ battle tower",
		CurrentValue = State.sendWebhookBattle,
		Flag = "BattleWebhookToggle",
		Callback = function(value)
			State.sendWebhookBattle = value
		end,
	})
	Misc:CreateToggle({
		Name = "Auto Send Webhook your boss story/battle tower cooldown",
		CurrentValue = State.sendWebhookCd,
		Flag = "CdWebhookToggle",
		Callback = function(value)
			State.sendWebhookCd = value
		end,
	})
	Misc:CreateToggle({
		Name = "Auto Send Webhook your ranked results",
		CurrentValue = State.sendWebhookResult,
		Flag = "ResultWebhookToggle",
		Callback = function(value)
			State.sendWebhookResult = value
		end,
	})
	-- Auto Rejoin
	local times = {}
	for i = 10, 180, 10 do
		table.insert(times, i .. "m")
	end
	Misc:CreateSection("Auto Rejoin Setting")
	Misc:CreateDropdown({
		Name = "Rejoin Time",
		Options = times,
		CurrentOption = { "" },
		Flag = "RejoinTime",
		Callback = function(value)
			local minutes = tonumber(value[1]:match("(%d+)"))
			if minutes then
				State.timeRejoin = minutes * 60
			end
		end,
	})
	Misc:CreateToggle({
		Name = "Enable Auto Rejoin every x time",
		CurrentValue = State.enableRejoin,
		Flag = "EnableRejoin",
		Callback = function(value)
			State.enableRejoin = value
		end,
	})

	Misc:CreateButton({
		Name = "Test Rejoin Now",
		Callback = function()
			pcall(tryReconnect) -- gọi ngay, không chờ
		end,
	})
	Misc:CreateToggle({
		Name = "Auto Execute On Rejoin/Hop Server",
		CurrentValue = false,
		Flag = "autoexetoggle",
		Callback = function(value)
			if value then
				local ScriptURL =
					"https://api.junkie-development.de/api/v1/luascripts/public/23736d956dd70723dbe8b3f09221f4546e79313588368fa45cb917b0f3142d10/download"
				-- Tự động chạy lại script sau khi teleport hoặc rejoin
				if syn and syn.queue_on_teleport then
					syn.queue_on_teleport(string.format([[loadstring(game:HttpGet("%s"))()]], ScriptURL))
				elseif queue_on_teleport then
					queue_on_teleport(string.format([[loadstring(game:HttpGet("%s"))()]], ScriptURL))
				end
			end
		end,
	})
	-- Performance
	Misc:CreateSection("Performance")
	Misc:CreateToggle({
		Name = "Boost Fps",
		CurrentValue = State.boostfpsv1,
		Flag = "BoostFpsToggle",
		Callback = function(value)
			if value then
				_G.Settings = {
					Players = {
						["Ignore Me"] = true, -- Ignore your Character
						["Ignore Others"] = true,
						["Ignore Tools"] = true,
					},
					Meshes = {
						Destroy = false, -- Destroy Meshes
						LowDetail = true, -- Low detail meshes (NOT SURE IT DOES ANYTHING)
					},
					Images = {
						Invisible = true, -- Invisible Images
						LowDetail = false, -- Low detail images (NOT SURE IT DOES ANYTHING)
						Destroy = false, -- Destroy Images
					},

					["No Particles"] = true, -- Disables all ParticleEmitter, Trail, Smoke, Fire and Sparkles
					["No Camera Effects"] = true, -- Disables all PostEffect's (Camera/Lighting Effects)
					["No Explosions"] = true, -- Makes Explosion's invisible
					["No Clothes"] = true, -- Removes Clothing from the game
					["Low Water Graphics"] = true, -- Removes Water Quality
					["No Shadows"] = true, -- Remove Shadows
					["Low Rendering"] = true, -- Lower Rendering
					["Low Quality Parts"] = true, -- Lower quality parts
				}
				loadstring(game:HttpGet("https://raw.githubusercontent.com/CasperFlyModz/discord.gg-rips/main/FPSBooster.lua"))()
			end
		end,
	})

	Misc:CreateToggle({
		Name = "Boost Fps V2(better than v1 but effect visual)",
		CurrentValue = State.boostfpsv2,
		Flag = "BoostFpsV2Toggle",
		Callback = function(value)
			if value then
				_G.Settings = {
					Players = {
						["Ignore Me"] = true,
						["Ignore Others"] = true,
						["Ignore Tools"] = true,
					},
					Meshes = {
						NoMesh = true,
						NoTexture = true,
						Destroy = false,
					},
					Images = {
						Invisible = true,
						Destroy = false,
					},
					Explosions = {
						Smaller = true,
						Invisible = false, -- Not recommended for PVP games
						Destroy = true, -- Not recommended for PVP games
					},
					Particles = {
						Invisible = true,
						Destroy = false,
					},
					TextLabels = {
						LowerQuality = false,
						Invisible = false,
						Destroy = false,
					},
					MeshParts = {
						LowerQuality = true,
						Invisible = true,
						NoTexture = true,
						NoMesh = true,
						Destroy = false,
					},
					Other = {
						["No Particles"] = true,
						["FPS Cap"] = true, -- Set this true to uncap FPS
						["No Camera Effects"] = true,
						["No Clothes"] = true,
						["Low Water Graphics"] = true,
						["No Shadows"] = true,
						["Low Rendering"] = true,
						["Low Quality Parts"] = true,
						["Low Quality Models"] = true,
						["Reset Materials"] = true,
						["Lower Quality MeshParts"] = true,
						ClearNilInstances = false, -- NEW (EXPERIMENTAL)
					},
				}

				loadstring(game:HttpGet("https://raw.githubusercontent.com/CasperFlyModz/discord.gg-rips/main/FPSBooster.lua"))()
			end
		end,
	})
	Misc:CreateToggle({
		Name = "Turn Off Render 3D ( Reduce GPU)",
		CurrentValue = false,
		Flag = "DisableRenderToggle",
		Callback = function(value)
			if value then
				RunService:Set3dRenderingEnabled(false)
			else
				RunService:Set3dRenderingEnabled(true)
			end
		end,
	})

	Misc:CreateButton({
		Name = "Hide UserName(client)",
		Callback = function()
			LocalPlayer.Name = "Aqua Hub"
		end,
	})
	local Setting = Window:CreateTab("Setting", "settings")

	-- Map tên hiển thị sang Theme Identifier (cần đúng Identifier của Rayfield)
	local themeMap = {
		["Default"] = "Default",
		["Amber Glow"] = "AmberGlow",
		["Amethyst"] = "Amethyst",
		["Bloom"] = "Bloom",
		["Dark Blue"] = "DarkBlue",
		["Green"] = "Green",
		["Light"] = "Light",
		["Ocean"] = "Ocean",
		["Serenity"] = "Serenity",
	}
	Setting:CreateToggle({
		Name = "Auto Minimize UI",
		CurrentValue = false,
		Flag = "minimizetoggle",
		Callback = function(value)
			if value then
				Rayfield:SetVisibility(false)
			end
		end,
	})

	-- Dropdown chọn Theme
	Setting:CreateDropdown({
		Name = "Select Theme",
		Options = { "Default", "Amber Glow", "Amethyst", "Bloom", "Dark Blue", "Green", "Light", "Ocean", "Serenity" },
		CurrentOption = "Default",
		Flag = "SelectedTheme",
		MultipleOptions = false,
		Callback = function(selected)
			local themeId = themeMap[selected[1]]
			if themeId then
				-- Chỉ đổi theme khi themeId hợp lệ
				Window.ModifyTheme(themeId)
			else
				warn("Theme identifier not found for: " .. selected[1])
			end
		end,
	})
	-- Load config safely
	pcall(function()
		Rayfield:LoadConfiguration()
	end)
