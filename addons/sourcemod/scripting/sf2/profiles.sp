#if defined _sf2_profiles_included
 #endinput
#endif
#define _sf2_profiles_included

#define FILE_PROFILES "configs/sf2/profiles.cfg"

static Handle:g_hBossProfileList = INVALID_HANDLE;
static Handle:g_hSelectableBossProfileList = INVALID_HANDLE;

static Handle:g_hBossProfileNames = INVALID_HANDLE;
static Handle:g_hBossProfileData = INVALID_HANDLE;

#if defined METHODMAPS

methodmap SF2BossProfile
{
	property int Index
	{
		public get() { return _:this; }
	}
	
	property int UniqueProfileIndex
	{
		public get() { return GetBossProfileUniqueProfileIndex(this.Index); }
	}
	
	property int Skin
	{
		public get() { return GetBossProfileSkin(this.Index); }
	}
	
	property int BodyGroups
	{
		public get() { return GetBossProfileBodyGroups(this.Index); }
	}
	
	property float ModelScale
	{
		public get() { return GetBossProfileModelScale(this.Index); }
	}
	
	property int Type
	{
		public get() { return GetBossProfileType(this.Index); }
	}
	
	property int Flags
	{
		public get() { return GetBossProfileFlags(this.Index); }
	}
	
	property float SearchRadius
	{
		public get() { return GetBossProfileSearchRadius(this.Index); }
	}
	
	property float FOV
	{
		public get() { return GetBossProfileFOV(this.Index); }
	}
	
	property float TurnRate
	{
		public get() { return GetBossProfileTurnRate(this.Index); }
	}
	
	property float AngerStart
	{
		public get() { return GetBossProfileAngerStart(this.Index); }
	}
	
	property float AngerAddOnPageGrab
	{
		public get() { return GetBossProfileAngerAddOnPageGrab(this.Index); }
	}
	
	property float AngerAddOnPageGrabTimeDiff
	{
		public get() { return GetBossProfileAngerPageGrabTimeDiff(this.Index); }
	}
	
	property float InstantKillRadius
	{
		public get() { return GetBossProfileInstantKillRadius(this.Index); }
	}
	
	property float ScareRadius
	{
		public get() { return GetBossProfileScareRadius(this.Index); }
	}
	
	property float ScareCooldown
	{
		public get() { return GetBossProfileScareCooldown(this.Index); }
	}
	
	property int TeleportType
	{
		public get() { return GetBossProfileTeleportType(this.Index); }
	}
	
	public float GetSpeed(int difficulty)
	{
		return GetBossProfileSpeed(this.Index, difficulty);
	}
	
	public float GetMaxSpeed(int difficulty)
	{
		return GetBossProfileMaxSpeed(this.Index, difficulty);
	}
	
	public void GetEyePositionOffset(float buffer[3])
	{
		GetBossProfileEyePositionOffset(this.Index, buffer);
	}
	
	public void GetEyeAngleOffset(float buffer[3])
	{
		GetBossProfileEyeAngleOffset(this.Index, buffer);
	}
}

#endif

#include "sf2/profiles/profile_chaser.sp"

enum
{
	BossProfileData_UniqueProfileIndex,
	BossProfileData_Type,
	BossProfileData_ModelScale,
	BossProfileData_Skin,
	BossProfileData_Body,
	BossProfileData_Flags,
	
	BossProfileData_SpeedEasy,
	BossProfileData_SpeedNormal,
	BossProfileData_SpeedHard,
	BossProfileData_SpeedInsane,
	
	BossProfileData_WalkSpeedEasy,
	BossProfileData_WalkSpeedNormal,
	BossProfileData_WalkSpeedHard,
	BossProfileData_WalkSpeedInsane,
	
	BossProfileData_AirSpeedEasy,
	BossProfileData_AirSpeedNormal,
	BossProfileData_AirSpeedHard,
	BossProfileData_AirSpeedInsane,
	
	BossProfileData_MaxSpeedEasy,
	BossProfileData_MaxSpeedNormal,
	BossProfileData_MaxSpeedHard,
	BossProfileData_MaxSpeedInsane,
	
