--
-- 海鳗插件：实用小工具
--

HM_ToolBox = {
	bAutoRepair = false,	-- 打开 NPC 后自动修理
	bSellGray = false,		-- 打开 NPC 后自动卖掉灰色物品
	bIgnoreSell = true,		-- 卖蓝色装备免确认
	--bIgnoreRaid = false,	-- 自动团队确认
	bIgnoreTrade = false,	-- 自动交易确认 TradingInvite
	bIgnoreHorse = false,	-- 自动双骑确认  OnInviteFollow
	bQuestItem = true,		-- 自动采集任务物品
	bCustomDoodad = false,	-- 自动采集指定物品
	szCustomDoodad = _L["HuiZhenYan"],
	nBroadType = 0,
	szBroadText = "Hi",
}

for k, _ in pairs(HM_ToolBox) do
	RegisterCustomData("HM_ToolBox." .. k)
end
HM_ToolBox.bIgnoreRaid = false

---------------------------------------------------------------------
-- 本地函数和变量
---------------------------------------------------------------------
local _HM_ToolBox = {
	nRaidID = 0,
	tDoodad = {},	-- 待处理的 doodad 列表
}

-- 自动卖灰色
_HM_ToolBox.SellGrayItem = function(nNpcID, nShopID)
	local me = GetClientPlayer()
	for i = 1, 5 do
		local dwBox = INVENTORY_INDEX.PACKAGE + i - 1
		local dwSize = me.GetBoxSize(dwBox) - 1
		for dwX = 0, dwSize, 1 do
			local item = GetPlayerItem(me, dwBox, dwX)
			if item and item.nQuality == 0 then
				local nCount = 1
				if item.nGenre == ITEM_GENRE.EQUIPMENT and item.nSub == EQUIPMENT_SUB.ARROW then --远程武器
					nCount = item.nCurrentDurability
				elseif item.bCanStack then
					nCount = item.nStackNum
				end
				SellItem(nNpcID, nShopID, dwBox, dwX, nCount)
			end
		end
	end
end

-- 检查有没有权限
_HM_ToolBox.HasBroadPerm = function()
	local tong, me = GetTongClient(), GetClientPlayer()
	if me and me.dwTongID ~= 0 and tong then
		local info = tong.GetMemberInfo(me.dwID)
		return tong.CheckBaseOperationGroup(info.nGroupID, 1)
	end
	return false
end

-- 群发团队密聊
_HM_ToolBox.SendBroadRaid = function()
	local team, me = GetClientTeam(), GetClientPlayer()
	if not team or not me or not me.IsInParty() then
		return
	end
	for _, dwID in ipairs(team.GetTeamMemberList()) do
		if dwID ~= me.dwID then
			local info = team.GetMemberInfo(dwID)
			if info and info.bIsOnLine and dwID ~= me.dwID then
				HM.Talk(info.szName, _L["[Party BC] "] .. HM_ToolBox.szBroadText)
			end
		end
	end
end

-- 群发广播
_HM_ToolBox.SendBroadCast = function()
	if HM_ToolBox.nBroadType == 3 then
		return _HM_ToolBox.SendBroadRaid()
	end
	local tong, me = GetTongClient(), GetClientPlayer()
	if not tong or not me or me.dwTongID == 0 then
		return
	end
	local dwMapID, szText, nType = me.GetScene().dwMapID, HM_ToolBox.szBroadText, HM_ToolBox.nBroadType
	local aPlayer = tong.GetMemberList(false, "name", false, -1, -1)
	for _, v in pairs(aPlayer) do
		local info = tong.GetMemberInfo(v)
		if nType == 0 or (nType == 1 and dwMapID ~= info.dwMapID) or (nType == 2 and dwMapID == info.dwMapID) then
			HM.Talk(info.szName, _L["[Guild BC] "] .. szText)
		end
	end
end

