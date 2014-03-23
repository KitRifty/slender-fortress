#if defined _sf2_profiles_included
 #endinput
#endif
#define _sf2_profiles_included

#define FILE_PROFILES "configs/sf2/profiles.cfg"


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

bool:SelectProfile(iBossIndex, const String:sProfile[], iFlags=0, iCopyMaster=-1, bool:bSpawnCompanions=true, bool:bPlaySpawnSound=true)
{
	if (g_hConfig == INVALID_HANDLE) 
	{
		LogError("Could not select profile for boss %d: profile list does not exist!", iBossIndex);
		return false;
	}
	
	KvRewind(g_hConfig);
	if (!KvJumpToKey(g_hConfig, sProfile)) 
	{
		LogError("Could not select profile for boss %d: profile does not exist!", iBossIndex);
		return false;
	}
	
	RemoveProfile(iBossIndex);
	
	++g_iSlenderGlobalID;
	
	strcopy(g_strSlenderProfile[iBossIndex], sizeof(g_strSlenderProfile[]), sProfile);
	g_iSlenderType[iBossIndex] = GetProfileNum(sProfile, "type");
	g_iSlenderID[iBossIndex] = g_iSlenderGlobalID;
	GetProfileVector(sProfile, "eye_pos", g_flSlenderEyePosOffset[iBossIndex]);
	GetProfileVector(sProfile, "eye_ang_offset", g_flSlenderEyeAngOffset[iBossIndex], Float:{ 0.0, 0.0, 0.0 });
	GetProfileVector(sProfile, "mins", g_flSlenderDetectMins[iBossIndex]);
	GetProfileVector(sProfile, "maxs", g_flSlenderDetectMaxs[iBossIndex]);
	g_iSlenderCopyMaster[iBossIndex] = -1;
	g_iSlenderHealth[iBossIndex] = GetProfileNum(sProfile, "health", 900);
	g_flSlenderAnger[iBossIndex] = GetProfileFloat(sProfile, "anger_start", 1.0);
	g_flSlenderFOV[iBossIndex] = GetProfileFloat(sProfile, "fov", 90.0);
	g_flSlenderSpeed[iBossIndex] = GetProfileFloat(sProfile, "speed", 150.0);
	g_flSlenderAcceleration[iBossIndex] = GetProfileFloat(sProfile, "acceleration", 150.0);
	g_flSlenderWalkSpeed[iBossIndex] = GetProfileFloat(sProfile, "walkspeed", 30.0);
	g_flSlenderAirSpeed[iBossIndex] = GetProfileFloat(sProfile, "airspeed", 50.0);
	g_flSlenderTurnRate[iBossIndex] = GetProfileFloat(sProfile, "turnrate", 90.0);
	g_hSlenderFakeTimer[iBossIndex] = INVALID_HANDLE;
	g_hSlenderEntityThink[iBossIndex] = INVALID_HANDLE;
	g_hSlenderAttackTimer[iBossIndex] = INVALID_HANDLE;
	g_flSlenderNextTeleportTime[iBossIndex] = GetGameTime();
	g_flSlenderLastKill[iBossIndex] = GetGameTime();
	g_flSlenderTimeUntilKill[iBossIndex] = -1.0;
	g_flSlenderNextJumpScare[iBossIndex] = -1.0;
	g_flSlenderTimeUntilNextProxy[iBossIndex] = -1.0;
	g_flSlenderTeleportMinRange[iBossIndex] = GetProfileFloat(sProfile, "teleport_range_min", 325.0);
	g_flSlenderTeleportMaxRange[iBossIndex] = GetProfileFloat(sProfile, "teleport_range_max", 1024.0);
	g_flSlenderStaticRadius[iBossIndex] = GetProfileFloat(sProfile, "static_radius");
	g_flSlenderSearchRange[iBossIndex] = GetProfileFloat(sProfile, "search_range");
	g_flSlenderWakeRange[iBossIndex] = GetProfileFloat(sProfile, "wake_radius", 150.0);
	g_flSlenderInstaKillRange[iBossIndex] = GetProfileFloat(sProfile, "kill_radius");
	g_flSlenderScareRadius[iBossIndex] = GetProfileFloat(sProfile, "scare_radius");
	g_flSlenderIdleAnimationPlaybackRate[iBossIndex] = GetProfileFloat(sProfile, "animation_idle_playbackrate", 1.0);
	g_flSlenderWalkAnimationPlaybackRate[iBossIndex] = GetProfileFloat(sProfile, "animation_walk_playbackrate", 1.0);
	g_flSlenderRunAnimationPlaybackRate[iBossIndex] = GetProfileFloat(sProfile, "animation_run_playbackrate", 1.0);
	g_flSlenderJumpSpeed[iBossIndex] = GetProfileFloat(sProfile, "jump_speed", 512.0);
	g_flSlenderPathNodeTolerance[iBossIndex] = GetProfileFloat(sProfile, "search_node_dist_tolerance", 32.0);
	g_flSlenderPathNodeLookAhead[iBossIndex] = GetProfileFloat(sProfile, "search_node_dist_lookahead", 512.0);
	g_flSlenderStepSize[iBossIndex] = GetProfileFloat(sProfile, "stepsize", 18.0)
	g_flSlenderProxyTeleportMinRange[iBossIndex] = GetProfileFloat(sProfile, "proxies_teleport_range_min");
	g_flSlenderProxyTeleportMaxRange[iBossIndex] = GetProfileFloat(sProfile, "proxies_teleport_range_max");
	
	// Parse through flags.
	if (!(iFlags & SFF_HASSTATICSHAKE) && GetProfileNum(sProfile, "static_shake")) iFlags |= SFF_HASSTATICSHAKE;
	if (!(iFlags & SFF_STATICONLOOK) && GetProfileNum(sProfile, "static_on_look")) iFlags |= SFF_STATICONLOOK;
	if (!(iFlags & SFF_STATICONRADIUS) && GetProfileNum(sProfile, "static_on_radius")) iFlags |= SFF_STATICONRADIUS;
	if (!(iFlags & SFF_PROXIES) && GetProfileNum(sProfile, "proxies")) iFlags |= SFF_PROXIES;
	if (!(iFlags & SFF_HASJUMPSCARE) && GetProfileNum(sProfile, "jumpscare")) iFlags |= SFF_HASJUMPSCARE;
	if (!(iFlags & SFF_HASSIGHTSOUNDS) && GetProfileNum(sProfile, "sound_sight_enabled")) iFlags |= SFF_HASSIGHTSOUNDS;
	if (!(iFlags & SFF_HASSTATICLOOPLOCALSOUND) && GetProfileNum(sProfile, "sound_static_loop_local_enabled")) iFlags |= SFF_HASSTATICLOOPLOCALSOUND;
	if (!(iFlags & SFF_HASVIEWSHAKE) && GetProfileNum(sProfile, "view_shake", 1)) iFlags |= SFF_HASVIEWSHAKE;
	if (!(iFlags & SFF_COPIES) && GetProfileNum(sProfile, "copy")) iFlags |= SFF_COPIES;
	if (!(iFlags & SFF_ATTACKPROPS) && GetProfileNum(sProfile, "attack_props", 1)) iFlags |= SFF_ATTACKPROPS;
	
	switch (g_iSlenderType[iBossIndex])
	{
		case 2:
		{
			SlenderRemoveTargetMemory(iBossIndex);
			SlenderCreateTargetMemory(iBossIndex);
			
			if (!(iFlags & SFF_WANDERMOVE) && GetProfileNum(sProfile, "wander_move", 1)) iFlags |= SFF_WANDERMOVE;
		}
		default:
		{
			SlenderRemoveTargetMemory(iBossIndex);
		}
	}
	
	g_iSlenderFlags[iBossIndex] = iFlags;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		g_flPlayerLastChaseBossEncounterTime[i][iBossIndex] = -1.0;
		g_flSlenderTeleportPlayersRestTime[iBossIndex][i] = -1.0;
	}
	
	g_iSlenderTeleportType[iBossIndex] = GetProfileNum(sProfile, "teleport_type", 0);
	g_iSlenderTeleportTarget[iBossIndex] = INVALID_ENT_REFERENCE;
	g_flSlenderTeleportMaxTargetStress[iBossIndex] = 9999.0;
	g_flSlenderTeleportMaxTargetTime[iBossIndex] = -1.0;
	g_flSlenderNextTeleportTime[iBossIndex] = -1.0;
	g_flSlenderTeleportTargetTime[iBossIndex] = -1.0;
	
	g_hSlenderThink[iBossIndex] = CreateTimer(0.1, Timer_SlenderTeleportThink, iBossIndex, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	if (iCopyMaster >= 0 && iCopyMaster < MAX_BOSSES && g_iSlenderID[iCopyMaster] != -1)
	{
		g_iSlenderCopyMaster[iBossIndex] = iCopyMaster;
		g_flSlenderAnger[iBossIndex] = g_flSlenderAnger[iCopyMaster];
		g_flSlenderNextJumpScare[iBossIndex] = g_flSlenderNextJumpScare[iCopyMaster];
	}
	else
	{
		if (bPlaySpawnSound)
		{
			decl String:sBuffer[PLATFORM_MAX_PATH];
			GetRandomStringFromProfile(sProfile, "sound_spawn_all", sBuffer, sizeof(sBuffer));
			if (sBuffer[0]) EmitSoundToAll(sBuffer, _, SNDCHAN_STATIC, SNDLEVEL_HELICOPTER);
		}
		
		if (bSpawnCompanions)
		{
			KvRewind(g_hConfig);
			KvJumpToKey(g_hConfig, sProfile);
			
			decl String:sCompProfile[SF2_MAX_PROFILE_NAME_LENGTH];
			new Handle:hCompanions = CreateArray(SF2_MAX_PROFILE_NAME_LENGTH);
			
			if (KvJumpToKey(g_hConfig, "companions"))
			{
				decl String:sNum[32];
				
				for (new i = 1;;i++)
				{
					IntToString(i, sNum, sizeof(sNum));
					KvGetString(g_hConfig, sNum, sCompProfile, sizeof(sCompProfile));
					if (!sCompProfile[0]) break;
					
					PushArrayString(hCompanions, sCompProfile);
				}
			}
			
			for (new i = 0, iSize = GetArraySize(hCompanions); i < iSize; i++)
			{
				GetArrayString(hCompanions, i, sCompProfile, sizeof(sCompProfile));
				AddProfile(sCompProfile, _, _, false, false); // Prevent spam.
			}
			
			CloseHandle(hCompanions);
		}
	}
	
	Call_StartForward(fOnBossAdded);
	Call_PushCell(iBossIndex);
	Call_Finish();
	
	return true;
}