	BossProfileData_MaxWalkSpeedEasy,
	BossProfileData_MaxWalkSpeedNormal,
	BossProfileData_MaxWalkSpeedHard,
	BossProfileData_MaxWalkSpeedInsane,
	
	BossProfileData_MaxAirSpeedEasy,
	BossProfileData_MaxAirSpeedNormal,
	BossProfileData_MaxAirSpeedHard,
	BossProfileData_MaxAirSpeedInsane,
	
	BossProfileData_SearchRange,
	BossProfileData_FieldOfView,
	BossProfileData_TurnRate,
	BossProfileData_EyePosOffsetX,
	BossProfileData_EyePosOffsetY,
	BossProfileData_EyePosOffsetZ,
	BossProfileData_EyeAngOffsetX,
	BossProfileData_EyeAngOffsetY,
	BossProfileData_EyeAngOffsetZ,
	BossProfileData_AngerStart,
	BossProfileData_AngerAddOnPageGrab,
	BossProfileData_AngerPageGrabTimeDiffReq,
	BossProfileData_InstantKillRadius,
	
	BossProfileData_ScareRadius,
	BossProfileData_ScareCooldown,
	
	BossProfileData_TeleportType,
	BossProfileData_MaxStats
};

InitializeBossProfiles()
{
	g_hBossProfileNames = CreateTrie();
	g_hBossProfileData = CreateArray(BossProfileData_MaxStats);
	
	InitializeChaserProfiles();
}

BossProfilesOnMapEnd()
{
	ClearBossProfiles();
}

/**
 *	Clears all data and memory currently in use by all boss profiles.
 */
ClearBossProfiles()
{
	if (g_hBossProfileList != INVALID_HANDLE)
	{
		CloseHandle(g_hBossProfileList);
		g_hBossProfileList = INVALID_HANDLE;
	}
	
	if (g_hSelectableBossProfileList != INVALID_HANDLE)
	{
		CloseHandle(g_hSelectableBossProfileList);
		g_hSelectableBossProfileList = INVALID_HANDLE;
	}
	
	ClearTrie(g_hBossProfileNames);
	ClearArray(g_hBossProfileData);
	
	ClearChaserProfiles();
}

ReloadBossProfiles()
{
	if (g_hConfig != INVALID_HANDLE)
	{
		CloseHandle(g_hConfig);
		g_hConfig = INVALID_HANDLE;
	}
	
	// Clear and reload the lists.
	ClearBossProfiles();
	
	if (g_hBossProfileList == INVALID_HANDLE)
	{
		g_hBossProfileList = CreateArray(SF2_MAX_PROFILE_NAME_LENGTH);
	}
	
	if (g_hSelectableBossProfileList == INVALID_HANDLE)
	{
		g_hSelectableBossProfileList = CreateArray(SF2_MAX_PROFILE_NAME_LENGTH);
	}
	
	decl String:buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, sizeof(buffer), FILE_PROFILES);
	new Handle:kv = CreateKeyValues("root");
	if (!FileToKeyValues(kv, buffer))
	{
		CloseHandle(kv);
		LogSF2Message("Boss profiles config file not found! No boss profiles will be loaded.");
	}
	else
	{
		LogSF2Message("Loading boss profiles from config file...");
	
		KvRewind(kv);
		if (KvGotoFirstSubKey(kv))
		{
			g_hConfig = kv;
			
			decl String:sProfile[SF2_MAX_PROFILE_NAME_LENGTH];
			decl String:sProfileLoadFailReason[512];
			
			new iLoadedCount = 0;
			
			do
			{
				KvGetSectionName(g_hConfig, sProfile, sizeof(sProfile));
				if (LoadBossProfile(sProfile, sProfileLoadFailReason, sizeof(sProfileLoadFailReason)))
				{
					iLoadedCount++;
					LogSF2Message("%s...", sProfile);
				}
				else
				{
					LogSF2Message("%s...FAILED (reason: %s)", sProfile, sProfileLoadFailReason);
				}
			}
			while (KvGotoNextKey(g_hConfig));
			
			LogSF2Message("Loaded %d boss profile(s) from config file!", iLoadedCount);
		}
		else
		{
			CloseHandle(kv);
			
			LogSF2Message("No boss profiles detected in config file! No boss profiles will be loaded.");
		}
	}
}