-------------------------------------
-- 事件处理
-------------------------------------
_HM_ToolBox.OnOpenShop = function()
	local nNpcID, nShopID = arg4, arg0
	if arg3 and HM_ToolBox.bAutoRepair then
		if GetRepairAllItemsPrice(nNpcID, nShopID) > 0 then
			RepairAllItems(nNpcID, nShopID)
		end
	end
	if HM_ToolBox.bSellGray then
		_HM_ToolBox.SellGrayItem(nNpcID, nShopID)
	end
end

_HM_ToolBox.OnAutoConfirm = function()
	if HM_ToolBox.bIgnoreSell then
		HM.DoMessageBox("SellItemSure")
	end
	if HM_ToolBox.bIgnoreRaid then
		HM.DoMessageBox("ReadyConfirm" .. _HM_ToolBox.nRaidID)
	end
	if HM_ToolBox.bIgnoreTrade then
		HM.DoMessageBox("TradingInvite")
	end
	if HM_ToolBox.bIgnoreHorse then
		HM.DoMessageBox("OnInviteFollow")
	end
end

_HM_ToolBox.OnAutoDoodad = function()
	local me = GetClientPlayer()
	if not me or me.bFightState or me.GetOTActionState() ~= 0 or me.bOnHorse
		or (me.nMoveState ~= MOVE_STATE.ON_STAND and me.nMoveState ~= MOVE_STATE.ON_FLOAT)
	then
		return
	end
	for k, v in pairs(_HM_ToolBox.tDoodad) do
		local d, bKeep, bInteract = GetDoodad(k), false, false
		--if d and d.nKind ~= DOODAD_KIND.CORPSE and d.nKind ~= DOODAD_KIND.NPCDROP then
		if d and d.nKind ~= DOODAD_KIND.NPCDROP then
			if (HM_ToolBox.bQuestItem and d.HaveQuest(me.dwID))
				or (HM_ToolBox.bCustomDoodad and StringFindW("|" .. HM_ToolBox.szCustomDoodad .. "|", "|" .. d.szName .. "|"))
			then
				bKeep = v < 4
				if d.CanDialog(me) then
					_HM_ToolBox.tDoodad[k] = v + 1
					bInteract = true
				end
			end
		end
		if not bKeep then
			_HM_ToolBox.tDoodad[k] = nil
		end
		if bInteract then
			return InteractDoodad(k)
		end
	end
end

-------------------------------------
-- 设置界面
-------------------------------------
_HM_ToolBox.PS = {}

