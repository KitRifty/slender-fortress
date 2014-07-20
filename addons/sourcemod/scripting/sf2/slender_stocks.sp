#if defined _sf2_slender_stocks_included
 #endinput
#endif
#define _sf2_slender_stocks_included

#define SF2_BOSS_PAGE_CALCULATION 0.3
#define SF2_BOSS_COPY_SPAWN_MIN_DISTANCE 1850.0 // The default minimum distance boss copies can spawn from each other.


static g_iSlenderGlobalID = -1;

new g_iSlenderID[MAX_BOSSES] = { -1, ... };

SlenderGetID(iBossIndex)
{
	return g_iSlenderID[iBossIndex];
}

public SlenderOnConfigsExecuted()
{
	g_iSlenderGlobalID = -1;
}

SlenderGetCount()
{
	new iCount;
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		if (SlenderGetID(i) == -1) continue;
		if (g_iSlenderFlags[i] & SFF_FAKE) continue;
		
		iCount++;
	}
	
	return iCount;
}

bool:SlenderCanRemove(iBossIndex)
{
	if (SlenderGetID(iBossIndex) == -1) return false;
	
	if (PeopleCanSeeSlender(iBossIndex, _, false)) return false;
	
	new iTeleportType = GetProfileNum(g_strSlenderProfile[iBossIndex], "teleport_type");
	
	switch (iTeleportType)
	{
		case 0:
		{
			if (GetProfileNum(g_strSlenderProfile[iBossIndex], "static_on_radius"))
			{
				decl Float:flSlenderPos[3], Float:flBuffer[3];
				SlenderGetAbsOrigin(iBossIndex, flSlenderPos);
			
				for (new i = 1; i <= MaxClients; i++)
				{
					if (!IsClientInGame(i) || 
						!IsPlayerAlive(i) || 
						g_bPlayerEliminated[i] || 
						IsClientInGhostMode(i) || 
						IsClientInDeathCam(i)) continue;
					
					if (!IsPointVisibleToPlayer(i, flSlenderPos, false, false)) continue;
					
					GetClientAbsOrigin(i, flBuffer);
					if (GetVectorDistance(flBuffer, flSlenderPos) <= GetProfileFloat(g_strSlenderProfile[iBossIndex], "static_radius"))
					{
						return false;
					}
				}
			}
		}
		case 1:
		{
			if (PeopleCanSeeSlender(iBossIndex, _, SlenderUsesBlink(iBossIndex)) || PeopleCanSeeSlender(iBossIndex, false, false))
			{
				return false;
			}
		}
		case 2:
		{
			new iState = g_iSlenderState[iBossIndex];
			if (iState == STATE_IDLE || iState == STATE_WANDER)
			{
				if (GetGameTime() < g_flSlenderTimeUntilKill[iBossIndex])
				{
					return false;
				}
			}
			else
			{
				return false;
			}
		}
	}
	
	return true;
}

bool:SlenderGetAbsOrigin(iBossIndex, Float:buffer[3], const Float:flDefaultValue[3]={ 0.0, 0.0, 0.0 })
{
	for (new i = 0; i < 3; i++) buffer[i] = flDefaultValue[i];

	if (iBossIndex < 0 || !g_strSlenderProfile[iBossIndex][0]) return false;
	
	new slender = SlenderArrayIndexToEntIndex(iBossIndex);
	if (!slender || slender == INVALID_ENT_REFERENCE) return false;
	
	decl Float:flPos[3], Float:flOffset[3];
	GetEntPropVector(slender, Prop_Data, "m_vecAbsOrigin", flPos);
	GetProfileVector(g_strSlenderProfile[iBossIndex], "pos_offset", flOffset, flDefaultValue);
	SubtractVectors(flPos, flOffset, buffer);
	
	return true;
}

bool:SlenderGetEyePosition(iBossIndex, Float:buffer[3], const Float:flDefaultValue[3]={ 0.0, 0.0, 0.0 })
{
	for (new i = 0; i < 3; i++) buffer[i] = flDefaultValue[i];

	if (iBossIndex < 0 || !g_strSlenderProfile[iBossIndex][0]) return false;
	
	new slender = SlenderArrayIndexToEntIndex(iBossIndex);
	if (!slender || slender == INVALID_ENT_REFERENCE) return false;
	
	decl Float:flPos[3], Float:flEyePos[3];
	SlenderGetAbsOrigin(iBossIndex, flPos);
	GetProfileVector(g_strSlenderProfile[iBossIndex], "eye_pos", flEyePos);
	AddVectors(flPos, flEyePos, buffer);
	
	return true;
}