/**
 *	Loads a profile in the current KeyValues position in g_hConfig.
 */
static bool:LoadBossProfile(const String:sProfile[], String:sLoadFailReasonBuffer[], iLoadFailReasonBufferLen)
{
	new iBossType = KvGetNum(g_hConfig, "type", SF2BossType_Unknown);
	if (iBossType == SF2BossType_Unknown || iBossType >= SF2BossType_MaxTypes) 
	{
		Format(sLoadFailReasonBuffer, iLoadFailReasonBufferLen, "boss type is unknown!");
		return false;
	}
	
	new Float:flBossModelScale = KvGetFloat(g_hConfig, "model_scale", 1.0);
	if (flBossModelScale <= 0.0)
	{
		Format(sLoadFailReasonBuffer, iLoadFailReasonBufferLen, "model_scale must be a value greater than 0!");
		return false;
	}
	
	new iBossSkin = KvGetNum(g_hConfig, "skin");
	if (iBossSkin < 0)
	{
		Format(sLoadFailReasonBuffer, iLoadFailReasonBufferLen, "skin must be a value that is at least 0!");
		return false;
	}
	
	new iBossBodyGroups = KvGetNum(g_hConfig, "body");
	if (iBossBodyGroups < 0)
	{
		Format(sLoadFailReasonBuffer, iLoadFailReasonBufferLen, "body must be a value that is at least 0!");
		return false;
	}
	
	new Float:flBossAngerStart = KvGetFloat(g_hConfig, "anger_start", 1.0);
	if (flBossAngerStart < 0.0)
	{
		Format(sLoadFailReasonBuffer, iLoadFailReasonBufferLen, "anger_start must be a value that is at least 0!");
		return false;
	}
	
	new Float:flBossInstantKillRadius = KvGetFloat(g_hConfig, "kill_radius");
	if (flBossInstantKillRadius < 0.0)
	{
		Format(sLoadFailReasonBuffer, iLoadFailReasonBufferLen, "kill_radius must be a value that is at least 0!");
		return false;
	}
	
	new Float:flBossScareRadius = KvGetFloat(g_hConfig, "scare_radius");
	if (flBossScareRadius < 0.0)
	{
		Format(sLoadFailReasonBuffer, iLoadFailReasonBufferLen, "scare_radius must be a value that is at least 0!");
		return false;
	}
	
	new iBossTeleportType = KvGetNum(g_hConfig, "teleport_type");
	if (iBossTeleportType < 0)
	{
		Format(sLoadFailReasonBuffer, iLoadFailReasonBufferLen, "unknown teleport type!");
		return false;
	}
	
	new Float:flBossFOV = KvGetFloat(g_hConfig, "fov", 90.0);
	if (flBossFOV < 0.0)
	{
		flBossFOV = 0.0;
	}
	else if (flBossFOV > 360.0)
	{
		flBossFOV = 360.0;
	}
	
	new Float:flBossMaxTurnRate = KvGetFloat(g_hConfig, "turnrate", 90.0);
	if (flBossMaxTurnRate < 0.0)
	{
		flBossMaxTurnRate = 0.0;
	}
	
	new Float:flBossScareCooldown = KvGetFloat(g_hConfig, "scare_cooldown");
	if (flBossScareCooldown < 0.0)
	{
		// clamp value 
		flBossScareCooldown = 0.0;
	}
	
	new Float:flBossAngerAddOnPageGrab = KvGetFloat(g_hConfig, "anger_add_on_page_grab", -1.0);
	if (flBossAngerAddOnPageGrab < 0.0)
	{
		flBossAngerAddOnPageGrab = KvGetFloat(g_hConfig, "anger_page_add", -1.0);		// backwards compatibility
		if (flBossAngerAddOnPageGrab < 0.0)
		{
			flBossAngerAddOnPageGrab = 0.0;
		}
	}
	
	new Float:flBossAngerPageGrabTimeDiffReq = KvGetFloat(g_hConfig, "anger_req_page_grab_time_diff", -1.0);
	if (flBossAngerPageGrabTimeDiffReq < 0.0)
	{
		flBossAngerPageGrabTimeDiffReq = KvGetFloat(g_hConfig, "anger_page_time_diff", -1.0);		// backwards compatibility
		if (flBossAngerPageGrabTimeDiffReq < 0.0)
		{
			flBossAngerPageGrabTimeDiffReq = 0.0;
		}
	}
	
	new Float:flBossSearchRadius = KvGetFloat(g_hConfig, "search_radius", -1.0);
	if (flBossSearchRadius < 0.0)
	{
		flBossSearchRadius = KvGetFloat(g_hConfig, "search_range", -1.0);		// backwards compatibility
		if (flBossSearchRadius < 0.0)
		{
			flBossSearchRadius = 0.0;
		}
	}
	
	new Float:flBossDefaultSpeed = KvGetFloat(g_hConfig, "speed", 150.0);
	new Float:flBossSpeedEasy = KvGetFloat(g_hConfig, "speed_easy", flBossDefaultSpeed);
	new Float:flBossSpeedHard = KvGetFloat(g_hConfig, "speed_hard", flBossDefaultSpeed);
	new Float:flBossSpeedInsane = KvGetFloat(g_hConfig, "speed_insane", flBossDefaultSpeed);
	
	new Float:flBossDefaultMaxSpeed = KvGetFloat(g_hConfig, "speed_max", 150.0);
	new Float:flBossMaxSpeedEasy = KvGetFloat(g_hConfig, "speed_max_easy", flBossDefaultMaxSpeed);
	new Float:flBossMaxSpeedHard = KvGetFloat(g_hConfig, "speed_max_hard", flBossDefaultMaxSpeed);
	new Float:flBossMaxSpeedInsane = KvGetFloat(g_hConfig, "speed_max_insane", flBossDefaultMaxSpeed);
	
	decl Float:flBossEyePosOffset[3];
	KvGetVector(g_hConfig, "eye_pos", flBossEyePosOffset);
	
	decl Float:flBossEyeAngOffset[3];
	KvGetVector(g_hConfig, "eye_ang_offset", flBossEyeAngOffset);
	
	// Parse through flags.
	new iBossFlags = 0;
	if (KvGetNum(g_hConfig, "static_shake")) iBossFlags |= SFF_HASSTATICSHAKE;
	if (KvGetNum(g_hConfig, "static_on_look")) iBossFlags |= SFF_STATICONLOOK;
	if (KvGetNum(g_hConfig, "static_on_radius")) iBossFlags |= SFF_STATICONRADIUS;
	if (KvGetNum(g_hConfig, "proxies")) iBossFlags |= SFF_PROXIES;
	if (KvGetNum(g_hConfig, "jumpscare")) iBossFlags |= SFF_HASJUMPSCARE;
	if (KvGetNum(g_hConfig, "sound_sight_enabled")) iBossFlags |= SFF_HASSIGHTSOUNDS;
	if (KvGetNum(g_hConfig, "sound_static_loop_local_enabled")) iBossFlags |= SFF_HASSTATICLOOPLOCALSOUND;
	if (KvGetNum(g_hConfig, "view_shake", 1)) iBossFlags |= SFF_HASVIEWSHAKE;
	if (KvGetNum(g_hConfig, "copy")) iBossFlags |= SFF_COPIES;
	if (KvGetNum(g_hConfig, "wander_move", 1)) iBossFlags |= SFF_WANDERMOVE;
	
	// Try validating unique profile.
	new iUniqueProfileIndex = -1;
	
	switch (iBossType)
	{
		case SF2BossType_Chaser:
		{
			if (!LoadChaserBossProfile(sProfile, iUniqueProfileIndex, sLoadFailReasonBuffer, iLoadFailReasonBufferLen))
			{
				return false;
			}
		}
	}
	
	// Add to our array.
	new iIndex = PushArrayCell(g_hBossProfileData, -1);
	SetTrieValue(g_hBossProfileNames, sProfile, iIndex);
	
	SetArrayCell(g_hBossProfileData, iIndex, iUniqueProfileIndex, BossProfileData_UniqueProfileIndex);
	
	SetArrayCell(g_hBossProfileData, iIndex, iBossType, BossProfileData_Type);
	SetArrayCell(g_hBossProfileData, iIndex, flBossModelScale, BossProfileData_ModelScale);
	SetArrayCell(g_hBossProfileData, iIndex, iBossSkin, BossProfileData_Skin);
	SetArrayCell(g_hBossProfileData, iIndex, iBossBodyGroups, BossProfileData_Body);
	
	SetArrayCell(g_hBossProfileData, iIndex, iBossFlags, BossProfileData_Flags);
	
	SetArrayCell(g_hBossProfileData, iIndex, flBossDefaultSpeed, BossProfileData_SpeedNormal);
	SetArrayCell(g_hBossProfileData, iIndex, flBossSpeedEasy, BossProfileData_SpeedEasy);
	SetArrayCell(g_hBossProfileData, iIndex, flBossSpeedHard, BossProfileData_SpeedHard);
	SetArrayCell(g_hBossProfileData, iIndex, flBossSpeedInsane, BossProfileData_SpeedInsane);
	
	SetArrayCell(g_hBossProfileData, iIndex, flBossDefaultMaxSpeed, BossProfileData_MaxSpeedNormal);
	SetArrayCell(g_hBossProfileData, iIndex, flBossMaxSpeedEasy, BossProfileData_MaxSpeedEasy);
	SetArrayCell(g_hBossProfileData, iIndex, flBossMaxSpeedHard, BossProfileData_MaxSpeedHard);
	SetArrayCell(g_hBossProfileData, iIndex, flBossMaxSpeedInsane, BossProfileData_MaxSpeedInsane);
	
	SetArrayCell(g_hBossProfileData, iIndex, flBossEyePosOffset[0], BossProfileData_EyePosOffsetX);
	SetArrayCell(g_hBossProfileData, iIndex, flBossEyePosOffset[1], BossProfileData_EyePosOffsetY);
	SetArrayCell(g_hBossProfileData, iIndex, flBossEyePosOffset[2], BossProfileData_EyePosOffsetZ);
	
	SetArrayCell(g_hBossProfileData, iIndex, flBossEyeAngOffset[0], BossProfileData_EyeAngOffsetX);
	SetArrayCell(g_hBossProfileData, iIndex, flBossEyeAngOffset[1], BossProfileData_EyeAngOffsetY);
	SetArrayCell(g_hBossProfileData, iIndex, flBossEyeAngOffset[2], BossProfileData_EyeAngOffsetZ);
	
	SetArrayCell(g_hBossProfileData, iIndex, flBossAngerStart, BossProfileData_AngerStart);
	SetArrayCell(g_hBossProfileData, iIndex, flBossAngerAddOnPageGrab, BossProfileData_AngerAddOnPageGrab);
	SetArrayCell(g_hBossProfileData, iIndex, flBossAngerPageGrabTimeDiffReq, BossProfileData_AngerPageGrabTimeDiffReq);
	
	SetArrayCell(g_hBossProfileData, iIndex, flBossInstantKillRadius, BossProfileData_InstantKillRadius);
	
	SetArrayCell(g_hBossProfileData, iIndex, flBossScareRadius, BossProfileData_ScareRadius);
	SetArrayCell(g_hBossProfileData, iIndex, flBossScareCooldown, BossProfileData_ScareCooldown);
	
	SetArrayCell(g_hBossProfileData, iIndex, iBossTeleportType, BossProfileData_TeleportType);
	
	SetArrayCell(g_hBossProfileData, iIndex, flBossSearchRadius, BossProfileData_SearchRange);
	SetArrayCell(g_hBossProfileData, iIndex, flBossFOV, BossProfileData_FieldOfView);
	SetArrayCell(g_hBossProfileData, iIndex, flBossMaxTurnRate, BossProfileData_TurnRate);
	
	// Add to the boss list.
	PushArrayString(GetBossProfileList(), sProfile);
	
	if (bool:KvGetNum(g_hConfig, "enable_random_selection", 1))
	{
		// Add to the selectable boss list.
		PushArrayString(GetSelectableBossProfileList(), sProfile);
	}
	
	if (KvGotoFirstSubKey(g_hConfig))
	{
		decl String:s2[64], String:s3[64], String:s4[PLATFORM_MAX_PATH], String:s5[PLATFORM_MAX_PATH];
		
		do
		{
			KvGetSectionName(g_hConfig, s2, sizeof(s2));
			
			if (!StrContains(s2, "sound_"))
			{
				for (new i = 1;; i++)
				{
					IntToString(i, s3, sizeof(s3));
					KvGetString(g_hConfig, s3, s4, sizeof(s4));
					if (!s4[0]) break;
					
					PrecacheSound2(s4);
				}
			}
			else if (StrEqual(s2, "download"))
			{
				for (new i = 1;; i++)
				{
					IntToString(i, s3, sizeof(s3));
					KvGetString(g_hConfig, s3, s4, sizeof(s4));
					if (!s4[0]) break;
					
					AddFileToDownloadsTable(s4);
				}
			}
			else if (StrEqual(s2, "mod_precache"))
			{
				for (new i = 1;; i++)
				{
					IntToString(i, s3, sizeof(s3));
					KvGetString(g_hConfig, s3, s4, sizeof(s4));
					if (!s4[0]) break;
					
					PrecacheModel(s4, true);
				}
			}
			else if (StrEqual(s2, "mat_download"))
			{	
				for (new i = 1;; i++)
				{
					IntToString(i, s3, sizeof(s3));
					KvGetString(g_hConfig, s3, s4, sizeof(s4));
					if (!s4[0]) break;
					
					Format(s5, sizeof(s5), "%s.vtf", s4);
					AddFileToDownloadsTable(s5);
					Format(s5, sizeof(s5), "%s.vmt", s4);
					AddFileToDownloadsTable(s5);
				}
			}
			else if (StrEqual(s2, "mod_download"))
			{
				static const String:extensions[][] = { ".mdl", ".phy", ".dx80.vtx", ".dx90.vtx", ".sw.vtx", ".vvd" };
				
				for (new i = 1;; i++)
				{
					IntToString(i, s3, sizeof(s3));
					KvGetString(g_hConfig, s3, s4, sizeof(s4));
					if (!s4[0]) break;
					
					for (new is = 0; is < sizeof(extensions); is++)
					{
						Format(s5, sizeof(s5), "%s%s", s4, extensions[is]);
						AddFileToDownloadsTable(s5);
					}
				}
			}
		}
		while (KvGotoNextKey(g_hConfig));
		
		KvGoBack(g_hConfig);
	}
	
	return true;
}

