#if defined _sf2_specialround_included
 #endinput
#endif
#define _sf2_specialround_included

#define SR_CYCLELENGTH 10.0
#define SR_STARTDELAY 1.25
#define SR_MUSIC "slender/specialround.mp3"
#define SR_SOUND_SELECT "slender/specialroundselect.mp3"

#define FILE_SPECIALROUNDS "configs/sf2/specialrounds.cfg"

ReloadSpecialRounds()
{
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

public Action:Timer_SpecialRoundCycle(Handle:timer)
{
	if (timer != g_hSpecialRoundTimer) return Plugin_Stop;
	
	if (GetGameTime() >= g_flSpecialRoundCycleEndTime)
	{
		SpecialRoundCycleFinish();
		return Plugin_Stop;
	}
	
	g_iSpecialRoundCycleNum++;
	if (g_iSpecialRoundCycleNum >= SPECIALROUND_MAXROUNDS)
	{
		g_iSpecialRoundCycleNum = 1;
	}
	else if (g_iSpecialRoundCycleNum < 1)
	{
		g_iSpecialRoundCycleNum = 1;
	}
	
	decl String:sBuffer[64];
	SpecialRoundGetDescriptionHud(g_iSpecialRoundCycleNum, sBuffer, sizeof(sBuffer));
	
	GameTextTFMessage(sBuffer);
	
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
		g_iSpecialRound = GetRandomInt(1, SPECIALROUND_MAXROUNDS - 1);
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
				KvGetSectionName(g_hConfig, sBuffer, sizeof(sBuffer));
				PushArrayString(hArray, sBuffer);
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
			new iMaxPlayers = GetConVarInt(g_cvMaxPlayers);
			
			for (new i = 0; i < iMaxPlayers; i++)
			{
				ForceInNextPlayerInQueue();
			}
			
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