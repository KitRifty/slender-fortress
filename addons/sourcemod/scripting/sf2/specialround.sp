#if defined _sf2_specialround_included
 #endinput
#endif
#define _sf2_specialround_included

#define SR_CYCLELENGTH 10.0
#define SR_STARTDELAY 1.25
#define SR_MUSIC "slender/specialround.mp3"
#define SR_SOUND_SELECT "slender/specialroundselect.mp3"

#define FILE_SPECIALROUNDS "configs/sf2/specialrounds.cfg"

static Handle:g_hSpecialRoundCycleNames = INVALID_HANDLE;

static Handle:g_hSpecialRoundTimer = INVALID_HANDLE;
static g_iSpecialRoundCycleNum = 0;
static Float:g_flSpecialRoundCycleEndTime = -1.0;

ReloadSpecialRounds()
{
	if (g_hSpecialRoundCycleNames == INVALID_HANDLE)
	{
		g_hSpecialRoundCycleNames = CreateArray(128);
	}
	
	ClearArray(g_hSpecialRoundCycleNames);

	if (g_hSpecialRoundsConfig != INVALID_HANDLE)
	{
		CloseHandle(g_hSpecialRoundsConfig);
		g_hSpecialRoundsConfig = INVALID_HANDLE;
	}
	
	decl String:buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, sizeof(buffer), FILE_SPECIALROUNDS);
	new Handle:kv = CreateKeyValues("root");
	if (!FileToKeyValues(kv, buffer))
	{
		CloseHandle(kv);
		LogError("Failed to load special rounds! File %s not found!", FILE_SPECIALROUNDS);
	}
	else
	{
		g_hSpecialRoundsConfig = kv;
		LogMessage("Loaded special rounds file!");
		
		// Load names for the cycle.
		decl String:sBuffer[128];
		SpecialRoundGetDescriptionHud(SPECIALROUND_DOUBLETROUBLE, sBuffer, sizeof(sBuffer));
		PushArrayString(g_hSpecialRoundCycleNames, sBuffer);
		
		SpecialRoundGetDescriptionHud(SPECIALROUND_DOUBLETROUBLE, sBuffer, sizeof(sBuffer));
		PushArrayString(g_hSpecialRoundCycleNames, sBuffer);
		
		SpecialRoundGetDescriptionHud(SPECIALROUND_SINGLEPLAYER, sBuffer, sizeof(sBuffer));
		PushArrayString(g_hSpecialRoundCycleNames, sBuffer);
		
		SpecialRoundGetDescriptionHud(SPECIALROUND_DOUBLEMAXPLAYERS, sBuffer, sizeof(sBuffer));
		PushArrayString(g_hSpecialRoundCycleNames, sBuffer);
		
		SpecialRoundGetDescriptionHud(SPECIALROUND_LIGHTSOUT, sBuffer, sizeof(sBuffer));
		PushArrayString(g_hSpecialRoundCycleNames, sBuffer);
		
		KvRewind(kv);
		if (KvJumpToKey(kv, "jokes"))
		{
			if (KvGotoFirstSubKey(kv, false))
			{
				do
				{
					KvGetString(kv, NULL_STRING, sBuffer, sizeof(sBuffer));
					if (strlen(sBuffer) > 0)
					{
						PushArrayString(g_hSpecialRoundCycleNames, sBuffer);
					}
				}
				while (KvGotoNextKey(kv, false));
			}
		}
		
		SortADTArray(g_hSpecialRoundCycleNames, Sort_Random, Sort_String);
	}
}

stock SpecialRoundGetDescriptionHud(iSpecialRound, String:buffer[], bufferlen)
{
	strcopy(buffer, bufferlen, "");

	if (g_hSpecialRoundsConfig == INVALID_HANDLE) return;
	
	KvRewind(g_hSpecialRoundsConfig);
	decl String:sSpecialRound[32];
	IntToString(iSpecialRound, sSpecialRound, sizeof(sSpecialRound));
	
	if (!KvJumpToKey(g_hSpecialRoundsConfig, sSpecialRound)) return;
	
	KvGetString(g_hSpecialRoundsConfig, "display_text_hud", buffer, bufferlen);
}

stock SpecialRoundGetDescriptionChat(iSpecialRound, String:buffer[], bufferlen)
{
	strcopy(buffer, bufferlen, "");

	if (g_hSpecialRoundsConfig == INVALID_HANDLE) return;
	
	KvRewind(g_hSpecialRoundsConfig);
	decl String:sSpecialRound[32];
	IntToString(iSpecialRound, sSpecialRound, sizeof(sSpecialRound));
	
	if (!KvJumpToKey(g_hSpecialRoundsConfig, sSpecialRound)) return;
	
	KvGetString(g_hSpecialRoundsConfig, "display_text_chat", buffer, bufferlen);
}