bool:IsProfileValid(const String:sProfile[])
{
	return bool:(FindStringInArray(GetBossProfileList(), sProfile) != -1);
}

stock GetProfileNum(const String:sProfile[], const String:keyValue[], defaultValue=0)
{
	if (!IsProfileValid(sProfile)) return defaultValue;
	
	KvRewind(g_hConfig);
	KvJumpToKey(g_hConfig, sProfile);
	
	return KvGetNum(g_hConfig, keyValue, defaultValue);
}

stock Float:GetProfileFloat(const String:sProfile[], const String:keyValue[], Float:defaultValue=0.0)
{
	if (!IsProfileValid(sProfile)) return defaultValue;
	
	KvRewind(g_hConfig);
	KvJumpToKey(g_hConfig, sProfile);
	
	return KvGetFloat(g_hConfig, keyValue, defaultValue);
}

stock bool:GetProfileVector(const String:sProfile[], const String:keyValue[], Float:buffer[3], const Float:defaultValue[3]=NULL_VECTOR)
{
	for (new i = 0; i < 3; i++) buffer[i] = defaultValue[i];
	
	if (!IsProfileValid(sProfile)) return false;
	
	KvRewind(g_hConfig);
	KvJumpToKey(g_hConfig, sProfile);
	
	KvGetVector(g_hConfig, keyValue, buffer, defaultValue);
	return true;
}

