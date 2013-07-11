#if defined _sf2_profiles_included
 #endinput
#endif
#define _sf2_profiles_included

#define FILE_PROFILES "configs/sf2/profiles.cfg"

//new Handle:g_hProfileNames;
//new Handle:g_hProfileNamesArray;

ReloadProfiles()
{
	if (g_hConfig != INVALID_HANDLE)
	{
		CloseHandle(g_hConfig);
		g_hConfig = INVALID_HANDLE;
	}
	
	decl String:buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, sizeof(buffer), FILE_PROFILES);
	new Handle:kv = CreateKeyValues("root");
	if (!FileToKeyValues(kv, buffer))
	{
		CloseHandle(kv);
		SetFailState("Failed to load profiles! File not found!");
	}
	else
	{
		KvRewind(kv);
		if (KvGotoFirstSubKey(kv))
		{
			g_hConfig = kv;
		
			decl String:strName[64];
			new Handle:hArray = CreateArray(64);
		
			do
			{
				KvGetSectionName(g_hConfig, strName, sizeof(strName));
				PushArrayString(hArray, strName);
			}
			while KvGotoNextKey(g_hConfig);
			
			new size = GetArraySize(hArray);
			for (new i = 0; i < size; i++)
			{
				GetArrayString(hArray, i, strName, sizeof(strName));
				LoadProfile(strName);
			}
			
			CloseHandle(hArray);
			
			LogMessage("Boss profiles successfully loaded!");
		}
		else
		{
			CloseHandle(kv);
			SetFailState("Failed to load boss profiles! No entries found!");
		}
	}
}

LoadProfile(const String:strName[])
{
	if (g_hConfig == INVALID_HANDLE) return;
	
	KvRewind(g_hConfig);
	if (!KvJumpToKey(g_hConfig, strName)) return;
	if (!KvGotoFirstSubKey(g_hConfig)) return;
	
	decl String:sBuffer[64];
	KvGetString(g_hConfig, "name", sBuffer, sizeof(sBuffer));
	if (!sBuffer[0]) strcopy(sBuffer, sizeof(sBuffer), strName);
	
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
			new String:extensions[][] = { ".mdl", ".phy", ".dx80.vtx", ".dx90.vtx", ".sw.vtx", ".vvd" };
			
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
	
	LogMessage("Successfully loaded boss %s", sBuffer);
}