AddProfile(const String:strName[], iFlags=0, iCopyMaster=-1, bool:bSpawnCompanions=true, bool:bPlaySpawnSound=true)
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
		if (g_iSlenderID[i] == -1)
		{
			SelectProfile(i, strName, iFlags, iCopyMaster, bSpawnCompanions, bPlaySpawnSound);
			return i;
		}
	}
	
	return -1;
}

RemoveProfile(iBossIndex)
{
	RemoveSlender(iBossIndex);
	
	// Call our forward.
	Call_StartForward(fOnBossRemoved);
	Call_PushCell(iBossIndex);
	Call_Finish();
	
	// Remove all possible sounds, for emergencies.
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i)) continue;
		
		// Remove chase music.
		if (g_iPlayerChaseMusicMaster[i] == iBossIndex)
		{
			ClientStopAllSlenderSounds(i, g_strSlenderProfile[iBossIndex], "sound_chase", SNDCHAN_AUTO);
		}
	}
	
	// Clean up on the clients.
	for (new i = 1; i <= MaxClients; i++)
	{
		g_flSlenderLastFoundPlayer[iBossIndex][i] = -1.0;
		g_flPlayerLastChaseBossEncounterTime[i][iBossIndex] = -1.0;
		g_flSlenderTeleportPlayersRestTime[iBossIndex][i] = -1.0;
		
		for (new i2 = 0; i2 < 3; i2++)
		{
			g_flSlenderLastFoundPlayerPos[iBossIndex][i][i2] = 0.0;
		}
		
		if (IsClientInGame(i))
		{
			if (g_iSlenderID[iBossIndex] == g_iPlayerStaticMaster[i])
			{
				g_iPlayerStaticMaster[i] = -1;
				
				// No one is the static master.
				g_hPlayerStaticTimer[i] = CreateTimer(g_flPlayerStaticDecreaseRate[i], 
					Timer_ClientDecreaseStatic, 
					GetClientUserId(i), 
					TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
					
				TriggerTimer(g_hPlayerStaticTimer[i], true);
			}
		}
	}
	
	g_iSlenderTeleportType[iBossIndex] = -1;
	g_iSlenderTeleportTarget[iBossIndex] = INVALID_ENT_REFERENCE;
	g_flSlenderTeleportMaxTargetStress[iBossIndex] = 9999.0;
	g_flSlenderTeleportMaxTargetTime[iBossIndex] = -1.0;
	g_flSlenderNextTeleportTime[iBossIndex] = -1.0;
	g_flSlenderTeleportTargetTime[iBossIndex] = -1.0;
	g_flSlenderTimeUntilKill[iBossIndex] = -1.0;
	
	// Remove all copies associated with me.
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		if (i == iBossIndex || g_iSlenderID[i] == -1) continue;
		
		if (g_iSlenderCopyMaster[i] == iBossIndex)
		{
			LogMessage("Removed boss index %d because it is a copy of boss index %d", i, iBossIndex);
			RemoveProfile(i);
		}
	}
	
	strcopy(g_strSlenderProfile[iBossIndex], sizeof(g_strSlenderProfile[]), "");
	g_iSlenderFlags[iBossIndex] = 0;
	g_iSlenderCopyMaster[iBossIndex] = -1;
	g_iSlenderID[iBossIndex] = -1;
	g_iSlender[iBossIndex] = INVALID_ENT_REFERENCE;
	g_hSlenderAttackTimer[iBossIndex] = INVALID_HANDLE;
	g_hSlenderThink[iBossIndex] = INVALID_HANDLE;
	g_hSlenderEntityThink[iBossIndex] = INVALID_HANDLE;
	
	g_hSlenderFakeTimer[iBossIndex] = INVALID_HANDLE;
	g_flSlenderAnger[iBossIndex] = 1.0;
	g_flSlenderLastKill[iBossIndex] = -1.0;
	g_iSlenderType[iBossIndex] = -1;
	g_iSlenderState[iBossIndex] = STATE_IDLE;
	g_iSlenderTarget[iBossIndex] = INVALID_ENT_REFERENCE;
	g_iSlenderModel[iBossIndex] = INVALID_ENT_REFERENCE;
	g_flSlenderFOV[iBossIndex] = 0.0;
	g_flSlenderSpeed[iBossIndex] = 0.0;
	g_flSlenderAcceleration[iBossIndex] = 0.0;
	g_flSlenderWalkSpeed[iBossIndex] = 0.0;
	g_flSlenderAirSpeed[iBossIndex] = 0.0;
	g_flSlenderTimeUntilNextProxy[iBossIndex] = -1.0;
	g_flSlenderSearchRange[iBossIndex] = 0.0;
	g_flSlenderWakeRange[iBossIndex] = 0.0;
	g_flSlenderInstaKillRange[iBossIndex] = 0.0;
	g_flSlenderScareRadius[iBossIndex] = 0.0;
	g_flSlenderProxyTeleportMinRange[iBossIndex] = 0.0;
	g_flSlenderProxyTeleportMaxRange[iBossIndex] = 0.0;
	
	for (new i = 0; i < 3; i++)
	{
		g_flSlenderDetectMins[iBossIndex][i] = 0.0;
		g_flSlenderDetectMaxs[iBossIndex][i] = 0.0;
		g_flSlenderEyePosOffset[iBossIndex][i] = 0.0;
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
	for (new i = 0; i < 3; i++) buffer[i] = defaultValue[i];
	
	if (g_hConfig == INVALID_HANDLE) return false;
	
	KvRewind(g_hConfig);
	if (!KvJumpToKey(g_hConfig, strName)) return false;
	
	KvGetVector(g_hConfig, keyValue, buffer, defaultValue);
	return true;
}

stock bool:GetProfileColor(const String:strName[], 
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

	if (g_hConfig == INVALID_HANDLE) return false;
	
	KvRewind(g_hConfig);
	if (!KvJumpToKey(g_hConfig, strName)) return false;
	
	decl String:sValue[64];
	KvGetString(g_hConfig, keyValue, sValue, sizeof(sValue));
	if (!sValue[0]) return false;
	
	KvGetColor(g_hConfig, keyValue, r, g, b, a);
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