stock bool:GetProfileColor(const String:sProfile[], 
	const String:keyValue[], 
	&r, 
	&g, 
	&b, 
	&a,
	dr=255,
	dg=255,
	db=255,
	da=255)
{
	r = dr;
	g = dg;
	b = db;
	a = da;
	
	if (!IsProfileValid(sProfile)) return false;
	
	KvRewind(g_hConfig);
	KvJumpToKey(g_hConfig, sProfile);
	
	decl String:sValue[64];
	KvGetString(g_hConfig, keyValue, sValue, sizeof(sValue));
	
	if (strlen(sValue) != 0)
	{
		KvGetColor(g_hConfig, keyValue, r, g, b, a);
	}
	
	return true;
}

stock bool:GetProfileString(const String:sProfile[], const String:keyValue[], String:buffer[], bufferlen, const String:defaultValue[]="")
{
	strcopy(buffer, bufferlen, defaultValue);
	
	if (!IsProfileValid(sProfile)) return false;
	
	KvRewind(g_hConfig);
	KvJumpToKey(g_hConfig, sProfile);
	
	KvGetString(g_hConfig, keyValue, buffer, bufferlen, defaultValue);
	return true;
}

GetBossProfileIndexFromName(const String:sProfile[])
{
	new iReturn = -1;
	GetTrieValue(g_hBossProfileNames, sProfile, iReturn);
	return iReturn;
}