stock SpecialRoundGetIconHud(iSpecialRound, String:buffer[], bufferlen)
{
	strcopy(buffer, bufferlen, "");

	if (g_hSpecialRoundsConfig == INVALID_HANDLE) return;
	
	KvRewind(g_hSpecialRoundsConfig);
	decl String:sSpecialRound[32];
	IntToString(iSpecialRound, sSpecialRound, sizeof(sSpecialRound));
	
	if (!KvJumpToKey(g_hSpecialRoundsConfig, sSpecialRound)) return;
	
	KvGetString(g_hSpecialRoundsConfig, "display_icon_hud", buffer, bufferlen);
}

stock bool:SpecialRoundCanBeSelected(iSpecialRound)
{
	if (g_hSpecialRoundsConfig == INVALID_HANDLE) return false;
	
	KvRewind(g_hSpecialRoundsConfig);
	decl String:sSpecialRound[32];
	IntToString(iSpecialRound, sSpecialRound, sizeof(sSpecialRound));
	
	if (!KvJumpToKey(g_hSpecialRoundsConfig, sSpecialRound)) return false;
	
	return bool:KvGetNum(g_hSpecialRoundsConfig, "enabled", 1);
}

public Action:Timer_SpecialRoundCycle(Handle:timer)
{
	if (timer != g_hSpecialRoundTimer) return Plugin_Stop;
	
	if (GetGameTime() >= g_flSpecialRoundCycleEndTime)
	{
		SpecialRoundCycleFinish();
		return Plugin_Stop;
	}
	
	decl String:sBuffer[128];
	GetArrayString(g_hSpecialRoundCycleNames, g_iSpecialRoundCycleNum, sBuffer, sizeof(sBuffer));
	
	GameTextTFMessage(sBuffer);
	
	g_iSpecialRoundCycleNum++;
	if (g_iSpecialRoundCycleNum >= GetArraySize(g_hSpecialRoundCycleNames))
	{
		g_iSpecialRoundCycleNum = 0;
	}
	
	return Plugin_Continue;
}

public Action:Timer_SpecialRoundStart(Handle:timer)
{
	if (timer != g_hSpecialRoundTimer) return;
	if (!g_bSpecialRound) return;
	
	SpecialRoundStart();
}

/*
public Action:Timer_SpecialRoundAttribute(Handle:timer)
{
	if (timer != g_hSpecialRoundTimer) return Plugin_Stop;
	if (!g_bSpecialRound) return Plugin_Stop;
	
	new iCond = -1;
	
	switch (g_iSpecialRoundType)
	{
		case SPECIALROUND_DEFENSEBUFF: iCond = _:TFCond_DefenseBuffed;
		case SPECIALROUND_MARKEDFORDEATH: iCond = _:TFCond_MarkedForDeath;
	}
	
	if (iCond != -1)
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || !IsPlayerAlive(i) || g_bPlayerEliminated[i] || g_bPlayerGhostMode[i]) continue;
			
			TF2_AddCondition(i, TFCond:iCond, 0.8);
		}
	}
	
	return Plugin_Continue;
}
*/