bool:SelectProfile(iBossIndex, const String:sProfile[], iFlags=0, iCopyMaster=-1, bool:bSpawnCompanions=true, bool:bPlaySpawnSound=true)
{
	if (g_hConfig == INVALID_HANDLE) 
	{
		LogError("Could not select profile for boss %d: profile list does not exist!", iBossIndex);
		return false;
	}
	
	if (!IsProfileValid(sProfile))
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
	
	if (iCopyMaster >= 0 && iCopyMaster < MAX_BOSSES && SlenderGetID(iCopyMaster) != -1)
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
				AddProfile(sCompProfile, _, _, false, false);
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
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		if (SlenderGetID(i) == -1)
		{
			if (SelectProfile(i, strName, iFlags, iCopyMaster, bSpawnCompanions, bPlaySpawnSound))
			{
				return i;
			}
			
			break;
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
			if (SlenderGetID(iBossIndex) == g_iPlayerStaticMaster[i])
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
		if (i == iBossIndex || SlenderGetID(i) == -1) continue;
		
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

SpawnSlender(iBossIndex, const Float:pos[3])
{
	RemoveSlender(iBossIndex);
	
	decl String:sProfile[SF2_MAX_PROFILE_NAME_LENGTH];
	strcopy(sProfile, sizeof(sProfile), g_strSlenderProfile[iBossIndex]);
	
	decl Float:flTruePos[3];
	GetProfileVector(sProfile, "pos_offset", flTruePos);
	AddVectors(flTruePos, pos, flTruePos);
	
	new iSlenderModel = SpawnSlenderModel(iBossIndex, flTruePos);
	if (iSlenderModel == -1) 
	{
		LogError("Could not spawn boss: model failed to spawn!");
		return;
	}
	
	decl String:sBuffer[PLATFORM_MAX_PATH];
	
	g_iSlenderModel[iBossIndex] = EntIndexToEntRef(iSlenderModel);
	
	switch (g_iSlenderType[iBossIndex])
	{
		case 1:
		{
			g_iSlender[iBossIndex] = g_iSlenderModel[iBossIndex];
			g_hSlenderEntityThink[iBossIndex] = CreateTimer(BOSS_THINKRATE, Timer_SlenderBlinkBossThink, g_iSlender[iBossIndex], TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		}
		case 2:
		{
			GetProfileString(sProfile, "model", sBuffer, sizeof(sBuffer));
			
			new iBoss = CreateEntityByName("monster_generic");
			SetEntityModel(iBoss, sBuffer);
			TeleportEntity(iBoss, flTruePos, NULL_VECTOR, NULL_VECTOR);
			DispatchSpawn(iBoss);
			ActivateEntity(iBoss);
			SetEntityRenderMode(iBoss, RENDER_TRANSCOLOR);
			SetEntityRenderColor(iBoss, 0, 0, 0, 1);
			SetVariantString("!activator");
			AcceptEntityInput(iSlenderModel, "SetParent", iBoss);
			AcceptEntityInput(iSlenderModel, "EnableShadow");
			SetEntProp(iSlenderModel, Prop_Send, "m_usSolidFlags", FSOLID_NOT_SOLID | FSOLID_TRIGGER);
			AcceptEntityInput(iBoss, "DisableShadow");
			SetEntPropFloat(iBoss, Prop_Data, "m_flFriction", 0.0);
			
			// Reset stats.
			g_iSlender[iBossIndex] = EntIndexToEntRef(iBoss);
			g_iSlenderTarget[iBossIndex] = INVALID_ENT_REFERENCE;
			g_iSlenderState[iBossIndex] = STATE_IDLE;
			g_bSlenderAttacking[iBossIndex] = false;
			g_hSlenderAttackTimer[iBossIndex] = INVALID_HANDLE;
			g_iSlenderHealthUntilStun[iBossIndex] = GetProfileNum(sProfile, "health_stun", 85);
			g_flSlenderTargetSoundLastTime[iBossIndex] = -1.0;
			g_flSlenderTargetSoundDiscardMasterPosTime[iBossIndex] = -1.0;
			g_iSlenderTargetSoundType[iBossIndex] = SoundType_None;
			g_bSlenderInvestigatingSound[iBossIndex] = false;
			g_flSlenderLastHeardFootstep[iBossIndex] = GetGameTime();
			g_flSlenderLastHeardVoice[iBossIndex] = GetGameTime();
			g_flSlenderLastHeardWeapon[iBossIndex] = GetGameTime();
			g_flSlenderNextVoiceSound[iBossIndex] = GetGameTime();
			g_flSlenderNextMoanSound[iBossIndex] = GetGameTime();
			g_flSlenderNextWanderPos[iBossIndex] = GetGameTime() + 3.0;
			g_flSlenderTimeUntilKill[iBossIndex] = GetGameTime() + GetProfileFloat(sProfile, "idle_lifetime", 10.0);
			g_flSlenderTimeUntilRecover[iBossIndex] = -1.0;
			g_flSlenderTimeUntilAlert[iBossIndex] = -1.0;
			g_flSlenderTimeUntilIdle[iBossIndex] = -1.0;
			g_flSlenderTimeUntilChase[iBossIndex] = -1.0;
			g_flSlenderTimeUntilNoPersistence[iBossIndex] = -1.0;
			g_flSlenderNextJump[iBossIndex] = GetGameTime() + GetProfileFloat(sProfile, "jump_cooldown", 2.0);
			g_flSlenderNextPathTime[iBossIndex] = GetGameTime();
			g_hSlenderEntityThink[iBossIndex] = CreateTimer(BOSS_THINKRATE, Timer_SlenderChaseBossThink, EntIndexToEntRef(iBoss), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
			g_iSlenderInterruptConditions[iBossIndex] = 0;
			g_bSlenderChaseDeathPosition[iBossIndex] = false;
			
			for (new i = 0; i < 3; i++)
			{
				g_flSlenderGoalPos[iBossIndex][i] = 0.0;
				g_flSlenderTargetSoundTempPos[iBossIndex][i] = 0.0;
				g_flSlenderTargetSoundMasterPos[iBossIndex][i] = 0.0;
				g_flSlenderChaseDeathPosition[iBossIndex][i] = 0.0;
			}
			
			for (new i = 1; i <= MaxClients; i++)
			{
				g_flSlenderLastFoundPlayer[iBossIndex][i] = -1.0;
				
				for (new i2 = 0; i2 < 3; i2++)
				{
					g_flSlenderLastFoundPlayerPos[iBossIndex][i][i2] = 0.0;
				}
			}
			
			SlenderClearTargetMemory(iBossIndex);
			
			if (GetProfileNum(sProfile, "stun_enabled"))
			{
				SetEntProp(iBoss, Prop_Data, "m_takedamage", 1);
			}
			
			SDKHook(iBoss, SDKHook_OnTakeDamage, Hook_SlenderOnTakeDamage);
			SDKHook(iBoss, SDKHook_OnTakeDamagePost, Hook_SlenderOnTakeDamagePost);
			DHookEntity(g_hSDKShouldTransmit, true, iBoss);
		}
		/*
		default:
		{
			g_iSlender[iBossIndex] = g_iSlenderModel[iBossIndex];
			SDKHook(iSlenderModel, SDKHook_SetTransmit, Hook_SlenderSetTransmit);
		}
		*/
	}
	
	SDKHook(iSlenderModel, SDKHook_SetTransmit, Hook_SlenderModelSetTransmit);
	
	SlenderSpawnEffects(iBossIndex, EffectEvent_Constant);
	
	SetEntProp(iSlenderModel, Prop_Send, "m_nSkin", GetProfileNum(sProfile, "skin"));
	SetEntProp(iSlenderModel, Prop_Send, "m_nBody", GetProfileNum(sProfile, "body"));
	
	// Initialize our pose parameters, if needed.
	new iPose = EntRefToEntIndex(g_iSlenderPoseEnt[iBossIndex]);
	g_iSlenderPoseEnt[iBossIndex] = INVALID_ENT_REFERENCE;
	if (iPose && iPose != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(iPose, "Kill");
	}
	
	decl String:sPoseParameter[64];
	GetProfileString(sProfile, "pose_parameter", sPoseParameter, sizeof(sPoseParameter));
	if (sPoseParameter[0])
	{
		iPose = CreateEntityByName("point_posecontroller");
		if (iPose != -1)
		{
			// We got a pose parameter! We need a name!
			Format(sBuffer, sizeof(sBuffer), "s%dposepls", g_iSlenderModel[iBossIndex]);
			DispatchKeyValue(iSlenderModel, "targetname", sBuffer);
			
			DispatchKeyValue(iPose, "PropName", sBuffer);
			DispatchKeyValue(iPose, "PoseParameterName", sPoseParameter);
			DispatchKeyValueFloat(iPose, "PoseValue", GetProfileFloat(sProfile, "pose_parameter_max"));
			DispatchSpawn(iPose);
			SetVariantString(sPoseParameter);
			AcceptEntityInput(iPose, "SetPoseParameterName");
			SetVariantString("!activator");
			AcceptEntityInput(iPose, "SetParent", iSlenderModel);
			
			g_iSlenderPoseEnt[iBossIndex] = EntIndexToEntRef(iPose);
		}
	}
	
	// Call our forward.
	Call_StartForward(fOnBossSpawn);
	Call_PushCell(iBossIndex);
	Call_Finish();
}

RemoveSlender(iBossIndex)
{
	new iBoss = SlenderArrayIndexToEntIndex(iBossIndex);
	g_iSlender[iBossIndex] = INVALID_ENT_REFERENCE;
	
	if (iBoss && iBoss != INVALID_ENT_REFERENCE)
	{
		// Stop all possible looping sounds.
		ClientStopAllSlenderSounds(iBoss, g_strSlenderProfile[iBossIndex], "sound_move", SNDCHAN_AUTO);
		
		if (g_iSlenderFlags[iBossIndex] & SFF_HASSTATICLOOPLOCALSOUND)
		{
			decl String:sLoopSound[PLATFORM_MAX_PATH];
			GetRandomStringFromProfile(g_strSlenderProfile[iBossIndex], "sound_static_loop_local", sLoopSound, sizeof(sLoopSound), 1);
			
			if (sLoopSound[0])
			{
				StopSound(iBoss, SNDCHAN_STATIC, sLoopSound);
			}
		}
		
		AcceptEntityInput(iBoss, "Kill");
	}
}

stock bool:SlenderCanHearPlayer(iBossIndex, client, SoundType:iSoundType)
{
	if (!IsValidClient(client) || !IsPlayerAlive(client)) return false;
	
	new iSlender = SlenderArrayIndexToEntIndex(iBossIndex);
	if (!iSlender || iSlender == INVALID_ENT_REFERENCE) return false;
	
	decl Float:flHisPos[3], Float:flMyPos[3];
	GetClientAbsOrigin(client, flHisPos);
	SlenderGetAbsOrigin(iBossIndex, flMyPos);
	
	new Float:flHearRadius = GetProfileFloat(g_strSlenderProfile[iBossIndex], "search_sound_range", 1024.0);
	if (flHearRadius <= 0.0) return false;
	
	new Float:flDistance = GetVectorDistance(flHisPos, flMyPos);
	
	// Trace check.
	new Handle:hTrace = INVALID_HANDLE;
	new bool:bTraceHit = false;
	
	decl Float:flMyEyePos[3];
	SlenderGetEyePosition(iBossIndex, flMyEyePos);
	
	if (iSoundType == SoundType_Footstep)
	{
		if (!(GetEntityFlags(client) & FL_ONGROUND)) return false;
		
		if (GetEntProp(client, Prop_Send, "m_bDucking") || GetEntProp(client, Prop_Send, "m_bDucked")) flDistance *= 1.85;
		if (IsClientReallySprinting(client)) flDistance *= 0.66;
		
		hTrace = TR_TraceRayFilterEx(flMyPos, flHisPos, MASK_NPCSOLID, RayType_EndPoint, TraceRayDontHitPlayersOrEntity, iSlender);
		bTraceHit = TR_DidHit(hTrace);
		CloseHandle(hTrace);
	}
	else if (iSoundType == SoundType_Voice)
	{
		decl Float:flHisEyePos[3];
		GetClientEyePosition(client, flHisEyePos);
		
		hTrace = TR_TraceRayFilterEx(flMyEyePos, flHisEyePos, MASK_NPCSOLID, RayType_EndPoint, TraceRayDontHitPlayersOrEntity, iSlender);
		bTraceHit = TR_DidHit(hTrace);
		CloseHandle(hTrace);
		
		flDistance *= 0.5;
	}
	else if (iSoundType == SoundType_Weapon)
	{
		decl Float:flHisMins[3], Float:flHisMaxs[3];
		GetEntPropVector(client, Prop_Send, "m_vecMins", flHisMins);
		GetEntPropVector(client, Prop_Send, "m_vecMaxs", flHisMaxs);
		
		new Float:flMiddle[3];
		for (new i = 0; i < 2; i++) flMiddle[i] = (flHisMins[i] + flHisMaxs[i]) / 2.0;
		
		decl Float:flEndPos[3];
		GetClientAbsOrigin(client, flEndPos);
		AddVectors(flHisPos, flMiddle, flEndPos);
		
		hTrace = TR_TraceRayFilterEx(flMyEyePos, flEndPos, MASK_NPCSOLID, RayType_EndPoint, TraceRayDontHitPlayersOrEntity, iSlender);
		bTraceHit = TR_DidHit(hTrace);
		CloseHandle(hTrace);
		
		flDistance *= 0.66;
	}
	
	if (bTraceHit) flDistance *= 1.66;
	
	if (TF2_GetPlayerClass(client) == TFClass_Spy) flDistance *= 1.35;
	
	if (flDistance > flHearRadius) return false;
	
	return true;
}

stock SlenderEntIndexToArrayIndex(entity)
{
	if (!entity || !IsValidEntity(entity)) return -1;
	
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		if (SlenderArrayIndexToEntIndex(i) == entity)
		{
			return i;
		}
	}
	
	return -1;
}

stock SlenderArrayIndexToEntIndex(iBossIndex)
{
	return EntRefToEntIndex(g_iSlender[iBossIndex]);
}

stock bool:SlenderOnlyLooksIfNotSeen(iBossIndex)
{
	if (g_iSlenderType[iBossIndex] == 1) return true;
	return false;
}

stock bool:SlenderUsesBlink(iBossIndex)
{
	if (g_iSlenderType[iBossIndex] == 1) return true;
	return false;
}

stock bool:SlenderKillsOnNear(iBossIndex)
{
	if (g_iSlenderType[iBossIndex] == 1) return false;
	return true;
}

stock SlenderClearTargetMemory(iBossIndex)
{
	if (iBossIndex == -1) return;
	
	g_iSlenderCurrentPathNode[iBossIndex] = -1;
	if (g_hSlenderPath[iBossIndex] == INVALID_HANDLE) return;
	
	ClearArray(g_hSlenderPath[iBossIndex]);
}

stock bool:SlenderCreateTargetMemory(iBossIndex)
{
	if (iBossIndex == -1) return false;
	
	g_iSlenderCurrentPathNode[iBossIndex] = -1;
	if (g_hSlenderPath[iBossIndex] != INVALID_HANDLE) return true;
	
	g_hSlenderPath[iBossIndex] = CreateArray(3);
	return true;
}

stock SlenderRemoveTargetMemory(iBossIndex)
{
	if (iBossIndex == -1) return;
	
	g_iSlenderCurrentPathNode[iBossIndex] = -1;
	
	if (g_hSlenderPath[iBossIndex] == INVALID_HANDLE) return;
	
	new Handle:hLocs = g_hSlenderPath[iBossIndex];
	g_hSlenderPath[iBossIndex] = INVALID_HANDLE;
	CloseHandle(hLocs);
}

bool:SlenderCalculateApproachToPlayer(iBossIndex, iBestPlayer, Float:buffer[3])
{
	if (!IsValidClient(iBestPlayer)) return false;
	
	new slender = SlenderArrayIndexToEntIndex(iBossIndex);
	if (!slender || slender == INVALID_ENT_REFERENCE) return false;
	
	decl Float:flSlenderPos[3], Float:flPos[3], Float:flReferenceAng[3], Float:hisEyeAng[3], Float:tempDir[3], Float:tempPos[3];
	GetClientEyePosition(iBestPlayer, flPos);
	
	GetEntPropVector(slender, Prop_Data, "m_angAbsRotation", hisEyeAng);
	AddVectors(hisEyeAng, g_flSlenderEyeAngOffset[iBossIndex], hisEyeAng);
	for (new i = 0; i < 3; i++) hisEyeAng[i] = AngleNormalize(hisEyeAng[i]);
	
	SlenderGetAbsOrigin(iBossIndex, flSlenderPos);
	
	SubtractVectors(flPos, flSlenderPos, flReferenceAng);
	GetVectorAngles(flReferenceAng, flReferenceAng);
	for (new i = 0; i < 3; i++) flReferenceAng[i] = AngleNormalize(flReferenceAng[i]);
	new Float:flDist = GetProfileFloat(g_strSlenderProfile[iBossIndex], "speed") * g_flRoundDifficultyModifier;
	if (flDist < GetProfileFloat(g_strSlenderProfile[iBossIndex], "kill_radius")) flDist = GetProfileFloat(g_strSlenderProfile[iBossIndex], "kill_radius") / 2.0;
	new Float:flWithinFOV = 45.0;
	new Float:flWithinFOVSide = 90.0;
	
	decl Handle:hTrace, index, Float:flHitNormal[3], Float:tempPos2[3], Float:flBuffer[3], Float:flBuffer2[3];
	new Handle:hArray = CreateArray(6);
	
	decl Float:flCheckAng[3];
	
	new iRange = 0;
	new iID = 1;
	
	for (new Float:addAng = 0.0; addAng < 360.0; addAng += 7.5)
	{
		tempDir[0] = 0.0;
		tempDir[1] = AngleNormalize(hisEyeAng[1] + addAng);
		tempDir[2] = 0.0;
		
		GetAngleVectors(tempDir, tempDir, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(tempDir, tempDir);
		ScaleVector(tempDir, flDist);
		AddVectors(tempDir, flSlenderPos, tempPos);
		AddVectors(tempPos, g_flSlenderEyePosOffset[iBossIndex], tempPos);
		AddVectors(flSlenderPos, g_flSlenderEyePosOffset[iBossIndex], tempPos2);
		
		flBuffer[0] = g_flSlenderDetectMins[iBossIndex][0];
		flBuffer[1] = g_flSlenderDetectMins[iBossIndex][1];
		flBuffer[2] = 0.0;
		flBuffer2[0] = g_flSlenderDetectMaxs[iBossIndex][0];
		flBuffer2[1] = g_flSlenderDetectMaxs[iBossIndex][1];
		flBuffer2[2] = 0.0;
		
		// Get a good move position.
		hTrace = TR_TraceHullFilterEx(tempPos2, tempPos, flBuffer, flBuffer2, MASK_PLAYERSOLID_BRUSHONLY, TraceRayDontHitPlayersOrEntity, slender);
		TR_GetEndPosition(tempPos, hTrace);
		CloseHandle(hTrace);
		
		// Drop to the ground if we're above ground.
		hTrace = TR_TraceRayFilterEx(tempPos, Float:{ 90.0, 0.0, 0.0 }, MASK_PLAYERSOLID_BRUSHONLY, RayType_Infinite, TraceRayDontHitPlayersOrEntity, slender);
		new bool:bHit = TR_DidHit(hTrace);
		TR_GetEndPosition(tempPos2, hTrace);
		CloseHandle(hTrace);
		
		// Then calculate from there.
		hTrace = TR_TraceHullFilterEx(tempPos, tempPos2, g_flSlenderDetectMins[iBossIndex], g_flSlenderDetectMaxs[iBossIndex], MASK_PLAYERSOLID_BRUSHONLY, TraceRayDontHitPlayersOrEntity, slender);
		TR_GetEndPosition(tempPos, hTrace);
		TR_GetPlaneNormal(hTrace, flHitNormal);
		CloseHandle(hTrace);
		SubtractVectors(tempPos, flSlenderPos, flCheckAng);
		GetVectorAngles(flCheckAng, flCheckAng);
		GetVectorAngles(flHitNormal, flHitNormal);
		for (new i = 0; i < 3; i++) 
		{
			flHitNormal[i] = AngleNormalize(flHitNormal[i]);
			flCheckAng[i] = AngleNormalize(flCheckAng[i]);
		}
		
		new Float:diff = AngleDiff(flCheckAng[1], flReferenceAng[1]);
		
		new bool:bBackup = false;
		
		if (FloatAbs(diff) > flWithinFOV) bBackup = true;
		
		if (diff >= 0.0 && diff <= flWithinFOVSide) iRange = 1;
		else if (diff < 0.0 && diff >= -flWithinFOVSide) iRange = 2;
		else continue;
		
		if ((flHitNormal[0] >= 0.0 && flHitNormal[0] < 45.0)
			|| (flHitNormal[0] < 0.0 && flHitNormal[0] > -45.0)
			|| !bHit
			|| TR_PointOutsideWorld(tempPos)
			|| IsSpaceOccupiedNPC(tempPos, g_flSlenderDetectMins[iBossIndex], g_flSlenderDetectMaxs[iBossIndex], iBestPlayer))
		{
			continue;
		}
		
		// Check from top to bottom of me.
		
		if (!IsPointVisibleToPlayer(iBestPlayer, tempPos, false, false)) continue;
		
		AddVectors(tempPos, g_flSlenderEyePosOffset[iBossIndex], tempPos);
		
		if (!IsPointVisibleToPlayer(iBestPlayer, tempPos, false, false)) continue;
		
		SubtractVectors(tempPos, g_flSlenderEyePosOffset[iBossIndex], tempPos);
		
		//	Insert the vector into our array.
		index = PushArrayCell(hArray, iID);
		SetArrayCell(hArray, index, tempPos[0], 1);
		SetArrayCell(hArray, index, tempPos[1], 2);
		SetArrayCell(hArray, index, tempPos[2], 3);
		SetArrayCell(hArray, index, iRange, 4);
		SetArrayCell(hArray, index, bBackup, 5);
		
		iID++;
	}
	
	new size;
	if ((size = GetArraySize(hArray)) > 0)
	{
		new Float:diff = AngleDiff(hisEyeAng[1], flReferenceAng[1]);
		if (diff >= 0.0) iRange = 1;
		else iRange = 2;
		
		new bool:bBackup = false;
		
		// Clean up any vectors that we don't need.
		new Handle:hArray2 = CloneArray(hArray);
		for (new i = 0; i < size; i++)
		{
			if (GetArrayCell(hArray2, i, 4) != iRange || bool:GetArrayCell(hArray2, i, 5) != bBackup)
			{
				new iIndex = FindValueInArray(hArray, GetArrayCell(hArray2, i));
				if (iIndex != -1) RemoveFromArray(hArray, iIndex);
			}
		}
		
		CloseHandle(hArray2);
		
		size = GetArraySize(hArray);
		if (size)
		{
			index = GetRandomInt(0, size - 1);
			buffer[0] = Float:GetArrayCell(hArray, index, 1);
			buffer[1] = Float:GetArrayCell(hArray, index, 2);
			buffer[2] = Float:GetArrayCell(hArray, index, 3);
		}
		else
		{
			CloseHandle(hArray);
			return false;
		}
	}
	else
	{
		CloseHandle(hArray);
		return false;
	}
	
	CloseHandle(hArray);
	return true;
}

// This functor ensures that the proposed boss position is not too
// close to other players that are within the distance defined by
// flMinSearchDist.

// Returning false on the functor will immediately discard the proposed position.

public bool:SlenderChaseBossPlaceFunctor(iBossIndex, const Float:flActiveAreaCenterPos[3], const Float:flAreaPos[3], Float:flMinSearchDist, Float:flMaxSearchDist, bool:bOriginalResult)
{
	if (FloatAbs(flActiveAreaCenterPos[2] - flAreaPos[2]) > 320.0)
	{
		return false;
	}
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) ||
			!IsPlayerAlive(i) ||
			g_bPlayerEliminated[i] ||
			g_bPlayerEscaped[i]) continue;
		
		decl Float:flClientPos[3];
		GetClientAbsOrigin(i, flClientPos);
		
		if (GetVectorDistance(flClientPos, flAreaPos) < flMinSearchDist)
		{
			return false;
		}
	}
	
	return bOriginalResult;
}

/*
// Deprecated.

// This is just to calculate the new place, not do time checks.
// Distance will be determined by the progression of the game and the
// manually set values determined by flMinSearchDist and flMaxSearchDist,
// which are float values that are (or should be) defined in the boss's
// config file.

// The place chosen should be out of (possible) sight of the players,
// but should be within the AAS radius, the center being flActiveAreaCenterPos.
// The game will try to find a place that is of flMinSearchDist first, but
// if it can't, then it will try to find places that are a bit farther.

// If the whole function fails, no place is given and the boss will not
// be able to spawn.

bool:SlenderChaseBossCalculateNewPlace(iBossIndex, const Float:flActiveAreaCenterPos[3], Float:flMinSearchDist, Float:flMaxSearchDist, Function:iFunctor, Float:flBuffer[3])
{
	new Handle:hAreas = NavMesh_GetAreas();
	if (hAreas == INVALID_HANDLE) return false;
	
	new iBestAreaIndex = -1;
	new Float:flBestAreaDist = -1.0;
	
	decl Float:flAreaCenterPos[3];
	for (new i = 0, iSize = GetArraySize(hAreas); i < iSize; i++)
	{
		NavMeshArea_GetCenter(i, flAreaCenterPos);
		
		new Float:flDist = GetVectorDistance(flActiveAreaCenterPos, flAreaCenterPos);
		if (flDist < flMinSearchDist || flDist > flMaxSearchDist) continue;
		
		if (IsPointVisibleToAPlayer(flAreaCenterPos, false, false)) continue;
		
		decl Float:flTestPos[3];
		for (new i2 = 0; i2 < 3; i2++) flTestPos[i2] = flAreaCenterPos[i2] + g_flSlenderEyePosOffset[iBossIndex][i2];
		
		if (IsPointVisibleToAPlayer(flTestPos, false, false)) continue;
		
		if (iFunctor != INVALID_FUNCTION)
		{
			new bool:bResult = true;
			
			Call_StartFunction(INVALID_HANDLE, iFunctor);
			Call_PushCell(iBossIndex);
			Call_PushArray(flActiveAreaCenterPos, 3);
			Call_PushArray(flAreaCenterPos, 3);
			Call_PushFloat(flMinSearchDist);
			Call_PushFloat(flMaxSearchDist);
			Call_PushCell(bResult);
			Call_Finish(bResult);
			
			if (!bResult) continue;
		}
		
		if (flBestAreaDist < 0.0 || flDist < flBestAreaDist)
		{
			iBestAreaIndex = i;
			flBestAreaDist = flDist;
		}
	}
	
	if (iBestAreaIndex == -1) return false;
	
	NavMeshArea_GetCenter(iBestAreaIndex, flBuffer);
	return true;
}
*/

bool:SlenderCalculateNewPlace(iBossIndex, Float:buffer[3], bool:bIgnoreCopies=false, bool:bProxy=false, iProxyPlayer=-1, &iBestPlayer=-1)
{
	new Float:flPercent = 0.0;
	if (g_iPageMax > 0)
	{
		flPercent = (float(g_iPageCount) / float(g_iPageMax)) * g_flRoundDifficultyModifier * g_flSlenderAnger[iBossIndex];
	}
	
#if defined DEBUG
	new iArraySize, iArraySize2;
#endif
	
	if (!IsValidClient(iBestPlayer))
	{
		// 	Pick a player to appear to.
		new Handle:hArray = CreateArray();
		
		for (new i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || 
				!IsPlayerAlive(i) || 
				IsClientInDeathCam(i) || 
				g_bPlayerEliminated[i] || 
				g_bPlayerEscaped[i]) continue;
			
			if (SlenderGetFromID(g_iSlenderCopyMaster[iBossIndex]) != -1 && !bIgnoreCopies)
			{
				new bool:bwub = false;
			
				// No? Then check if players around him are targeted by a boss already (not me).
				for (new iBossPlayer = 1; iBossPlayer <= MaxClients; iBossPlayer++)
				{
					if (i == iBossPlayer) continue;
				
					if (!IsClientInGame(iBossPlayer) || 
						!IsPlayerAlive(iBossPlayer) || 
						IsClientInDeathCam(iBossPlayer) || 
						g_bPlayerEliminated[iBossPlayer] || 
						g_bPlayerEscaped[iBossPlayer]) continue;
					
					// Get the boss that's targeting this player, if any.
					for (new iBoss = 0; iBoss < MAX_BOSSES; iBoss++)
					{
						if (iBossIndex == iBoss || SlenderGetID(iBoss) == -1) continue;
						
						if (EntRefToEntIndex(g_iSlenderTarget[iBoss]) == iBossPlayer)
						{
							// Are we near this player?
							if (EntityDistanceFromEntity(iBossPlayer, i) < SF2_BOSS_COPY_SPAWN_MIN_DISTANCE)
							{
								bwub = true;
								break;
							}
						}
					}
				}
				
				if (bwub) continue;
			}
			
			PushArrayCell(hArray, i);
		}
		
#if defined DEBUG
		iArraySize = GetArraySize(hArray);
		iArraySize2 = iArraySize;
#endif
		
		if (GetArraySize(hArray))
		{
			if (g_iSlenderCopyMaster[iBossIndex] == -1 ||
				GetProfileNum(g_strSlenderProfile[iBossIndex], "copy_calculatepagecount", 0))
			{
				new tempBestPageCount = -1;
				
				new Handle:hTempArray = CloneArray(hArray);
				for (new i = 0; i < GetArraySize(hTempArray); i++)
				{
					new iClient = GetArrayCell(hTempArray, i);
					if (g_iPlayerPageCount[iClient] > tempBestPageCount)
					{
						tempBestPageCount = g_iPlayerPageCount[iClient];
					}
				}
				
				for (new i = 0; i < GetArraySize(hTempArray); i++)
				{
					new iClient = GetArrayCell(hTempArray, i);
					if ((float(g_iPlayerPageCount[iClient]) / float(tempBestPageCount)) < SF2_BOSS_PAGE_CALCULATION)
					{
						new index = FindValueInArray(hArray, iClient);
						if (index != -1) RemoveFromArray(hArray, index);
					}
				}
				
				CloseHandle(hTempArray);
			}
			
#if defined DEBUG
			iArraySize2 = GetArraySize(hArray);
#endif
		}
		
		if (GetArraySize(hArray))
		{
			iBestPlayer = GetArrayCell(hArray, GetRandomInt(0, GetArraySize(hArray) - 1));
		}
	
		CloseHandle(hArray);
	}
	
#if defined DEBUG
	if (GetConVarBool(g_cvDebugBosses)) PrintToChatAll("SlenderCalculateNewPlace(%d): array size 1 = %d, array size 2 = %d", iBossIndex, iArraySize, iArraySize2);
#endif
	
	if (iBestPlayer <= 0) 
	{
#if defined DEBUG
		if (GetConVarBool(g_cvDebugBosses)) PrintToChatAll("SlenderCalculateNewPlace(%d) failed: no ibestPlayer!", iBossIndex);
#endif
		return false;
	}
	
	//	Determine the distance we can appear from the player.
	new Float:flPercentFar = 0.75 * (1.0 - flPercent);
	new Float:flPercentAverage = 0.6 * (1.0 - flPercent);
	//new Float:flPercentClose = 1.0 - flPercentFar - flPercentAverage;
	
	new Float:flUpperBoundFar = flPercentFar;
	new Float:flUpperBoundAverage = flPercentFar + flPercentAverage;
	//new Float:flUpperBoundClose = 1.0;
	
	new iRange = 1;
	new Float:flChance = GetRandomFloat(0.0, 1.0);
	new Float:flMaxRangeN = GetProfileFloat(g_strSlenderProfile[iBossIndex], "teleport_range_max");
	new Float:flMinRangeN = GetProfileFloat(g_strSlenderProfile[iBossIndex], "teleport_range_min");
	
	new bool:bVisiblePls = false;
	new bool:bBeCreepy = false;
	
	if (!bProxy)
	{
		// Are we gonna teleport in front of a player this time?
		if (GetProfileNum(g_strSlenderProfile[iBossIndex], "teleport_ignorevis_enable"))
		{
			if (GetRandomFloat(0.0, 1.0) < GetProfileFloat(g_strSlenderProfile[iBossIndex], "teleport_ignorevis_chance") * g_flSlenderAnger[iBossIndex] * g_flRoundDifficultyModifier)
			{
				bVisiblePls = true;
			}
			
			if (GetRandomFloat(0.0, 1.0) < GetProfileFloat(g_strSlenderProfile[iBossIndex], "teleport_creepy_chance", 0.33))
			{
				bBeCreepy = true;
			}
		}
	}
	
	new Float:flMaxRange = flMaxRangeN;
	new Float:flMinRange = flMinRangeN;
	
	if (bVisiblePls)
	{
		flMaxRange = GetProfileFloat(g_strSlenderProfile[iBossIndex], "teleport_ignorevis_range_max", flMaxRangeN);
		flMinRange = GetProfileFloat(g_strSlenderProfile[iBossIndex], "teleport_ignorevis_range_min", flMinRangeN);
	}
	
	// Get distances.
	new Float:flDistanceFar = GetRandomFloat(flMaxRange * 0.75, flMaxRange);
	if (flDistanceFar < flMinRange) flDistanceFar = flMinRange;
	new Float:flDistanceAverage = GetRandomFloat(flMaxRange * 0.33, flMaxRange * 0.75);
	if (flDistanceAverage < flMinRange) flDistanceAverage = flMinRange;
	new Float:flDistanceClose = GetRandomFloat(0.0, flMaxRange * 0.33);
	if (flDistanceClose < flMinRange) flDistanceClose = flMinRange;
	
	if (flChance >= 0.0 && flChance < flUpperBoundFar) iRange = 1;
	else if (flChance >= flUpperBoundFar && flChance < flUpperBoundAverage) iRange = 2;
	else if (flChance >= flUpperBoundAverage) iRange = 3;
	
	// 	Get a circle of positions around the player that we can appear in.
	
	// Create arrays first.
	new Handle:hArrayFar = CreateArray(3);
	new Handle:hArrayAverage = CreateArray(3);
	new Handle:hArrayClose = CreateArray(3);
	
	// Set up our distances array.
	decl Float:flDistances[3];
	flDistances[0] = flDistanceFar;
	flDistances[1] = flDistanceAverage;
	flDistances[2] = flDistanceClose;
	
	decl Float:hisEyePos[3], Float:hisEyeAng[3], Float:tempPos[3], Float:tempDir[3], Float:flBuffer[3], Float:flBuffer2[3], Float:flBuffer3[3];
	GetClientEyePosition(iBestPlayer, hisEyePos);
	GetClientEyeAngles(iBestPlayer, hisEyeAng);
	
	decl Handle:hTrace, index, Float:flHitNormal[3];
	decl Handle:hArray;
	
	decl Float:flTargetMins[3], Float:flTargetMaxs[3];
	if (!bProxy)
	{
		for (new i = 0; i < 3; i++)
		{
			flTargetMins[i] = g_flSlenderDetectMins[iBossIndex][i];
			flTargetMaxs[i] = g_flSlenderDetectMaxs[iBossIndex][i];
		}
	}
	else
	{
		GetEntPropVector(iProxyPlayer, Prop_Send, "m_vecMins", flTargetMins);
		GetEntPropVector(iProxyPlayer, Prop_Send, "m_vecMaxs", flTargetMaxs);
	}
	
	for (new i = 0; i < iRange; i++)
	{
		for (new Float:addAng = 0.0; addAng < 360.0; addAng += 7.5)
		{
			tempDir[0] = 0.0;
			tempDir[1] = hisEyeAng[1] + addAng;
			tempDir[2] = 0.0;
			
			GetAngleVectors(tempDir, tempDir, NULL_VECTOR, NULL_VECTOR);
			NormalizeVector(tempDir, tempDir);
			ScaleVector(tempDir, flDistances[i]);
			AddVectors(tempDir, hisEyePos, tempPos);
			
			// Drop to the ground if we're above ground using a TraceHull so IsSpaceOccupiedNPC can return true on something.
			hTrace = TR_TraceRayFilterEx(tempPos, Float:{ 90.0, 0.0, 0.0 }, MASK_NPCSOLID, RayType_Infinite, TraceRayDontHitPlayersOrEntity, iBestPlayer);
			TR_GetEndPosition(flBuffer, hTrace);
			CloseHandle(hTrace);
			
			flBuffer2[0] = flTargetMins[0];
			flBuffer2[1] = flTargetMins[1];
			flBuffer2[2] = -flTargetMaxs[2];
			flBuffer3[0] = flTargetMaxs[0];
			flBuffer3[1] = flTargetMaxs[1];
			flBuffer3[2] = -flTargetMins[0];
			
			if (GetVectorDistance(tempPos, flBuffer) >= 300.0) continue;
			
			// Drop dowwwwwn.
			hTrace = TR_TraceHullFilterEx(tempPos, flBuffer, flBuffer2, flBuffer3, MASK_NPCSOLID, TraceRayDontHitPlayersOrEntity, iBestPlayer);
			TR_GetEndPosition(tempPos, hTrace);
			TR_GetPlaneNormal(hTrace, flHitNormal);
			CloseHandle(hTrace);
			
			GetVectorAngles(flHitNormal, flHitNormal);
			for (new i2 = 0; i2 < 3; i2++) flHitNormal[i2] = AngleNormalize(flHitNormal[i2]);
			
			tempPos[2] -= g_flSlenderDetectMaxs[iBossIndex][2];
			
			if (TR_PointOutsideWorld(tempPos)
				|| (IsSpaceOccupiedNPC(tempPos, flTargetMins, flTargetMaxs, SlenderArrayIndexToEntIndex(iBossIndex)))
				|| (bProxy && IsSpaceOccupiedPlayer(tempPos, flTargetMins, flTargetMaxs, iProxyPlayer))
				|| (flHitNormal[0] >= 0.0 && flHitNormal[0] < 45.0)
				|| (flHitNormal[0] < 0.0 && flHitNormal[0] > -45.0))
			{
				continue;
			}
			
			// Check if this position isn't too close to anyone else.
			new bool:bTooClose = false;
			
			for (new i2 = 1; i2 <= MaxClients; i2++)
			{
				if (!IsClientInGame(i2) || !IsPlayerAlive(i2) || g_bPlayerEliminated[i2] || IsClientInGhostMode(i2)) continue;
				GetClientAbsOrigin(i2, flBuffer);
				if (GetVectorDistance(flBuffer, tempPos) < flMinRange)
				{
					bTooClose = true;
					break;
				}
			}
			
			// Check if this position is too close to a boss.
			if (!bTooClose)
			{
				decl iSlender;
				for (new i2 = 0; i2 < MAX_BOSSES; i2++)
				{
					if (i2 == iBossIndex) continue;
					if (SlenderGetID(i2) == -1) continue;
					if (!g_strSlenderProfile[i2][0]) continue;
					
					// If I'm a main boss, only check the distance between my copies and me.
					if (g_iSlenderCopyMaster[iBossIndex] == -1)
					{
						if (g_iSlenderCopyMaster[i2] != iBossIndex) continue;
					}
					// If I'm a copy, just check with my other copy friends and my main boss.
					else
					{
						new iMyMaster = g_iSlenderCopyMaster[iBossIndex];
						if (g_iSlenderCopyMaster[i2] != iMyMaster || i2 != iMyMaster) continue;
					}
					
					iSlender = SlenderArrayIndexToEntIndex(i2);
					if (!iSlender || iSlender == INVALID_ENT_REFERENCE) continue;
					
					SlenderGetAbsOrigin(i2, flBuffer);
					if (GetVectorDistance(flBuffer, tempPos) < GetProfileFloat(g_strSlenderProfile[iBossIndex], "teleport_dist_from_other_copies", 800.0))
					{
						bTooClose = true;
						break;
					}
				}
			}
			
			if (bTooClose) continue;
			
			// Check from top to bottom of me.
			
			new bool:bCheckBlink = bool:GetProfileNum(g_strSlenderProfile[iBossIndex], "teleport_use_blink");
			
			// Check if my copy master or my fellow copies could see this position.
			new bool:bDontAddPosition = false;
			new iCopyMaster = SlenderGetFromID(g_iSlenderCopyMaster[iBossIndex]);
			
			decl Float:flCopyCheckPositions[6];
			for (new i2 = 0; i2 < 3; i2++) flCopyCheckPositions[i2] = tempPos[i2];
			for (new i2 = 3; i2 < 6; i2++) flCopyCheckPositions[i2] = tempPos[i2 - 3] + g_flSlenderEyePosOffset[iBossIndex][i2 - 3];
			
			for (new i2 = 0; i2 < 2; i2++)
			{
				decl Float:flCopyCheckPos[3];
				for (new i3 = 0; i3 < 3; i3++) flCopyCheckPos[i3] = flCopyCheckPositions[i3 + (3 * i2)];
				
				// Check the conditions first.
				if (bVisiblePls)
				{
					if (!IsPointVisibleToAPlayer(flCopyCheckPos, _, bCheckBlink) &&
						!IsPointVisibleToPlayer(iBestPlayer, flCopyCheckPos, _, bCheckBlink))
					{
						bDontAddPosition = true;
						break;
					}
				}
				else if (bBeCreepy)
				{
					if (!IsPointVisibleToAPlayer(flCopyCheckPos, _, bCheckBlink) &&
						IsPointVisibleToAPlayer(flCopyCheckPos, false, bCheckBlink) &&
						IsPointVisibleToPlayer(iBestPlayer, flCopyCheckPos, false, bCheckBlink))
					{
						// Do nothing.
					}
					else
					{
						continue;
					}
				}
				else
				{
					if (IsPointVisibleToAPlayer(flCopyCheckPos, _, bCheckBlink))
					{
						bDontAddPosition = true;
						break;
					}
				}
				
				for (new i3 = 0; i3 < MAX_BOSSES; i3++)
				{
					if (i3 == iBossIndex) continue;
					if (SlenderGetID(i3) == -1) continue;
					
					new iBoss = SlenderArrayIndexToEntIndex(i3);
					if (!iBoss || iBoss == INVALID_ENT_REFERENCE) continue;
					
					if (i3 == iCopyMaster || 
						(iCopyMaster != -1 && SlenderGetFromID(g_iSlenderCopyMaster[i3]) == iCopyMaster))
					{
					}
					else continue;
					
					decl Float:flCopyPos[3];
					SlenderGetEyePosition(i3, flCopyPos);
					hTrace = TR_TraceRayFilterEx(flCopyPos,
						flCopyCheckPos,
						CONTENTS_SOLID | CONTENTS_MOVEABLE | CONTENTS_MIST,
						RayType_EndPoint,
						TraceRayBossVisibility,
						iBoss);
					
					bDontAddPosition = !TR_DidHit(hTrace);
					CloseHandle(hTrace);
					
					if (!bDontAddPosition)
					{
						decl Float:flCopyMins[3], Float:flCopyMaxs[3];
						GetEntPropVector(iBoss, Prop_Data, "m_vecAbsOrigin", flCopyPos);
						GetEntPropVector(iBoss, Prop_Send, "m_vecMins", flCopyMins);
						GetEntPropVector(iBoss, Prop_Send, "m_vecMaxs", flCopyMaxs);
						
						for (new i4 = 0; i4 < 3; i4++) flCopyPos[i4] += ((flCopyMins[i4] + flCopyMaxs[i4]) / 2.0);
						
						hTrace = TR_TraceRayFilterEx(flCopyPos,
							flCopyCheckPos,
							CONTENTS_SOLID | CONTENTS_MOVEABLE | CONTENTS_MIST,
							RayType_EndPoint,
							TraceRayBossVisibility,
							iBoss);
						
						bDontAddPosition = !TR_DidHit(hTrace);
						CloseHandle(hTrace);
					}
					
					if (bDontAddPosition) break;
				}
				
				if (bDontAddPosition) break;
			}
			
			if (bDontAddPosition) continue;
			
			// Insert the vector into our array. Choose which one, first.
			// We're just using hArray as a variable to store the correct array, not the array itself. All arrays will be closed at the end.
			if (i == 0) hArray = hArrayFar;
			else if (i == 1) hArray = hArrayAverage;
			else if (i == 2) hArray = hArrayClose;
			
			index = PushArrayCell(hArray, tempPos[0]);
			SetArrayCell(hArray, index, tempPos[1], 1);
			SetArrayCell(hArray, index, tempPos[2], 2);
		}
	}
	
	new size;
	if ((size = GetArraySize(hArrayClose)) > 0)
	{
		index = GetRandomInt(0, size - 1);
		buffer[0] = Float:GetArrayCell(hArrayClose, index);
		buffer[1] = Float:GetArrayCell(hArrayClose, index, 1);
		buffer[2] = Float:GetArrayCell(hArrayClose, index, 2);
	}
	else if ((size = GetArraySize(hArrayAverage)) > 0)
	{
		index = GetRandomInt(0, size - 1);
		buffer[0] = Float:GetArrayCell(hArrayAverage, index);
		buffer[1] = Float:GetArrayCell(hArrayAverage, index, 1);
		buffer[2] = Float:GetArrayCell(hArrayAverage, index, 2);
	}
	else if ((size = GetArraySize(hArrayFar)) > 0)
	{
		index = GetRandomInt(0, size - 1);
		buffer[0] = Float:GetArrayCell(hArrayFar, index);
		buffer[1] = Float:GetArrayCell(hArrayFar, index, 1);
		buffer[2] = Float:GetArrayCell(hArrayFar, index, 2);
	}
	else
	{
		CloseHandle(hArrayClose);
		CloseHandle(hArrayAverage);
		CloseHandle(hArrayFar);
		
#if defined DEBUG
		if (GetConVarBool(g_cvDebugBosses)) PrintToChatAll("SlenderCalculateNewPlace(%d) failed: no locations available", iBossIndex);
#endif
		
		return false;
	}
	
	CloseHandle(hArrayClose);
	CloseHandle(hArrayAverage);
	CloseHandle(hArrayFar);
	return true;
}