GetBossProfileUniqueProfileIndex(iProfileIndex)
{
	return GetArrayCell(g_hBossProfileData, iProfileIndex, BossProfileData_UniqueProfileIndex);
}

GetBossProfileSkin(iProfileIndex)
{
	return GetArrayCell(g_hBossProfileData, iProfileIndex, BossProfileData_Skin);
}

GetBossProfileBodyGroups(iProfileIndex)
{
	return GetArrayCell(g_hBossProfileData, iProfileIndex, BossProfileData_Body);
}

Float:GetBossProfileModelScale(iProfileIndex)
{
	return Float:GetArrayCell(g_hBossProfileData, iProfileIndex, BossProfileData_ModelScale);
}

GetBossProfileType(iProfileIndex)
{
	return GetArrayCell(g_hBossProfileData, iProfileIndex, BossProfileData_Type);
}

GetBossProfileFlags(iProfileIndex)
{
	return GetArrayCell(g_hBossProfileData, iProfileIndex, BossProfileData_Flags);
}

Float:GetBossProfileSpeed(iProfileIndex, iDifficulty)
{
	switch (iDifficulty)
	{
		case Difficulty_Easy: return GetArrayCell(g_hBossProfileData, iProfileIndex, BossProfileData_SpeedEasy);
		case Difficulty_Hard: return GetArrayCell(g_hBossProfileData, iProfileIndex, BossProfileData_SpeedHard);
		case Difficulty_Insane: return GetArrayCell(g_hBossProfileData, iProfileIndex, BossProfileData_SpeedInsane);
	}
	
	return GetArrayCell(g_hBossProfileData, iProfileIndex, BossProfileData_SpeedNormal);
}