bool:SelectProfile(iBossIndex, const String:strName[], iFlags=0, iCopyMaster=-1)
{
	if (g_hConfig == INVALID_HANDLE) 
	{
		LogError("Could not select profile for boss %d: profile list does not exist!", iBossIndex);
		return false;
	}
	
	KvRewind(g_hConfig);
	if (!KvJumpToKey(g_hConfig, strName)) 
	{
		LogError("Could not select profile for boss %d: profile does not exist!", iBossIndex);
		return false;
	}
	
	RemoveProfile(iBossIndex);
	
	g_iSlenderGlobalID++;
	
	strcopy(g_strSlenderProfile[iBossIndex], sizeof(g_strSlenderProfile[]), strName);
	g_iSlenderFlags[iBossIndex] = iFlags;
	g_iSlenderCopyOfBoss[iBossIndex] = -1;
	g_iSlenderSpawnedForPlayer[iBossIndex] = -1;
	g_iSlenderID[iBossIndex] = g_iSlenderGlobalID;
	g_flSlenderAnger[iBossIndex] = GetProfileFloat(g_strSlenderProfile[iBossIndex], "anger_start", 1.0);
	g_flSlenderLastKill[iBossIndex] = GetGameTime();
	GetProfileVector(g_strSlenderProfile[iBossIndex], "eye_pos", g_flSlenderVisiblePos[iBossIndex]);
	GetProfileVector(g_strSlenderProfile[iBossIndex], "mins", g_flSlenderMins[iBossIndex]);
	GetProfileVector(g_strSlenderProfile[iBossIndex], "maxs", g_flSlenderMaxs[iBossIndex]);
	g_iSlenderHealth[iBossIndex] = GetProfileNum(g_strSlenderProfile[iBossIndex], "health", 900);
	g_iSlenderType[iBossIndex] = GetProfileNum(g_strSlenderProfile[iBossIndex], "type");
	g_hSlenderMoveTimer[iBossIndex] = CreateTimer(0.01, Timer_SlenderMove, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	g_flSlenderFOV[iBossIndex] = GetProfileFloat(g_strSlenderProfile[iBossIndex], "fov", 90.0);
	g_flSlenderSpeed[iBossIndex] = GetProfileFloat(g_strSlenderProfile[iBossIndex], "speed");
	g_flSlenderWalkSpeed[iBossIndex] = GetProfileFloat(g_strSlenderProfile[iBossIndex], "walkspeed");
	g_flSlenderTurnRate[iBossIndex] = GetProfileFloat(g_strSlenderProfile[iBossIndex], "turnrate", 30.0);
	g_hSlenderFakeTimer[iBossIndex] = INVALID_HANDLE;
	g_hSlenderThinkTimer[iBossIndex] = INVALID_HANDLE;
	g_hSlenderTeleportTimer[iBossIndex] = CreateTimer(2.0, Timer_SlenderTeleport, iBossIndex, TIMER_FLAG_NO_MAPCHANGE);
	g_flSlenderNextJumpScare[iBossIndex] = -1.0;
	g_flSlenderTimeUntilNextProxy[iBossIndex] = -1.0;
	
	switch (g_iSlenderType[iBossIndex])
	{
		case 2:
		{
			SlenderCreateTargetMemory(iBossIndex);
		}
		default:
		{
			SlenderRemoveTargetMemory(iBossIndex);
		}
	}
	
	if (iCopyMaster >= 0 && iCopyMaster < MAX_BOSSES && g_strSlenderProfile[iCopyMaster][0])
	{
		g_iSlenderCopyOfBoss[iBossIndex] = iCopyMaster;
		g_flSlenderAnger[iBossIndex] = g_flSlenderAnger[iCopyMaster];
		g_flSlenderNextJumpScare[iBossIndex] = g_flSlenderNextJumpScare[iCopyMaster];
	}
	else
	{
		decl String:sBuffer[PLATFORM_MAX_PATH];
		GetRandomStringFromProfile(strName, "sound_spawn_all", sBuffer, sizeof(sBuffer));
		if (sBuffer[0]) EmitSoundToAll(sBuffer, _, SNDCHAN_STATIC, SNDLEVEL_HELICOPTER);
	}
	
	Call_StartForward(fOnBossAdded);
	Call_PushCell(iBossIndex);
	Call_Finish();
	
	return true;
}

AddProfile(const String:strName[], iFlags=0, iCopyMaster=-1)
{
	if (g_hConfig == INVALID_HANDLE) 
	{
		LogError("Could not add profile: profile list does not exist!");
		return -1;
	}
	
	KvRewind(g_hConfig);
	if (!KvJumpToKey(g_hConfig, strName)) 
	{
		LogError("Could not add profile: profile does not exist!");
		return -1;
	}
	
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		if (!g_strSlenderProfile[i][0])
		{
			SelectProfile(i, strName, iFlags, iCopyMaster);
			return i;
		}
	}
	
	return -1;
}