bool:SlenderMarkAsFake(iBossIndex)
{
	if (g_iSlenderFlags[iBossIndex] & SFF_MARKEDASFAKE) return false;
	
	new slender = SlenderArrayIndexToEntIndex(iBossIndex);
	new iSlenderModel = EntRefToEntIndex(g_iSlenderModel[iBossIndex]);
	g_iSlender[iBossIndex] = INVALID_ENT_REFERENCE;
	g_iSlenderModel[iBossIndex] = INVALID_ENT_REFERENCE;
	g_iSlenderFlags[iBossIndex] |= SFF_MARKEDASFAKE;
	
	g_hSlenderFakeTimer[iBossIndex] = CreateTimer(3.0, Timer_SlenderMarkedAsFake, iBossIndex, TIMER_FLAG_NO_MAPCHANGE);
	
	if (slender && slender != INVALID_ENT_REFERENCE)
	{
		CreateTimer(2.0, Timer_KillEntity, EntIndexToEntRef(slender), TIMER_FLAG_NO_MAPCHANGE);
	
		new iFlags = GetEntProp(slender, Prop_Send, "m_usSolidFlags");
		if (!(iFlags & 0x0004)) iFlags |= 0x0004; // 	FSOLID_NOT_SOLID
		if (!(iFlags & 0x0008)) iFlags |= 0x0008; // 	FSOLID_TRIGGER
		SetEntProp(slender, Prop_Send, "m_usSolidFlags", iFlags);
	}
	
	if (iSlenderModel && iSlenderModel != INVALID_ENT_REFERENCE)
	{
		SetVariantFloat(0.0);
		AcceptEntityInput(iSlenderModel, "SetPlaybackRate");
		SetEntityRenderFx(iSlenderModel, RENDERFX_FADE_FAST);
	}
	
	return true;
}