Float:GetBossProfileMaxSpeed(iProfileIndex, iDifficulty)
{
	switch (iDifficulty)
	{
		case Difficulty_Easy: return GetArrayCell(g_hBossProfileData, iProfileIndex, BossProfileData_MaxSpeedEasy);
		case Difficulty_Hard: return GetArrayCell(g_hBossProfileData, iProfileIndex, BossProfileData_MaxSpeedHard);
		case Difficulty_Insane: return GetArrayCell(g_hBossProfileData, iProfileIndex, BossProfileData_MaxSpeedInsane);
	}
	
	return GetArrayCell(g_hBossProfileData, iProfileIndex, BossProfileData_MaxSpeedNormal);
}

Float:GetBossProfileSearchRadius(iProfileIndex)
{
	return Float:GetArrayCell(g_hBossProfileData, iProfileIndex, BossProfileData_SearchRange);
}

Float:GetBossProfileFOV(iProfileIndex)
{
	return Float:GetArrayCell(g_hBossProfileData, iProfileIndex, BossProfileData_FieldOfView);
}

Float:GetBossProfileTurnRate(iProfileIndex)
{
	return Float:GetArrayCell(g_hBossProfileData, iProfileIndex, BossProfileData_TurnRate);
}

GetBossProfileEyePositionOffset(iProfileIndex, Float:buffer[3])
{
	buffer[0] = Float:GetArrayCell(g_hBossProfileData, iProfileIndex, BossProfileData_EyePosOffsetX);
	buffer[1] = Float:GetArrayCell(g_hBossProfileData, iProfileIndex, BossProfileData_EyePosOffsetY);
	buffer[2] = Float:GetArrayCell(g_hBossProfileData, iProfileIndex, BossProfileData_EyePosOffsetZ);
}

