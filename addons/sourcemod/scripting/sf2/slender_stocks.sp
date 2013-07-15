#if defined _sf2_slender_stocks_included
 #endinput
#endif
#define _sf2_slender_stocks_included

#define SF2_BOSS_PAGE_CALCULATION 0.3
#define SF2_BOSS_COPY_SPAWN_MIN_DISTANCE 1850.0 // The default minimum distance boss copies can spawn from each other.

SlenderGetCount()
{
	new iCount;
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		if (!g_strSlenderProfile[i][0]) continue;
		if (g_iSlenderFlags[i] & SFF_FAKE) continue;
		iCount++;
	}
	
	return iCount;
}

bool:SlenderCanRemove(iBossIndex)
{
	if (!g_strSlenderProfile[iBossIndex][0]) return false;
	if (PeopleCanSeeSlender(iBossIndex, _, false)) return false;
	
	switch (g_iSlenderType[iBossIndex])
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
					g_bPlayerGhostMode[i] || 
					g_bPlayerDeathCam[i]) continue;
					
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

SpawnSlender(iBossIndex, const Float:pos[3])
{
	RemoveSlender(iBossIndex);
	
	decl Float:flTruePos[3];
	GetProfileVector(g_strSlenderProfile[iBossIndex], "pos_offset", flTruePos);
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
		case 2:
		{
			GetProfileString(g_strSlenderProfile[iBossIndex], "model", sBuffer, sizeof(sBuffer));
			
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
			AcceptEntityInput(iBoss, "DisableShadow");
			
			// Reset stats.
			g_iSlender[iBossIndex] = EntIndexToEntRef(iBoss);
			g_iSlenderTarget[iBossIndex] = INVALID_ENT_REFERENCE;
			g_iSlenderTargetSound[iBossIndex] = INVALID_ENT_REFERENCE;
			g_iSlenderState[iBossIndex] = STATE_IDLE;
			g_bSlenderAttacking[iBossIndex] = false;
			g_hSlenderMoveTimer[iBossIndex] = INVALID_HANDLE;
			g_iSlenderHealthUntilStun[iBossIndex] = GetProfileNum(g_strSlenderProfile[iBossIndex], "health_stun", 85);
			g_flSlenderLastHeardFootstep[iBossIndex] = GetGameTime();
			g_flSlenderLastHeardVoice[iBossIndex] = GetGameTime();
			g_flSlenderLastHeardWeapon[iBossIndex] = GetGameTime();
			g_flSlenderNextVoiceSound[iBossIndex] = GetGameTime();
			g_flSlenderNextMoanSound[iBossIndex] = GetGameTime();
			g_flSlenderNextWanderPos[iBossIndex] = GetGameTime();
			g_flSlenderTimeUntilKill[iBossIndex] = GetGameTime() + GetProfileFloat(g_strSlenderProfile[iBossIndex], "idle_lifetime", 10.0);
			g_flSlenderTimeUntilRecover[iBossIndex] = -1.0;
			g_flSlenderTimeUntilAlert[iBossIndex] = -1.0;
			g_flSlenderTimeUntilIdle[iBossIndex] = -1.0;
			g_flSlenderTimeUntilChase[iBossIndex] = -1.0;
			g_flSlenderNextJump[iBossIndex] = GetGameTime() + GetProfileFloat(g_strSlenderProfile[iBossIndex], "jump_cooldown", 2.0);
			g_flSlenderNextTrackTargetPos[iBossIndex] = GetGameTime();
			g_hSlenderThinkTimer[iBossIndex] = CreateTimer(BOSS_THINKRATE, Timer_SlenderThink, EntIndexToEntRef(iBoss), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
			
			for (new i = 0; i < 3; i++)
			{
				g_flSlenderGoalPos[iBossIndex][i] = 0.0;
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
			SlenderResetSoundData(iBossIndex);
			
			if (GetProfileNum(g_strSlenderProfile[iBossIndex], "stun_enabled"))
			{
				SetEntProp(iBoss, Prop_Data, "m_takedamage", 1);
			}
			
			SDKHook(iBoss, SDKHook_OnTakeDamage, Hook_SlenderOnTakeDamage);
			SDKHook(iBoss, SDKHook_OnTakeDamagePost, Hook_SlenderOnTakeDamagePost);
		}
		default:
		{
			g_iSlender[iBossIndex] = g_iSlenderModel[iBossIndex];
			SDKHook(iSlenderModel, SDKHook_SetTransmit, Hook_SlenderSetTransmit);
		}
	}
	
	// Initialize our pose parameters, if needed.
	new iPose = EntRefToEntIndex(g_iSlenderPoseEnt[iBossIndex]);
	g_iSlenderPoseEnt[iBossIndex] = INVALID_ENT_REFERENCE;
	if (iPose && iPose != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(iPose, "Kill");
	}
	
	decl String:sPoseParameter[64];
	GetProfileString(g_strSlenderProfile[iBossIndex], "pose_parameter", sPoseParameter, sizeof(sPoseParameter));
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
			DispatchKeyValueFloat(iPose, "PoseValue", GetProfileFloat(g_strSlenderProfile[iBossIndex], "pose_parameter_max"));
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
	new slender = EntRefToEntIndex(g_iSlender[iBossIndex]);
	g_iSlender[iBossIndex] = INVALID_ENT_REFERENCE;
	if (slender > 0 && slender != INVALID_ENT_REFERENCE)
	{
		// Stop all possible looping sounds.
		ClientStopAllSlenderSounds(slender, g_strSlenderProfile[iBossIndex], "sound_move", SNDCHAN_AUTO);
		AcceptEntityInput(slender, "Kill");
	}
}

SlenderAlertOfPlayerSound(iBossIndex, client, SoundType:iSoundType)
{
	new iOldTarget = EntRefToEntIndex(g_iSlenderTargetSound[iBossIndex]);
	new SoundType:iOldSoundType = g_iSlenderTargetSoundType[iBossIndex];
	new iNewTarget = INVALID_ENT_REFERENCE;
	
	if (!iOldTarget || iOldTarget == INVALID_ENT_REFERENCE || g_bPlayerEliminated[iOldTarget] || !IsPlayerAlive(iOldTarget))
	{
		// Heard something. I better go check it out.
		iNewTarget = client;
	}
	else
	{
		// I think there's something over there because a lot of sound is being made over there...
		if (client == iOldTarget)
		{
			iNewTarget = client;
		}
		else
		{
			// More noticable than the sound I just heard not too long ago.
			if (iSoundType >= iOldSoundType)
			{
				iNewTarget = client;
			}
			// Something else is making the same sound and it's been a while since I last heard anything.
			else if ((GetGameTime() - g_flSlenderTargetSoundTime[iBossIndex]) >= GetProfileFloat(g_strSlenderProfile[iBossIndex], "search_sound_ignoreweakersounds_duration", 5.0))
			{
				iNewTarget = client;
			}
		}
	}
	
	if (g_iSlenderState[iBossIndex] != STATE_CHASE && g_iSlenderState[iBossIndex] != STATE_ATTACK)
	{
		if (iNewTarget && iNewTarget != INVALID_ENT_REFERENCE)
		{
			if (iNewTarget == iOldTarget) g_iSlenderTargetSoundCount[iBossIndex]++;
			else g_iSlenderTargetSoundCount[iBossIndex] = 1;
			
			g_iSlenderTargetSound[iBossIndex] = EntIndexToEntRef(iNewTarget);
			g_iSlenderTargetSoundType[iBossIndex] = iSoundType;
			g_flSlenderTargetSoundTime[iBossIndex] = GetGameTime();
			GetClientAbsOrigin(client, g_flSlenderTargetSoundPos[iBossIndex]);
			g_bSlenderTargetSoundFoundPos[iBossIndex] = false // new position! Try to find it!
		}
	}
}

stock SlenderResetSoundData(iBossIndex, bool:bResetTime=true)
{
	g_iSlenderTargetSound[iBossIndex] = INVALID_ENT_REFERENCE;
	g_iSlenderTargetSoundType[iBossIndex] = SoundType_None;
	g_bSlenderTargetSoundFoundPos[iBossIndex] = false;
	if (bResetTime) g_flSlenderTargetSoundTime[iBossIndex] = -1.0;
	for (new i = 0; i < 2; i++) g_flSlenderTargetSoundPos[iBossIndex][i] = 0.0;
}

stock bool:SlenderCanHearPlayer(iBossIndex, client, SoundType:iSoundType)
{
	if (!IsValidClient(client) || !IsPlayerAlive(client)) return false;
	
	new iSlender = EntRefToEntIndex(g_iSlender[iBossIndex]);
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
		if (ClientSprintIsValid(client)) flDistance *= 0.66;
		
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
		
		decl Float:flEndPOs[3];
		GetClientAbsOrigin(client, flEndPOs);
		AddVectors(flHisPos, flMiddle, flEndPOs);
		
		hTrace = TR_TraceRayFilterEx(flMyEyePos, flEndPOs, MASK_NPCSOLID, RayType_EndPoint, TraceRayDontHitPlayersOrEntity, iSlender);
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
	if (entity && IsValidEntity(entity))
	{
		new iEntRef = EntIndexToEntRef(entity);
		for (new i = 0; i < MAX_BOSSES; i++)
		{
			if (g_iSlender[i] == iEntRef)
			{
				return i;
			}
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

stock SlenderInsertPathNode(iBossIndex, const Float:pos[3])
{
	if (iBossIndex == -1) return;
	
	new slender = EntRefToEntIndex(g_iSlender[iBossIndex]);
	if (!slender || slender == INVALID_ENT_REFERENCE) return;
	
	if (g_hSlenderTargetMemory[iBossIndex] == INVALID_HANDLE) return;
	
	new Handle:hLocs = g_hSlenderTargetMemory[iBossIndex];
	
	new index = PushArrayCell(hLocs, pos[0]);
	SetArrayCell(hLocs, index, pos[1], 1);
	SetArrayCell(hLocs, index, pos[2], 2);
	
	new size = GetArraySize(hLocs);
	if (size > MAX_NODES) RemoveFromArray(hLocs, 0);
}

stock SlenderRemovePathNode(iBossIndex, index)
{
	if (iBossIndex == -1) return;
	
	new slender = EntRefToEntIndex(g_iSlender[iBossIndex]);
	if (!slender || slender == INVALID_ENT_REFERENCE) return;
	
	if (g_hSlenderTargetMemory[iBossIndex] == INVALID_HANDLE) return;
	
	RemoveFromArray(g_hSlenderTargetMemory[iBossIndex], index);
}

SlenderGetBestPathNodeToTarget(iBossIndex)
{
	if (iBossIndex == -1) return -1;
	
	new slender = EntRefToEntIndex(g_iSlender[iBossIndex]);
	if (!slender || slender == INVALID_ENT_REFERENCE) return -1;
	
	new iTarget = EntRefToEntIndex(g_iSlenderTarget[iBossIndex]);
	if (!iTarget || iTarget == INVALID_ENT_REFERENCE) return -1;
	
	new Handle:hLocs = g_hSlenderTargetMemory[iBossIndex];
	if (hLocs == INVALID_HANDLE) return -1;
	
	decl Float:flMyPos[3], Float:flTargetPos[3], Float:flBestPos[3], Float:flBuffer[3];
	SlenderGetAbsOrigin(iBossIndex, flMyPos);
	GetClientAbsOrigin(iTarget, flTargetPos);
	
	new Float:tempDist;
	new bestIndex = -1;
	new Float:bestDist = 99999999.0;
	new size = GetArraySize(hLocs);
	for (new i = 0; i < size; i++)
	{
		flBuffer[0] = Float:GetArrayCell(hLocs, i);
		flBuffer[1] = Float:GetArrayCell(hLocs, i, 1);
		flBuffer[2] = Float:GetArrayCell(hLocs, i, 2);
		
		new Handle:hTrace = TR_TraceHullFilterEx(flMyPos, flTargetPos, g_flSlenderMins[iBossIndex], g_flSlenderMaxs[iBossIndex], MASK_NPCSOLID, TraceRayDontHitPlayersOrEntity, slender);
		new iEntity = TR_GetEntityIndex(hTrace);
		CloseHandle(hTrace);
		
		new Float:flValue = float(i);
		if (!IsValidEntity(iEntity)) flValue *= 10.0;
		
		if ((tempDist = GetVectorDistance(flBuffer, flMyPos) - (flValue)) < bestDist)
		{
			bestIndex = i;
			bestDist = tempDist;
			flBestPos[0] = flBuffer[0];
			flBestPos[1] = flBuffer[1];
			flBestPos[2] = flBuffer[2];
		}
	}
	
	if (bestIndex > 0)
	{
		for (new i = 0; i < bestIndex - 1; i++)
		{
			RemoveFromArray(hLocs, 0);
		}
	}
	
	return bestIndex;
}

bool:SlenderGetPathNodePosition(iBossIndex, index2, Float:buffer[3])
{
	if (iBossIndex == -1) return false;
	
	new Handle:hLocs = g_hSlenderTargetMemory[iBossIndex];
	if (hLocs == INVALID_HANDLE) return false;
	
	if (index2 >= GetArraySize(hLocs)) return false;
	
	buffer[0] = Float:GetArrayCell(hLocs, index2);
	buffer[1] = Float:GetArrayCell(hLocs, index2, 1);
	buffer[2] = Float:GetArrayCell(hLocs, index2, 2);
	
	return true;
}

stock SlenderClearTargetMemory(iBossIndex)
{
	if (iBossIndex == -1) return;
	
	if (g_hSlenderTargetMemory[iBossIndex] == INVALID_HANDLE) return;
	
	ClearArray(g_hSlenderTargetMemory[iBossIndex]);
}

stock bool:SlenderCreateTargetMemory(iBossIndex)
{
	if (iBossIndex == -1) return false;
	
	if (g_hSlenderTargetMemory[iBossIndex] != INVALID_HANDLE) return true;
	
	g_hSlenderTargetMemory[iBossIndex] = CreateArray(3);
	return true;
}

stock SlenderRemoveTargetMemory(iBossIndex)
{
	if (iBossIndex == -1) return;
	
	if (g_hSlenderTargetMemory[iBossIndex] == INVALID_HANDLE) return;
	
	new Handle:hLocs = g_hSlenderTargetMemory[iBossIndex];
	g_hSlenderTargetMemory[iBossIndex] = INVALID_HANDLE;
	CloseHandle(hLocs);
}

bool:SlenderCalculateApproachToPlayer(iBossIndex, iBestPlayer, Float:buffer[3])
{
	if (!IsValidClient(iBestPlayer)) return false;

	new slender = EntRefToEntIndex(g_iSlender[iBossIndex]);
	if (!slender || slender == INVALID_ENT_REFERENCE) return false;
	
	decl Float:flSlenderPos[3], Float:flPos[3], Float:flReferenceAng[3], Float:hisEyeAng[3], Float:tempDir[3], Float:tempPos[3];
	GetClientEyePosition(iBestPlayer, flPos);
	
	// Take care of angle offsets.
	GetProfileVector(g_strSlenderProfile[iBossIndex], "eye_ang_offset", tempDir);
	GetEntPropVector(slender, Prop_Data, "m_angAbsRotation", hisEyeAng);
	AddVectors(hisEyeAng, tempDir, hisEyeAng);
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
		AddVectors(tempPos, g_flSlenderVisiblePos[iBossIndex], tempPos);
		AddVectors(flSlenderPos, g_flSlenderVisiblePos[iBossIndex], tempPos2);
		
		flBuffer[0] = g_flSlenderMins[iBossIndex][0];
		flBuffer[1] = g_flSlenderMins[iBossIndex][1];
		flBuffer[2] = 0.0;
		flBuffer2[0] = g_flSlenderMaxs[iBossIndex][0];
		flBuffer2[1] = g_flSlenderMaxs[iBossIndex][1];
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
		hTrace = TR_TraceHullFilterEx(tempPos, tempPos2, g_flSlenderMins[iBossIndex], g_flSlenderMaxs[iBossIndex], MASK_PLAYERSOLID_BRUSHONLY, TraceRayDontHitPlayersOrEntity, slender);
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
			|| IsSpaceOccupiedNPC(tempPos, g_flSlenderMins[iBossIndex], g_flSlenderMaxs[iBossIndex], iBestPlayer))
		{
			continue;
		}
		
		// Check from top to bottom of me.
		
		if (!IsPointVisibleToPlayer(iBestPlayer, tempPos, false, false)) continue;
		
		AddVectors(tempPos, g_flSlenderVisiblePos[iBossIndex], tempPos);
		
		if (!IsPointVisibleToPlayer(iBestPlayer, tempPos, false, false)) continue;
		
		SubtractVectors(tempPos, g_flSlenderVisiblePos[iBossIndex], tempPos);
		
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

bool:SlenderCalculateNewPlace(iBossIndex, Float:buffer[3], bool:bIgnoreCopies=false, bool:bProxy=false, &iBestPlayer=-1)
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
				g_bPlayerDeathCam[i] || 
				g_bPlayerEliminated[i] || 
				g_bPlayerEscaped[i]) continue;
			
			if (g_iSlenderCopyOfBoss[iBossIndex] != -1 && !bIgnoreCopies)
			{
				// Check if a boss has already spawned for this player.
				new bool:bwub = false;
				for (new iBoss = 0; iBoss < MAX_BOSSES; iBoss++)
				{
					if (iBoss == iBossIndex || !g_strSlenderProfile[iBoss][0]) continue;
					
					if (g_iSlenderSpawnedForPlayer[iBoss] == i)
					{
						bwub = true;
						break;
					}
				}
				
				if (bwub) continue;
				
				// No? Then check if players around him are targeted by a boss already (not me).
				for (new iBossPlayer = 1; iBossPlayer <= MaxClients; iBossPlayer++)
				{
					if (i == iBossPlayer) continue;
				
					if (!IsClientInGame(iBossPlayer) || 
						!IsPlayerAlive(iBossPlayer) || 
						g_bPlayerDeathCam[iBossPlayer] || 
						g_bPlayerEliminated[iBossPlayer] || 
						g_bPlayerEscaped[iBossPlayer]) continue;
					
					// Get the boss that's targeting this player, if any.
					for (new iBoss = 0; iBoss < MAX_BOSSES; iBoss++)
					{
						if (iBossIndex == iBoss || !g_strSlenderProfile[iBoss][0]) continue;
						
						if (g_iSlenderSpawnedForPlayer[iBoss] == iBossPlayer)
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
			if (g_iSlenderCopyOfBoss[iBossIndex] == -1 ||
				GetProfileNum(g_strSlenderProfile[iBossIndex], "copy_calculatepagecount", 0))
			{
				new tempBestPageCount = -1;
				
				new Handle:hTempArray = CloneArray(hArray);
				for (new i = 0; i < GetArraySize(hTempArray); i++)
				{
					new iClient = GetArrayCell(hTempArray, i);
					if (g_iPlayerFoundPages[iClient] > tempBestPageCount)
					{
						tempBestPageCount = g_iPlayerFoundPages[iClient];
					}
				}
				
				for (new i = 0; i < GetArraySize(hTempArray); i++)
				{
					new iClient = GetArrayCell(hTempArray, i);
					if ((float(g_iPlayerFoundPages[iClient]) / float(tempBestPageCount)) < SF2_BOSS_PAGE_CALCULATION)
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
			
			flBuffer2[0] = g_flSlenderMins[iBossIndex][0];
			flBuffer2[1] = g_flSlenderMins[iBossIndex][1];
			flBuffer2[2] = -g_flSlenderMaxs[iBossIndex][2];
			flBuffer3[0] = g_flSlenderMaxs[iBossIndex][0];
			flBuffer3[1] = g_flSlenderMaxs[iBossIndex][1];
			flBuffer3[2] = -g_flSlenderMins[iBossIndex][0];
			
			if (GetVectorDistance(tempPos, flBuffer) >= 312.0) continue;
			
			// Drop dowwwwwn.
			hTrace = TR_TraceHullFilterEx(tempPos, flBuffer, flBuffer2, flBuffer3, MASK_NPCSOLID, TraceRayDontHitPlayersOrEntity, iBestPlayer);
			TR_GetEndPosition(tempPos, hTrace);
			TR_GetPlaneNormal(hTrace, flHitNormal);
			CloseHandle(hTrace);
			
			GetVectorAngles(flHitNormal, flHitNormal);
			for (new i2 = 0; i2 < 3; i2++) flHitNormal[i2] = AngleNormalize(flHitNormal[i2]);
			
			tempPos[2] -= g_flSlenderMaxs[iBossIndex][2];
			
			if (TR_PointOutsideWorld(tempPos)
				|| IsSpaceOccupiedNPC(tempPos, g_flSlenderMins[iBossIndex], g_flSlenderMaxs[iBossIndex], EntRefToEntIndex(g_iSlender[iBossIndex]))
				|| (flHitNormal[0] >= 0.0 && flHitNormal[0] < 45.0)
				|| (flHitNormal[0] < 0.0 && flHitNormal[0] > -45.0))
			{
				continue;
			}
			
			// Check if this position isn't too close to anyone else.
			new bool:bTooClose = false;
			
			for (new i2 = 1; i2 <= MaxClients; i2++)
			{
				if (!IsClientInGame(i2) || !IsPlayerAlive(i2) || g_bPlayerEliminated[i2] || g_bPlayerGhostMode[i2]) continue;
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
					if (!g_strSlenderProfile[i2][0]) continue;
					
					// If I'm a main boss, only check the distance between my copies and me.
					if (g_iSlenderCopyOfBoss[iBossIndex] == -1)
					{
						if (g_iSlenderCopyOfBoss[i2] != iBossIndex) continue;
					}
					// If I'm a copy, just check with my other copy friends and my main boss.
					else
					{
						new iMyMaster = g_iSlenderCopyOfBoss[iBossIndex];
						if (g_iSlenderCopyOfBoss[i2] != iMyMaster || i2 != iMyMaster) continue;
					}
					
					iSlender = SlenderArrayIndexToEntIndex(i2);
					if (!iSlender || iSlender == INVALID_ENT_REFERENCE) continue;
					
					SlenderGetAbsOrigin(i2, flBuffer);
					if (GetVectorDistance(flBuffer, tempPos) < GetProfileFloat(g_strSlenderProfile[iBossIndex], "teleport_dist_from_me", 800.0))
					{
						bTooClose = true;
						break;
					}
				}
			}
			
			if (bTooClose) continue;
			
			// Check from top to bottom of me.
			
			new bool:bCheckBlink = bool:GetProfileNum(g_strSlenderProfile[iBossIndex], "teleport_use_blink");
			
			if (bVisiblePls)
			{
				if (!IsPointVisibleToAPlayer(tempPos, _, bCheckBlink)) continue;
			}
			else if (bBeCreepy)
			{
				if (IsPointVisibleToAPlayer(tempPos, _, bCheckBlink) ||
					!IsPointVisibleToAPlayer(tempPos, false, bCheckBlink) ||
					!IsPointVisibleToPlayer(iBestPlayer, tempPos, false, bCheckBlink)) continue;
			}
			else
			{
				if (IsPointVisibleToAPlayer(tempPos, _, bCheckBlink)) continue;
			}
			
			new bool:bTooVisible = false;
			
			for (new i2 = 0; i2 < MAX_BOSSES; i2++)
			{
				if (i2 == iBossIndex) continue;
				new iSlender = EntRefToEntIndex(g_iSlender[i2]);
				if (!iSlender || iSlender == INVALID_ENT_REFERENCE) continue;
				
				if (IsPointVisibleToPlayer(iBestPlayer, tempPos, false, bCheckBlink) &&
					((SlenderGetAbsOrigin(i2, flBuffer) && IsPointVisibleToPlayer(iBestPlayer, flBuffer, false, bCheckBlink)) ||
					(SlenderGetEyePosition(i2, flBuffer) && IsPointVisibleToPlayer(iBestPlayer, flBuffer, false, bCheckBlink))))
				{
					bTooVisible = true;
					break;
				}
			}
			
			if (bTooVisible) continue;
			
			AddVectors(tempPos, g_flSlenderVisiblePos[iBossIndex], tempPos);
			
			if (bVisiblePls)
			{
				if (!IsPointVisibleToAPlayer(tempPos, _, bCheckBlink)) continue;
			}
			else if (bBeCreepy)
			{
				if (IsPointVisibleToAPlayer(tempPos, _, bCheckBlink) ||
					!IsPointVisibleToAPlayer(tempPos, false, bCheckBlink) ||
					!IsPointVisibleToPlayer(iBestPlayer, tempPos, false, bCheckBlink)) continue;
			}
			else
			{
				if (IsPointVisibleToAPlayer(tempPos, _, bCheckBlink)) continue;
			}
			
			for (new i2 = 0; i2 < MAX_BOSSES; i2++)
			{
				if (i2 == iBossIndex) continue;
				new iSlender = EntRefToEntIndex(g_iSlender[i2]);
				if (!iSlender || iSlender == INVALID_ENT_REFERENCE) continue;
				
				if (IsPointVisibleToPlayer(iBestPlayer, tempPos, false, bCheckBlink) &&
					((SlenderGetAbsOrigin(i2, flBuffer) && IsPointVisibleToPlayer(iBestPlayer, flBuffer, false, bCheckBlink)) ||
					(SlenderGetEyePosition(i2, flBuffer) && IsPointVisibleToPlayer(iBestPlayer, flBuffer, false, bCheckBlink))))
				{
					bTooVisible = true;
					break;
				}
			}
			
			if (bTooVisible) continue;
			
			SubtractVectors(tempPos, g_flSlenderVisiblePos[iBossIndex], tempPos);
			
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
	
	new slender = EntRefToEntIndex(g_iSlender[iBossIndex]);
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
	
	decl String:buffer[PLATFORM_MAX_PATH];
	GetProfileString(g_strSlenderProfile[iBossIndex], "model", buffer, sizeof(buffer));
	if (!buffer[0])
	{
		LogError("Could not spawn boss model: model is invalid!");
		return -1;
	}
	
	new Float:flModelScale = GetProfileFloat(g_strSlenderProfile[iBossIndex], "model_scale");
	if (flModelScale <= 0.0)
	{
		LogError("Could not spawn boss model: model scale is less than or equal to 0.0!");
		return -1;
	}
	
	new slender = CreateEntityByName("prop_dynamic_override");
	if (slender != -1)
	{
		SetEntityModel(slender, buffer);
		
		TeleportEntity(slender, pos, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(slender);
		ActivateEntity(slender);
		
		GetProfileString(g_strSlenderProfile[iBossIndex], "animation_idle", buffer, sizeof(buffer));
		if (buffer[0])
		{
			SetVariantString(buffer);
			AcceptEntityInput(slender, "SetDefaultAnimation");
			SetVariantString(buffer);
			AcceptEntityInput(slender, "SetAnimation");
			AcceptEntityInput(slender, "DisableCollision");
		}
		
		SetVariantFloat(GetProfileFloat(g_strSlenderProfile[iBossIndex], "animation_idle_playbackrate", 1.0));
		AcceptEntityInput(slender, "SetPlaybackRate");
		
		SetEntPropFloat(slender, Prop_Send, "m_flModelScale", flModelScale);
	}
	
	return slender;
}

stock bool:PlayerCanSeeSlender(client, iBossIndex, bool:bCheckFOV=true, bool:bCheckBlink=false, bool:bCheckEliminated=true)
{
	if (iBossIndex < 0) return false;

	new slender = EntRefToEntIndex(g_iSlender[iBossIndex]);
	if (slender && slender != INVALID_ENT_REFERENCE)
	{
		decl Float:myPos[3];
		SlenderGetAbsOrigin(iBossIndex, myPos);
		AddVectors(myPos, g_flSlenderVisiblePos[iBossIndex], myPos);
		return IsPointVisibleToPlayer(client, myPos, bCheckFOV, bCheckBlink, bCheckEliminated);
	}
	
	return false;
}

stock SlenderGetFromID(iID)
{
	if (iID == -1) return -1;
	
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		if (g_iSlenderID[i] == iID)
		{
			return i;
		}
	}
	
	return -1;
}

stock bool:PeopleCanSeeSlender(iBossIndex, bool:bCheckFOV=true, bool:bCheckBlink=false)
{
	new slender = EntRefToEntIndex(g_iSlender[iBossIndex]);
	if (slender && slender != INVALID_ENT_REFERENCE)
	{
		decl Float:myPos[3];
		SlenderGetAbsOrigin(iBossIndex, myPos);
		AddVectors(myPos, g_flSlenderVisiblePos[iBossIndex], myPos);
		return IsPointVisibleToAPlayer(myPos, bCheckFOV, bCheckBlink);
	}
	
	return false;
}

stock Float:SlenderGetDistanceFromPlayer(iBossIndex, client)
{
	new slender = EntRefToEntIndex(g_iSlender[iBossIndex]);
	if (slender && slender != INVALID_ENT_REFERENCE)
	{
		decl Float:myPos[3], Float:flHisPos[3];
		SlenderGetAbsOrigin(iBossIndex, myPos);
		GetClientAbsOrigin(client, flHisPos);
		return GetVectorDistance(flHisPos, myPos);
	}
	
	return -1.0;
}