public Action:Timer_SlenderMarkedAsFake(Handle:timer, any:data)
{
	if (timer != g_hSlenderFakeTimer[data]) return;
	
	RemoveProfile(data);
}

stock SpawnSlenderModel(iBossIndex, const Float:pos[3])
{
	if (!g_strSlenderProfile[iBossIndex][0])
	{
		LogError("Could not spawn boss model: profile is invalid!");
		return -1;
	}
	
	decl String:buffer[PLATFORM_MAX_PATH], String:sProfile[SF2_MAX_PROFILE_NAME_LENGTH];
	strcopy(sProfile, sizeof(sProfile), g_strSlenderProfile[iBossIndex]);
	
	GetProfileString(sProfile, "model", buffer, sizeof(buffer));
	if (!buffer[0])
	{
		LogError("Could not spawn boss model: model is invalid!");
		return -1;
	}
	
	new Float:flModelScale = GetProfileFloat(sProfile, "model_scale");
	if (flModelScale <= 0.0)
	{
		LogError("Could not spawn boss model: model scale is less than or equal to 0.0!");
		return -1;
	}
	
	new iSlenderModel = CreateEntityByName("prop_dynamic_override");
	if (iSlenderModel != -1)
	{
		SetEntityModel(iSlenderModel, buffer);
		
		TeleportEntity(iSlenderModel, pos, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(iSlenderModel);
		ActivateEntity(iSlenderModel);
		
		GetProfileString(sProfile, "animation_idle", buffer, sizeof(buffer));
		if (buffer[0])
		{
			SetVariantString(buffer);
			AcceptEntityInput(iSlenderModel, "SetDefaultAnimation");
			SetVariantString(buffer);
			AcceptEntityInput(iSlenderModel, "SetAnimation");
			AcceptEntityInput(iSlenderModel, "DisableCollision");
		}
		
		SetVariantFloat(GetProfileFloat(sProfile, "animation_idle_playbackrate", 1.0));
		AcceptEntityInput(iSlenderModel, "SetPlaybackRate");
		
		SetEntPropFloat(iSlenderModel, Prop_Send, "m_flModelScale", flModelScale);
		
		// Create special effects.
		SetEntityRenderMode(iSlenderModel, RenderMode:GetProfileNum(sProfile, "effect_rendermode", _:RENDER_NORMAL));
		SetEntityRenderFx(iSlenderModel, RenderFx:GetProfileNum(sProfile, "effect_renderfx", _:RENDERFX_NONE));
		
		decl iColor[4];
		GetProfileColor(sProfile, "effect_rendercolor", iColor[0], iColor[1], iColor[2], iColor[3]);
		SetEntityRenderColor(iSlenderModel, iColor[0], iColor[1], iColor[2], iColor[3]);
		
		KvRewind(g_hConfig);
		if (KvJumpToKey(g_hConfig, sProfile) && 
			KvJumpToKey(g_hConfig, "effects") &&
			KvGotoFirstSubKey(g_hConfig))
		{
			do
			{
				
			}
			while KvGotoNextKey(g_hConfig);
		}
	}
	
	return iSlenderModel;
}

stock bool:PlayerCanSeeSlender(client, iBossIndex, bool:bCheckFOV=true, bool:bCheckBlink=false, bool:bCheckEliminated=true)
{
	if (iBossIndex < 0) return false;

	new slender = SlenderArrayIndexToEntIndex(iBossIndex);
	if (slender && slender != INVALID_ENT_REFERENCE)
	{
		decl Float:myPos[3];
		SlenderGetAbsOrigin(iBossIndex, myPos);
		AddVectors(myPos, g_flSlenderEyePosOffset[iBossIndex], myPos);
		return IsPointVisibleToPlayer(client, myPos, bCheckFOV, bCheckBlink, bCheckEliminated);
	}
	
	return false;
}

stock SlenderGetFromID(iID)
{
	if (iID == -1) return -1;
	
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		if (SlenderGetID(i) == iID)
		{
			return i;
		}
	}
	
	return -1;
}