GetBossProfileEyeAngleOffset(iProfileIndex, Float:buffer[3])
{
	buffer[0] = Float:GetArrayCell(g_hBossProfileData, iProfileIndex, BossProfileData_EyeAngOffsetX);
	buffer[1] = Float:GetArrayCell(g_hBossProfileData, iProfileIndex, BossProfileData_EyeAngOffsetY);
	buffer[2] = Float:GetArrayCell(g_hBossProfileData, iProfileIndex, BossProfileData_EyeAngOffsetZ);
}

Float:GetBossProfileAngerStart(iProfileIndex)
{
	return Float:GetArrayCell(g_hBossProfileData, iProfileIndex, BossProfileData_AngerStart);
}

Float:GetBossProfileAngerAddOnPageGrab(iProfileIndex)
{
	return Float:GetArrayCell(g_hBossProfileData, iProfileIndex, BossProfileData_AngerAddOnPageGrab);
}

Float:GetBossProfileAngerPageGrabTimeDiff(iProfileIndex)
{
	return Float:GetArrayCell(g_hBossProfileData, iProfileIndex, BossProfileData_AngerPageGrabTimeDiffReq);
}

Float:GetBossProfileInstantKillRadius(iProfileIndex)
{
	return Float:GetArrayCell(g_hBossProfileData, iProfileIndex, BossProfileData_InstantKillRadius);
}

Float:GetBossProfileScareRadius(iProfileIndex)
{
	return Float:GetArrayCell(g_hBossProfileData, iProfileIndex, BossProfileData_ScareRadius);
}

Float:GetBossProfileScareCooldown(iProfileIndex)
{
	return Float:GetArrayCell(g_hBossProfileData, iProfileIndex, BossProfileData_ScareCooldown);
}

GetBossProfileTeleportType(iProfileIndex)
{
	return GetArrayCell(g_hBossProfileData, iProfileIndex, BossProfileData_TeleportType);
}

// Code originally from FF2. Credits to the original authors Rainbolt Dash and FlaminSarge.
stock bool:GetRandomStringFromProfile(const String:sProfile[], const String:strKeyValue[], String:buffer[], bufferlen, index=-1)
{
	strcopy(buffer, bufferlen, "");
	
	if (!IsProfileValid(sProfile)) return false;
	
	KvRewind(g_hConfig);
	KvJumpToKey(g_hConfig, sProfile);
	
	if (!KvJumpToKey(g_hConfig, strKeyValue)) return false;
	
	decl String:s[32], String:s2[PLATFORM_MAX_PATH];
	
	new i = 1;
	for (;;)
	{
		IntToString(i, s, sizeof(s));
		KvGetString(g_hConfig, s, s2, sizeof(s2));
		if (!s2[0]) break;
		
		i++;
	}
	
	if (i == 1) return false;
	
	IntToString(index < 0 ? GetRandomInt(1, i - 1) : index, s, sizeof(s));
	KvGetString(g_hConfig, s, buffer, bufferlen);
	return true;
}

/**
 *	Returns an array of strings of the profile names of every valid boss.
 */
Handle:GetBossProfileList()
{
	return g_hBossProfileList;
}

/**
 *	Returns an array of strings of the profile names of every valid boss that can be randomly selected.
 */
Handle:GetSelectableBossProfileList()
{
	return g_hSelectableBossProfileList;
}