SpecialRoundCycleStart()
{
	if (!g_bSpecialRound) return;
	
	EmitSoundToAll(SR_MUSIC, _, MUSIC_CHAN);
	g_iSpecialRoundType = 0;
	g_iSpecialRoundCycleNum = 0;
	g_flSpecialRoundCycleEndTime = GetGameTime() + SR_CYCLELENGTH;
	g_hSpecialRoundTimer = CreateTimer(0.12, Timer_SpecialRoundCycle, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

SpecialRoundCycleFinish()
{
	EmitSoundToAll(SR_SOUND_SELECT, _, SNDCHAN_AUTO);
	
	new iOverride = GetConVarInt(g_cvSpecialRoundOverride);
	if (iOverride >= 1 && iOverride < SPECIALROUND_MAXROUNDS)
	{
		g_iSpecialRoundType = iOverride;
	}
	else
	{
		new Handle:hEnabledRounds = CreateArray();
		
		if (GetArraySize(GetSelectableBossProfileList()) > 0)
		{
			PushArrayCell(hEnabledRounds, SPECIALROUND_DOUBLETROUBLE);
		}
		
		if (GetActivePlayerCount() <= GetConVarInt(g_cvMaxPlayers) * 2)
		{
			PushArrayCell(hEnabledRounds, SPECIALROUND_DOUBLEMAXPLAYERS);
		}
		
		/*
		if (GetActivePlayerCount() > 1)
		{
			PushArrayCell(hEnabledRounds, SPECIALROUND_SINGLEPLAYER);
		}
		*/
		
		PushArrayCell(hEnabledRounds, SPECIALROUND_INSANEDIFFICULTY);
		PushArrayCell(hEnabledRounds, SPECIALROUND_LIGHTSOUT);
	
		g_iSpecialRoundType = GetArrayCell(hEnabledRounds, GetRandomInt(0, GetArraySize(hEnabledRounds) - 1));
		
		CloseHandle(hEnabledRounds);
	}
	
	SetConVarInt(g_cvSpecialRoundOverride, -1);
	
	decl String:sDescHud[64];
	SpecialRoundGetDescriptionHud(g_iSpecialRoundType, sDescHud, sizeof(sDescHud));
	
	decl String:sIconHud[64];
	SpecialRoundGetIconHud(g_iSpecialRoundType, sIconHud, sizeof(sIconHud));
	
	decl String:sDescChat[64];
	SpecialRoundGetDescriptionChat(g_iSpecialRoundType, sDescChat, sizeof(sDescChat));
	
	GameTextTFMessage(sDescHud, sIconHud);
	CPrintToChatAll("%t", "SF2 Special Round Announce Chat", sDescChat); // For those who are using minimized HUD...
	
	g_hSpecialRoundTimer = CreateTimer(SR_STARTDELAY, Timer_SpecialRoundStart, _, TIMER_FLAG_NO_MAPCHANGE);
}

SpecialRoundStart()
{
	if (!g_bSpecialRound) return;
	if (g_iSpecialRoundType < 1 || g_iSpecialRoundType >= SPECIALROUND_MAXROUNDS) return;
	
	// What to do with the timer...
	switch (g_iSpecialRoundType)
	{
		/*
		case SPECIALROUND_DEFENSEBUFF, SPECIALROUND_MARKEDFORDEATH:
		{
			g_hSpecialRoundTimer = CreateTimer(0.5, Timer_SpecialRoundAttribute, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		}
		*/
		default:
		{
			g_hSpecialRoundTimer = INVALID_HANDLE;
		}
	}
	
	switch (g_iSpecialRoundType)
	{
		case SPECIALROUND_DOUBLETROUBLE:
		{
			decl String:sBuffer[SF2_MAX_PROFILE_NAME_LENGTH];
			new Handle:hSelectableBosses = GetSelectableBossProfileList();
			
			if (GetArraySize(hSelectableBosses) > 0)
			{
				GetArrayString(hSelectableBosses, GetRandomInt(0, GetArraySize(hSelectableBosses) - 1), sBuffer, sizeof(sBuffer));
				AddProfile(sBuffer);
			}
		}
		case SPECIALROUND_INSANEDIFFICULTY:
		{
			SetConVarString(g_cvDifficulty, "3"); // Override difficulty to Insane.
		}
		case SPECIALROUND_SINGLEPLAYER:
		{
			for (new i = 1; i <= MaxClients; i++)
			{
				if (!IsClientInGame(i)) continue;
				
				ClientUpdateListeningFlags(i);
			}
		}
		case SPECIALROUND_DOUBLEMAXPLAYERS:
		{
			ForceInNextPlayersInQueue(GetConVarInt(g_cvMaxPlayers));
			SetConVarString(g_cvDifficulty, "3"); // Override difficulty to Insane.
		}
		case SPECIALROUND_LIGHTSOUT:
		{
			for (new i = 1; i <= MaxClients; i++)
			{
				if (!IsClientInGame(i)) continue;
				
				if (!g_bPlayerEliminated[i])
				{
					ClientResetFlashlight(i);
					ClientActivateUltravision(i);
				}
			}
		}
	}
}

public Action:Timer_DisplaySpecialRound(Handle:timer)
{
	decl String:sDescHud[64];
	SpecialRoundGetDescriptionHud(g_iSpecialRoundType, sDescHud, sizeof(sDescHud));
	
	decl String:sIconHud[64];
	SpecialRoundGetIconHud(g_iSpecialRoundType, sIconHud, sizeof(sIconHud));
	
	decl String:sDescChat[64];
	SpecialRoundGetDescriptionChat(g_iSpecialRoundType, sDescChat, sizeof(sDescChat));
	
	GameTextTFMessage(sDescHud, sIconHud);
	CPrintToChatAll("%t", "SF2 Special Round Announce Chat", sDescChat); // For those who are using minimized HUD...
}

SpecialRoundReset()
{
	g_iSpecialRoundType = 0;
	g_hSpecialRoundTimer = INVALID_HANDLE;
	g_iSpecialRoundCycleNum = 0;
	g_flSpecialRoundCycleEndTime = -1.0;
}

bool:IsSpecialRoundRunning()
{
	return g_bSpecialRound;
}

public SpecialRoundInitializeAPI()
{
	CreateNative("SF2_IsSpecialRoundRunning", Native_IsSpecialRoundRunning);
	CreateNative("SF2_GetSpecialRoundType", Native_GetSpecialRoundType);
}

public Native_IsSpecialRoundRunning(Handle:plugin, numParams)
{
	return g_bSpecialRound;
}

public Native_GetSpecialRoundType(Handle:plugin, numParams)
{
	return g_iSpecialRoundType;
}