stock bool:PeopleCanSeeSlender(iBossIndex, bool:bCheckFOV=true, bool:bCheckBlink=false)
{
	new slender = SlenderArrayIndexToEntIndex(iBossIndex);
	if (slender && slender != INVALID_ENT_REFERENCE)
	{
		decl Float:myPos[3];
		SlenderGetAbsOrigin(iBossIndex, myPos);
		AddVectors(myPos, g_flSlenderEyePosOffset[iBossIndex], myPos);
		return IsPointVisibleToAPlayer(myPos, bCheckFOV, bCheckBlink);
	}
	
	return false;
}

stock Float:SlenderGetDistanceFromPlayer(iBossIndex, client)
{
	new slender = SlenderArrayIndexToEntIndex(iBossIndex);
	if (slender && slender != INVALID_ENT_REFERENCE)
	{
		decl Float:myPos[3], Float:flHisPos[3];
		SlenderGetAbsOrigin(iBossIndex, myPos);
		GetClientAbsOrigin(client, flHisPos);
		return GetVectorDistance(flHisPos, myPos);
	}
	
	return -1.0;
}

public bool:TraceRayBossVisibility(entity, mask, any:data)
{
	if (entity == data || IsValidClient(entity)) return false;
	
	new iBossIndex = SlenderEntIndexToArrayIndex(entity);
	if (iBossIndex != -1) return false;
	
	if (IsValidEdict(entity))
	{
		decl String:sClass[64];
		GetEntityNetClass(entity, sClass, sizeof(sClass));
		
		if (StrEqual(sClass, "CTFAmmoPack")) return false;
	}
	
	return true;
}