-- init
_HM_ToolBox.PS.OnPanelActive = function(frame)
	local ui, nX = HM.UI(frame), 0
	ui:Append("Text", { txt = _L["Shop NPC"], x = 0, y = 0, font = 27 })
	ui:Append("WndCheckBox", { txt = _L["Auto repair all equipments when open shop"], x = 10, y = 28, checked = HM_ToolBox.bAutoRepair })
	:Click(function(bChecked)
		HM_ToolBox.bAutoRepair = bChecked
	end)
	ui:Append("WndCheckBox", { txt = _L["Auto sell all grey items when open shop"], x = 10, y = 56, checked = HM_ToolBox.bSellGray })
	:Click(function(bChecked)
		HM_ToolBox.bSellGray = bChecked
	end)
	-- auto confirm
	ui:Append("Text", { txt = _L["Auto feature"], x = 0, y = 92, font = 27 })
	nX = ui:Append("WndCheckBox", { txt = _L["Auto confirm for selling blue level item"], x = 10, y = 120, checked = HM_ToolBox.bIgnoreSell })
	:Click(function(bChecked)
		HM_ToolBox.bIgnoreSell = bChecked
	end):Pos_()
	ui:Append("WndCheckBox", { txt = _L["Auto confirm for team ready"], x = nX + 10, y = 120, checked = HM_ToolBox.bIgnoreRaid })
	:Enable(false):Click(function(bChecked)
		HM_ToolBox.bIgnoreRaid = bChecked
	end)
	ui:Append("WndCheckBox", { txt = _L["Auto confirm for trade request"], x = 10, y = 148, checked = HM_ToolBox.bIgnoreTrade })
	:Click(function(bChecked)
		HM_ToolBox.bIgnoreTrade = bChecked
	end)
	ui:Append("WndCheckBox", { txt = _L["Auto confirm for ridding horse"], x = nX + 10, y = 148, checked = HM_ToolBox.bIgnoreHorse })
	:Click(function(bChecked)
		HM_ToolBox.bIgnoreHorse = bChecked
	end)
	-- auto doodad
	ui:Append("WndCheckBox", { txt = _L["Auto interact quest doodad"], x = 10, y = 176, checked = HM_ToolBox.bQuestItem })
	:Click(function(bChecked)
		HM_ToolBox.bQuestItem = bChecked
	end)
	nX = ui:Append("WndCheckBox", { txt = _L["Auto interact specified doodad"], x = 10, y = 204, checked = HM_ToolBox.bCustomDoodad })
	:Click(function(bChecked)
		HM_ToolBox.bCustomDoodad = bChecked
		ui:Fetch("Edit_Doodad"):Enable(bChecked)
	end):Pos_()
	ui:Append("WndEdit", "Edit_Doodad", { x = nX + 10, y = 204, limit = 1024, h = 27, w = 260 })
	:Text(HM_ToolBox.szCustomDoodad):Enable(HM_ToolBox.bCustomDoodad)
	:Change(function(szText)
		HM_ToolBox.szCustomDoodad = szText
	end)
	-- tong broadcast
	ui:Append("Text", { txt = _L["Group whisper oline (Guild perm required)"], x = 0, y = 240, font = 27 })
	ui:Append("WndEdit", "Edit_Msg", { x = 10, y = 268, limit = 1024, multi = true, h = 50, w = 480, txt = HM_ToolBox.szBroadText })
	:Change(function(szText) HM_ToolBox.szBroadText = szText end)
	local nX = ui:Append("WndRadioBox", { txt = _L["Online"], checked = HM_ToolBox.nBroadType == 0, group = "Broad" })
	:Pos(10, 324):Click(function(b) if b then HM_ToolBox.nBroadType = 0  end end):Pos_()
	nX = ui:Append("WndRadioBox", { txt = _L["Other map"], checked = HM_ToolBox.nBroadType == 1, group = "Broad" })
	:Pos(10 + nX, 324):Click(function(b) if b then HM_ToolBox.nBroadType = 1  end end):Pos_()
	nX = ui:Append("WndRadioBox", { txt = _L["Current map"], checked = HM_ToolBox.nBroadType == 2, group = "Broad" })
	:Pos(10 + nX, 324):Click(function(b) if b then HM_ToolBox.nBroadType = 2 end end):Pos_()
	nX = ui:Append("WndRadioBox", { txt = _L["Team"], checked = HM_ToolBox.nBroadType == 3, group = "Broad" })
	:Pos(10 + nX, 324):Click(function(b) if b then HM_ToolBox.nBroadType = 3 end end):Pos_()
	ui:Append("WndButton", { txt = _L["Submit"], x = nX + 10, y = 325 })
	:Enable(_HM_ToolBox.HasBroadPerm()):Click(_HM_ToolBox.SendBroadCast)
end

---------------------------------------------------------------------
-- 注册事件、初始化
---------------------------------------------------------------------
HM.RegisterEvent("RIAD_READY_CONFIRM_RECEIVE_QUESTION", function()
	_HM_ToolBox.nRaidID = arg0
end)
HM.RegisterEvent("SHOP_OPENSHOP", _HM_ToolBox.OnOpenShop)
HM.RegisterEvent("DOODAD_ENTER_SCENE", function() _HM_ToolBox.tDoodad[arg0] = 0 end)
HM.RegisterEvent("DOODAD_LEAVE_SCENE", function() _HM_ToolBox.tDoodad[arg0] = nil end)
HM.BreatheCall("AutoConfirm", _HM_ToolBox.OnAutoConfirm, 130)
HM.BreatheCall("AutoDoodad", _HM_ToolBox.OnAutoDoodad)

-- add to HM collector
HM.RegisterPanel(_L["Misc toolbox"], 352, _L["Others"], _HM_ToolBox.PS)
