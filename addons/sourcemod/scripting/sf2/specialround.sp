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
	
	switch (g_iSpecialRound)
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
	g_iSpecialRound = 0;
	g_iSpecialRoundCycleNum = 0;
	g_flSpecialRoundCycleEndTime = GetGameTime() + SR_CYCLELENGTH;
	g_hSpecialRoundTimer = CreateTimer(0.05, Timer_SpecialRoundCycle, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

SpecialRoundCycleFinish()
{
	EmitSoundToAll(SR_SOUND_SELECT, _, SNDCHAN_AUTO);
	
	new iOverride = GetConVarInt(g_cvSpecialRoundOverride);
	if (iOverride >= 1 && iOverride < SPECIALROUND_MAXROUNDS)
	{
		g_iSpecialRound = iOverride;
	}
	else
	{
		new Handle:hEnabledRounds = CreateArray();
		PushArrayCell(hEnabledRounds, SPECIALROUND_DOUBLETROUBLE);
		PushArrayCell(hEnabledRounds, SPECIALROUND_INSANEDIFFICULTY);
		PushArrayCell(hEnabledRounds, SPECIALROUND_DOUBLEMAXPLAYERS);
		PushArrayCell(hEnabledRounds, SPECIALROUND_LIGHTSOUT);
	
		g_iSpecialRound = GetArrayCell(hEnabledRounds, GetRandomInt(0, GetArraySize(hEnabledRounds) - 1));
		
		CloseHandle(hEnabledRounds);
	}
	
	SetConVarInt(g_cvSpecialRoundOverride, -1);
	
	decl String:sDescHud[64];
	SpecialRoundGetDescriptionHud(g_iSpecialRound, sDescHud, sizeof(sDescHud));
	
	decl String:sIconHud[64];
	SpecialRoundGetIconHud(g_iSpecialRound, sIconHud, sizeof(sIconHud));
	
	decl String:sDescChat[64];
	SpecialRoundGetDescriptionChat(g_iSpecialRound, sDescChat, sizeof(sDescChat));
	
	GameTextTFMessage(sDescHud, sIconHud);
	CPrintToChatAll("%t", "SF2 Special Round Announce Chat", sDescChat); // For those who are using minimized HUD...
	
	g_hSpecialRoundTimer = CreateTimer(SR_STARTDELAY, Timer_SpecialRoundStart, _, TIMER_FLAG_NO_MAPCHANGE);
}

SpecialRoundStart()
{
	if (!g_bSpecialRound) return;
	if (g_iSpecialRound < 1 || g_iSpecialRound >= SPECIALROUND_MAXROUNDS) return;
	
	// What to do with the timer...
	switch (g_iSpecialRound)
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
	
	switch (g_iSpecialRound)
	{
		case SPECIALROUND_DOUBLETROUBLE:
		{
			decl String:sBuffer[64];
			new Handle:hArray = CreateArray(64);
			KvRewind(g_hConfig);
			KvGotoFirstSubKey(g_hConfig);
			do
			{
				if (bool:KvGetNum(g_hConfig, "enable_random_selection", 1)) 
				{
					KvGetSectionName(g_hConfig, sBuffer, sizeof(sBuffer));
					PushArrayString(hArray, sBuffer);
				}
			}
			while (KvGotoNextKey(g_hConfig));
			
			GetArrayString(hArray, GetRandomInt(0, GetArraySize(hArray) - 1), sBuffer, sizeof(sBuffer));
			CloseHandle(hArray);
			
			AddProfile(sBuffer);
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
				ClientDeactivateFlashlight(i);
			}
		}
	}
}

SpecialRoundReset()
{
	g_bSpecialRound = false;
	g_bSpecialRoundNew = false;
	g_iSpecialRound = 0;
	g_hSpecialRoundTimer = INVALID_HANDLE;
	g_iSpecialRoundCycleNum = 0;
	g_flSpecialRoundCycleEndTime = -1.0;
}