#if defined _sf2_client_included
 #endinput
#endif
#define _sf2_client_included

#define GHOST_MODEL ""
#define BLACK_OVERLAY "overlays/slender/black_final"

#define SF2_FLASHLIGHT_WIDTH 512.0 // How wide the player's Flashlight should be in world units.
#define SF2_FLASHLIGHT_LENGTH 1024.0 // How far the player's Flashlight can reach in world units.
#define SF2_FLASHLIGHT_BRIGHTNESS 3 // Intensity of the players' Flashlight.
#define SF2_FLASHLIGHT_DRAIN_RATE 0.65 // How long (in seconds) each bar on the player's Flashlight meter lasts.
#define SF2_FLASHLIGHT_RECHARGE_RATE 0.68 // How long (in seconds) it takes each bar on the player's Flashlight meter to recharge.
#define SF2_FLASHLIGHT_FLICKERAT 0.25 // The percentage of the Flashlight battery where the Flashlight will start to blink.
#define SF2_FLASHLIGHT_ENABLEAT 0.3 // The percentage of the Flashlight battery where the Flashlight will be able to be used again (if the player shortens out the Flashlight from excessive use).
#define SF2_FLASHLIGHT_COOLDOWN 0.4 // How much time players have to wait before being able to switch their flashlight on again after turning it off.

#define SF2_ULTRAVISION_WIDTH 512.0
#define SF2_ULTRAVISION_LENGTH 512.0
#define SF2_ULTRAVISION_BRIGHTNESS 0 // Intensity of Ultravision.
#define SF2_ULTRAVISION_CONE 180.0

#define SF2_PLAYER_BREATH_COOLDOWN_MIN 0.8
#define SF2_PLAYER_BREATH_COOLDOWN_MAX 2.0

new String:g_sPlayerProjectileClasses[][] = 
{
	"tf_projectile_rocket", 
	"tf_projectile_sentryrocket", 
	"tf_projectile_arrow", 
	"tf_projectile_stun_ball",
	"tf_projectile_ball_ornament",
	"tf_projectile_cleaver",
	"tf_projectile_energy_ball",
	"tf_projectile_energy_ring",
	"tf_projectile_flare",
	"tf_projectile_healing_bolt",
	"tf_projectile_jar",
	"tf_projectile_jar_milk",
	"tf_projectile_pipe",
	"tf_projectile_pipe_remote",
	"tf_projectile_syringe"
};

new String:g_strPlayerBreathSounds[][] = 
{
	"slender/fastbreath1.wav"
};

static String:g_strPlayerLagCompensationWeapons[][] = 
{
	"tf_weapon_sniperrifle",
	"tf_weapon_sniperrifle_decap"
};

public MRESReturn:Hook_ClientWantsLagCompensationOnEntity(this, Handle:hReturn, Handle:hParams)
{
	if (!g_bEnabled || IsFakeClient(this)) return MRES_Ignored;
	
	DHookSetReturn(hReturn, true);
	return MRES_Supercede;
}

ClientResetHints(client)
{
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("START ClientResetHints(%d)", client);
#endif

	for (new i = 0; i < PlayerHint_MaxNum; i++)
	{
		g_bPlayerHints[client][i] = false;
	}
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("END ClientResetHints(%d)", client);
#endif
}

ClientShowHint(client, iHint)
{
	g_bPlayerHints[client][iHint] = true;
	
	switch (iHint)
	{
		case PlayerHint_Sprint: PrintHintText(client, "%T", "SF2 Hint Sprint", client);
		case PlayerHint_Flashlight: PrintHintText(client, "%T", "SF2 Hint Flashlight", client);
		case PlayerHint_Blink: PrintHintText(client, "%T", "SF2 Hint Blink", client);
		case PlayerHint_MainMenu: PrintHintText(client, "%T", "SF2 Hint Main Menu", client);
	}
}

stock ClientViewPunch(client, const Float:angleOffset[3])
{
	if (g_offsPlayerPunchAngleVel == -1) return;
	
	decl Float:flOffset[3];
	for (new i = 0; i < 3; i++) flOffset[i] = angleOffset[i];
	ScaleVector(flOffset, 20.0);
	
	if (!IsFakeClient(client))
	{
		new Float:flLatency = GetClientLatency(client, NetFlow_Outgoing);
		new Float:flCalcDiff = (((1.0 / 2500.0) * Pow(flLatency, 2.0)) + ((3.0 / 50.0) * flLatency) + 2.0);
		ScaleVector(flOffset, flCalcDiff);
	}
	
	decl Float:flAngleVel[3];
	GetEntDataVector(client, g_offsPlayerPunchAngleVel, flAngleVel);
	AddVectors(flAngleVel, flOffset, flOffset);
	SetEntDataVector(client, g_offsPlayerPunchAngleVel, flOffset, true);
}

stock ClientSDKFlashlightTurnOn(client)
{
	if (g_hSDKFlashlightTurnOn == INVALID_HANDLE) return;
	if (!IsValidClient(client)) return;
	
	SDKCall(g_hSDKFlashlightTurnOn, client);
}

stock ClientSDKFlashlightTurnOff(client)
{
	if (g_hSDKFlashlightTurnOff == INVALID_HANDLE) return;
	if (!IsValidClient(client)) return;
	
	SDKCall(g_hSDKFlashlightTurnOff, client);
}

ClientEscape(client)
{
#if defined DEBUG
	DebugMessage("START ClientEscape(%d)", client);
#endif

	if (!g_bPlayerEscaped[client])
	{
		ClientResetBreathing(client);
		
		decl String:sName[MAX_NAME_LENGTH];
		g_bPlayerEscaped[client] = true;
		GetClientName(client, sName, sizeof(sName));
		
		CPrintToChatAll("%t", "SF2 Player Escaped", sName);
		
		// Speed recalculation. Props to the creators of FF2/VSH for this snippet.
		TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.001);
		
		// Reset HUD.
		SetEntProp(client, Prop_Send, "m_iHideHUD", 0);
		
		CheckRoundState();
		
		Call_StartForward(fOnClientEscape);
		Call_PushCell(client);
		Call_Finish();
	}
	
#if defined DEBUG
	DebugMessage("END ClientEscape(%d)", client);
#endif
}

#define SF2_PLAYER_VIEWBOB_TIMER 10.0
#define SF2_PLAYER_VIEWBOB_SCALE_X 0.05
#define SF2_PLAYER_VIEWBOB_SCALE_Y 0.0
#define SF2_PLAYER_VIEWBOB_SCALE_Z 0.0

stock Float:ClientGetDistanceFromEntity(client, entity)
{
	decl Float:flStartPos[3], Float:flEndPos[3];
	GetClientAbsOrigin(client, flStartPos);
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", flEndPos);
	return GetVectorDistance(flStartPos, flEndPos);
}

ClientEnableFakeLagCompensation(client)
{
	if (!GetConVarBool(g_cvPlayerFakeLagCompensation)) return;
	
	if (!IsValidClient(client) || !IsPlayerAlive(client) || g_bPlayerLagCompensation[client]) return;
	
	// Can only enable lag compensation if we're in either of these two teams only.
	new iMyTeam = GetClientTeam(client);
	if (iMyTeam != _:TFTeam_Red && iMyTeam != _:TFTeam_Blue) return;
	
	// Can only enable lag compensation if there are other active teammates around. This is to prevent spontaneous round restarting.
	new iCount;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (i == client) continue;
		
		if (IsValidClient(i) && IsPlayerAlive(i))
		{
			new iTeam = GetClientTeam(i);
			if ((iTeam == _:TFTeam_Red || iTeam == _:TFTeam_Blue) && iTeam == iMyTeam)
			{
				iCount++;
			}
		}
	}
	
	if (!iCount) return;
	
	// Can only enable lag compensation only for specific weapons.
	new iActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (!IsValidEdict(iActiveWeapon)) return;
	
	decl String:sClassName[64];
	GetEdictClassname(iActiveWeapon, sClassName, sizeof(sClassName));
	
	new bool:bCompensate = false;
	for (new i = 0; i < sizeof(g_strPlayerLagCompensationWeapons); i++)
	{
		if (StrEqual(sClassName, g_strPlayerLagCompensationWeapons[i], false))
		{
			bCompensate = true;
			break;
		}
	}
	
	if (!bCompensate) return;
	
	g_bPlayerLagCompensation[client] = true;
	g_iPlayerLagCompensationTeam[client] = iMyTeam;
	SetEntProp(client, Prop_Send, "m_iTeamNum", 0);
}

ClientDisableFakeLagCompensation(client)
{
	if (!g_bPlayerLagCompensation[client]) return;
	
	SetEntProp(client, Prop_Send, "m_iTeamNum", g_iPlayerLagCompensationTeam[client]);
	g_bPlayerLagCompensation[client] = false;
	g_iPlayerLagCompensationTeam[client] = -1;
}

/*
public Action:Hook_ClientTeamNumSendProxy(entity, const String:PropName[], &iValue, element)
{
	if (!g_bEnabled) return Plugin_Continue;
	
	if (IsValidClient(entity))
	{
		if (g_bPlayerLagCompensation[entity]) 
		{
			iValue = g_iPlayerLagCompensationTeam[entity];
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}
*/

public Hook_ClientPreThink(client)
{
	if (!g_bEnabled) return;
	
	// One of the worst ways to calculate eye angular velocity!
	decl Float:newAng[3];
	GetClientEyeAngles(client, newAng);
	for (new i = 0; i < 3; i++)
	{
		g_flPlayerEyeAngleVelocity[client][i] = -AngleDiff(newAng[i], g_flPlayerLastEyeAngles[client][i]);
		g_flPlayerLastEyeAngles[client][i] = newAng[i];
	}
	
	ClientProcessVisibility(client);
	ClientProcessFlashlight(client);
	ClientProcessGlow(client);
	
	if ((!g_bPlayerEliminated[client] || g_bPlayerProxy[client]) && 
		!g_bPlayerEscaped[client] &&
		!g_bRoundEnded && 
		!g_bRoundWarmup)
	{
		// Process view bobbing, if enabled.
		// This code is based on the code in this page: https://developer.valvesoftware.com/wiki/Camera_Bob
		// Many thanks to whomever created it in the first place.
		if (IsPlayerAlive(client))
		{
			if (GetConVarBool(g_cvPlayerViewbobEnabled))
			{
				new Float:flPunchVel[3];
			
				if (!GetConVarBool(g_cvPlayerViewBobSprintEnabled) || !ClientSprintIsValid(client))
				{
					decl Float:flVelocity[3];
					GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", flVelocity);
					new Float:flSpeed = GetVectorLength(flVelocity);
				
					new Float:flPunchIdle[3];
					flPunchIdle[0] = Sine(GetGameTime() * SF2_PLAYER_VIEWBOB_TIMER) * flSpeed * SF2_PLAYER_VIEWBOB_SCALE_X / 400.0;
					flPunchIdle[1] = Sine(2.0 * GetGameTime() * SF2_PLAYER_VIEWBOB_TIMER) * flSpeed * SF2_PLAYER_VIEWBOB_SCALE_Y / 400.0;
					flPunchIdle[2] = Sine(1.6 * GetGameTime() * SF2_PLAYER_VIEWBOB_TIMER) * flSpeed * SF2_PLAYER_VIEWBOB_SCALE_Z / 400.0;
					
					AddVectors(flPunchVel, flPunchIdle, flPunchVel);
				}
				
				if (GetConVarBool(g_cvPlayerViewBobHurtEnabled))
				{
					// Shake screen the more the player is hurt.
					new Float:flHealth = float(GetEntProp(client, Prop_Send, "m_iHealth"));
					new Float:flMaxHealth = float(SDKCall(g_hSDKGetMaxHealth, client));
					
					decl Float:flPunchVelHurt[3];
					flPunchVelHurt[0] = Sine(1.22 * GetGameTime()) * 48.5 * ((flMaxHealth - flHealth) / (flMaxHealth * 0.75)) / flMaxHealth;
					flPunchVelHurt[1] = Sine(2.12 * GetGameTime()) * 80.0 * ((flMaxHealth - flHealth) / (flMaxHealth * 0.75)) / flMaxHealth;
					flPunchVelHurt[2] = Sine(0.5 * GetGameTime()) * 36.0 * ((flMaxHealth - flHealth) / (flMaxHealth * 0.75)) / flMaxHealth;
					
					AddVectors(flPunchVel, flPunchVelHurt, flPunchVel);
				}
				
				ClientViewPunch(client, flPunchVel);
			}
		}
	}
	
	if (g_bPlayerGhostMode[client])
	{
		SetEntPropFloat(client, Prop_Send, "m_flNextAttack", GetGameTime() + 2.0);
		SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 520.0);
	}
	else if (!g_bPlayerEliminated[client] || g_bPlayerProxy[client])
	{
		if (!g_bRoundEnded && !g_bRoundWarmup && !g_bPlayerEscaped[client])
		{
			if (!g_bPlayerProxy[client])
			{
				SetEntProp(client, Prop_Send, "m_iAirDash", -1);
				
				if (_:GameRules_GetRoundState() == 4)
				{
					new bool:bDanger = false;
					if (g_flPlayerSeesSlenderMeter[client] > 0.4) bDanger = true;
					
					if (!bDanger)
					{
						decl iState;
						decl iBossTarget;
						
						for (new i = 0; i < MAX_BOSSES; i++)
						{
							if (g_iSlenderID[i] == -1 || !g_strSlenderProfile[i][0]) continue;
							
							if (g_iSlenderType[i] == 2)
							{
								iBossTarget = EntRefToEntIndex(g_iSlenderTarget[i]);
								iState = g_iSlenderState[i];
								
								if ((iState == STATE_ALERT || iState == STATE_CHASE || iState == STATE_ATTACK) &&
									((iBossTarget != INVALID_ENT_REFERENCE && (iBossTarget == client || ClientGetDistanceFromEntity(client, iBossTarget) < 512.0)) || SlenderGetDistanceFromPlayer(i, client) < 512.0))
								{
									bDanger = true;
									break;
								}
							}
						}
					}
					
					if (!bDanger)
					{
						new Float:flCurTime = GetGameTime();
						new Float:flScareSprintDuration = 3.0;
						if (TF2_GetPlayerClass(client) == TFClass_DemoMan) flScareSprintDuration *= 1.667;
						
						for (new i = 0; i < MAX_BOSSES; i++)
						{
							if (g_iSlenderID[i] == -1 || !g_strSlenderProfile[i][0]) continue;
							
							if ((flCurTime - g_flPlayerLastScareFromBoss[client][i]) <= flScareSprintDuration)
							{
								bDanger = true;
								break;
							}
						}
					}
					
					new Float:flWalkSpeed = ClientGetDefaultWalkSpeed(client);
					new Float:flSprintSpeed = ClientGetDefaultSprintSpeed(client);
					
					// Check for weapon speed changes.
					new iWeapon = INVALID_ENT_REFERENCE;
					
					for (new iSlot = 0; iSlot <= 5; iSlot++)
					{
						iWeapon = GetPlayerWeaponSlot(client, iSlot);
						if (!iWeapon || iWeapon == INVALID_ENT_REFERENCE) continue;
						
						new iItemDef = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
						switch (iItemDef)
						{
							case 239: // Gloves of Running Urgently
							{
								if (GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") == iWeapon)
								{
									flSprintSpeed += (flSprintSpeed * 0.1);
								}
							}
							case 775: // Escape Plan
							{
								new Float:flHealth = float(GetEntProp(client, Prop_Send, "m_iHealth"));
								new Float:flMaxHealth = float(SDKCall(g_hSDKGetMaxHealth, client));
								new Float:flPercentage = flHealth / flMaxHealth;
								
								if (flPercentage < 0.805 && flPercentage >= 0.605) flSprintSpeed += (flSprintSpeed * 0.05);
								else if (flPercentage < 0.605 && flPercentage >= 0.405) flSprintSpeed += (flSprintSpeed * 0.1);
								else if (flPercentage < 0.405 && flPercentage >= 0.205) flSprintSpeed += (flSprintSpeed * 0.15);
								else if (flPercentage < 0.205) flSprintSpeed += (flSprintSpeed * 0.2);
							}
						}
					}
					
					// Speed buff?
					if (TF2_IsPlayerInCondition(client, TFCond_SpeedBuffAlly))
					{
						flWalkSpeed += (flWalkSpeed * 0.08);
						flSprintSpeed += (flSprintSpeed * 0.08);
					}
					
					if (bDanger)
					{
						flWalkSpeed *= 1.33;
						flSprintSpeed *= 1.33;
						
						if (!g_bPlayerHints[client][PlayerHint_Sprint])
						{
							ClientShowHint(client, PlayerHint_Sprint);
						}
					}
					
					new Float:flSprintSpeedSubtract = ((flSprintSpeed - flWalkSpeed) * 0.5);
					flSprintSpeedSubtract -= flSprintSpeedSubtract * (g_iPlayerSprintPoints[client] != 0 ? (float(g_iPlayerSprintPoints[client]) / 100.0) : 0.0);
					flSprintSpeed -= flSprintSpeedSubtract;
					
					if (g_bPlayerSprint[client]) 
					{
						SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", flSprintSpeed);
					}
					else 
					{
						SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", flWalkSpeed);
					}
					
					if (ClientCanBreath(client) && !g_bPlayerBreath[client])
					{
						ClientStartBreathing(client);
					}
				}
			}
			else
			{
				new TFClassType:iClass = TF2_GetPlayerClass(client);
				new bool:bSpeedup = TF2_IsPlayerInCondition(client, TFCond_SpeedBuffAlly);
			
				switch (iClass)
				{
					case TFClass_Scout:
					{
						SetEntProp(client, Prop_Send, "m_iAirDash", -1);
						
						if (_:GameRules_GetRoundState() == 4)
						{
							if (bSpeedup) SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 405.0);
							else SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 300.0);
						}
					}
					case TFClass_Medic:
					{
						if (_:GameRules_GetRoundState() == 4)
						{
							if (bSpeedup) SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 385.0);
							else SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 300.0);
						}
					}
				}
			}
		}
	}
	
	static Handle:hFlames = INVALID_HANDLE;
	if (hFlames == INVALID_HANDLE) hFlames = CreateArray(2);
	
	if (GetArraySize(hFlames))
	{
		new Handle:hCopy = CloneArray(hFlames);
		
		decl entref, ent, iIndex;
		for (new i = 0, iSize = GetArraySize(hCopy); i < iSize; i++)
		{
			entref = GetArrayCell(hCopy, i);
			ent = EntRefToEntIndex(entref);
			if (!ent || ent == INVALID_ENT_REFERENCE)
			{
				iIndex = FindValueInArray(hFlames, entref);
				if (iIndex != -1) RemoveFromArray(hFlames, iIndex);
			}
		}
		
		CloseHandle(hCopy);
	}
	
	
	if (g_bRoundWarmup || IsClientInPvP(client))
	{
		// BOOOOX!
		decl Float:flOrigin[3], Handle:hTrace;
		new Float:flMins[3] = { -6.0, ... };
		new Float:flMaxs[3] = { 6.0, ... };
	
		new flame = -1;
		
		while ((flame = FindEntityByClassname(flame, "tf_flame")) != -1)
		{
			new iOwnerEntity = -1;
			new iFlamethrower = GetEntPropEnt(flame, Prop_Data, "m_hOwnerEntity");
			if (IsValidEdict(iFlamethrower))
			{
				iOwnerEntity = GetEntPropEnt(iFlamethrower, Prop_Data, "m_hOwnerEntity");
			}
			
			if (iOwnerEntity == client)
			{
				GetEntPropVector(flame, Prop_Data, "m_vecAbsOrigin", flOrigin);
				
				hTrace = TR_TraceHullFilterEx(flOrigin, flOrigin, flMins, flMaxs, MASK_PLAYERSOLID, TraceRayDontHitEntity, iOwnerEntity);
				new iHitEntity = TR_GetEntityIndex(hTrace);
				CloseHandle(hTrace);
				
				if (IsValidEntity(iHitEntity))
				{
					new entref = EntIndexToEntRef(flame);
					
					new iIndex = FindValueInArray(hFlames, entref);
					if (iIndex == -1)
					{
						iIndex = PushArrayCell(hFlames, entref);
						SetArrayCell(hFlames, iIndex, INVALID_ENT_REFERENCE, 1);
					}
					
					if (iHitEntity != EntRefToEntIndex(GetArrayCell(hFlames, iIndex, 1)))
					{
						SetArrayCell(hFlames, iIndex, EntIndexToEntRef(iHitEntity), 1);
						FakeHook_TFFlameStartTouchPost(flame, iHitEntity);
					}
				}
			}
		}
	}
	
	// Process screen shake, if enabled.
	if (GetConVarBool(g_cvPlayerShakeEnabled))
	{
		if (IsPlayerAlive(client))
		{
			new Float:flPercent = g_flPlayerSeesSlenderMeter[client];
			
			new Float:flAmplitudeMax = GetConVarFloat(g_cvPlayerShakeAmplitudeMax);
			new Float:flAmplitude = flAmplitudeMax * flPercent;
			
			new Float:flFrequencyMax = GetConVarFloat(g_cvPlayerShakeFrequencyMax);
			new Float:flFrequency = flFrequencyMax * flPercent;
			
			UTIL_ScreenShake(client, flAmplitude, 0.5, flFrequency);
		}
	}
	
	if (IsClientInPvP(client))
	{
		for (new i = 0; i < sizeof(g_sPlayerProjectileClasses); i++)
		{
			new ent = -1;
			while ((ent = FindEntityByClassname(ent, g_sPlayerProjectileClasses[i])) != -1)
			{
				new iThrowerOffset = FindDataMapOffs(ent, "m_hThrower");
				new bool:bMine = false;
			
				new iOwnerEntity = GetEntPropEnt(ent, Prop_Data, "m_hOwnerEntity");
				if (iOwnerEntity == client)
				{
					bMine = true;
				}
				else if (iThrowerOffset != -1)
				{
					iOwnerEntity = GetEntDataEnt2(ent, iThrowerOffset);
					if (iOwnerEntity == client)
					{
						bMine = true;
					}
				}
				
				if (bMine)
				{
					SetEntProp(ent, Prop_Data, "m_iInitialTeamNum", 0);
					SetEntProp(ent, Prop_Send, "m_iTeamNum", 0);
				}
			}
		}
	}
	
	ClientUpdateMusicSystem(client);
}