RemoveProfile(iBossIndex)
{
	RemoveSlender(iBossIndex);

	// Remove all possible sounds, for emergencies.
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i)) continue;
		
		// Remove static noises.
		if (g_iPlayerStaticMaster[i] == iBossIndex) 
		{
			ClientStopAllSlenderSounds(i, g_strSlenderProfile[iBossIndex], "sound_static", SNDCHAN_AUTO);
			ClientStopAllSlenderSounds(i, g_strSlenderProfile[iBossIndex], "sound_20dollars", SNDCHAN_AUTO);
		}
		
		// Remove chase music.
		if (g_iPlayerChaseMusicMaster[i] == iBossIndex)
		{
			ClientStopAllSlenderSounds(i, g_strSlenderProfile[iBossIndex], "sound_chase", SNDCHAN_AUTO);
		}
	}
	
	strcopy(g_strSlenderProfile[iBossIndex], sizeof(g_strSlenderProfile[]), "");
	g_iSlenderFlags[iBossIndex] = 0;
	g_iSlenderCopyOfBoss[iBossIndex] = -1;
	g_iSlenderSpawnedForPlayer[iBossIndex] = -1;
	g_iSlenderID[iBossIndex] = -1;
	g_iSlender[iBossIndex] = INVALID_ENT_REFERENCE;
	g_hSlenderMoveTimer[iBossIndex] = INVALID_HANDLE;
	g_hSlenderTeleportTimer[iBossIndex] = INVALID_HANDLE;
	g_hSlenderThinkTimer[iBossIndex] = INVALID_HANDLE;
	g_hSlenderFakeTimer[iBossIndex] = INVALID_HANDLE;
	g_flSlenderAnger[iBossIndex] = 1.0;
	g_flSlenderLastKill[iBossIndex] = -1.0;
	g_iSlenderType[iBossIndex] = -1;
	g_iSlenderState[iBossIndex] = STATE_IDLE;
	g_iSlenderTarget[iBossIndex] = INVALID_ENT_REFERENCE;
	g_iSlenderModel[iBossIndex] = INVALID_ENT_REFERENCE;
	g_flSlenderFOV[iBossIndex] = 0.0;
	g_flSlenderSpeed[iBossIndex] = 0.0;
	g_flSlenderWalkSpeed[iBossIndex] = 0.0;
	g_flSlenderTimeUntilNextProxy[iBossIndex] = -1.0;
	
	for (new i = 0; i < 3; i++)
	{
		g_flSlenderMins[iBossIndex][i] = 0.0;
		g_flSlenderMaxs[iBossIndex][i] = 0.0;
		g_flSlenderVisiblePos[iBossIndex][i] = 0.0;
	}
	
	for (new i = 1; i <= MaxClients; i++)
	{
		g_flSlenderLastFoundPlayer[iBossIndex][i] = -1.0;
		
		for (new i2 = 0; i2 < 3; i2++)
		{
			g_flSlenderLastFoundPlayerPos[iBossIndex][i][i2] = 0.0;
		}
	}
	
	SlenderRemoveTargetMemory(iBossIndex);
}

stock GetProfileNum(const String:strName[], const String:keyValue[], defaultValue=0)
{
	if (g_hConfig == INVALID_HANDLE) return defaultValue;
	
	KvRewind(g_hConfig);
	if (!KvJumpToKey(g_hConfig, strName)) return defaultValue;
	
	return KvGetNum(g_hConfig, keyValue, defaultValue);
}

stock Float:GetProfileFloat(const String:strName[], const String:keyValue[], Float:defaultValue=0.0)
{
	if (g_hConfig == INVALID_HANDLE) return defaultValue;
	
	KvRewind(g_hConfig);
	if (!KvJumpToKey(g_hConfig, strName)) return defaultValue;
	
	return KvGetFloat(g_hConfig, keyValue, defaultValue);
}

stock bool:GetProfileVector(const String:strName[], const String:keyValue[], Float:buffer[3], const Float:defaultValue[3]=NULL_VECTOR)
{
	for (new i = 0; i < 3; i++) buffer[0] = defaultValue[0];
	
	if (g_hConfig == INVALID_HANDLE) return false;
	
	KvRewind(g_hConfig);
	if (!KvJumpToKey(g_hConfig, strName)) return false;
	
	KvGetVector(g_hConfig, keyValue, buffer, defaultValue);
	return true;
}

stock bool:GetProfileString(const String:strName[], const String:keyValue[], String:buffer[], bufferlen, const String:defaultValue[]="")
{
	strcopy(buffer, bufferlen, defaultValue);
	
	if (g_hConfig == INVALID_HANDLE) return false;
	
	KvRewind(g_hConfig);
	if (!KvJumpToKey(g_hConfig, strName)) return false;
	
	KvGetString(g_hConfig, keyValue, buffer, bufferlen, defaultValue);
	return true;
}

// Code originally from FF2. Credits to the original authors Rainbolt Dash and FlaminSarge.
stock bool:GetRandomStringFromProfile(const String:strName[], const String:strKeyValue[], String:buffer[], bufferlen, index=-1)
{
	strcopy(buffer, bufferlen, "");
	
	if (g_hConfig == INVALID_HANDLE) return false;
	
	KvRewind(g_hConfig);
	if (!KvJumpToKey(g_hConfig, strName)) return false;
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