public Hook_ClientProjectileSpawnPost(ent)
{
	decl String:sClass[64];
	GetEntityClassname(ent, sClass, sizeof(sClass));
	
	new iThrowerOffset = FindDataMapOffs(ent, "m_hThrower");
	new iOwnerEntity = GetEntPropEnt(ent, Prop_Data, "m_hOwnerEntity");
	
	if (iOwnerEntity == -1 && iThrowerOffset != -1)
	{
		iOwnerEntity = GetEntDataEnt2(ent, iThrowerOffset);
	}
	
	if (IsValidClient(iOwnerEntity))
	{
		if (IsClientInPvP(iOwnerEntity))
		{
			SetEntProp(ent, Prop_Data, "m_iInitialTeamNum", 0);
			SetEntProp(ent, Prop_Send, "m_iTeamNum", 0);
		}
	}
}

stock bool:ClientHasCrits(client)
{
	if (TF2_IsPlayerInCondition(client, TFCond_Kritzkrieged) ||
		TF2_IsPlayerInCondition(client, TFCond_HalloweenCritCandy) ||
		TF2_IsPlayerInCondition(client, TFCond_CritCanteen) ||
		TF2_IsPlayerInCondition(client, TFCond_CritOnFirstBlood) ||
		TF2_IsPlayerInCondition(client, TFCond_CritOnWin) ||
		TF2_IsPlayerInCondition(client, TFCond_CritOnFlagCapture) ||
		TF2_IsPlayerInCondition(client, TFCond_CritOnKill) ||
		TF2_IsPlayerInCondition(client, TFCond_CritOnDamage))
	{
		return true;
	}
	
	new iActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (IsValidEdict(iActiveWeapon))
	{
		decl String:sNetClass[64];
		GetEntityNetClass(iActiveWeapon, sNetClass, sizeof(sNetClass));
		
		if (StrEqual(sNetClass, "CTFFlameThrower"))
		{
			if (GetEntProp(iActiveWeapon, Prop_Send, "m_bCritFire")) return true;
		
			new iItemDef = GetEntProp(iActiveWeapon, Prop_Send, "m_iItemDefinitionIndex");
			if (iItemDef == 594 && TF2_IsPlayerInCondition(client, TFCond_CritMmmph)) return true;
		}
		else if (StrEqual(sNetClass, "CTFMinigun"))
		{
			if (GetEntProp(iActiveWeapon, Prop_Send, "m_bCritShot")) return true;
		}
	}
	
	return false;
}

FakeHook_TFFlameStartTouchPost(flame, other)
{
	if (IsValidClient(other))
	{
		if ((g_bRoundWarmup || IsClientInPvP(other)) && !g_bRoundEnded)
		{
			new iFlamethrower = GetEntPropEnt(flame, Prop_Data, "m_hOwnerEntity");
			if (IsValidEdict(iFlamethrower))
			{
				new iOwnerEntity = GetEntPropEnt(iFlamethrower, Prop_Data, "m_hOwnerEntity");
				if (iOwnerEntity != other && IsValidClient(iOwnerEntity))
				{
					if (g_bRoundWarmup || IsClientInPvP(iOwnerEntity))
					{
						if (GetClientTeam(other) == GetClientTeam(iOwnerEntity))
						{
							TF2_IgnitePlayer(other, iOwnerEntity);
							SDKHooks_TakeDamage(other, iOwnerEntity, iOwnerEntity, 7.0, ClientHasCrits(iOwnerEntity) ? (DMG_BURN | DMG_PREVENT_PHYSICS_FORCE | DMG_ACID) : DMG_BURN | DMG_PREVENT_PHYSICS_FORCE); 
						}
					}
				}
			}
		}
	}
}

public bool:Hook_ClientPvPShouldCollide(ent, collisiongroup, contentsmask, bool:originalResult)
{
	if (!g_bEnabled) return originalResult;
	return true;
}

ClientProcessFlashlight(i)
{
	if (!IsClientInGame(i) || !IsPlayerAlive(i)) return;

	decl fl, flAng, Float:eyeAng[3], Float:ang2[3];
	
	if (g_bPlayerFlashlight[i])
	{
		new bool:bFlicker = false;
		if (g_flPlayerFlashlightMeter[i] <= SF2_FLASHLIGHT_FLICKERAT) bFlicker = true;
		
		fl = EntRefToEntIndex(g_iPlayerFlashlightEnt[i]);
		if (fl && fl != INVALID_ENT_REFERENCE)
		{
			TeleportEntity(fl, NULL_VECTOR, Float:{ 0.0, 0.0, 0.0 }, NULL_VECTOR);
			
			if (bFlicker) SetEntProp(fl, Prop_Data, "m_LightStyle", 10);
			else SetEntProp(fl, Prop_Data, "m_LightStyle", 0);
		}
		
		flAng = EntRefToEntIndex(g_iPlayerFlashlightEntAng[i]);
		if (flAng && flAng != INVALID_ENT_REFERENCE)
		{
			GetClientEyeAngles(i, eyeAng);
			GetClientAbsAngles(i, ang2);
			SubtractVectors(eyeAng, ang2, eyeAng);
			TeleportEntity(flAng, NULL_VECTOR, eyeAng, NULL_VECTOR);
			
			if (bFlicker) SetEntityRenderFx(flAng, RenderFx:13);
			else SetEntityRenderFx(flAng, RenderFx:0);
		}
	}
}

stock Float:ClientGetDefaultWalkSpeed(client)
{
	new Float:flReturn = 190.0;
	new Float:flReturn2 = flReturn;
	new Action:iAction = Plugin_Continue;
	new TFClassType:iClass = TF2_GetPlayerClass(client);
	
	switch (iClass)
	{
		case TFClass_Scout: flReturn = 190.0;
		case TFClass_Sniper: flReturn = 190.0;
		case TFClass_Soldier: flReturn = 190.0;
		case TFClass_DemoMan: flReturn = 190.0;
		case TFClass_Heavy: flReturn = 190.0;
		case TFClass_Medic: flReturn = 190.0;
		case TFClass_Pyro: flReturn = 190.0;
		case TFClass_Spy: flReturn = 190.0;
		case TFClass_Engineer: flReturn = 190.0;
	}
	
	// Call our forward.
	Call_StartForward(fOnClientGetDefaultWalkSpeed);
	Call_PushCell(client);
	Call_PushCellRef(flReturn2);
	Call_Finish(iAction);
	
	if (iAction == Plugin_Changed) flReturn = flReturn2;
	
	return flReturn;
}

stock Float:ClientGetDefaultSprintSpeed(client)
{
	new Float:flReturn = 300.0;
	new Float:flReturn2 = flReturn;
	new Action:iAction = Plugin_Continue;
	new TFClassType:iClass = TF2_GetPlayerClass(client);
	
	switch (iClass)
	{
		case TFClass_Scout: flReturn = 300.0;
		case TFClass_Sniper: flReturn = 300.0;
		case TFClass_Soldier: flReturn = 275.0;
		case TFClass_DemoMan: flReturn = 285.0;
		case TFClass_Heavy: flReturn = 270.0;
		case TFClass_Medic: flReturn = 300.0;
		case TFClass_Pyro: flReturn = 300.0;
		case TFClass_Spy: flReturn = 300.0;
		case TFClass_Engineer: flReturn = 300.0;
	}
	
	// Call our forward.
	Call_StartForward(fOnClientGetDefaultSprintSpeed);
	Call_PushCell(client);
	Call_PushCellRef(flReturn2);
	Call_Finish(iAction);
	
	if (iAction == Plugin_Changed) flReturn = flReturn2;
	
	return flReturn;
}

ClientProcessVisibility(client)
{
	if (!IsClientInGame(client) || !IsPlayerAlive(client)) return;
	
	new String:sProfile[SF2_MAX_PROFILE_NAME_LENGTH];
	
	new bool:bWasSeeingSlender[MAX_BOSSES];
	new bool:bWasStatic[MAX_BOSSES];
	
	decl Float:flSlenderPos[3];
	
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		strcopy(sProfile, sizeof(sProfile), g_strSlenderProfile[i]);
		if (!sProfile[0]) continue;
		
		bWasSeeingSlender[i] = g_bPlayerSeesSlender[client][i];
		bWasStatic[i] = g_bPlayerStatic[client][i];
		g_bPlayerSeesSlender[client][i] = false;
		g_bPlayerStatic[client][i] = false;
		
		new slender = EntRefToEntIndex(g_iSlender[i]);
		
		new Float:endPos[3];
		decl Float:myPos[3];
		GetClientAbsOrigin(client, myPos);
		
		if (slender && slender != INVALID_ENT_REFERENCE)
		{
			SlenderGetAbsOrigin(i, endPos);
			AddVectors(endPos, g_flSlenderVisiblePos[i], endPos);
		}
		
		if (g_bPlayerGhostMode[client])
		{
		}
		else if (!g_bPlayerDeathCam[client])
		{
			if (slender && slender != INVALID_ENT_REFERENCE)
			{
				SlenderGetAbsOrigin(i, flSlenderPos);
				
				g_bPlayerSeesSlender[client][i] = IsPointVisibleToPlayer(client, endPos, _, SlenderUsesBlink(i));
				
				if ((GetGameTime() - g_flPlayerSeesSlenderLastTime[client][i]) > GetProfileFloat(sProfile, "static_look_grace_time", 1.0) || 
					(bWasStatic[i] && g_flPlayerSeesSlenderMeter[client] > 0.1))
				{
					if (GetProfileNum(sProfile, "static_on_look") && g_bPlayerSeesSlender[client][i]) 
					{
						g_bPlayerStatic[client][i] = true;
					}
					else if (GetProfileNum(sProfile, "static_on_radius") && GetVectorDistance(myPos, flSlenderPos) <= GetProfileFloat(sProfile, "static_radius") && IsPointVisibleToPlayer(client, endPos, false, false)) 
					{
						g_bPlayerStatic[client][i] = true;
					}
				}
				
				// Determine player kill conditions.
				if (g_flPlayerSeesSlenderMeter[client] >= 1.0 ||
				(GetVectorDistance(myPos, flSlenderPos) <= GetProfileFloat(sProfile, "kill_radius") && (SlenderKillsOnNear(i) && IsPointVisibleToPlayer(client, endPos, false, SlenderUsesBlink(i)))))
				{
					g_flSlenderLastKill[i] = GetGameTime();
					SubtractVectors(endPos, g_flSlenderVisiblePos[i], endPos);
					ClientStartDeathCam(client, i, endPos);
				}
			}
		}
		else
		{
			g_bPlayerStatic[client][i] = true;
		}
		
		if (g_bPlayerSeesSlender[client][i] && !bWasSeeingSlender[i])
		{
			g_flPlayerSeesSlenderLastTime[client][i] = GetGameTime();
			
			if ((GetGameTime() - g_flPlayerSeesSlenderLastTime2[client][i]) > GetProfileFloat(sProfile, "scare_cooldown"))
			{
				if (GetVectorDistance(myPos, endPos) <= GetProfileFloat(sProfile, "scare_radius"))
				{
					ClientPerformScare(client, i);
					
					if (SlenderHasAttribute(i, "ignite player on scare"))
					{
						new Float:flValue = SlenderGetAttributeValue(i, "ignite player on scare");
						if (flValue > 0.0) TF2_IgnitePlayer(client, client);
					}
				}
			}
			
			if (g_iSlenderType[i] == 0)
			{
				if (g_iSlenderFlags[i] & SFF_FAKE)
				{
					SlenderMarkAsFake(i);
					return;
				}
			}
			
			Call_StartForward(fOnClientLooksAtBoss);
			Call_PushCell(client);
			Call_PushCell(i);
			Call_Finish();
		}
		else if (!g_bPlayerSeesSlender[client][i] && bWasSeeingSlender[i])
		{
			g_flPlayerSeesSlenderLastTime2[client][i] = GetGameTime();
			
			Call_StartForward(fOnClientLooksAwayFromBoss);
			Call_PushCell(client);
			Call_PushCell(i);
			Call_Finish();
		}
	}
	
	// Initialize static timers.
	new iBossLastStatic = g_iPlayerStaticMaster[client];
	new iBossNewStatic = iBossLastStatic;
	
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		// Determine new static rates.
		if (!g_bPlayerStatic[client][i]) continue;
		
		if (iBossLastStatic < 0 || !g_strSlenderProfile[iBossLastStatic][0] || !g_bPlayerStatic[client][iBossLastStatic] || g_flSlenderAnger[iBossLastStatic] < g_flSlenderAnger[i])
		{
			iBossNewStatic = i;
		}
	}
	
	g_iPlayerStaticMaster[client] = iBossNewStatic;
	
	if (iBossNewStatic != -1)
	{
		new Float:flStaticIncreaseRate = GetProfileFloat(g_strSlenderProfile[iBossNewStatic], "static_rate");
		new Float:flStaticDecreaseRate = GetProfileFloat(g_strSlenderProfile[iBossNewStatic], "static_rate_decay");
	
		decl String:sBuffer[PLATFORM_MAX_PATH];
		GetRandomStringFromProfile(g_strSlenderProfile[iBossNewStatic], "sound_static", sBuffer, sizeof(sBuffer), 1);
		if (sBuffer[0])
		{
			strcopy(g_strPlayerStaticSound[client], sizeof(g_strPlayerStaticSound[]), sBuffer);
		}
		
		if (g_bPlayerStatic[client][iBossNewStatic] && (!bWasStatic[iBossNewStatic]))
		{
			new Float:flStaticRate = flStaticIncreaseRate / (g_flRoundDifficultyModifier * g_flSlenderAnger[iBossNewStatic]);
			g_hPlayerStaticTimer[client][iBossNewStatic] = CreateTimer(flStaticRate, Timer_PlayerSeesSlenderIncrease, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
			TriggerTimer(g_hPlayerStaticTimer[client][iBossNewStatic], true);
		}
		else if (!g_bPlayerStatic[client][iBossNewStatic] && (bWasStatic[iBossNewStatic]))
		{
			new Float:flStaticRate = flStaticDecreaseRate * g_flSlenderAnger[iBossNewStatic];
			g_hPlayerStaticTimer[client][iBossNewStatic] = CreateTimer(flStaticRate, Timer_PlayerSeesSlenderDecay, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
			TriggerTimer(g_hPlayerStaticTimer[client][iBossNewStatic], true);
		}
		
		if (iBossLastStatic != -1 && iBossLastStatic != iBossNewStatic)
		{
			// Cross-fade out the static sounds from the old boss.
			g_flPlayerStaticLastMeter[client][iBossLastStatic] = g_flPlayerSeesSlenderMeter[client];
			g_flPlayerStaticLastTime[client][iBossLastStatic] = GetGameTime();
			g_hPlayerStaticTimer[client][iBossLastStatic] = CreateTimer(0.05, Timer_PlayerFadeOutSoundForSlender, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
			TriggerTimer(g_hPlayerStaticTimer[client][iBossLastStatic], true);
		}
	}
}

ClientProcessGlow(client)
{
	if (!IsClientInGame(client) || !IsPlayerAlive(client) || (g_bPlayerEliminated[client] && !g_bPlayerProxy[client]) || g_bPlayerGhostMode[client]) return;
	
	new iOldLookEntity = EntRefToEntIndex(g_iPlayerGlowLookAtEntity[client]);
	
	decl Float:flStartPos[3], Float:flMyEyeAng[3];
	GetClientEyePosition(client, flStartPos);
	GetClientEyeAngles(client, flMyEyeAng);
	
	new Handle:hTrace = TR_TraceRayFilterEx(flStartPos, flMyEyeAng, MASK_VISIBLE, RayType_Infinite, TraceRayDontHitPlayers, -1);
	new iEnt = TR_GetEntityIndex(hTrace);
	CloseHandle(hTrace);
	
	if (IsValidEntity(iEnt))
	{
		g_iPlayerGlowLookAtEntity[client] = EntRefToEntIndex(iEnt);
	}
	else
	{
		g_iPlayerGlowLookAtEntity[client] = INVALID_ENT_REFERENCE;
	}
	
	if (iEnt != iOldLookEntity)
	{
		ClientRemoveGlow(client);
		
		if (IsEntityClassname(iEnt, "prop_dynamic", false))
		{
			decl String:sTargetName[64];
			GetEntPropString(iEnt, Prop_Data, "m_iName", sTargetName, sizeof(sTargetName));
			
			if (!StrContains(sTargetName, "sf2_page", false) || !StrContains(sTargetName, "sf2_interact", false))
			{
				ClientCreateGlowOnEntity(client, iEnt);
			}
		}
	}
}

ClientResetGlow(client)
{
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("START ClientResetGlow(%d)", client);
#endif

	ClientRemoveGlow(client);
	g_iPlayerGlowLookAtEntity[client] = INVALID_ENT_REFERENCE;
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("END ClientResetGlow(%d)", client);
#endif
}

ClientResetBreathing(client)
{
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("START ClientResetBreathing(%d)", client);
#endif

	g_bPlayerBreath[client] = false;
	g_hPlayerBreathTimer[client] = INVALID_HANDLE;
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("END ClientResetBreathing(%d)", client);
#endif
}

Float:ClientCalculateBreathingCooldown(client)
{
	new Float:flAverage = 0.0;
	new iAverageNum = 0;
	
	// Sprinting only, for now.
	flAverage += (SF2_PLAYER_BREATH_COOLDOWN_MAX * 6.7765 * Pow((float(g_iPlayerSprintPoints[client]) / 100.0), 1.65));
	iAverageNum++;
	
	flAverage /= float(iAverageNum)
	
	if (flAverage < SF2_PLAYER_BREATH_COOLDOWN_MIN) flAverage = SF2_PLAYER_BREATH_COOLDOWN_MIN;
	
	return flAverage;
}

ClientStartBreathing(client)
{
	g_bPlayerBreath[client] = true;
	g_hPlayerBreathTimer[client] = CreateTimer(ClientCalculateBreathingCooldown(client), Timer_ClientBreath, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

ClientStopBreathing(client)
{
	g_bPlayerBreath[client] = false;
	g_hPlayerBreathTimer[client] = INVALID_HANDLE;
}

bool:ClientCanBreath(client)
{
	return bool:(ClientCalculateBreathingCooldown(client) < SF2_PLAYER_BREATH_COOLDOWN_MAX);
}

public Action:Timer_ClientBreath(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client <= 0) return;
	
	if (timer != g_hPlayerBreathTimer[client]) return;
	
	if (!g_bPlayerBreath[client]) return;
	
	if (ClientCanBreath(client))
	{
		EmitSoundToAll(g_strPlayerBreathSounds[GetRandomInt(0, sizeof(g_strPlayerBreathSounds) - 1)], client, SNDCHAN_AUTO, SNDLEVEL_SCREAMING);
	
		ClientStartBreathing(client);
		return;
	}
	
	ClientStopBreathing(client);
}

ClientResetSprint(client)
{
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("START ClientResetSprint(%d)", client);
#endif

	g_bPlayerSprint[client] = false;
	g_iPlayerSprintPoints[client] = 100;
	g_hPlayerSprintTimer[client] = INVALID_HANDLE;
	
	if (IsValidClient(client))
	{
		SDKUnhook(client, SDKHook_PreThink, Hook_ClientSprintingPreThink);
		SDKUnhook(client, SDKHook_PreThink, Hook_ClientRechargeSprintPreThink);
	}
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("END ClientResetSprint(%d)", client);
#endif
}

ClientStartSprint(client)
{
	if (g_bPlayerSprint[client]) return;
	
	g_bPlayerSprint[client] = true;
	ClientSprintTimer(client);
	TriggerTimer(g_hPlayerSprintTimer[client], true);
	
	SDKHook(client, SDKHook_PreThink, Hook_ClientSprintingPreThink);
	SDKUnhook(client, SDKHook_PreThink, Hook_ClientRechargeSprintPreThink);
}

ClientSprintTimer(client, bool:bRecharge=false)
{
	new Float:flRate = 0.28;
	if (bRecharge) flRate = 0.8;
	
	decl Float:flVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", flVelocity);
	
	if (bRecharge)
	{
		if (!(GetEntityFlags(client) & FL_ONGROUND)) flRate *= 0.75;
		else if (GetVectorLength(flVelocity) == 0.0)
		{
			if (GetEntProp(client, Prop_Send, "m_bDucked")) flRate *= 0.66;
			else flRate *= 0.75;
		}
	}
	else
	{
		if (TF2_GetPlayerClass(client) == TFClass_Scout) flRate *= 1.15;
	}
	
	if (bRecharge) g_hPlayerSprintTimer[client] = CreateTimer(flRate, Timer_ClientRechargeSprint, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	else g_hPlayerSprintTimer[client] = CreateTimer(flRate, Timer_ClientSprinting, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

ClientStopSprint(client)
{
	if (!g_bPlayerSprint[client]) return;
	
	g_bPlayerSprint[client] = false;
	ClientSprintTimer(client, true);
	
	SDKHook(client, SDKHook_PreThink, Hook_ClientRechargeSprintPreThink);
	SDKUnhook(client, SDKHook_PreThink, Hook_ClientSprintingPreThink);
}

bool:ClientSprintIsValid(client)
{
	if (!g_bPlayerSprint[client]) return false;
	if (!(GetEntityFlags(client) & FL_ONGROUND)) return false;
	
	decl Float:flVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", flVelocity);
	if (GetVectorLength(flVelocity) < 30.0) return false;
	
	return true;
}

public Action:Timer_ClientSprinting(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client <= 0) return;
	
	if (timer != g_hPlayerSprintTimer[client]) return;
	
	if (!g_bPlayerSprint[client]) return;
	
	if (g_iPlayerSprintPoints[client] <= 0)
	{
		ClientStopSprint(client);
		g_iPlayerSprintPoints[client] = 0;
		return;
	}
	
	if (ClientSprintIsValid(client)) g_iPlayerSprintPoints[client]--;
	
	ClientSprintTimer(client);
}

public Hook_ClientSprintingPreThink(client)
{
	if (!ClientSprintIsValid(client))
	{
		SDKUnhook(client, SDKHook_PreThink, Hook_ClientSprintingPreThink);
		SDKHook(client, SDKHook_PreThink, Hook_ClientRechargeSprintPreThink);
		return;
	}
	
	new iFOV = GetEntData(client, g_offsPlayerDefaultFOV);
	
	new iTargetFOV = g_iPlayerDesiredFOV[client] + 10;
	
	if (iFOV < iTargetFOV)
	{
		new iDiff = RoundFloat(FloatAbs(float(iFOV - iTargetFOV)));
		if (iDiff >= 1)
		{
			ClientSetFOV(client, iFOV + 1);
		}
		else
		{
			ClientSetFOV(client, iTargetFOV);
		}
	}
	else if (iFOV >= iTargetFOV)
	{
		ClientSetFOV(client, iTargetFOV);
		//SDKUnhook(client, SDKHook_PreThink, Hook_ClientSprintingPreThink);
	}
}

public Hook_ClientRechargeSprintPreThink(client)
{
	if (ClientSprintIsValid(client))
	{
		SDKUnhook(client, SDKHook_PreThink, Hook_ClientRechargeSprintPreThink);
		SDKHook(client, SDKHook_PreThink, Hook_ClientSprintingPreThink);
		return;
	}
	
	new iFOV = GetEntData(client, g_offsPlayerDefaultFOV);
	if (iFOV > g_iPlayerDesiredFOV[client])
	{
		new iDiff = RoundFloat(FloatAbs(float(iFOV - g_iPlayerDesiredFOV[client])));
		if (iDiff >= 1)
		{
			ClientSetFOV(client, iFOV - 1);
		}
		else
		{
			ClientSetFOV(client, g_iPlayerDesiredFOV[client]);
		}
	}
	else if (iFOV <= g_iPlayerDesiredFOV[client])
	{
		ClientSetFOV(client, g_iPlayerDesiredFOV[client]);
		//SDKUnhook(client, SDKHook_PreThink, Hook_ClientRechargeSprintPreThink);
	}
}

public Action:Timer_ClientRechargeSprint(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client <= 0) return;
	
	if (timer != g_hPlayerSprintTimer[client]) return;
	
	if (g_bPlayerSprint[client]) return;
	
	if (g_iPlayerSprintPoints[client] >= 100)
	{
		g_iPlayerSprintPoints[client] = 100;
		return;
	}
	
	g_iPlayerSprintPoints[client]++;
	ClientSprintTimer(client, true);
}

ClientRemoveGlow(client)
{
	new iGlow = EntRefToEntIndex(g_iPlayerGlowEntity[client]);
	g_iPlayerGlowEntity[client] = INVALID_ENT_REFERENCE;
	if (iGlow && iGlow != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(iGlow, "Kill");
	}
}

bool:ClientCreateGlowOnEntity(client, iEnt, const String:sAttachment[]="")
{
	ClientRemoveGlow(client);

	if (!iEnt || !IsValidEntity(iEnt)) return false;

	decl String:sBuffer[PLATFORM_MAX_PATH];
	GetEntPropString(iEnt, Prop_Data, "m_ModelName", sBuffer, sizeof(sBuffer));
	
	if (!sBuffer[0]) return false;
	
	new ent = CreateEntityByName("simple_bot");
	if (ent != -1)
	{
		DispatchSpawn(ent);
		ActivateEntity(ent);
		SetEntityModel(ent, sBuffer);
		SetEntityRenderMode(ent, RENDER_TRANSCOLOR);
		SetEntityRenderColor(ent, 0, 0, 0, 1);
		SetEntProp(ent, Prop_Data, "m_takedamage", 0);
		SetEntProp(ent, Prop_Send, "m_bGlowEnabled", 1);
		SetEntPropFloat(ent, Prop_Send, "m_flModelScale", GetEntPropFloat(iEnt, Prop_Send, "m_flModelScale"));
		// Set solid flags.
		new iFlags = GetEntProp(ent, Prop_Send, "m_usSolidFlags");
		
		if (!(iFlags & 0x0004)) iFlags |= 0x0004; // 	FSOLID_NOT_SOLID
		if (!(iFlags & 0x0008)) iFlags |= 0x0008; // 	FSOLID_TRIGGER
		SetEntProp(ent, Prop_Send, "m_usSolidFlags", iFlags);
		
		iFlags = GetEntProp(ent, Prop_Send, "m_fEffects");
		if (!(iFlags & (1 << 0))) iFlags |= (1 << 0); // 	EF_BONEMERGE
		SetEntProp(ent, Prop_Send, "m_fEffects", iFlags);
		
		SetEntityMoveType(ent, MOVETYPE_NONE);
		SetVariantString("!activator");
		AcceptEntityInput(ent, "SetParent", iEnt);
		
		if (sAttachment[0])
		{
			SetVariantString(sAttachment);
			AcceptEntityInput(ent, "SetParentAttachment");
		}
		
		g_iPlayerGlowEntity[client] = EntIndexToEntRef(ent);
		
		SDKHook(ent, SDKHook_SetTransmit, Hook_GlowSetTransmit);
		
		return true;
	}
	
	return false;
}

public Action:Hook_GlowSetTransmit(ent, other)
{
	if (!g_bEnabled) return Plugin_Continue;

	if (EntRefToEntIndex(g_iPlayerGlowEntity[other]) != ent) return Plugin_Handled;
	
	return Plugin_Continue;
}

ClientResetProxyGlow(client)
{
	ClientRemoveProxyGlow(client);
}

ClientRemoveProxyGlow(client)
{
	if (!g_bPlayerHasProxyGlow[client]) return;
	
	g_bPlayerHasProxyGlow[client] = false;
	
	if (IsClientInGame(client))
	{
		new iFlags = GetEdictFlags(client);
		if (iFlags & FL_EDICT_ALWAYS) iFlags &= ~FL_EDICT_ALWAYS;
		SetEdictFlags(client, iFlags);
	}

	new iGlow = EntRefToEntIndex(g_iPlayerProxyGlowEntity[client]);
	if (iGlow && iGlow != INVALID_ENT_REFERENCE) AcceptEntityInput(iGlow, "Kill");
	
	g_iPlayerProxyGlowEntity[client] = INVALID_ENT_REFERENCE;
}

bool:ClientCreateProxyGlow(client, const String:sAttachment[]="")
{
	ClientRemoveProxyGlow(client);
	
	g_bPlayerHasProxyGlow[client] = true;
	
	// Set edict flags so that the glow will appear for Proxies anywhere.
	new iFlags = GetEdictFlags(client);
	if (!(iFlags & FL_EDICT_ALWAYS)) iFlags |= FL_EDICT_ALWAYS;
	SetEdictFlags(client, iFlags);
	
	decl String:sBuffer[PLATFORM_MAX_PATH];
	GetEntPropString(client, Prop_Data, "m_ModelName", sBuffer, sizeof(sBuffer));
	
	if (!sBuffer[0]) return false;
	
	new iGlow = CreateEntityByName("simple_bot");
	if (iGlow != -1)
	{
		new Float:flModelScale = GetEntPropFloat(client, Prop_Send, "m_flModelScale");
		
		DispatchSpawn(iGlow);
		ActivateEntity(iGlow);
		SetEntityMoveType(iGlow, MOVETYPE_NONE);
		SetEntityModel(iGlow, sBuffer);
		SetEntityRenderMode(iGlow, RENDER_TRANSCOLOR);
		SetEntityRenderColor(iGlow, 0, 0, 0, 1);
		SetEntProp(iGlow, Prop_Data, "m_takedamage", 0);
		SetEntProp(iGlow, Prop_Send, "m_bGlowEnabled", 1);
		SetEntPropFloat(iGlow, Prop_Send, "m_flModelScale", flModelScale);
		
		// Set solid flags.
		iFlags = GetEntProp(iGlow, Prop_Send, "m_usSolidFlags");
		if (!(iFlags & FSOLID_NOT_SOLID)) iFlags |= FSOLID_NOT_SOLID;
		if (!(iFlags & FSOLID_TRIGGER)) iFlags |= FSOLID_TRIGGER;
		SetEntProp(iGlow, Prop_Send, "m_usSolidFlags", iFlags);
		
		// Set effect flags.
		iFlags = GetEntProp(iGlow, Prop_Send, "m_fEffects");
		if (!(iFlags & (1 << 0))) iFlags |= (1 << 0); // EF_BONEMERGE
		SetEntProp(iGlow, Prop_Send, "m_fEffects", iFlags);
		
		SetVariantString("!activator");
		AcceptEntityInput(iGlow, "SetParent", client);
		
		if (sAttachment[0])
		{
			SetVariantString(sAttachment);
			AcceptEntityInput(iGlow, "SetParentAttachment");
		}
		
		g_iPlayerProxyGlowEntity[client] = EntIndexToEntRef(iGlow);
		
		SDKHook(iGlow, SDKHook_SetTransmit, Hook_ProxyGlowSetTransmit);
		
		return true;
	}
	
	return false;
}

public Action:Hook_ProxyGlowSetTransmit(ent, other)
{
	if (!g_bEnabled) return Plugin_Continue;
	
	new iOwner = -1;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i)) continue;
		if (EntRefToEntIndex(g_iPlayerProxyGlowEntity[i]) == ent)
		{
			iOwner = i;
			break;
		}
	}
	
	if (iOwner != -1)
	{
		if (!IsPlayerAlive(iOwner) || g_bPlayerEliminated[iOwner]) return Plugin_Handled;
		if (!IsPlayerAlive(other) || !g_bPlayerProxy[other]) return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action:Hook_TEFireBullets(const String:te_name[], const Players[], numClients, Float:delay)
{
	if (!g_bEnabled) return Plugin_Continue;
	
	new client = TE_ReadNum("m_iPlayer") + 1;
	if (IsValidClient(client))
	{
		if ((g_bRoundWarmup || IsClientInPvP(client)) && !g_bRoundEnded)
		{
			ClientEnableFakeLagCompensation(client);
		}
	}
	
	return Plugin_Continue;
}

public Action:TF2_CalcIsAttackCritical(client, weapon, String:sWeaponName[], &bool:result)
{
	if (!g_bEnabled) return Plugin_Continue;
	
	if ((g_bRoundWarmup || IsClientInPvP(client)) && !g_bRoundEnded)
	{
		if (StrEqual(sWeaponName, "tf_weapon_sniperrifle"))
		{
			// TRACE!
			decl Float:flStartPos[3], Float:flEyeAng[3];
			GetClientEyePosition(client, flStartPos);
			GetClientEyeAngles(client, flEyeAng);
			
			new Handle:hTrace = TR_TraceRayFilterEx(flStartPos, flEyeAng, MASK_SHOT, RayType_Infinite, TraceRayDontHitEntity, client);
			new iHitEntity = TR_GetEntityIndex(hTrace);
			new iHitGroup = TR_GetHitGroup(hTrace);
			CloseHandle(hTrace);
			
			if (IsValidClient(iHitEntity))
			{
				if (GetClientTeam(iHitEntity) == GetClientTeam(client))
				{
					if (g_bRoundWarmup || IsClientInPvP(iHitEntity))
					{
						new Float:flDamage = GetEntPropFloat(weapon, Prop_Send, "m_flChargedDamage");
						if (flDamage < 50.0) flDamage = 50.0;
						new iDamageType = DMG_BULLET;
						
						if (ClientHasCrits(client) || (iHitGroup == 1 && TF2_IsPlayerInCondition(client, TFCond_Zoomed)))
						{
							result = true;
							iDamageType |= DMG_ACID;
						}
						
						SDKHooks_TakeDamage(iHitEntity, client, client, flDamage, iDamageType);
						return Plugin_Changed;
					}
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public Action:Hook_ClientOnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	if (!g_bEnabled) return Plugin_Continue;
	
	if (g_bRoundWarmup) return Plugin_Continue;
	
	if (attacker != victim && IsValidClient(attacker))
	{
		if (!g_bRoundEnded)
		{
			if (IsClientInPvP(victim) && IsClientInPvP(attacker))
			{
				if (attacker == inflictor)
				{
					if (IsValidEdict(weapon))
					{
						decl String:sWeaponClass[64];
						GetEdictClassname(weapon, sWeaponClass, sizeof(sWeaponClass));
						
						// Backstab check!
						if (StrEqual(sWeaponClass, "tf_weapon_knife", false) ||
						(TF2_GetPlayerClass(attacker) == TFClass_Spy && StrEqual(sWeaponClass, "saxxy", false)))
						{
							decl Float:flMyPos[3], Float:flHisPos[3], Float:flMyDirection[3];
							GetClientAbsOrigin(victim, flMyPos);
							GetClientAbsOrigin(attacker, flHisPos);
							GetClientEyeAngles(victim, flMyDirection);
							GetAngleVectors(flMyDirection, flMyDirection, NULL_VECTOR, NULL_VECTOR);
							NormalizeVector(flMyDirection, flMyDirection);
							ScaleVector(flMyDirection, 32.0);
							AddVectors(flMyDirection, flMyPos, flMyDirection);
							
							decl Float:p[3], Float:s[3];
							MakeVectorFromPoints(flMyPos, flHisPos, p);
							MakeVectorFromPoints(flMyPos, flMyDirection, s);
							if (GetVectorDotProduct(p, s) <= 0.0)
							{
								damage = float(GetEntProp(victim, Prop_Send, "m_iHealth")) * 2.0;
								
								new Handle:hCvar = FindConVar("tf_weapon_criticals");
								if (hCvar != INVALID_HANDLE && GetConVarBool(hCvar)) damagetype |= DMG_ACID;
								return Plugin_Changed;
							}
						}
					}
				}
			}
			else if (g_bPlayerProxy[victim] || g_bPlayerProxy[attacker])
			{
				if (g_bPlayerEliminated[attacker] == g_bPlayerEliminated[victim])
				{
					damage = 0.0;
					return Plugin_Changed;
				}
				
				if (g_bPlayerProxy[attacker])
				{
					new iMaxHealth = SDKCall(g_hSDKGetMaxHealth, victim);
					new iMaster = g_iPlayerProxyMaster[attacker];
					if (iMaster != -1 && g_strSlenderProfile[iMaster][0])
					{
						if (damagecustom == TF_CUSTOM_TAUNT_GRAND_SLAM ||
						damagecustom == TF_CUSTOM_TAUNT_FENCING ||
						damagecustom == TF_CUSTOM_TAUNT_ARROW_STAB ||
						damagecustom == TF_CUSTOM_TAUNT_GRENADE ||
						damagecustom == TF_CUSTOM_TAUNT_BARBARIAN_SWING ||
						damagecustom == TF_CUSTOM_TAUNT_ENGINEER_ARM ||
						damagecustom == TF_CUSTOM_TAUNT_ARMAGEDDON)
						{
							if (damage >= float(iMaxHealth)) damage = float(iMaxHealth) * 0.5;
							else damage = 0.0;
						}
						else if (damagecustom == TF_CUSTOM_BACKSTAB) // Modify backstab damage.
						{
							damage = float(iMaxHealth) * GetProfileFloat(g_strSlenderProfile[iMaster], "proxies_damage_scale_vs_enemy_backstab", 0.25);
							if (damagetype & DMG_ACID) damage /= 3.0;
						}
					
						g_iPlayerProxyControl[attacker] += GetProfileNum(g_strSlenderProfile[iMaster], "proxies_controlgain_hitenemy");
						if (g_iPlayerProxyControl[attacker] > 100)
						{
							g_iPlayerProxyControl[attacker] = 100;
						}
						
						damage *= GetProfileFloat(g_strSlenderProfile[iMaster], "proxies_damage_scale_vs_enemy", 1.0);
					}
					
					return Plugin_Changed;
				}
				else if (g_bPlayerProxy[victim])
				{
					new iMaster = g_iPlayerProxyMaster[victim];
					if (iMaster != -1 && g_strSlenderProfile[iMaster][0])
					{
						g_iPlayerProxyControl[attacker] += GetProfileNum(g_strSlenderProfile[iMaster], "proxies_controlgain_hitbyenemy");
						if (g_iPlayerProxyControl[attacker] > 100)
						{
							g_iPlayerProxyControl[attacker] = 100;
						}
						
						damage *= GetProfileFloat(g_strSlenderProfile[iMaster], "proxies_damage_scale_vs_self", 1.0);
					}
					
					return Plugin_Changed;
				}
			}
			else
			{
				damage = 0.0;
				return Plugin_Changed;
			}
		}
		else
		{
			if (g_bPlayerEliminated[attacker] == g_bPlayerEliminated[victim])
			{
				damage = 0.0;
				return Plugin_Changed;
			}
		}
		
		if (g_bPlayerGhostMode[victim])
		{
			damage = 0.0;
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}

stock ClientSetFOV(client, iFOV)
{
	SetEntData(client, g_offsPlayerFOV, iFOV);
	SetEntData(client, g_offsPlayerDefaultFOV, iFOV);
}

public OnClientGetDesiredFOV(QueryCookie:cookie, client, ConVarQueryResult:result, const String:cvarName[], const String:cvarValue[])
{
	if (!IsValidClient(client)) return;
	
	g_iPlayerDesiredFOV[client] = StringToInt(cvarValue);
	ClientSetFOV(client, g_iPlayerDesiredFOV[client]);
}

InitializeClient(client)
{
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("START InitializeClient(%d)", client);
#endif

	g_iPlayerGhostModeTarget[client] = INVALID_ENT_REFERENCE;
	g_iPlayerStaticMaster[client] = -1;
	strcopy(g_strPlayerStaticSound[client], sizeof(g_strPlayerStaticSound[]), "");
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 1) DebugMessage("InitializeClient(%d): QueryClientConVar fov_desired", client);
#endif
	
	if (!IsFakeClient(client))
	{
		QueryClientConVar(client, "fov_desired", OnClientGetDesiredFOV, GetClientUserId(client));
	}
	else
	{
		g_iPlayerDesiredFOV[client] = 90;
	}
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 1) DebugMessage("InitializeClient(%d): ClientStopAllSlenderSounds", client);
#endif
	
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		g_bPlayerStatic[client][i] = false;
		g_flPlayerStaticLastTime[client][i] = 0.0;
		
		if (g_strSlenderProfile[i][0])
		{
			ClientStopAllSlenderSounds(client, g_strSlenderProfile[i], "sound_static", SNDCHAN_STATIC);
			ClientStopAllSlenderSounds(client, g_strSlenderProfile[i], "sound_20dollars", SNDCHAN_STATIC);
		}
	}
	
	g_iPlayerFoundPages[client] = 0;
	
	StopSound(client, SNDCHAN_STATIC, TWENTYDOLLARS_SOUND);
	
	ClientResetSlenderStats(client);
	ClientResetFlashlight(client);
	ClientResetCampingStats(client);
	ClientResetBlink(client);
	ClientResetOverlay(client);
	ClientResetJumpScare(client);
	ClientUpdateListeningFlags(client);
	ClientUpdateMusicSystem(client);
	ClientMusicReset(client);
	ClientChaseMusicReset(client);
	ClientChaseMusicSeeReset(client);
	ClientResetGlow(client);
	ClientResetPvP(client);
	ClientResetProxy(client);
	ClientResetProxyGlow(client);
	ClientResetSprint(client);
	ClientResetBreathing(client);
	ClientResetHints(client);
	ClientResetScare(client);
	ClientDisableFakeLagCompensation(client);
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("END InitializeClient(%d)", client);
#endif
}

ClientResetProxy(client, bool:bResetFull=true)
{
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("START ClientResetProxy(%d)", client);
#endif

	new iOldMaster = g_iPlayerProxyMaster[client];
	new String:sOldProfileName[64];
	if (iOldMaster >= 0)
	{
		strcopy(sOldProfileName, sizeof(sOldProfileName), g_strSlenderProfile[iOldMaster]);
	}
	
	new bool:bOldProxy = g_bPlayerProxy[client];
	if (bResetFull) 
	{
		g_bPlayerProxy[client] = false;
		g_iPlayerProxyMaster[client] = -1;
	}
	
	g_iPlayerProxyControl[client] = 0;
	g_hPlayerProxyControlTimer[client] = INVALID_HANDLE;
	g_flPlayerProxyControlRate[client] = 0.0;
	g_flPlayerProxyVoiceTimer[client] = INVALID_HANDLE;
	
	if (IsClientInGame(client))
	{
		if (bOldProxy)
		{
			ClientStartProxyAvailableTimer(client);
		
			if (bResetFull)
			{
				SetVariantString("");
				AcceptEntityInput(client, "SetCustomModel");
			}
			
			if (sOldProfileName[0])
			{
				ClientStopAllSlenderSounds(client, sOldProfileName, "sound_proxy_spawn", GetProfileNum(sOldProfileName, "sound_proxy_spawn_channel", SNDCHAN_AUTO));
				ClientStopAllSlenderSounds(client, sOldProfileName, "sound_proxy_hurt", GetProfileNum(sOldProfileName, "sound_proxy_hurt_channel", SNDCHAN_AUTO));
			}
		}
	}
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("END ClientResetProxy(%d)", client);
#endif
}

stock TF2_GetClassName(TFClassType:iClass, String:sBuffer[], sBufferLen)
{
	switch (iClass)
	{
		case TFClass_Scout: strcopy(sBuffer, sBufferLen, "scout");
		case TFClass_Sniper: strcopy(sBuffer, sBufferLen, "sniper");
		case TFClass_Soldier: strcopy(sBuffer, sBufferLen, "soldier");
		case TFClass_DemoMan: strcopy(sBuffer, sBufferLen, "demoman");
		case TFClass_Heavy: strcopy(sBuffer, sBufferLen, "heavyweapons");
		case TFClass_Medic: strcopy(sBuffer, sBufferLen, "medic");
		case TFClass_Pyro: strcopy(sBuffer, sBufferLen, "pyro");
		case TFClass_Spy: strcopy(sBuffer, sBufferLen, "spy");
		case TFClass_Engineer: strcopy(sBuffer, sBufferLen, "engineer");
		default: strcopy(sBuffer, sBufferLen, "");
	}
}

ClientStartProxyAvailableTimer(client)
{
	g_bPlayerProxyAvailable[client] = false;
	g_hPlayerProxyAvailableTimer[client] = CreateTimer(GetConVarFloat(g_cvPlayerProxyWaitTime), Timer_ClientProxyAvailable, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

ClientStartProxyForce(client, iSlenderID, const Float:flPos[3])
{
	g_iPlayerProxyAskMaster[client] = iSlenderID;
	for (new i = 0; i < 3; i++) g_iPlayerProxyAskPosition[client][i] = flPos[i];

	g_iPlayerProxyAvailableCount[client] = 6;
	g_bPlayerProxyAvailableInForce[client] = true;
	g_hPlayerProxyAvailableTimer[client] = CreateTimer(1.0, Timer_ClientForceProxy, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	TriggerTimer(g_hPlayerProxyAvailableTimer[client], true);
}

ClientStopProxyForce(client)
{
	g_iPlayerProxyAvailableCount[client] = 0;
	g_bPlayerProxyAvailableInForce[client] = false;
	g_hPlayerProxyAvailableTimer[client] = INVALID_HANDLE;
}

public Action:Timer_ClientForceProxy(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client <= 0) return Plugin_Stop;
	
	if (timer != g_hPlayerProxyAvailableTimer[client]) return Plugin_Stop;
	
	if (!g_bRoundEnded)
	{
		new iBossIndex = SlenderGetFromID(g_iPlayerProxyAskMaster[client]);
		if (iBossIndex != -1)
		{
			new iMaxProxies = GetProfileNum(g_strSlenderProfile[iBossIndex], "proxies_max");
			new iNumProxies;
			
			for (new iClient = 1; iClient <= MaxClients; iClient++)
			{
				if (!IsClientInGame(iClient) || !g_bPlayerEliminated[iClient]) continue;
				if (!g_bPlayerProxy[iClient]) continue;
				if (g_iPlayerProxyMaster[iClient] != iBossIndex) continue;
				
				iNumProxies++;
			}
			
			if (iNumProxies < iMaxProxies)
			{
				if (g_iPlayerProxyAvailableCount[client] > 0)
				{
					g_iPlayerProxyAvailableCount[client]--;
					
					SetHudTextParams(-1.0, 0.25, 
						1.0,
						255, 255, 255, 255,
						_,
						_,
						0.25, 1.25);
					
					ShowSyncHudText(client, g_hHudSync, "%T", "SF2 Proxy Force Message", client, g_iPlayerProxyAvailableCount[client]);
					
					return Plugin_Continue;
				}
				else
				{
					ClientEnableProxy(client, iBossIndex);
					TeleportEntity(client, g_iPlayerProxyAskPosition[client], NULL_VECTOR, Float:{ 0.0, 0.0, 0.0 });
				}
			}
			else
			{
				PrintToChat(client, "%T", "SF2 Too Many Proxies", client);
			}
		}
	}
	
	ClientStopProxyForce(client);
	return Plugin_Stop;
}

DisplayProxyAskMenu(client, iAskMaster, const Float:flPos[3])
{
	decl String:sBuffer[512];
	new Handle:hMenu = CreateMenu(Menu_ProxyAsk);
	SetMenuTitle(hMenu, "%T\n \n%T\n \n", "SF2 Proxy Ask Menu Title", client, "SF2 Proxy Ask Menu Description", client);
	
	Format(sBuffer, sizeof(sBuffer), "%T", "Yes", client);
	AddMenuItem(hMenu, "1", sBuffer);
	Format(sBuffer, sizeof(sBuffer), "%T", "No", client);
	AddMenuItem(hMenu, "0", sBuffer);
	
	g_iPlayerProxyAskMaster[client] = iAskMaster;
	for (new i = 0; i < 3; i++) g_iPlayerProxyAskPosition[client][i] = flPos[i];
	DisplayMenu(hMenu, client, 15);
}

public Menu_ProxyAsk(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_End: CloseHandle(menu);
		case MenuAction_Select:
		{
			if (!g_bRoundEnded)
			{
				new iBossIndex = SlenderGetFromID(g_iPlayerProxyAskMaster[param1]);
				if (iBossIndex != -1)
				{
					new iMaxProxies = GetProfileNum(g_strSlenderProfile[iBossIndex], "proxies_max");
					new iNumProxies;
				
					for (new iClient = 1; iClient <= MaxClients; iClient++)
					{
						if (!IsClientInGame(iClient) || !g_bPlayerEliminated[iClient]) continue;
						if (!g_bPlayerProxy[iClient]) continue;
						if (g_iPlayerProxyMaster[iClient] != iBossIndex) continue;
						
						iNumProxies++;
					}
					
					if (iNumProxies < iMaxProxies)
					{
						if (param2 == 0)
						{
							ClientEnableProxy(param1, iBossIndex);
							TeleportEntity(param1, g_iPlayerProxyAskPosition[param1], NULL_VECTOR, Float:{ 0.0, 0.0, 0.0 });
						}
						else
						{
							ClientStartProxyAvailableTimer(param1);
						}
					}
					else
					{
						PrintToChat(param1, "%T", "SF2 Too Many Proxies", param1);
					}
				}
			}
		}
	}
}

public Action:Timer_ClientProxyAvailable(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client <= 0) return;
	
	if (timer != g_hPlayerProxyAvailableTimer[client]) return;
	
	g_bPlayerProxyAvailable[client] = true;
	g_hPlayerProxyAvailableTimer[client] = INVALID_HANDLE;
}

ClientEnableProxy(client, iBossIndex)
{
	if (!g_strSlenderProfile[iBossIndex][0]) return;
	if (!GetProfileNum(g_strSlenderProfile[iBossIndex], "proxies")) return;
	if (g_bPlayerProxy[client]) return;
	
	decl String:sProfile[SF2_MAX_PROFILE_NAME_LENGTH];
	strcopy(sProfile, sizeof(sProfile), g_strSlenderProfile[iBossIndex]);
	
	ClientDisableGhostMode(client);
	ClientDisablePvP(client);
	ClientStopProxyForce(client);
	ChangeClientTeamNoSuicide(client, _:TFTeam_Blue);
	if (!IsPlayerAlive(client)) TF2_RespawnPlayer(client);
	// Speed recalculation. Props to the creators of FF2/VSH for this snippet.
	TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.001);
	
	g_bPlayerProxy[client] = true;
	g_iPlayerProxyMaster[client] = iBossIndex;
	g_iPlayerProxyControl[client] = 100;
	g_flPlayerProxyControlRate[client] = GetProfileFloat(sProfile, "proxies_controldrainrate");
	g_hPlayerProxyControlTimer[client] = CreateTimer(g_flPlayerProxyControlRate[client], Timer_ClientProxyControl, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	g_bPlayerProxyAvailable[client] = false;
	g_hPlayerProxyAvailableTimer[client] = INVALID_HANDLE;
	
	decl String:sAllowedClasses[512];
	GetProfileString(sProfile, "proxies_classes", sAllowedClasses, sizeof(sAllowedClasses));
	
	decl String:sClassName[64];
	TF2_GetClassName(TF2_GetPlayerClass(client), sClassName, sizeof(sClassName));
	if (sAllowedClasses[0] && sClassName[0] && StrContains(sAllowedClasses, sClassName, false) == -1)
	{
		// Pick the first class that's allowed.
		new String:sAllowedClassesList[32][32];
		new iClassCount = ExplodeString(sAllowedClasses, " ", sAllowedClassesList, 32, 32);
		if (iClassCount)
		{
			TF2_SetPlayerClass(client, TF2_GetClass(sAllowedClassesList[0]), _, false);
			TF2_RegeneratePlayer(client);
			
			new iMaxHealth = GetEntProp(client, Prop_Send, "m_iHealth");
			TF2_RegeneratePlayer(client);
			SetEntProp(client, Prop_Data, "m_iHealth", iMaxHealth);
			SetEntProp(client, Prop_Send, "m_iHealth", iMaxHealth);
		}
	}
	
	UTIL_ScreenFade(client, 200, 1, FFADE_IN, 255, 255, 255, 100);
	PrecacheSound("weapons/teleporter_send.wav");
	EmitSoundToClient(client, "weapons/teleporter_send.wav", _, SNDCHAN_STATIC);
	
	ClientActivateUltravision(client);
	
	Call_StartForward(fOnClientSpawnedAsProxy);
	Call_PushCell(client);
	Call_Finish();
}

public Action:Timer_ClientProxyControl(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client <= 0) return;
	
	if (timer != g_hPlayerProxyControlTimer[client]) return;
	
	g_iPlayerProxyControl[client]--;
	if (g_iPlayerProxyControl[client] <= 0)
	{
		// ForcePlayerSuicide isn't really dependable, since the player doesn't suicide until several seconds after spawning has passed.
		SDKHooks_TakeDamage(client, client, client, 9001.0, DMG_PREVENT_PHYSICS_FORCE, _, Float:{ 0.0, 0.0, 0.0 });
		return;
	}
	
	g_hPlayerProxyControlTimer[client] = CreateTimer(g_flPlayerProxyControlRate[client], Timer_ClientProxyControl, userid, TIMER_FLAG_NO_MAPCHANGE);
}

ClientResetJumpScare(client)
{
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("START ClientResetJumpScare(%d)", client);
#endif

	g_iPlayerJumpScareMaster[client] = -1;
	g_flPlayerJumpScareLifeTime[client] = -1.0;
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("END ClientResetJumpScare(%d)", client);
#endif
}

bool:ClientSetQueuePoints(client, iAmount)
{
	if (!IsClientConnected(client) || !AreClientCookiesCached(client)) return false;
	g_iPlayerQueuePoints[client] = iAmount;
	ClientSaveCookies(client);
	return true;
}

ClientSaveCookies(client)
{
	if (!IsClientConnected(client) || !AreClientCookiesCached(client)) return;
	
	// Save and reset our queue points.
	decl String:s[64];
	Format(s, sizeof(s), "%d ; %d ; %d ; %d ; %d", g_iPlayerQueuePoints[client], g_bPlayerShowHints[client], g_iPlayerMuteMode[client], g_bPlayerFlashlightProjected[client], g_bPlayerWantsTheP[client]);
	SetClientCookie(client, g_hCookie, s);
}

ClientOnButtonPress(client, button)
{
	switch (button)
	{
		case IN_ATTACK2:
		{
			if (IsPlayerAlive(client))
			{
				if (g_bPlayerGhostMode[client]) ClientGhostModeNextTarget(client);
				else 
				{
					if (!g_bRoundWarmup && 
						!g_bRoundEnded && 
						!g_bPlayerEscaped[client])
					{
						if ((GetGameTime() - g_flPlayerFlashlightLastEnable[client]) >= SF2_FLASHLIGHT_COOLDOWN || 
							g_bPlayerFlashlight[client])
						{
							ClientToggleFlashlight(client);
						}
					}
				}
			}
		}
		case IN_RELOAD:
		{
			if (IsPlayerAlive(client))
			{
				if (!g_bPlayerEliminated[client])
				{
					if (!g_bRoundEnded && 
					!g_bRoundWarmup &&
					!g_bPlayerEscaped[client])
					{
						ClientBlink(client);
					}
				}
			}
		}
		case IN_JUMP:
		{
			if (IsPlayerAlive(client))
			{
				if (!g_bPlayerEliminated[client])
				{
					if (!g_bRoundEnded && 
					!g_bRoundWarmup &&
					!g_bPlayerEscaped[client])
					{
						if (!bool:GetEntProp(client, Prop_Send, "m_bDucked") && 
							(GetEntityFlags(client) & FL_ONGROUND) &&
							GetEntProp(client, Prop_Send, "m_nWaterLevel") < 2)
						{
							g_iPlayerSprintPoints[client] -= 7;
							if (g_iPlayerSprintPoints[client] < 0) g_iPlayerSprintPoints[client] = 0;
							
						}
					}
				}
			}
		}
	}
}

/*
ClientOnButtonRelease(client, button)
{
}
*/


ClientResetDeathCam(client)
{
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("START ClientResetDeathCam(%d)", client);
#endif

	new bool:bOld = g_bPlayerDeathCam[client];
	new iOldBoss = g_iPlayerDeathCamBoss[client];
	
	g_iPlayerDeathCamBoss[client] = -1;
	g_bPlayerDeathCam[client] = false;
	g_bPlayerDeathCamShowOverlay[client] = false;
	g_hPlayerDeathCamTimer[client] = INVALID_HANDLE;
	
	if (IsClientInGame(client))
	{
		SetClientViewEntity(client, client);
	}
	
	new ent = EntRefToEntIndex(g_iPlayerDeathCamEnt[client]);
	g_iPlayerDeathCamEnt[client] = INVALID_ENT_REFERENCE;
	if (ent && ent != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(ent, "Disable");
		AcceptEntityInput(ent, "Kill");
	}
	
	ent = EntRefToEntIndex(g_iPlayerDeathCamEnt2[client]);
	g_iPlayerDeathCamEnt2[client] = INVALID_ENT_REFERENCE;
	if (ent && ent != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(ent, "Kill");
	}
	
	if (bOld && iOldBoss != -1)
	{
		Call_StartForward(fOnClientEndDeathCam);
		Call_PushCell(client);
		Call_PushCell(iOldBoss);
		Call_Finish();
	}
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("END ClientResetDeathCam(%d)", client);
#endif
}

ClientStartDeathCam(client, iBossIndex, const Float:vecLookPos[3])
{
	decl String:buffer[PLATFORM_MAX_PATH];
	new String:sProfile[SF2_MAX_PROFILE_NAME_LENGTH];
	strcopy(sProfile, sizeof(sProfile), g_strSlenderProfile[iBossIndex]);
	
	if (GetProfileNum(sProfile, "death_cam_play_scare_sound"))
	{
		GetRandomStringFromProfile(sProfile, "sound_scare_player", buffer, sizeof(buffer));
		if (buffer[0]) EmitSoundToClient(client, buffer, _, MUSIC_CHAN, SNDLEVEL_NONE);
	}
	
	GetRandomStringFromProfile(sProfile, "sound_player_death", buffer, sizeof(buffer));
	if (buffer[0]) EmitSoundToClient(client, buffer, _, MUSIC_CHAN, SNDLEVEL_NONE);
	
	GetRandomStringFromProfile(sProfile, "sound_player_death_all", buffer, sizeof(buffer));
	if (buffer[0]) EmitSoundToAll(buffer, _, MUSIC_CHAN, SNDLEVEL_HELICOPTER);
	
	// Call our forward.
	Call_StartForward(fOnClientCaughtByBoss);
	Call_PushCell(client);
	Call_PushCell(iBossIndex);
	Call_Finish();
	
	if (!GetProfileNum(sProfile, "death_cam"))
	{
		SetEntProp(client, Prop_Data, "m_takedamage", 2); // We do this because the point_viewcontrol changes our lifestate.
		
		// TODO: Add more attributes!
		if (SlenderHasAttribute(iBossIndex, "ignite player on death"))
		{
			new Float:flValue = SlenderGetAttributeValue(iBossIndex, "ignite player on death");
			if (flValue > 0.0) TF2_IgnitePlayer(client, client);
		}
		
		SDKHooks_TakeDamage(client, 0, 0, 9001.0, 0x80 | DMG_PREVENT_PHYSICS_FORCE, _, Float:{ 0.0, 0.0, 0.0 });
		return;
	}
	
	ClientResetDeathCam(client);
	
	g_iPlayerDeathCamBoss[client] = iBossIndex;
	g_bPlayerDeathCam[client] = true;
	g_bPlayerDeathCamShowOverlay[client] = false;
	
	decl Float:eyePos[3], Float:eyeAng[3], Float:vecAng[3];
	GetClientEyePosition(client, eyePos);
	GetClientEyeAngles(client, eyeAng);
	SubtractVectors(eyePos, vecLookPos, vecAng);
	GetVectorAngles(vecAng, vecAng);
	vecAng[0] = 0.0;
	vecAng[2] = 0.0;
	
	// Create fake model.
	new slender = SpawnSlenderModel(iBossIndex, vecLookPos);
	TeleportEntity(slender, vecLookPos, vecAng, NULL_VECTOR);
	g_iPlayerDeathCamEnt2[client] = EntIndexToEntRef(slender);
	SDKHook(slender, SDKHook_SetTransmit, Hook_DeathCamSetTransmit);
	
	// Create camera look point.
	decl String:sName[64];
	Format(sName, sizeof(sName), "sf2_boss_%d", EntIndexToEntRef(slender));
	
	decl Float:flOffsetPos[3];
	new target = CreateEntityByName("info_target");
	GetProfileVector(sProfile, "death_cam_pos", flOffsetPos);
	AddVectors(vecLookPos, flOffsetPos, flOffsetPos);
	TeleportEntity(target, flOffsetPos, NULL_VECTOR, NULL_VECTOR);
	DispatchKeyValue(target, "targetname", sName);
	SetVariantString("!activator");
	AcceptEntityInput(target, "SetParent", slender);
	
	// Create the camera itself.
	new camera = CreateEntityByName("point_viewcontrol");
	TeleportEntity(camera, eyePos, eyeAng, NULL_VECTOR);
	DispatchKeyValue(camera, "spawnflags", "12");
	DispatchKeyValue(camera, "target", sName);
	DispatchSpawn(camera);
	AcceptEntityInput(camera, "Enable", client);
	g_iPlayerDeathCamEnt[client] = EntIndexToEntRef(camera);
	
	if (GetProfileNum(sProfile, "death_cam_overlay") && GetProfileFloat(sProfile, "death_cam_time_overlay_start") >= 0.0)
	{
		g_hPlayerDeathCamTimer[client] = CreateTimer(GetProfileFloat(sProfile, "death_cam_time_overlay_start"), Timer_ClientResetDeathCam1, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		g_hPlayerDeathCamTimer[client] = CreateTimer(GetProfileFloat(sProfile, "death_cam_time_death"), Timer_ClientResetDeathCamEnd, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
	
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, Float:{ 0.0, 0.0, 0.0 });
	
	Call_StartForward(fOnClientStartDeathCam);
	Call_PushCell(client);
	Call_PushCell(iBossIndex);
	Call_Finish();
}

public Action:Timer_ClientResetDeathCam1(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client <= 0) return;
	
	if (timer != g_hPlayerDeathCamTimer[client]) return;
	
	g_bPlayerDeathCamShowOverlay[client] = true;
	
	g_hPlayerDeathCamTimer[client] = CreateTimer(GetProfileFloat(g_strSlenderProfile[g_iPlayerDeathCamBoss[client]], "death_cam_time_death"), Timer_ClientResetDeathCamEnd, userid, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_ClientResetDeathCamEnd(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client <= 0) return;
	
	if (timer != g_hPlayerDeathCamTimer[client]) return;
	
	SetEntProp(client, Prop_Data, "m_takedamage", 2); // We do this because the point_viewcontrol entity changes our damage state.
	
	if (SlenderHasAttribute(g_iPlayerDeathCamBoss[client], "ignite player on death"))
	{
		new Float:flValue = SlenderGetAttributeValue(g_iPlayerDeathCamBoss[client], "ignite player on death");
		if (flValue > 0.0) TF2_IgnitePlayer(client, client);
	}
	
	SDKHooks_TakeDamage(client, 0, 0, 9001.0, 0x80 | DMG_PREVENT_PHYSICS_FORCE, _, Float:{ 0.0, 0.0, 0.0 });
	ClientResetDeathCam(client);
}

ClientEnableGhostMode(client)
{
	if (!IsClientInGame(client)) return;
	
	g_bPlayerGhostMode[client] = true;
	
	// Set solid flags.
	new iFlags = GetEntProp(client, Prop_Send, "m_usSolidFlags");
	if (!(iFlags & FSOLID_NOT_SOLID)) iFlags |= FSOLID_NOT_SOLID;
	if (!(iFlags & FSOLID_TRIGGER)) iFlags |= FSOLID_TRIGGER;
	
	SetEntProp(client, Prop_Send, "m_usSolidFlags", iFlags);
	SetEntProp(client, Prop_Data, "m_CollisionGroup", COLLISION_GROUP_DEBRIS);
	
	if (strlen(GHOST_MODEL) > 0)
	{
		SetVariantString(GHOST_MODEL);
		AcceptEntityInput(client, "SetCustomModel");
		SetEntProp(client, Prop_Send, "m_bUseClassAnimations", true);
	}
	
	SetEntityRenderMode(client, RENDER_TRANSCOLOR);
	SetEntityRenderColor(client, 155, 255, 155, 125);
	
	// Remove hats.
	new ent = -1;
	while ((ent = FindEntityByClassname(ent, "tf_wearable")) != -1)
	{
		if (GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity") == client)
		{
			AcceptEntityInput(ent, "Kill");
		}
	}
	
	// Set first observer target.
	ClientGhostModeNextTarget(client);
	ClientActivateUltravision(client);
}

ClientDisableGhostMode(client)
{
	if (!g_bPlayerGhostMode[client]) return;
	
	g_bPlayerGhostMode[client] = false;
	
	if (!IsClientInGame(client)) return;
	
	// Set solid flags.
	new iFlags = GetEntProp(client, Prop_Send, "m_usSolidFlags");
	if (iFlags & FSOLID_NOT_SOLID) iFlags &= ~FSOLID_NOT_SOLID;
	if (iFlags & FSOLID_TRIGGER) iFlags &= ~FSOLID_TRIGGER;
	
	SetEntProp(client, Prop_Send, "m_usSolidFlags", iFlags);
	SetEntProp(client, Prop_Data, "m_CollisionGroup", COLLISION_GROUP_PLAYER);
	
	SetVariantString("");
	AcceptEntityInput(client, "SetCustomModel");
	
	SetEntityRenderMode(client, RENDER_NORMAL);
	SetEntityRenderColor(client, 255, 255, 255, 255);
}

ClientGhostModeNextTarget(client)
{
	new iLastTarget = EntRefToEntIndex(g_iPlayerGhostModeTarget[client]);
	new iNextTarget = -1;
	new iFirstTarget = -1;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && (!g_bPlayerEliminated[i] || g_bPlayerProxy[i]) && !g_bPlayerGhostMode[i] && IsPlayerAlive(i))
		{
			if (iFirstTarget == -1) iFirstTarget = i;
			if (i > iLastTarget) 
			{
				iNextTarget = i;
				break;
			}
		}
	}
	
	new iTarget = -1;
	if (IsValidClient(iNextTarget)) iTarget = iNextTarget;
	else iTarget = iFirstTarget;
	
	if (IsValidClient(iTarget))
	{
		g_iPlayerGhostModeTarget[client] = EntIndexToEntRef(iTarget);
		
		decl Float:flPos[3], Float:flAng[3], Float:flVelocity[3];
		GetClientAbsOrigin(iTarget, flPos);
		GetClientAbsAngles(iTarget, flAng);
		GetEntPropVector(iTarget, Prop_Data, "m_vecAbsVelocity", flVelocity);
		TeleportEntity(client, flPos, flAng, flVelocity);
	}
}

ClientActivateFlashlight(client)
{
	ClientDeactivateFlashlight(client);
	
	new Float:flDrainRate = SF2_FLASHLIGHT_DRAIN_RATE;
	if (TF2_GetPlayerClass(client) == TFClass_Engineer) flDrainRate *= 1.33;
	
	g_bPlayerFlashlight[client] = true;
	g_hPlayerFlashlightTimer[client] = CreateTimer(flDrainRate, Timer_DrainFlashlight, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	new ent = CreateEntityByName("light_dynamic");
	if (ent == -1) return;
	
	decl Float:pos[3];
	GetClientEyePosition(client, pos);
	
	TeleportEntity(ent, pos, NULL_VECTOR, NULL_VECTOR);
	DispatchKeyValue(ent, "targetname", "WUBADUBDUBMOTHERBUCKERS");
	DispatchKeyValue(ent, "rendercolor", "255 255 255");
	SetVariantFloat(SF2_FLASHLIGHT_WIDTH);
	AcceptEntityInput(ent, "spotlight_radius");
	SetVariantFloat(SF2_FLASHLIGHT_LENGTH);
	AcceptEntityInput(ent, "distance");
	SetVariantInt(SF2_FLASHLIGHT_BRIGHTNESS);
	AcceptEntityInput(ent, "brightness");
	
	// Convert WU to inches.
	new Float:cone = 55.0;
	cone *= 0.75;
	
	SetVariantInt(RoundToFloor(cone));
	AcceptEntityInput(ent, "_inner_cone");
	SetVariantInt(RoundToFloor(cone));
	AcceptEntityInput(ent, "_cone");
	DispatchSpawn(ent);
	ActivateEntity(ent);
	SetVariantString("!activator");
	AcceptEntityInput(ent, "SetParent", client);
	AcceptEntityInput(ent, "TurnOn");
	
	g_iPlayerFlashlightEnt[client] = EntIndexToEntRef(ent);
	
	SDKHook(ent, SDKHook_SetTransmit, Hook_FlashlightSetTransmit);
	
	// Create.
	ent = CreateEntityByName("point_spotlight");
	if (ent == -1) return;
	
	TeleportEntity(ent, pos, NULL_VECTOR, NULL_VECTOR);
	
	decl String:sBuffer[256];
	FloatToString(SF2_FLASHLIGHT_LENGTH, sBuffer, sizeof(sBuffer));
	DispatchKeyValue(ent, "spotlightlength", sBuffer);
	FloatToString(SF2_FLASHLIGHT_WIDTH, sBuffer, sizeof(sBuffer));
	DispatchKeyValue(ent, "spotlightwidth", sBuffer);
	DispatchKeyValue(ent, "rendercolor", "255 255 255");
	DispatchSpawn(ent);
	ActivateEntity(ent);
	SetVariantString("!activator");
	AcceptEntityInput(ent, "SetParent", client);
	AcceptEntityInput(ent, "LightOn");
	
	g_iPlayerFlashlightEntAng[client] = EntIndexToEntRef(ent);
	
	ClientDeactivateUltravision(client);
	
	Call_StartForward(fOnClientActivateFlashlight);
	Call_PushCell(client);
	Call_Finish();
}

ClientDeactivateFlashlight(client)
{
	new bool:bOld = g_bPlayerFlashlight[client];
	g_bPlayerFlashlight[client] = false;
	
	new ent = EntRefToEntIndex(g_iPlayerFlashlightEnt[client]);
	g_iPlayerFlashlightEnt[client] = INVALID_ENT_REFERENCE;
	if (ent != INVALID_ENT_REFERENCE) 
	{
		AcceptEntityInput(ent, "TurnOff");
		AcceptEntityInput(ent, "Kill");
	}
	
	ent = EntRefToEntIndex(g_iPlayerFlashlightEntAng[client]);
	if (ent && ent != INVALID_ENT_REFERENCE) 
	{
		AcceptEntityInput(ent, "LightOff");
		CreateTimer(0.1, Timer_KillEntity, g_iPlayerFlashlightEntAng[client], TIMER_FLAG_NO_MAPCHANGE);
	}
	
	g_iPlayerFlashlightEntAng[client] = INVALID_ENT_REFERENCE;
	
	if (IsClientInGame(client))
	{
		g_hPlayerFlashlightTimer[client] = CreateTimer(SF2_FLASHLIGHT_RECHARGE_RATE, Timer_RechargeFlashlight, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		g_hPlayerFlashlightTimer[client] = INVALID_HANDLE;
	}
	
	//ClientFlashlightTurnOff(client);
	ClientActivateUltravision(client);
	
	if (bOld && !g_bPlayerFlashlight[client])
	{
		Call_StartForward(fOnClientDeactivateFlashlight);
		Call_PushCell(client);
		Call_Finish();
	}
}

ClientToggleFlashlight(client)
{
	if (!IsClientInGame(client) || !IsPlayerAlive(client)) return;
	
	if (g_bPlayerFlashlight[client]) 
	{
		ClientDeactivateFlashlight(client);
		EmitSoundToAll(FLASHLIGHT_CLICKSOUND, client, SNDCHAN_STATIC, SNDLEVEL_DRYER);
		g_flPlayerFlashlightLastEnable[client] = GetGameTime();
	}
	else if (!g_bPlayerEliminated[client])
	{
		new bool:bCanUseFlashlight = true;
		if (g_bSpecialRound && g_iSpecialRound == SPECIALROUND_LIGHTSOUT) bCanUseFlashlight = false;
	
		if ((!g_bPlayerFlashlightBroken[client] || 
			g_flPlayerFlashlightMeter[client] >= SF2_FLASHLIGHT_ENABLEAT) &&
			bCanUseFlashlight)
		{
			ClientActivateFlashlight(client);
			EmitSoundToAll(FLASHLIGHT_CLICKSOUND, client, SNDCHAN_STATIC, SNDLEVEL_DRYER);
			g_flPlayerFlashlightLastEnable[client] = GetGameTime();
		}
		else
		{
			EmitSoundToClient(client, FLASHLIGHT_NOSOUND, _, SNDCHAN_ITEM, SNDLEVEL_NONE);
		}
	}
}

public Action:Hook_FlashlightSetTransmit(ent, other)
{
	if (!g_bEnabled) return Plugin_Continue;
	
	if (EntRefToEntIndex(g_iPlayerFlashlightEnt[other]) != ent) return Plugin_Handled;
	
	// We've already checked for flashlight ownership in the last statement. So we can do just this.
	if (g_bPlayerFlashlightProjected[other]) return Plugin_Handled;
	
	return Plugin_Continue;
}

public Action:Hook_Flashlight2SetTransmit(ent, other)
{
	if (!g_bEnabled) return Plugin_Continue;

	if (EntRefToEntIndex(g_iPlayerFlashlightEntAng[other]) == ent) return Plugin_Handled;
	return Plugin_Continue;
}

public Action:Timer_DrainFlashlight(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client <= 0) return Plugin_Stop;
	
	if (timer != g_hPlayerFlashlightTimer[client]) return Plugin_Stop;
	
	if (!g_bRoundInfiniteFlashlight) g_flPlayerFlashlightMeter[client] -= 0.01;
	
	if (g_flPlayerFlashlightMeter[client] <= 0.0)
	{
		g_flPlayerFlashlightMeter[client] = 0.0;
		g_bPlayerFlashlightBroken[client] = true;
		EmitSoundToAll(FLASHLIGHT_BREAKSOUND, client, SNDCHAN_STATIC, SNDLEVEL_DRYER);
		ClientDeactivateFlashlight(client);
		
		Call_StartForward(fOnClientBreakFlashlight);
		Call_PushCell(client);
		Call_Finish();
	}
	
	return Plugin_Continue;
}

public Action:Timer_RechargeFlashlight(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client <= 0) return Plugin_Stop;
	
	if (timer != g_hPlayerFlashlightTimer[client]) return Plugin_Stop;
	
	g_flPlayerFlashlightMeter[client] += 0.01;
	
	if (g_bPlayerFlashlightBroken[client] && g_flPlayerFlashlightMeter[client] >= SF2_FLASHLIGHT_ENABLEAT)
	{
		g_bPlayerFlashlightBroken[client] = false;
	}
	
	if (g_flPlayerFlashlightMeter[client] >= 1.0)
	{
		g_flPlayerFlashlightMeter[client] = 1.0;
		g_hPlayerFlashlightTimer[client] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

ClientActivateUltravision(client)
{
	ClientDeactivateUltravision(client);
	
	if (!IsClientInGame(client) || (g_bPlayerEliminated[client] && !g_bPlayerGhostMode[client] && !g_bPlayerProxy[client])) return;
	
	new ent = CreateEntityByName("light_dynamic");
	if (ent == -1) return;
	
	decl Float:flPos[3];
	GetClientEyePosition(client, flPos);
	
	TeleportEntity(ent, flPos, Float:{ 90.0, 0.0, 0.0 }, NULL_VECTOR);
	DispatchKeyValue(ent, "rendercolor", "0 200 255");
	
	if (g_bPlayerGhostMode[client] || g_bPlayerProxy[client]) SetVariantFloat(SF2_ULTRAVISION_WIDTH * 2.0);
	else SetVariantFloat(SF2_ULTRAVISION_WIDTH);
	AcceptEntityInput(ent, "spotlight_radius");
	
	SetVariantFloat(SF2_ULTRAVISION_LENGTH);
	AcceptEntityInput(ent, "distance");
	SetVariantInt(-10); // Start dark, then fade in via timer.
	AcceptEntityInput(ent, "brightness");
	
	// Convert WU to inches.
	new Float:cone = SF2_ULTRAVISION_CONE;
	cone *= 0.75;
	
	SetVariantInt(RoundToFloor(cone));
	AcceptEntityInput(ent, "_inner_cone");
	SetVariantInt(RoundToFloor(cone));
	AcceptEntityInput(ent, "_cone");
	DispatchSpawn(ent);
	ActivateEntity(ent);
	SetVariantString("!activator");
	AcceptEntityInput(ent, "SetParent", client);
	AcceptEntityInput(ent, "TurnOn");
	SetEntityRenderFx(ent, RENDERFX_SOLID_SLOW);
	SetEntityRenderColor(ent, 100, 200, 255, 255);
	g_iPlayerUltravisionEnt[client] = EntIndexToEntRef(ent);
	
	SDKHook(ent, SDKHook_SetTransmit, Hook_UltravisionSetTransmit);
	
	g_bPlayerUltravision[client] = true;
	
	// Fade in effect.
	CreateTimer(0.05, Timer_UltravisionFadeInEffect, g_iPlayerUltravisionEnt[client], TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_UltravisionFadeInEffect(Handle:timer, any:entref)
{
	new ent = EntRefToEntIndex(entref);
	if (!ent || ent == INVALID_ENT_REFERENCE) return Plugin_Stop;
	
	new iBrightness = GetEntProp(ent, Prop_Send, "m_Exponent");
	if (iBrightness >= SF2_ULTRAVISION_BRIGHTNESS) return Plugin_Stop;
	
	iBrightness++;
	SetVariantInt(iBrightness);
	AcceptEntityInput(ent, "brightness");
	
	return Plugin_Continue;
}

ClientDeactivateUltravision(client)
{
	g_bPlayerUltravision[client] = false;
	
	new ent = EntRefToEntIndex(g_iPlayerUltravisionEnt[client]);
	g_iPlayerUltravisionEnt[client] = INVALID_ENT_REFERENCE;
	if (ent != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(ent, "TurnOff");
		AcceptEntityInput(ent, "Kill");
	}
}

public Action:Hook_UltravisionSetTransmit(ent, other)
{
	if (!g_bEnabled) return Plugin_Continue;

	if (!GetConVarBool(g_cvUltravisionEnabled) || EntRefToEntIndex(g_iPlayerUltravisionEnt[other]) != ent || !IsPlayerAlive(other)) return Plugin_Handled;
	return Plugin_Continue;
}

ClientPerformScare(client, iBossIndex)
{
	g_flPlayerLastScareFromBoss[client][iBossIndex] = GetGameTime();
	
	decl String:buffer[PLATFORM_MAX_PATH];
	GetRandomStringFromProfile(g_strSlenderProfile[iBossIndex], "sound_scare_player", buffer, sizeof(buffer));
	if (buffer[0])
	{
		EmitSoundToClient(client, buffer, _, MUSIC_CHAN, SNDLEVEL_NONE);
	}
	
	// Deprecated.
	/*
	if (GetConVarBool(g_cvLegacyMode))
	{
	}
	else
	{
		TF2_AddCondition(client, TFCond_SpeedBuffAlly, 3.0);
	}
	*/
}

ClientResetScare(client)
{
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("START ClientResetScare(%d)", client);
#endif

	for (new i = 0; i < MAX_BOSSES; i++)
	{
		g_flPlayerLastScareFromBoss[client][i] = -1.0;
	}
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("END ClientResetScare(%d)", client);
#endif
}

public Action:Hook_ClientSetTransmit(client, other)
{
	if (!g_bEnabled) return Plugin_Continue;
	
	if (other != client)
	{
		if (g_bPlayerGhostMode[client] && !g_bPlayerGhostMode[other]) return Plugin_Handled;
		
		if (!g_bRoundEnded)
		{
			if (g_bSpecialRound && g_iSpecialRound == SPECIALROUND_SINGLEPLAYER)
			{
				if (!g_bPlayerEliminated[client] && !g_bPlayerEliminated[other] && !g_bPlayerEscaped[other]) return Plugin_Handled; 
			}
			
			if (g_bPlayerInPvP[client] && g_bPlayerInPvP[other]) 
			{
				if (TF2_IsPlayerInCondition(client, TFCond_Cloaked) &&
					!TF2_IsPlayerInCondition(client, TFCond_CloakFlicker) &&
					!TF2_IsPlayerInCondition(client, TFCond_Jarated) &&
					!TF2_IsPlayerInCondition(client, TFCond_Milked) &&
					!TF2_IsPlayerInCondition(client, TFCond_OnFire) &&
					(GetGameTime() > GetEntPropFloat(client, Prop_Send, "m_flInvisChangeCompleteTime")))
				{
					return Plugin_Handled;
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public Action:Hook_DeathCamSetTransmit(slender, other)
{
	if (!g_bEnabled) return Plugin_Continue;

	if (EntRefToEntIndex(g_iPlayerDeathCamEnt2[other]) != slender) return Plugin_Handled;
	return Plugin_Continue;
}

stock ClientResetCampingStats(client)
{
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("START ClientResetCampingStats(%d)", client);
#endif

	g_iPlayerCampingStrikes[client] = 0;
	g_hPlayerCampingTimer[client] = INVALID_HANDLE;
	g_bPlayerCampingFirstTime[client] = true;
	g_flPlayerCampingLastPosition[client][0] = 0.0;
	g_flPlayerCampingLastPosition[client][1] = 0.0;
	g_flPlayerCampingLastPosition[client][2] = 0.0;
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("END ClientResetCampingStats(%d)", client);
#endif
}

stock bool:IsClientInPvP(client)
{
	return g_bPlayerInPvP[client];
}

stock ClientEnablePvP(client)
{
	if (!IsValidClient(client)) return;
	
	new bool:bWasInPvP = g_bPlayerInPvP[client];
	g_bPlayerInPvP[client] = true;
	g_hPlayerPvPTimer[client] = INVALID_HANDLE;
	g_iPlayerPvPTimerCount[client] = 0;
	
	if (!bWasInPvP)
	{
		ClientRemoveAllProjectiles(client);
		
		new iHealth = GetEntProp(client, Prop_Send, "m_iHealth");
		TF2_RegeneratePlayer(client);
		SetEntProp(client, Prop_Data, "m_iHealth", iHealth);
		SetEntProp(client, Prop_Send, "m_iHealth", iHealth);
		
		SDKHook(client, SDKHook_ShouldCollide, Hook_ClientPvPShouldCollide);
	}
}

/*
public Action:Hook_PlayerResourceClientTeamNum(entity, const String:PropName[], &iValue, element)
{
	if (!g_bEnabled) return Plugin_Continue;
	
	if (IsValidClient(entity) && IsClientInPvP(entity))
	{
		iValue = 0;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}
*/

stock ClientDisablePvP(client)
{
	new bool:bWasInPvP = g_bPlayerInPvP[client];
	
	if (bWasInPvP)
	{
		if (IsValidClient(client))
		{
			ClientRemoveAllProjectiles(client);
			
			TF2_RemoveCondition(client, TFCond_Zoomed);
			
			new iHealth = GetEntProp(client, Prop_Send, "m_iHealth");
			TF2_RegeneratePlayer(client);
			SetEntProp(client, Prop_Data, "m_iHealth", iHealth);
			SetEntProp(client, Prop_Send, "m_iHealth", iHealth);
			
			SDKUnhook(client, SDKHook_ShouldCollide, Hook_ClientPvPShouldCollide);
		}
	}
	
	g_bPlayerInPvP[client] = false;
	g_hPlayerPvPTimer[client] = INVALID_HANDLE;
	g_iPlayerPvPTimerCount[client] = 0;
}

stock ClientResetPvP(client)
{
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("START ClientResetPvP(%d)", client);
#endif

	ClientDisablePvP(client);
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("END ClientResetPvP(%d)", client);
#endif
}

public Action:Timer_ClientDisablePvP(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client <= 0) return Plugin_Stop;
	
	if (timer != g_hPlayerPvPTimer[client]) return Plugin_Stop;
	
	if (!IsClientInPvP(client)) return Plugin_Stop;
	
	if (g_iPlayerPvPTimerCount[client] <= 0)
	{
		ClientDisablePvP(client);
		return Plugin_Stop;
	}
	
	g_iPlayerPvPTimerCount[client]--;
	
	if (!g_bPlayerProxyAvailableInForce[client])
	{
		SetHudTextParams(-1.0, 0.75, 
			1.0,
			255, 255, 255, 255,
			_,
			_,
			0.25, 1.25);
		
		ShowSyncHudText(client, g_hHudSync, "%T", "SF2 Exiting PvP Arena", client, g_iPlayerPvPTimerCount[client]);
	}
	
	return Plugin_Continue;
}

stock ClientRemoveAllProjectiles(client)
{
	for (new i = 0; i < sizeof(g_sPlayerProjectileClasses); i++)
	{
		new ent = -1;
		while ((ent = FindEntityByClassname(ent, g_sPlayerProjectileClasses[i])) != -1)
		{
			new iThrowerOffset = FindDataMapOffs(ent, "m_hThrower");
			new bool:bMine = false;
		
			new iOwnerEntity = GetEntPropEnt(ent, Prop_Data, "m_hOwnerEntity");
			if (iOwnerEntity == client)
			{
				bMine = true;
			}
			else if (iThrowerOffset != -1)
			{
				iOwnerEntity = GetEntDataEnt2(ent, iThrowerOffset);
				if (iOwnerEntity == client)
				{
					bMine = true;
				}
			}
			
			if (bMine) AcceptEntityInput(ent, "Kill");
		}
	}
}

public Action:Timer_ClientCheckCamp(Handle:timer, any:userid)
{
	if (g_bRoundWarmup) return Plugin_Stop;

	new client = GetClientOfUserId(userid);
	if (client <= 0) return Plugin_Stop;
	
	if (timer != g_hPlayerCampingTimer[client]) return Plugin_Stop;
	
	if (g_bRoundEnded || !IsPlayerAlive(client) || g_bPlayerEliminated[client] || g_bPlayerEscaped[client]) return Plugin_Stop;
	
	if (!g_bPlayerCampingFirstTime[client])
	{
		decl Float:flPos[3], Float:flMaxs[3], Float:flMins[3];
		GetClientAbsOrigin(client, flPos);
		GetEntPropVector(client, Prop_Send, "m_vecMins", flMins);
		GetEntPropVector(client, Prop_Send, "m_vecMaxs", flMaxs);
		
		// Only do something if the player is NOT stuck.
		new Float:flDistFromLastPosition = GetVectorDistance(g_flPlayerCampingLastPosition[client], flPos);
		new Float:flDistFromClosestBoss = 9999999.0;
		
		for (new i = 0; i < MAX_BOSSES; i++)
		{
			new iSlender = EntRefToEntIndex(g_iSlender[i]);
			if (!iSlender || iSlender == INVALID_ENT_REFERENCE) continue;
			
			decl Float:flSlenderPos[3];
			SlenderGetAbsOrigin(i, flSlenderPos);
			
			new Float:flDist = GetVectorDistance(flSlenderPos, flPos);
			if (flDist < flDistFromClosestBoss)
			{
				flDistFromClosestBoss = flDist;
			}
		}
		
		if (GetConVarBool(g_cvCampingEnabled) && 
			!g_bRoundGrace && 
			!IsSpaceOccupied(flPos, flMins, flMaxs, client) && 
			g_flPlayerSeesSlenderMeter[client] <= GetConVarFloat(g_cvCampingNoStrikeSanity) && 
			flDistFromClosestBoss >= GetConVarFloat(g_cvCampingNoStrikeBossDistance) &&
			flDistFromLastPosition <= GetConVarFloat(g_cvCampingMinDistance))
		{
			g_iPlayerCampingStrikes[client]++;
			if (g_iPlayerCampingStrikes[client] < GetConVarInt(g_cvCampingMaxStrikes))
			{
				if (g_iPlayerCampingStrikes[client] >= GetConVarInt(g_cvCampingStrikesWarn))
				{
					CPrintToChat(client, "{red}%T", "SF2 Camping System Warning", client, (GetConVarInt(g_cvCampingMaxStrikes) - g_iPlayerCampingStrikes[client]) * 5);
				}
			}
			else
			{
				g_iPlayerCampingStrikes[client] = 0;
				ClientStartDeathCam(client, 0, flPos);
			}
		}
		else
		{
			// Forgiveness.
			if (g_iPlayerCampingStrikes[client] > 0) g_iPlayerCampingStrikes[client]--;
		}
		
		g_flPlayerCampingLastPosition[client][0] = flPos[0];
		g_flPlayerCampingLastPosition[client][1] = flPos[1];
		g_flPlayerCampingLastPosition[client][2] = flPos[2];
	}
	else
	{
		g_bPlayerCampingFirstTime[client] = false;
	}
	
	return Plugin_Continue;
}

stock ClientResetFlashlight(client)
{
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("START ClientResetFlashlight(%d)", client);
#endif

	ClientDeactivateFlashlight(client);
	g_flPlayerFlashlightMeter[client] = 1.0;
	g_bPlayerFlashlightBroken[client] = false;
	g_flPlayerFlashlightLastEnable[client] = GetGameTime();
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("END ClientResetFlashlight(%d)", client);
#endif
}

stock ClientResetUltravision(client)
{
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("START ClientResetUltravision(%d)", client);
#endif

	ClientDeactivateUltravision(client);
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("END ClientResetUltravision(%d)", client);
#endif
}

stock ClientResetBlink(client)
{
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("START ClientResetBlink(%d)", client);
#endif

	g_hPlayerBlinkTimer[client] = INVALID_HANDLE;
	g_bPlayerBlink[client] = false;
	g_flPlayerBlinkMeter[client] = 1.0;
	g_iPlayerBlinkCount[client] = 0;
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("END ClientResetBlink(%d)", client);
#endif
}

stock ClientBlink(client)
{
	if (g_bRoundWarmup || g_bPlayerEscaped[client]) return;

	g_bPlayerBlink[client] = true;
	g_iPlayerBlinkCount[client]++;
	//UTIL_ScreenFade(client, 50, 0, FFADE_OUT | FFADE_STAYOUT, 0, 0, 0, 255);
	UTIL_ScreenFade(client, 100, RoundToFloor(GetConVarFloat(g_cvPlayerBlinkHoldTime) * 1000.0), FFADE_IN, 0, 0, 0, 255);
	g_hPlayerBlinkTimer[client] = CreateTimer(GetConVarFloat(g_cvPlayerBlinkHoldTime), Timer_BlinkTimer2, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	
	Call_StartForward(fOnClientBlink);
	Call_PushCell(client);
	Call_Finish();
}

public Action:Timer_BlinkTimer(Handle:timer, any:userid)
{
	if (g_bRoundWarmup) return Plugin_Stop;

	new client = GetClientOfUserId(userid);
	if (client <= 0) return Plugin_Stop;
	
	if (timer != g_hPlayerBlinkTimer[client]) return Plugin_Stop;
	
	if (IsPlayerAlive(client) && !g_bPlayerDeathCam[client] && !g_bPlayerEliminated[client] && !g_bPlayerGhostMode[client] && !g_bRoundEnded)
	{
		if (!g_bRoundInfiniteBlink) g_flPlayerBlinkMeter[client] -= 0.05;
		
		if (g_flPlayerBlinkMeter[client] <= 0.0)
		{
			ClientBlink(client);
			return Plugin_Stop;
		}
		else
		{
			g_hPlayerBlinkTimer[client] = CreateTimer(GetClientBlinkRate(client), Timer_BlinkTimer, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
			return Plugin_Stop;
		}
	}
	
	return Plugin_Continue;
}

public Action:Timer_BlinkTimer2(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client <= 0) return;
	
	if (timer != g_hPlayerBlinkTimer[client]) return;
	
	ClientResetBlink(client);
	g_hPlayerBlinkTimer[client] = CreateTimer(GetClientBlinkRate(client), Timer_BlinkTimer, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

stock ClientResetSlenderStats(client)
{
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("START ClientResetSlenderStats(%d)", client);
#endif

	g_iPlayerStaticMaster[client] = -1;
	g_flPlayerSeesSlenderMeter[client] = 0.0;
	
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		g_bPlayerSeesSlender[client][i] = false;
		g_flPlayerSeesSlenderLastTime[client][i] = -1.0;
		g_flPlayerSeesSlenderLastTime2[client][i] = -1.0;
		g_hPlayerStaticTimer[client][i] = INVALID_HANDLE;
		g_flPlayerStaticLastMeter[client][i] = 0.0;
		g_flPlayerStaticLastTime[client][i] = -1.0;
	}
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("END ClientResetSlenderStats(%d)", client);
#endif
}

stock ClientResetOverlay(client)
{
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("START ClientResetOverlay(%d)", client);
#endif

	g_hPlayerOverlayCheck[client] = INVALID_HANDLE;
	ClientCommand(client, "r_screenoverlay \"\"");
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("END ClientResetOverlay(%d)", client);
#endif
}

public Action:Timer_PlayerOverlayCheck(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client <= 0) return Plugin_Stop;
	
	if (timer != g_hPlayerOverlayCheck[client]) return Plugin_Stop;
	
	decl String:sMaterial[PLATFORM_MAX_PATH];
	if (g_iPlayerDeathCamBoss[client] != -1 && g_bPlayerDeathCamShowOverlay[client])
	{
		GetRandomStringFromProfile(g_strSlenderProfile[g_iPlayerDeathCamBoss[client]], "overlay_player_death", sMaterial, sizeof(sMaterial), 1);
	}
	else if (g_iPlayerJumpScareMaster[client] != -1 && GetGameTime() <= g_flPlayerJumpScareLifeTime[client])
	{
		GetRandomStringFromProfile(g_strSlenderProfile[g_iPlayerJumpScareMaster[client]], "overlay_jumpscare", sMaterial, sizeof(sMaterial), 1);
	}
	else if (g_bRoundWarmup || g_bPlayerEliminated[client] || g_bPlayerEscaped[client] && !g_bPlayerGhostMode[client])
	{
		//ClientCommand(client, "r_screenoverlay \"\"");
		return Plugin_Continue;
	}
	else
	{
		strcopy(sMaterial, sizeof(sMaterial), BLACK_OVERLAY);
	}
	
	ClientCommand(client, "r_screenoverlay %s", sMaterial);
	return Plugin_Continue;
}

// This could be used for entities as well.
stock ClientStopAllSlenderSounds(client, const String:profileName[], const String:sectionName[], iChannel)
{
	if (!client || !IsValidEntity(client)) return;
	if (g_hConfig == INVALID_HANDLE) return;
	
	decl String:buffer[PLATFORM_MAX_PATH];
	
	KvRewind(g_hConfig);
	if (KvJumpToKey(g_hConfig, profileName))
	{
		decl String:s[32];
		
		if (KvJumpToKey(g_hConfig, sectionName))
		{
			for (new i2 = 1;; i2++)
			{
				IntToString(i2, s, sizeof(s));
				KvGetString(g_hConfig, s, buffer, sizeof(buffer));
				if (!buffer[0]) break;
				
				StopSound(client, iChannel, buffer);
			}
		}
	}
}

stock ClientUpdateMusicSystem(client, bool:bInitialize=false)
{
	new iOldPageMusicMaster = EntRefToEntIndex(g_iPlayerPageMusicMaster[client]);
	new iOldMusicFlags = g_iPlayerMusicFlags[client];
	new iChasingBoss = -1;
	new iChasingSeeBoss = -1;
	
	if (g_bRoundEnded || !IsClientInGame(client) || IsFakeClient(client) || g_bPlayerEscaped[client] || (g_bPlayerEliminated[client] && !g_bPlayerGhostMode[client] && !g_bPlayerProxy[client])) 
	{
		g_iPlayerMusicFlags[client] = 0;
		g_iPlayerPageMusicMaster[client] = INVALID_ENT_REFERENCE;
	}
	else
	{
		new bool:bPlayMusicOnEscape = true;
		decl String:sName[64];
		new ent = -1;
		while ((ent = FindEntityByClassname(ent, "info_target")) != -1)
		{
			GetEntPropString(ent, Prop_Data, "m_iName", sName, sizeof(sName));
			if (StrEqual(sName, "sf2_escape_custommusic", false) ||
				StrEqual(sName, "slender_logic_escape_music", false))
			{
				bPlayMusicOnEscape = false;
				break;
			}
		}
		
		// Page music first.
		new iPageRange = 0;
		
		if (GetArraySize(g_hPageMusicRanges) > 0) // Map has its own defined page music?
		{
			for (new i = 0, iSize = GetArraySize(g_hPageMusicRanges); i < iSize; i++)
			{
				ent = EntRefToEntIndex(GetArrayCell(g_hPageMusicRanges, i));
				if (!ent || ent == INVALID_ENT_REFERENCE) continue;
				
				new iMin = GetArrayCell(g_hPageMusicRanges, i, 1);
				new iMax = GetArrayCell(g_hPageMusicRanges, i, 2);
				
				if (g_iPageCount >= iMin && g_iPageCount <= iMax)
				{
					g_iPlayerPageMusicMaster[client] = GetArrayCell(g_hPageMusicRanges, i);
					break;
				}
			}
		}
		else // Nope. Use old system instead.
		{
			g_iPlayerPageMusicMaster[client] = INVALID_ENT_REFERENCE;
		
			new Float:flPercent = g_iPageMax > 0 ? (float(g_iPageCount) / float(g_iPageMax)) : 0.0;
			if (flPercent > 0.0 && flPercent <= 0.25) iPageRange = 1;
			else if (flPercent > 0.25 && flPercent <= 0.5) iPageRange = 2;
			else if (flPercent > 0.5 && flPercent <= 0.75) iPageRange = 3;
			else if (flPercent > 0.75) iPageRange = 4;
			
			if (iPageRange == 1) ClientAddMusicFlag(client, MUSICF_PAGES1PERCENT);
			else if (iPageRange == 2) ClientAddMusicFlag(client, MUSICF_PAGES25PERCENT);
			else if (iPageRange == 3) ClientAddMusicFlag(client, MUSICF_PAGES50PERCENT);
			else if (iPageRange == 4) ClientAddMusicFlag(client, MUSICF_PAGES75PERCENT);
		}
		
		if (iPageRange != 1) ClientRemoveMusicFlag(client, MUSICF_PAGES1PERCENT);
		if (iPageRange != 2) ClientRemoveMusicFlag(client, MUSICF_PAGES25PERCENT);
		if (iPageRange != 3) ClientRemoveMusicFlag(client, MUSICF_PAGES50PERCENT);
		if (iPageRange != 4) ClientRemoveMusicFlag(client, MUSICF_PAGES75PERCENT);
		else if (g_iPageCount == g_iPageMax && g_bRoundMustEscape && !bPlayMusicOnEscape) ClientRemoveMusicFlag(client, MUSICF_PAGES75PERCENT);
		
		// Holy crap, are we getting chased by something? Let's check.
		new iOldChasingBoss = g_iPlayerChaseMusicMaster[client];
		new iOldChasingSeeBoss = g_iPlayerChaseMusicSeeMaster[client];
		new Float:flAnger = -1.0;
		new Float:flSeeAnger = -1.0;
		
		decl Float:flBuffer[3], Float:flBuffer2[3], Float:flBuffer3[3];
		for (new i = 0; i < MAX_BOSSES; i++)
		{
			if (!g_strSlenderProfile[i][0]) continue;
			if (g_iSlenderType[i] != 2) continue;
			if (SlenderArrayIndexToEntIndex(i) == INVALID_ENT_REFERENCE) continue;
			
			new iTarget = EntRefToEntIndex(g_iSlenderTarget[i]);
			if (iTarget != -1)
			{
				GetClientAbsOrigin(client, flBuffer);
				GetEntPropVector(iTarget, Prop_Data, "m_vecAbsOrigin", flBuffer2);
				SlenderGetAbsOrigin(i, flBuffer3);
				
				if ((g_iSlenderState[i] == STATE_CHASE || g_iSlenderState[i] == STATE_ATTACK || g_iSlenderState[i] == STATE_STUN) && !(g_iSlenderFlags[i] & SFF_MARKEDASFAKE) && (iTarget == client || GetVectorDistance(flBuffer, flBuffer2) <= 850.0 || GetVectorDistance(flBuffer, flBuffer3) <= 512.0))
				{
					if (g_flSlenderAnger[i] > flAnger)
					{
						flAnger = g_flSlenderAnger[i];
						iChasingBoss = i;
					}
					
					if ((g_iSlenderState[i] == STATE_CHASE || g_iSlenderState[i] == STATE_ATTACK) &&
						PlayerCanSeeSlender(client, i, false))
					{
						if (iOldChasingSeeBoss == -1 || !PlayerCanSeeSlender(client, iOldChasingSeeBoss, false) || (g_flSlenderAnger[i] > flSeeAnger))
						{
							flSeeAnger = g_flSlenderAnger[i];
							iChasingSeeBoss = i;
						}
					}
				}
			}
		}
		
		if (iChasingBoss != iOldChasingBoss)
		{
			if (iChasingBoss != -1)
			{
				ClientAddMusicFlag(client, MUSICF_CHASE);
			}
			else
			{
				ClientRemoveMusicFlag(client, MUSICF_CHASE);
			}
		}
		
		if (iChasingSeeBoss != iOldChasingSeeBoss)
		{
			if (iChasingSeeBoss != -1)
			{
				ClientAddMusicFlag(client, MUSICF_CHASEVISIBLE);
			}
			else
			{
				ClientRemoveMusicFlag(client, MUSICF_CHASEVISIBLE);
			}
		}
	}
	
	if (IsValidClient(client))
	{
		new bool:bWasChase = ClientHasMusicFlag2(iOldMusicFlags, MUSICF_CHASE);
		new bool:bChase = ClientHasMusicFlag(client, MUSICF_CHASE);
		new bool:bWasChaseSee = ClientHasMusicFlag2(iOldMusicFlags, MUSICF_CHASEVISIBLE);
		new bool:bChaseSee = ClientHasMusicFlag(client, MUSICF_CHASEVISIBLE);
		
		// Custom system.
		if (GetArraySize(g_hPageMusicRanges) > 0) 
		{
			decl String:sPath[PLATFORM_MAX_PATH];
		
			new iMaster = EntRefToEntIndex(g_iPlayerPageMusicMaster[client]);
			if (iMaster != INVALID_ENT_REFERENCE)
			{
				for (new i = 0, iSize = GetArraySize(g_hPageMusicRanges); i < iSize; i++)
				{
					new ent = EntRefToEntIndex(GetArrayCell(g_hPageMusicRanges, i));
					if (!ent || ent == INVALID_ENT_REFERENCE) continue;
					
					GetEntPropString(ent, Prop_Data, "m_iszSound", sPath, sizeof(sPath));
					
					if (ent == iMaster && 
						(iOldPageMusicMaster != iMaster || iOldPageMusicMaster == INVALID_ENT_REFERENCE))
					{
						if (!sPath[0])
						{
							LogError("Could not play music of page range %d-%d: no sound path specified!", GetArrayCell(g_hPageMusicRanges, i, 1), GetArrayCell(g_hPageMusicRanges, i, 2));
						}
						else
						{
							ClientMusicStart(client, sPath, _, MUSIC_PAGE_VOLUME, bChase);
						}
						
						if (iOldPageMusicMaster && iOldPageMusicMaster != INVALID_ENT_REFERENCE)
						{
							GetEntPropString(iOldPageMusicMaster, Prop_Data, "m_iszSound", sPath, sizeof(sPath));
							if (sPath[0])
							{
								StopSound(client, MUSIC_CHAN, sPath);
							}
						}
					}
				}
			}
			else
			{
				if (iOldPageMusicMaster && iOldPageMusicMaster != INVALID_ENT_REFERENCE)
				{
					GetEntPropString(iOldPageMusicMaster, Prop_Data, "m_iszSound", sPath, sizeof(sPath));
					if (sPath[0])
					{
						StopSound(client, MUSIC_CHAN, sPath);
					}
				}
			}
		}
		
		// Old system.
		if ((bInitialize || ClientHasMusicFlag2(iOldMusicFlags, MUSICF_PAGES1PERCENT)) && !ClientHasMusicFlag(client, MUSICF_PAGES1PERCENT))
		{
			StopSound(client, MUSIC_CHAN, MUSIC_GOTPAGES1_SOUND);
		}
		else if ((bInitialize || !ClientHasMusicFlag2(iOldMusicFlags, MUSICF_PAGES1PERCENT)) && ClientHasMusicFlag(client, MUSICF_PAGES1PERCENT))
		{
			ClientMusicStart(client, MUSIC_GOTPAGES1_SOUND, _, MUSIC_PAGE_VOLUME, bChase);
		}
		
		if ((bInitialize || ClientHasMusicFlag2(iOldMusicFlags, MUSICF_PAGES25PERCENT)) && !ClientHasMusicFlag(client, MUSICF_PAGES25PERCENT))
		{
			StopSound(client, MUSIC_CHAN, MUSIC_GOTPAGES2_SOUND);
		}
		else if ((bInitialize || !ClientHasMusicFlag2(iOldMusicFlags, MUSICF_PAGES25PERCENT)) && ClientHasMusicFlag(client, MUSICF_PAGES25PERCENT))
		{
			ClientMusicStart(client, MUSIC_GOTPAGES2_SOUND, _, MUSIC_PAGE_VOLUME, bChase);
		}
		
		if ((bInitialize || ClientHasMusicFlag2(iOldMusicFlags, MUSICF_PAGES50PERCENT)) && !ClientHasMusicFlag(client, MUSICF_PAGES50PERCENT))
		{
			StopSound(client, MUSIC_CHAN, MUSIC_GOTPAGES3_SOUND);
		}
		else if ((bInitialize || !ClientHasMusicFlag2(iOldMusicFlags, MUSICF_PAGES50PERCENT)) && ClientHasMusicFlag(client, MUSICF_PAGES50PERCENT))
		{
			ClientMusicStart(client, MUSIC_GOTPAGES3_SOUND, _, MUSIC_PAGE_VOLUME, bChase);
		}
		
		if ((bInitialize || ClientHasMusicFlag2(iOldMusicFlags, MUSICF_PAGES75PERCENT)) && !ClientHasMusicFlag(client, MUSICF_PAGES75PERCENT))
		{
			StopSound(client, MUSIC_CHAN, MUSIC_GOTPAGES4_SOUND);
		}
		else if ((bInitialize || !ClientHasMusicFlag2(iOldMusicFlags, MUSICF_PAGES75PERCENT)) && ClientHasMusicFlag(client, MUSICF_PAGES75PERCENT))
		{
			ClientMusicStart(client, MUSIC_GOTPAGES4_SOUND, _, MUSIC_PAGE_VOLUME, bChase);
		}
		
		if (bChase != bWasChase || iChasingBoss != g_iPlayerChaseMusicMaster[client])
		{
			if (bChase)
			{
				ClientMusicChaseStart(client, iChasingBoss);
				if (!bWasChase) ClientMusicStop(client);
			}
			else
			{
				ClientMusicChaseStop(client, g_iPlayerChaseMusicMaster[client]);
				if (bWasChase) ClientMusicStart(client, g_strPlayerMusic[client]);
			}
		}
		
		if (bChaseSee != bWasChaseSee || iChasingSeeBoss != g_iPlayerChaseMusicSeeMaster[client])
		{
			if (bChaseSee)
			{
				ClientMusicChaseSeeStart(client, iChasingSeeBoss);
			}
			else
			{
				ClientMusicChaseSeeStop(client, g_iPlayerChaseMusicSeeMaster[client]);
			}
		}
	}
}

stock ClientMusicReset(client)
{
	new String:sOldMusic[PLATFORM_MAX_PATH];
	strcopy(sOldMusic, sizeof(sOldMusic), g_strPlayerMusic[client]);
	strcopy(g_strPlayerMusic[client], sizeof(g_strPlayerMusic[]), "");
	if (IsClientInGame(client) && sOldMusic[0]) StopSound(client, MUSIC_CHAN, sOldMusic);
	
	g_iPlayerMusicFlags[client] = 0;
	g_flPlayerMusicVolume[client] = 0.0;
	g_flPlayerMusicTargetVolume[client] = 0.0;
	g_hPlayerMusicTimer[client] = INVALID_HANDLE;
	g_iPlayerPageMusicMaster[client] = INVALID_ENT_REFERENCE;
}

stock ClientMusicStart(client, const String:sNewMusic[], Float:flVolume=-1.0, Float:flTargetVolume=-1.0, bool:bCopyOnly=false)
{
	if (!IsClientInGame(client)) return;
	if (!sNewMusic[0]) return;
	
	new String:sOldMusic[PLATFORM_MAX_PATH];
	strcopy(sOldMusic, sizeof(sOldMusic), g_strPlayerMusic[client]);
	
	if (!StrEqual(sOldMusic, sNewMusic, false))
	{
		if (sOldMusic[0]) StopSound(client, MUSIC_CHAN, sOldMusic);
	}
	
	strcopy(g_strPlayerMusic[client], sizeof(g_strPlayerMusic[]), sNewMusic);
	if (flVolume >= 0.0) g_flPlayerMusicVolume[client] = flVolume;
	if (flTargetVolume >= 0.0) g_flPlayerMusicTargetVolume[client] = flTargetVolume;
	
	if (!bCopyOnly)
	{
		g_hPlayerMusicTimer[client] = CreateTimer(0.01, Timer_PlayerFadeInMusic, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		TriggerTimer(g_hPlayerMusicTimer[client], true);
	}
	else
	{
		g_hPlayerMusicTimer[client] = INVALID_HANDLE;
	}
}

stock ClientMusicStop(client)
{
	g_hPlayerMusicTimer[client] = CreateTimer(0.01, Timer_PlayerFadeOutMusic, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	TriggerTimer(g_hPlayerMusicTimer[client], true);
}

stock ClientChaseMusicReset(client)
{
	new String:sOldMusic[PLATFORM_MAX_PATH];
	strcopy(sOldMusic, sizeof(sOldMusic), g_strPlayerChaseMusic[client]);
	strcopy(g_strPlayerChaseMusic[client], sizeof(g_strPlayerChaseMusic[]), "");
	if (IsClientInGame(client) && sOldMusic[0]) StopSound(client, MUSIC_CHAN, sOldMusic);
	
	g_iPlayerChaseMusicMaster[client] = -1;
	
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		g_hPlayerChaseMusicTimer[client][i] = INVALID_HANDLE;
		g_flPlayerChaseMusicVolumes[client][i] = 0.0;
		
		if (g_strSlenderProfile[i][0])
		{
			if (IsClientInGame(client))
			{
				GetRandomStringFromProfile(g_strSlenderProfile[i], "sound_chase", sOldMusic, sizeof(sOldMusic), 1);
				if (sOldMusic[0]) StopSound(client, MUSIC_CHAN, sOldMusic);
			}
		}
	}
}

stock ClientMusicChaseStart(client, iBossIndex)
{
	if (!IsClientInGame(client)) return;
	
	new iOldMaster = g_iPlayerChaseMusicMaster[client];
	if (iOldMaster == iBossIndex) return;
	
	new String:sBuffer[PLATFORM_MAX_PATH];
	GetRandomStringFromProfile(g_strSlenderProfile[iBossIndex], "sound_chase", sBuffer, sizeof(sBuffer), 1);
	if (!sBuffer[0]) return;
	
	g_iPlayerChaseMusicMaster[client] = iBossIndex;
	strcopy(g_strPlayerChaseMusic[client], sizeof(g_strPlayerChaseMusic[]), sBuffer);
	g_hPlayerChaseMusicTimer[client][iBossIndex] = CreateTimer(0.01, Timer_PlayerFadeInChaseMusic, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	TriggerTimer(g_hPlayerChaseMusicTimer[client][iBossIndex], true);
	
	if (iOldMaster != -1)
	{
		ClientMusicChaseStop(client, iOldMaster);
	}
}

stock ClientMusicChaseStop(client, iBossIndex)
{
	if (!IsClientInGame(client)) return;
	if (iBossIndex == -1) return;
	
	if (iBossIndex == g_iPlayerChaseMusicMaster[client])
	{
		g_iPlayerChaseMusicMaster[client] = -1;
		strcopy(g_strPlayerChaseMusic[client], sizeof(g_strPlayerChaseMusic[]), "");
	}
	
	g_hPlayerChaseMusicTimer[client][iBossIndex] = CreateTimer(0.01, Timer_PlayerFadeOutChaseMusic, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	TriggerTimer(g_hPlayerChaseMusicTimer[client][iBossIndex], true);
}

stock ClientChaseMusicSeeReset(client)
{
	new String:sOldMusic[PLATFORM_MAX_PATH];
	strcopy(sOldMusic, sizeof(sOldMusic), g_strPlayerChaseMusicSee[client]);
	strcopy(g_strPlayerChaseMusicSee[client], sizeof(g_strPlayerChaseMusicSee[]), "");
	if (IsClientInGame(client) && sOldMusic[0]) StopSound(client, MUSIC_CHAN, sOldMusic);
	
	g_iPlayerChaseMusicSeeMaster[client] = -1;
	
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		g_hPlayerChaseMusicSeeTimer[client][i] = INVALID_HANDLE;
		g_flPlayerChaseMusicSeeVolumes[client][i] = 0.0;
		
		if (g_strSlenderProfile[i][0])
		{
			if (IsClientInGame(client))
			{
				GetRandomStringFromProfile(g_strSlenderProfile[i], "sound_chase_visible", sOldMusic, sizeof(sOldMusic), 1);
				if (sOldMusic[0]) StopSound(client, MUSIC_CHAN, sOldMusic);
			}
		}
	}
}

stock ClientMusicChaseSeeStart(client, iBossIndex)
{
	if (!IsClientInGame(client)) return;
	
	new iOldMaster = g_iPlayerChaseMusicSeeMaster[client];
	if (iOldMaster == iBossIndex) return;
	
	new String:sBuffer[PLATFORM_MAX_PATH];
	GetRandomStringFromProfile(g_strSlenderProfile[iBossIndex], "sound_chase_visible", sBuffer, sizeof(sBuffer), 1);
	if (!sBuffer[0]) return;
	
	g_iPlayerChaseMusicSeeMaster[client] = iBossIndex;
	strcopy(g_strPlayerChaseMusicSee[client], sizeof(g_strPlayerChaseMusicSee[]), sBuffer);
	g_hPlayerChaseMusicSeeTimer[client][iBossIndex] = CreateTimer(0.01, Timer_PlayerFadeInChaseMusicSee, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	TriggerTimer(g_hPlayerChaseMusicSeeTimer[client][iBossIndex], true);
	
	if (iOldMaster != -1)
	{
		ClientMusicChaseSeeStop(client, iOldMaster);
	}
}

stock ClientMusicChaseSeeStop(client, iBossIndex)
{
	if (!IsClientInGame(client)) return;
	if (iBossIndex == -1) return;
	
	if (iBossIndex == g_iPlayerChaseMusicSeeMaster[client])
	{
		g_iPlayerChaseMusicSeeMaster[client] = -1;
		strcopy(g_strPlayerChaseMusicSee[client], sizeof(g_strPlayerChaseMusicSee[]), "");
	}
	
	g_hPlayerChaseMusicSeeTimer[client][iBossIndex] = CreateTimer(0.01, Timer_PlayerFadeOutChaseMusicSee, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	TriggerTimer(g_hPlayerChaseMusicSeeTimer[client][iBossIndex], true);
}

public Action:Timer_PlayerFadeInMusic(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client <= 0) return Plugin_Stop;
	
	if (timer != g_hPlayerMusicTimer[client]) return Plugin_Stop;
	
	g_flPlayerMusicVolume[client] += 0.07;
	if (g_flPlayerMusicVolume[client] > g_flPlayerMusicTargetVolume[client]) g_flPlayerMusicVolume[client] = g_flPlayerMusicTargetVolume[client];
	
	if (g_strPlayerMusic[client][0]) EmitSoundToClient(client, g_strPlayerMusic[client], _, MUSIC_CHAN, SNDLEVEL_NONE, SND_CHANGEVOL, g_flPlayerMusicVolume[client]);

	if (g_flPlayerMusicVolume[client] >= g_flPlayerMusicTargetVolume[client])
	{
		g_hPlayerMusicTimer[client] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public Action:Timer_PlayerFadeOutMusic(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client <= 0) return Plugin_Stop;

	if (timer != g_hPlayerMusicTimer[client]) return Plugin_Stop;

	g_flPlayerMusicVolume[client] -= 0.07;
	if (g_flPlayerMusicVolume[client] < 0.0) g_flPlayerMusicVolume[client] = 0.0;

	if (g_strPlayerMusic[client][0]) EmitSoundToClient(client, g_strPlayerMusic[client], _, MUSIC_CHAN, SNDLEVEL_NONE, SND_CHANGEVOL, g_flPlayerMusicVolume[client]);

	if (g_flPlayerMusicVolume[client] <= 0.0)
	{
		g_hPlayerMusicTimer[client] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public Action:Timer_PlayerFadeInChaseMusic(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client <= 0) return Plugin_Stop;

	new iBossIndex = -1;
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		if (g_hPlayerChaseMusicTimer[client][i] == timer)
		{
			iBossIndex = i;
			break;
		}
	}
	
	if (iBossIndex == -1) return Plugin_Stop;
	
	g_flPlayerChaseMusicVolumes[client][iBossIndex] += 0.07;
	if (g_flPlayerChaseMusicVolumes[client][iBossIndex] > 1.0) g_flPlayerChaseMusicVolumes[client][iBossIndex] = 1.0;

	if (g_strPlayerChaseMusic[client][0]) EmitSoundToClient(client, g_strPlayerChaseMusic[client], _, MUSIC_CHAN, _, SND_CHANGEVOL, g_flPlayerChaseMusicVolumes[client][iBossIndex]);
	
	if (g_flPlayerChaseMusicVolumes[client][iBossIndex] >= 1.0)
	{
		g_hPlayerChaseMusicTimer[client][iBossIndex] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public Action:Timer_PlayerFadeInChaseMusicSee(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client <= 0) return Plugin_Stop;

	new iBossIndex = -1;
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		if (g_hPlayerChaseMusicSeeTimer[client][i] == timer)
		{
			iBossIndex = i;
			break;
		}
	}
	
	if (iBossIndex == -1) return Plugin_Stop;
	
	g_flPlayerChaseMusicSeeVolumes[client][iBossIndex] += 0.07;
	if (g_flPlayerChaseMusicSeeVolumes[client][iBossIndex] > 1.0) g_flPlayerChaseMusicSeeVolumes[client][iBossIndex] = 1.0;

	if (g_strPlayerChaseMusicSee[client][0]) EmitSoundToClient(client, g_strPlayerChaseMusicSee[client], _, MUSIC_CHAN, _, SND_CHANGEVOL, g_flPlayerChaseMusicSeeVolumes[client][iBossIndex]);
	
	if (g_flPlayerChaseMusicSeeVolumes[client][iBossIndex] >= 1.0)
	{
		g_hPlayerChaseMusicSeeTimer[client][iBossIndex] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public Action:Timer_PlayerFadeOutChaseMusic(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client <= 0) return Plugin_Stop;

	new iBossIndex = -1;
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		if (g_hPlayerChaseMusicTimer[client][i] == timer)
		{
			iBossIndex = i;
			break;
		}
	}
	
	if (iBossIndex == -1) return Plugin_Stop;
	
	decl String:sBuffer[PLATFORM_MAX_PATH];
	GetRandomStringFromProfile(g_strSlenderProfile[iBossIndex], "sound_chase", sBuffer, sizeof(sBuffer), 1);

	if (StrEqual(sBuffer, g_strPlayerChaseMusic[client], false))
	{
		g_hPlayerChaseMusicTimer[client][iBossIndex] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	g_flPlayerChaseMusicVolumes[client][iBossIndex] -= 0.07;
	if (g_flPlayerChaseMusicVolumes[client][iBossIndex] < 0.0) g_flPlayerChaseMusicVolumes[client][iBossIndex] = 0.0;

	if (sBuffer[0]) EmitSoundToClient(client, sBuffer, _, MUSIC_CHAN, _, SND_CHANGEVOL, g_flPlayerChaseMusicVolumes[client][iBossIndex]);
	
	if (g_flPlayerChaseMusicVolumes[client][iBossIndex] <= 0.0)
	{
		g_hPlayerChaseMusicTimer[client][iBossIndex] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public Action:Timer_PlayerFadeOutChaseMusicSee(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client <= 0) return Plugin_Stop;

	new iBossIndex = -1;
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		if (g_hPlayerChaseMusicSeeTimer[client][i] == timer)
		{
			iBossIndex = i;
			break;
		}
	}
	
	if (iBossIndex == -1) return Plugin_Stop;
	
	decl String:sBuffer[PLATFORM_MAX_PATH];
	GetRandomStringFromProfile(g_strSlenderProfile[iBossIndex], "sound_chase_visible", sBuffer, sizeof(sBuffer), 1);

	if (StrEqual(sBuffer, g_strPlayerChaseMusicSee[client], false))
	{
		g_hPlayerChaseMusicSeeTimer[client][iBossIndex] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	g_flPlayerChaseMusicSeeVolumes[client][iBossIndex] -= 0.07;
	if (g_flPlayerChaseMusicSeeVolumes[client][iBossIndex] < 0.0) g_flPlayerChaseMusicSeeVolumes[client][iBossIndex] = 0.0;

	if (sBuffer[0]) EmitSoundToClient(client, sBuffer, _, MUSIC_CHAN, _, SND_CHANGEVOL, g_flPlayerChaseMusicSeeVolumes[client][iBossIndex]);
	
	if (g_flPlayerChaseMusicSeeVolumes[client][iBossIndex] <= 0.0)
	{
		g_hPlayerChaseMusicSeeTimer[client][iBossIndex] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

stock bool:ClientHasMusicFlag(client, iFlag)
{
	return bool:(g_iPlayerMusicFlags[client] & iFlag);
}

stock bool:ClientHasMusicFlag2(iValue, iFlag)
{
	return bool:(iValue & iFlag);
}

stock ClientAddMusicFlag(client, iFlag)
{
	if (!ClientHasMusicFlag(client, iFlag)) g_iPlayerMusicFlags[client] |= iFlag;
}

stock ClientRemoveMusicFlag(client, iFlag)
{
	if (ClientHasMusicFlag(client, iFlag)) g_iPlayerMusicFlags[client] &= ~iFlag;
}

stock ClientUpdateListeningFlags(client, bool:bReset=false)
{
	if (!IsClientInGame(client)) return;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (i == client || !IsClientInGame(i)) continue;
		
		if (bReset || g_bRoundEnded)
		{
			SetListenOverride(client, i, Listen_Default);
			continue;
		}
		
		if (g_bPlayerEliminated[client])
		{
			if (!g_bPlayerEliminated[i])
			{
				if (g_iPlayerMuteMode[client] == MuteMode_DontHearOtherTeam)
				{
					SetListenOverride(client, i, Listen_No);
				}
				else if (g_iPlayerMuteMode[client] == MuteMode_DontHearOtherTeamIfNotProxy && !g_bPlayerProxy[client])
				{
					SetListenOverride(client, i, Listen_No);
				}
				else
				{
					SetListenOverride(client, i, Listen_Default);
				}
			}
			else
			{
				SetListenOverride(client, i, Listen_Default);
			}
		}
		else
		{
			if (!g_bPlayerEliminated[i])
			{
				if (g_bSpecialRound && g_iSpecialRound == SPECIALROUND_SINGLEPLAYER)
				{
					if (g_bPlayerEscaped[i])
					{
						if (!g_bPlayerEscaped[client])
						{
							SetListenOverride(client, i, Listen_No);
						}
						else
						{
							SetListenOverride(client, i, Listen_Default);
						}
					}
					else
					{
						if (!g_bPlayerEscaped[client])
						{
							SetListenOverride(client, i, Listen_No);
						}
						else
						{
							SetListenOverride(client, i, Listen_Default);
						}
					}
				}
				else
				{
					new bool:bCanHear = false;
					if (GetConVarFloat(g_cvPlayerVoiceDistance) <= 0.0) bCanHear = true;
					
					if (!bCanHear)
					{
						decl Float:flMyPos[3], Float:flHisPos[3];
						GetClientEyePosition(client, flMyPos);
						GetClientEyePosition(i, flHisPos);
						
						new Float:flDist = GetVectorDistance(flMyPos, flHisPos);
						
						if (GetConVarFloat(g_cvPlayerVoiceWallScale) > 0.0)
						{
							new Handle:hTrace = TR_TraceRayFilterEx(flMyPos, flHisPos, MASK_SOLID_BRUSHONLY, RayType_EndPoint, TraceRayDontHitPlayers);
							new bool:bDidHit = TR_DidHit(hTrace);
							CloseHandle(hTrace);
							
							if (bDidHit)
							{
								flDist *= GetConVarFloat(g_cvPlayerVoiceWallScale);
							}
						}
						
						if (flDist <= GetConVarFloat(g_cvPlayerVoiceDistance))
						{
							bCanHear = true;
						}
					}
						
					if (bCanHear)
					{
						if (g_bPlayerGhostMode[i] != g_bPlayerGhostMode[client] &&
							g_bPlayerEscaped[i] != g_bPlayerEscaped[client])
						{
							bCanHear = false;
						}
					}
					
					if (bCanHear)
					{
						SetListenOverride(client, i, Listen_Default);
					}
					else
					{
						SetListenOverride(client, i, Listen_No);
					}
				}
			}
			else
			{
				SetListenOverride(client, i, Listen_No);
			}
		}
	}
}

/*
stock ClientUpdateListeningFlags(client, bool:bReset=false)
{
	if (!IsClientInGame(client)) return;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (i == client || !IsClientInGame(i)) continue;
		
		if (bReset || g_bRoundEnded)
		{
			SetListenOverride(client, i, Listen_Default);
			SetListenOverride(i, client, Listen_Default);
		}
		else
		{
			if (g_bPlayerEliminated[client])
			{
				if (!g_bPlayerEliminated[i])
				{
					if (g_iPlayerMuteMode[client] == MuteMode_DontHearOtherTeam)
					{
						SetListenOverride(client, i, Listen_No);
					}
					else if (g_iPlayerMuteMode[client] == MuteMode_DontHearOtherTeamIfNotProxy && !g_bPlayerProxy[client])
					{
						SetListenOverride(client, i, Listen_No);
					}
					else
					{
						SetListenOverride(client, i, Listen_Default);
					}
				
					SetListenOverride(i, client, Listen_No);
				}
				else
				{
					SetListenOverride(i, client, Listen_Default);
					SetListenOverride(client, i, Listen_Default);
				}
			}
			else
			{
				if (!g_bPlayerEliminated[i])
				{
					if (g_bSpecialRound && g_iSpecialRound == SPECIALROUND_SINGLEPLAYER)
					{
						if (g_bPlayerEscaped[i])
						{
							if (!g_bPlayerEscaped[client])
							{
								SetListenOverride(client, i, Listen_No);
								SetListenOverride(i, client, Listen_Default);
							}
							else
							{
								SetListenOverride(client, i, Listen_Yes);
								SetListenOverride(i, client, Listen_Default);
							}
						}
						else
						{
							if (!g_bPlayerEscaped[client])
							{
								SetListenOverride(client, i, Listen_No);
								SetListenOverride(i, client, Listen_No);
							}
							else
							{
								SetListenOverride(client, i, Listen_Default);
								SetListenOverride(i, client, Listen_No);
							}
						}
					}
					else
					{
						new bool:bCanHear = false;
						if (GetConVarFloat(g_cvPlayerVoiceDistance) <= 0.0) bCanHear = true;
						
						if (!bCanHear)
						{
							decl Float:flMyPos[3], Float:flHisPos[3];
							GetClientEyePosition(client, flMyPos);
							GetClientEyePosition(i, flHisPos);
							
							new Float:flDist = GetVectorDistance(flMyPos, flHisPos);
							
							if (GetConVarFloat(g_cvPlayerVoiceWallScale) > 0.0)
							{
								new Handle:hTrace = TR_TraceRayFilterEx(flMyPos, flHisPos, MASK_SOLID_BRUSHONLY, RayType_EndPoint, TraceRayDontHitPlayers);
								new bool:bDidHit = TR_DidHit(hTrace);
								CloseHandle(hTrace);
								
								if (bDidHit)
								{
									flDist *= GetConVarFloat(g_cvPlayerVoiceWallScale);
								}
							}
							
							if (flDist <= GetConVarFloat(g_cvPlayerVoiceDistance))
							{
								bCanHear = true;
							}
						}
						
						if (bCanHear)
						{
							if (g_bPlayerGhostMode[i] != g_bPlayerGhostMode[client] &&
								g_bPlayerEscaped[i] != g_bPlayerEscaped[client])
							{
								bCanHear = false;
							}
						}
						
						if (bCanHear)
						{
							SetListenOverride(client, i, Listen_Default);
							SetListenOverride(i, client, Listen_Default);
						}
						else
						{
							SetListenOverride(client, i, Listen_No);
							SetListenOverride(i, client, Listen_No);
						}
					}
				}
				else
				{
					SetListenOverride(client, i, Listen_No);
					SetListenOverride(i, client, Listen_Default);
				}
			}
		}
	}
}
*/

stock ClientShowMainMessage(client, const String:sMessage[], any:...)
{
	decl String:message[512];
	VFormat(message, sizeof(message), sMessage, 3);
	
	SetHudTextParams(-1.0, 0.4,
		5.0,
		255,
		255,
		255,
		200,
		2,
		1.0,
		0.07,
		2.0);
	ShowSyncHudText(client, g_hHudSync, message);
}

stock Float:GetClientBlinkRate(client)
{
	new Float:flValue = GetConVarFloat(g_cvPlayerBlinkRate);
	if (GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 3) flValue *= 0.75;
	
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		if (g_bPlayerSeesSlender[client][i]) flValue *= GetProfileFloat(g_strSlenderProfile[i], "blink_look_rate_multiply", 1.0);
		else if (g_bPlayerStatic[client][i]) flValue *= GetProfileFloat(g_strSlenderProfile[i], "blink_static_rate_multiply", 1.0);
	}
	
	if (TF2_GetPlayerClass(client) == TFClass_Sniper) flValue *= 1.4;
	
	if (g_bPlayerFlashlight[client])
	{
		decl Float:startPos[3], Float:endPos[3], Float:flDirection[3];
		new Float:flLength = SF2_FLASHLIGHT_LENGTH;
		GetClientEyePosition(client, startPos);
		GetClientEyePosition(client, endPos);
		GetClientEyeAngles(client, flDirection);
		GetAngleVectors(flDirection, flDirection, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(flDirection, flDirection);
		ScaleVector(flDirection, flLength);
		AddVectors(endPos, flDirection, endPos);
		new Handle:hTrace = TR_TraceRayFilterEx(startPos, endPos, MASK_VISIBLE, RayType_EndPoint, TraceRayDontHitPlayersOrEntity, client);
		TR_GetEndPosition(endPos, hTrace);
		new bool:bHit = TR_DidHit(hTrace);
		CloseHandle(hTrace);
		
		if (bHit)
		{
			new Float:flPercent = (GetVectorDistance(startPos, endPos) / flLength);
			flPercent *= 3.5;
			if (flPercent > 1.0) flPercent = 1.0;
			flValue *= flPercent;
		}
	}
	
	return flValue;
}

#define SF2_PLAYER_LC_EYEANGLES 90.0
#define SF2_PLAYER_LC_ABSPOSITION 1.25
#define SF2_PLAYER_LC_MAXLATENCY 0.0

stock bool:GetClientPredictedEyeAngles(client, Float:buffer[3])
{
	if (!IsValidClient(client)) return false;
	
	GetClientEyeAngles(client, buffer);
	if (IsFakeClient(client)) return true;
	
	new Float:flLatency = GetClientLatency(client, NetFlow_Outgoing);
	new Float:flMaxLatency = SF2_PLAYER_LC_MAXLATENCY;
	if (flMaxLatency >= 0.0 && flLatency > flMaxLatency) flLatency = flMaxLatency;
	
	for (new i = 0; i < 3; i++) 
	{
		buffer[i] += (g_flPlayerEyeAngleVelocity[client][i] * flLatency * SF2_PLAYER_LC_EYEANGLES);
		buffer[i] = AngleNormalize(buffer[i]);
	}
	
	return true;
}

stock bool:GetClientPredictedEyePosition(client, Float:buffer[3])
{
	if (!IsValidClient(client)) return false;
	
	decl Float:flViewOffset[3];
	flViewOffset[0] = GetEntPropFloat(client, Prop_Send, "m_vecViewOffset[0]");
	flViewOffset[1] = GetEntPropFloat(client, Prop_Send, "m_vecViewOffset[1]");
	flViewOffset[2] = GetEntPropFloat(client, Prop_Send, "m_vecViewOffset[2]");
	GetClientPredictedAbsOrigin(client, buffer);
	AddVectors(buffer, flViewOffset, buffer);
	
	return true;
}

stock bool:GetClientPredictedAbsOrigin(client, Float:buffer[3])
{
	if (!IsValidClient(client)) return false;
	
	decl Float:startPos[3];
	GetClientAbsOrigin(client, startPos);
	if (IsFakeClient(client)) 
	{
		for (new i = 0; i < 3; i++) buffer[i] = startPos[i];
		return true;
	}
	
	decl Float:flVelocity[3], Float:flMins[3], Float:flMaxs[3], Float:endPos[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", flVelocity);
	GetEntPropVector(client, Prop_Send, "m_vecMins", flMins);
	GetEntPropVector(client, Prop_Send, "m_vecMaxs", flMaxs);
	
	new Float:flLatency = GetClientLatency(client, NetFlow_Outgoing);
	new Float:flMaxLatency = SF2_PLAYER_LC_MAXLATENCY;
	if (flMaxLatency >= 0.0 && flLatency > flMaxLatency) flLatency = flMaxLatency;
	
	for (new i = 0; i < 3; i++) 
	{
		endPos[i] = startPos[i] + (flVelocity[i] * flLatency * SF2_PLAYER_LC_ABSPOSITION);
	}
	
	new Handle:hTrace = TR_TraceHullFilterEx(startPos, endPos, flMins, flMaxs, MASK_PLAYERSOLID, TraceRayDontHitPlayersOrEntity, client);
	TR_GetEndPosition(buffer, hTrace);
	CloseHandle(hTrace);
	
	return true;
}

stock bool:IsPointVisibleToAPlayer(const Float:pos[3], bool:bCheckFOV=true, bool:bCheckBlink=false)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i)) continue;
		if (IsPointVisibleToPlayer(i, pos, bCheckFOV, bCheckBlink)) return true;
	}
	
	return false;
}

stock bool:IsPointVisibleToPlayer(client, const Float:pos[3], bool:bCheckFOV=true, bool:bCheckBlink=false, bool:bCheckEliminated=true)
{
	if (!IsValidClient(client) || !IsPlayerAlive(client) || g_bPlayerGhostMode[client]) return false;
	
	if (bCheckEliminated && g_bPlayerEliminated[client]) return false;
	
	if (bCheckBlink && g_bPlayerBlink[client]) return false;
	
	decl Float:eyePos[3];
	GetClientPredictedEyePosition(client, eyePos);
	
	if (g_offsPlayerFogCtrl != -1 && g_offsFogCtrlEnable != -1 && g_offsFogCtrlEnd != -1)
	{
		// Check fog.
		new iFogEntity = GetEntDataEnt2(client, g_offsPlayerFogCtrl);
		if (IsValidEdict(iFogEntity))
		{
			if (GetEntData(iFogEntity, g_offsFogCtrlEnable) &&
			GetVectorDistance(eyePos, pos) >= GetEntDataFloat(iFogEntity, g_offsFogCtrlEnd)) return false;
		}
	}
	
	new Handle:hTrace = TR_TraceRayFilterEx(eyePos, pos, CONTENTS_SOLID | CONTENTS_MOVEABLE | CONTENTS_MIST, RayType_EndPoint, TraceRayDontHitPlayersOrEntity, client);
	new bool:bHit = TR_DidHit(hTrace);
	CloseHandle(hTrace);
	
	if (bHit) return false;
	
	if (bCheckFOV)
	{
		decl Float:eyeAng[3], Float:reqVisibleAng[3];
		GetClientPredictedEyeAngles(client, eyeAng);
		
		new Float:flFOV = float(g_iPlayerDesiredFOV[client]);
		SubtractVectors(pos, eyePos, reqVisibleAng);
		GetVectorAngles(reqVisibleAng, reqVisibleAng);
		
		new Float:difference = FloatAbs(AngleDiff(eyeAng[0], reqVisibleAng[0])) + FloatAbs(AngleDiff(eyeAng[1], reqVisibleAng[1]));
		if (difference > ((flFOV * 0.5) + 10.0)) return false;
	}
	
	return true;
}

stock ChangeClientTeamNoSuicide(client, team, bool:bRespawn=true)
{
	if (!IsClientInGame(client)) return;
	
	if (GetClientTeam(client) != team)
	{
		SetEntProp(client, Prop_Send, "m_lifeState", 2);
		ChangeClientTeam(client, team);
		SetEntProp(client, Prop_Send, "m_lifeState", 0);
		if (bRespawn) TF2_RespawnPlayer(client);
	}
}

stock UTIL_ScreenShake(client, Float:amplitude, Float:duration, Float:frequency)
{
	new Handle:hBf = StartMessageOne("Shake", client);
	if (hBf != INVALID_HANDLE)
	{
		BfWriteByte(hBf, 0);
		BfWriteFloat(hBf, amplitude);
		BfWriteFloat(hBf, frequency);
		BfWriteFloat(hBf, duration);
		EndMessage();
	}
}

public UTIL_ScreenFade(client, duration, time, flags, r, g, b, a)
{
	new clients[1], Handle:bf;
	clients[0] = client;
	
	bf = StartMessage("Fade", clients, 1);
	BfWriteShort(bf, duration);
	BfWriteShort(bf, time);
	BfWriteShort(bf, flags);
	BfWriteByte(bf, r);
	BfWriteByte(bf, g);
	BfWriteByte(bf, b);
	BfWriteByte(bf, a);
	EndMessage();
}

stock bool:IsValidClient(client)
{
	return bool:(client > 0 && client <= MaxClients && IsClientInGame(client));
}

stock ClientSpawnSoundEffect(const Float:flOrigin[3], Float:flScale, iEntity=-1)
{
	/*
	static iModelIndex = -1;
	
	if (iModelIndex == -1) iModelIndex = PrecacheModel("materials/particle/particle_ring_wave_additive.vmt");
	if (iModelIndex == -1) return;
	
	decl clients[MAXPLAYERS + 1];
	new numClients;
	
	new Float:flHearRadius = 512.0 * flScale;
	
	if (IsValidClient(iEntity))
	{
		if (TF2_GetPlayerClass(iEntity) == TFClass_Spy) flHearRadius *= 0.65;
	}
	
	decl Float:flStartPos[3];
	decl Float:flTempDist;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || g_bPlayerEliminated[i]) continue;
		if (i == iEntity) continue;
		
		GetClientEyePosition(i, flStartPos);
		flTempDist = GetVectorDistance(flStartPos, flOrigin);
		
		if (!GetEntProp(i, Prop_Send, "m_bDucked")) continue;
		
		if (TF2_GetPlayerClass(i) == TFClass_Spy) flTempDist *= 0.75;
		
		if (flTempDist <= flHearRadius)
		{
			clients[numClients] = i;
			numClients++;
		}
	}
	
	if (numClients)
	{
		//TE_SetupBeamRingPoint(flOrigin, 10.0, 8000.0, iBeamSprite, iHaloSprite, 0, 60, 0.5, 2.5, 0.0, { 255, 255, 255, 255 }, 10, FBEAM_FADEOUT);
		//TE_SetupTFParticleEffect(iParticle, flOrigin, flOrigin);
		
		new iBrightness = RoundFloat(200.0 * flScale);
		if (iBrightness > 255) iBrightness = 255;
		
		TE_SetupGlowSprite(flOrigin, iModelIndex, 0.75 * flScale, 5.0 * flScale, iBrightness);
		TE_Send(clients, numClients);
	}
	*/
}

public Action:Timer_ClientPostWeapons(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client > 0)
	{
		if (IsPlayerAlive(client))
		{
			new bool:bRemoveWeapons = true;
			new bool:bRestrictWeapons = true;
			
			if (g_bRoundEnded)
			{
				if (!g_bPlayerEliminated[client]) 
				{
					bRemoveWeapons = false;
					bRestrictWeapons = false;
				}
			}
			
			if (IsClientInPvP(client)) 
			{
				bRemoveWeapons = false;
				bRestrictWeapons = false;
			}
			
			if (g_bRoundWarmup) 
			{
				bRemoveWeapons = false;
				bRestrictWeapons = false;
			}
			
			if (g_bPlayerGhostMode[client]) 
			{
				bRemoveWeapons = true;
			}
			
			if (bRemoveWeapons)
			{
				ClientSwitchToWeaponSlot(client, TFWeaponSlot_Melee);
				
				for (new i = 0; i <= 5; i++)
				{
					if (i == TFWeaponSlot_Melee) continue;
					TF2_RemoveWeaponSlot(client, i);
				}
				
				new ent = -1;
				while ((ent = FindEntityByClassname(ent, "tf_weapon_builder")) != -1)
				{
					if (GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity") == client)
					{
						AcceptEntityInput(ent, "Kill");
					}
				}
				
				ent = -1;
				while ((ent = FindEntityByClassname(ent, "tf_wearable_demoshield")) != -1)
				{
					if (GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity") == client)
					{
						AcceptEntityInput(ent, "Kill");
					}
				}
			}
			
			if (bRestrictWeapons)
			{
				new iHealth = GetEntProp(client, Prop_Send, "m_iHealth");
				
				if (g_hRestrictedWeaponsConfig != INVALID_HANDLE)
				{
					new TFClassType:iPlayerClass = TF2_GetPlayerClass(client);
					new Handle:hItem = INVALID_HANDLE;
					
					new iWeapon = INVALID_ENT_REFERENCE;
					for (new iSlot = 0; iSlot <= 5; iSlot++)
					{
						iWeapon = GetPlayerWeaponSlot(client, iSlot);
						
						if (IsValidEdict(iWeapon))
						{
							if (IsWeaponRestricted(iPlayerClass, GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex")))
							{
								hItem = INVALID_HANDLE;
								TF2_RemoveWeaponSlot(client, iSlot);
								
								switch (iSlot)
								{
									case TFWeaponSlot_Primary:
									{
										switch (iPlayerClass)
										{
											case TFClass_Scout: hItem = g_hSDKWeaponScattergun;
											case TFClass_Sniper: hItem = g_hSDKWeaponSniperRifle;
											case TFClass_Soldier: hItem = g_hSDKWeaponRocketLauncher;
											case TFClass_DemoMan: hItem = g_hSDKWeaponGrenadeLauncher;
											case TFClass_Heavy: hItem = g_hSDKWeaponMinigun;
											case TFClass_Medic: hItem = g_hSDKWeaponSyringeGun;
											case TFClass_Pyro: hItem = g_hSDKWeaponFlamethrower;
											case TFClass_Spy: hItem = g_hSDKWeaponRevolver;
											case TFClass_Engineer: hItem = g_hSDKWeaponShotgunPrimary;
										}
									}
									case TFWeaponSlot_Secondary:
									{
										switch (iPlayerClass)
										{
											case TFClass_Scout: hItem = g_hSDKWeaponPistolScout;
											case TFClass_Sniper: hItem = g_hSDKWeaponSMG;
											case TFClass_Soldier: hItem = g_hSDKWeaponShotgunSoldier;
											case TFClass_DemoMan: hItem = g_hSDKWeaponStickyLauncher;
											case TFClass_Heavy: hItem = g_hSDKWeaponShotgunHeavy;
											case TFClass_Medic: hItem = g_hSDKWeaponMedigun;
											case TFClass_Pyro: hItem = g_hSDKWeaponShotgunPyro;
											case TFClass_Engineer: hItem = g_hSDKWeaponPistol;
										}
									}
									case TFWeaponSlot_Melee:
									{
										switch (iPlayerClass)
										{
											case TFClass_Scout: hItem = g_hSDKWeaponBat;
											case TFClass_Sniper: hItem = g_hSDKWeaponKukri;
											case TFClass_Soldier: hItem = g_hSDKWeaponShovel;
											case TFClass_DemoMan: hItem = g_hSDKWeaponBottle;
											case TFClass_Heavy: hItem = g_hSDKWeaponFists;
											case TFClass_Medic: hItem = g_hSDKWeaponBonesaw;
											case TFClass_Pyro: hItem = g_hSDKWeaponFireaxe;
											case TFClass_Spy: hItem = g_hSDKWeaponKnife;
											case TFClass_Engineer: hItem = g_hSDKWeaponWrench;
										}
									}
									case 4:
									{
										switch (iPlayerClass)
										{
											case TFClass_Spy: hItem = g_hSDKWeaponInvis;
										}
									}
								}
								
								if (hItem != INVALID_HANDLE)
								{
									new iNewWeapon = TF2Items_GiveNamedItem(client, hItem);
									if (IsValidEntity(iNewWeapon)) 
									{
										EquipPlayerWeapon(client, iNewWeapon);
									}
								}
							}
						}
					}
				}
				
				// Fixes the Pretty Boy's Pocket Pistol glitch.
				new iMaxHealth = SDKCall(g_hSDKGetMaxHealth, client);
				if (iHealth > iMaxHealth)
				{
					SetEntProp(client, Prop_Data, "m_iHealth", iMaxHealth);
					SetEntProp(client, Prop_Send, "m_iHealth", iMaxHealth);
				}
			}
			
			// Change stats on some weapons.
			if (!g_bPlayerEliminated[client] || g_bPlayerProxy[client])
			{
				new iWeapon = INVALID_ENT_REFERENCE;
				decl Handle:hWeapon;
				for (new iSlot = 0; iSlot <= 5; iSlot++)
				{
					iWeapon = GetPlayerWeaponSlot(client, iSlot);
					if (!iWeapon || iWeapon == INVALID_ENT_REFERENCE) continue;
					
					new iItemDef = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
					switch (iItemDef)
					{
						case 214: // Powerjack
						{
							TF2_RemoveWeaponSlot(client, iSlot);
							
							hWeapon = PrepareItemHandle("tf_weapon_fireaxe", 214, 0, 0, "180 ; 20.0 ; 206 ; 1.33");
							new iEnt = TF2Items_GiveNamedItem(client, hWeapon);
							CloseHandle(hWeapon);
							EquipPlayerWeapon(client, iEnt);
						}
						case 357: // Half-Zatoichi
						{
							TF2_RemoveWeaponSlot(client, iSlot);
							
							hWeapon = PrepareItemHandle("tf_weapon_sword", 357, 0, 0, "219 ; 1.0 ; 180 ; 20.0 ; 226 ; 1.0");
							new iEnt = TF2Items_GiveNamedItem(client, hWeapon);
							CloseHandle(hWeapon);
							EquipPlayerWeapon(client, iEnt);
						}
						/*
						case 404: // Persian Persuader
						{
							TF2_RemoveWeaponSlot(client, iSlot);
							
							hWeapon = PrepareItemHandle("tf_weapon_sword", 404, 0, 0, "249 ; 2.0 ; 15 ; 0.0");
							new iEnt = TF2Items_GiveNamedItem(client, hWeapon);
							CloseHandle(hWeapon);
							EquipPlayerWeapon(client, iEnt);
						}
						*/
					}
				}
			}
			
			// Remove all hats.
			if (g_bPlayerGhostMode[client])
			{
				new ent = -1;
				while ((ent = FindEntityByClassname(ent, "tf_wearable")) != -1)
				{
					if (GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity") == client)
					{
						AcceptEntityInput(ent, "Kill");
					}
				}
			}
			
			if (g_bPlayerProxy[client] && g_iPlayerProxyMaster[client] != -1)
			{
				new iMaster = g_iPlayerProxyMaster[client];
				if (g_strSlenderProfile[iMaster][0]) 
				{
					decl String:sProfile[SF2_MAX_PROFILE_NAME_LENGTH];
					strcopy(sProfile, sizeof(sProfile), g_strSlenderProfile[iMaster]);
					
					// Set custom model, if any.
					decl String:sBuffer[PLATFORM_MAX_PATH];
					decl String:sSectionName[64];
					
					decl String:sClassName[64];
					TF2_GetClassName(TF2_GetPlayerClass(client), sClassName, sizeof(sClassName));
					
					Format(sSectionName, sizeof(sSectionName), "mod_proxy_%s", sClassName);
					if ((GetRandomStringFromProfile(sProfile, sSectionName, sBuffer, sizeof(sBuffer)) && sBuffer[0]) ||
						(GetRandomStringFromProfile(sProfile, "mod_proxy_all", sBuffer, sizeof(sBuffer)) && sBuffer[0]))
					{
						SetVariantString(sBuffer);
						AcceptEntityInput(client, "SetCustomModel");
						SetEntProp(client, Prop_Send, "m_bUseClassAnimations", true);
					}
					
					// Play any sounds, if any.
					if (GetRandomStringFromProfile(sProfile, "sound_proxy_spawn", sBuffer, sizeof(sBuffer)) && sBuffer[0])
					{
						new iChannel = GetProfileNum(sProfile, "sound_proxy_spawn_channel", SNDCHAN_AUTO);
						new iLevel = GetProfileNum(sProfile, "sound_proxy_spawn_level", SNDLEVEL_NORMAL);
						new iFlags = GetProfileNum(sProfile, "sound_proxy_spawn_flags", SND_NOFLAGS);
						new Float:flVolume = GetProfileFloat(sProfile, "sound_proxy_spawn_volume", SNDVOL_NORMAL);
						new iPitch = GetProfileNum(sProfile, "sound_proxy_spawn_pitch", SNDPITCH_NORMAL);
						
						EmitSoundToAll(sBuffer, client, iChannel, iLevel, iFlags, flVolume, iPitch);
					}
				}
			}
		}
	}
}

bool:IsWeaponRestricted(TFClassType:iClass, iItemDef)
{
	if (g_hRestrictedWeaponsConfig == INVALID_HANDLE) return false;
	
	new bool:bReturn = false;
	
	decl String:sItemDef[32];
	IntToString(iItemDef, sItemDef, sizeof(sItemDef));
	
	KvRewind(g_hRestrictedWeaponsConfig);
	if (KvJumpToKey(g_hRestrictedWeaponsConfig, "all"))
	{
		bReturn = bool:KvGetNum(g_hRestrictedWeaponsConfig, sItemDef);
	}
	
	new bool:bFoundSection = false;
	KvRewind(g_hRestrictedWeaponsConfig);
	
	switch (iClass)
	{
		case TFClass_Scout: bFoundSection = KvJumpToKey(g_hRestrictedWeaponsConfig, "scout");
		case TFClass_Soldier: bFoundSection = KvJumpToKey(g_hRestrictedWeaponsConfig, "soldier");
		case TFClass_Sniper: bFoundSection = KvJumpToKey(g_hRestrictedWeaponsConfig, "sniper");
		case TFClass_DemoMan: bFoundSection = KvJumpToKey(g_hRestrictedWeaponsConfig, "demoman");
		case TFClass_Heavy: 
		{
			bFoundSection = KvJumpToKey(g_hRestrictedWeaponsConfig, "heavy");
		
			if (!bFoundSection)
			{
				KvRewind(g_hRestrictedWeaponsConfig);
				bFoundSection = KvJumpToKey(g_hRestrictedWeaponsConfig, "heavyweapons");
			}
		}
		case TFClass_Medic: bFoundSection = KvJumpToKey(g_hRestrictedWeaponsConfig, "medic");
		case TFClass_Spy: bFoundSection = KvJumpToKey(g_hRestrictedWeaponsConfig, "spy");
		case TFClass_Pyro: bFoundSection = KvJumpToKey(g_hRestrictedWeaponsConfig, "pyro");
		case TFClass_Engineer: bFoundSection = KvJumpToKey(g_hRestrictedWeaponsConfig, "engineer");
	}
	
	if (bFoundSection)
	{
		bReturn = bool:KvGetNum(g_hRestrictedWeaponsConfig, sItemDef, bReturn);
	}
	
	return bReturn;
}

public Action:Timer_RespawnPlayer(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client <= 0) return;

	if (IsPlayerAlive(client)) return;
	
	TF2_RespawnPlayer(client);
}

public Action:Timer_CheckEscapedPlayer(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client <= 0) return;

	if (!IsPlayerAlive(client)) return;
	
	if (g_bPlayerEscaped[client])
	{
		decl String:sName[64];
		new ent = -1;
		while ((ent = FindEntityByClassname(ent, "info_target")) != -1)
		{
			GetEntPropString(ent, Prop_Data, "m_iName", sName, sizeof(sName));
			if (!StrContains(sName, "sf2_escape_spawnpoint", false) ||
				!StrContains(sName, "slender_escape_spawnpoint", false))
			{
				decl Float:pos[3], Float:ang[3];
				GetEntPropVector(ent, Prop_Data, "m_vecAbsOrigin", pos);
				GetEntPropVector(ent, Prop_Data, "m_angAbsRotation", ang);
				ang[2] = 0.0;
				TeleportEntity(client, pos, ang, Float:{ 0.0, 0.0, 0.0 });
				
				AcceptEntityInput(ent, "FireUser1", client);
				
				break;
			}
		}
	}
}