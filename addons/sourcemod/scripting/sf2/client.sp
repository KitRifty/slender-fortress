#if defined _sf2_client_included
 #endinput
#endif
#define _sf2_client_included

#define GHOST_MODEL "models/props_halloween/ghost_no_hat.mdl"
#define BLACK_OVERLAY "overlays/slender/newcamerahud"

#define SF2_FLASHLIGHT_WIDTH 512.0 // How wide the player's Flashlight should be in world units.
#define SF2_FLASHLIGHT_LENGTH 1024.0 // How far the player's Flashlight can reach in world units.
#define SF2_FLASHLIGHT_BRIGHTNESS 0 // Intensity of the players' Flashlight.
#define SF2_FLASHLIGHT_DRAIN_RATE 0.65 // How long (in seconds) each bar on the player's Flashlight meter lasts.
#define SF2_FLASHLIGHT_RECHARGE_RATE 0.68 // How long (in seconds) it takes each bar on the player's Flashlight meter to recharge.
#define SF2_FLASHLIGHT_FLICKERAT 0.25 // The percentage of the Flashlight battery where the Flashlight will start to blink.
#define SF2_FLASHLIGHT_ENABLEAT 0.3 // The percentage of the Flashlight battery where the Flashlight will be able to be used again (if the player shortens out the Flashlight from excessive use).
#define SF2_FLASHLIGHT_COOLDOWN 0.4 // How much time players have to wait before being able to switch their flashlight on again after turning it off.

#define SF2_ULTRAVISION_WIDTH 800.0
#define SF2_ULTRAVISION_LENGTH 800.0
#define SF2_ULTRAVISION_BRIGHTNESS -4 // Intensity of Ultravision.
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

//	==========================================================
//	GENERAL CLIENT HOOK FUNCTIONS
//	==========================================================

#define SF2_PLAYER_VIEWBOB_TIMER 10.0
#define SF2_PLAYER_VIEWBOB_SCALE_X 0.05
#define SF2_PLAYER_VIEWBOB_SCALE_Y 0.0
#define SF2_PLAYER_VIEWBOB_SCALE_Z 0.0


public MRESReturn:Hook_ClientWantsLagCompensationOnEntity(this, Handle:hReturn, Handle:hParams)
{
	if (!g_bEnabled || IsFakeClient(this)) return MRES_Ignored;
	
	DHookSetReturn(hReturn, true);
	return MRES_Supercede;
}

public Hook_ClientPreThink(client)
{
	if (!g_bEnabled) return;
	
	ClientProcessViewAngles(client);
	ClientProcessVisibility(client);
	ClientProcessStaticShake(client);
	ClientProcessFlashlight(client);
	ClientProcessGlow(client);
	
	if (g_bPlayerGhostMode[client])
	{
		SetEntPropFloat(client, Prop_Send, "m_flNextAttack", GetGameTime() + 2.0);
		SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 520.0);
	}
	else if (!g_bPlayerEliminated[client] || g_bPlayerProxy[client])
	{
		if (!g_bRoundEnded && !g_bRoundWarmup && !g_bPlayerEscaped[client])
		{
			new iRoundState = _:GameRules_GetRoundState();
		
			// No double jumping for players in play.
			SetEntProp(client, Prop_Send, "m_iAirDash", 99999);
		
			if (!g_bPlayerProxy[client])
			{
				if (iRoundState == 4)
				{
					new bool:bDanger = false;
					
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
								
								if ((iState == STATE_CHASE || iState == STATE_ATTACK || iState == STATE_STUN) &&
									((iBossTarget && iBossTarget != INVALID_ENT_REFERENCE && (iBossTarget == client || ClientGetDistanceFromEntity(client, iBossTarget) < 512.0)) || SlenderGetDistanceFromPlayer(i, client) < 512.0 || PlayerCanSeeSlender(client, i, false)))
								{
									bDanger = true;
									g_flPlayerDangerBoostTime[client] = GetGameTime() + 5.0;
									
									// Induce client stress levels.
									new Float:flUnComfortZoneDist = 512.0;
									new Float:flStressScalar = (flUnComfortZoneDist / SlenderGetDistanceFromPlayer(i, client));
									ClientAddStress(client, 0.025 * flStressScalar);
									
									break;
								}
							}
						}
					}
					
					if (g_flPlayerStaticAmount[client] > 0.4) bDanger = true;
					if (GetGameTime() < g_flPlayerDangerBoostTime[client]) bDanger = true;
					
					if (!bDanger)
					{
						decl iState;
						for (new i = 0; i < MAX_BOSSES; i++)
						{
							if (g_iSlenderID[i] == -1 || !g_strSlenderProfile[i][0]) continue;
							
							if (g_iSlenderType[i] == 2)
							{
								if (iState == STATE_ALERT)
								{
									if (PlayerCanSeeSlender(client, i))
									{
										bDanger = true;
										g_flPlayerDangerBoostTime[client] = GetGameTime() + 5.0;
									}
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
							
							if ((flCurTime - g_flPlayerScareLastTime[client][i]) <= flScareSprintDuration)
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
						if (iRoundState == 4)
						{
							if (bSpeedup) SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 405.0);
							else SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 300.0);
						}
					}
					case TFClass_Medic:
					{
						if (iRoundState == 4)
						{
							if (bSpeedup) SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 385.0);
							else SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 300.0);
						}
					}
				}
			}
		}
	}
	
	// Calculate player stress levels.
	if (GetGameTime() >= g_flPlayerStressNextUpdateTime[client])
	{
		//new Float:flPagePercent = g_iPageMax != 0 ? float(g_iPageCount) / float(g_iPageMax) : 0.0;
		//new Float:flPageCountPercent = g_iPageMax != 0? float(g_iPlayerPageCount[client]) / float(g_iPageMax) : 0.0;
		
		g_flPlayerStressNextUpdateTime[client] = GetGameTime() + 0.33;
		ClientAddStress(client, -0.01);
		
		SendDebugMessageToPlayer(client, DEBUG_PLAYER_STRESS, 1, "g_flPlayerStress[%d]: %0.1f", client, g_flPlayerStress[client]);
	}
	
	// Process screen shake, if enabled.
	if (g_bPlayerShakeEnabled)
	{
		new bool:bDoShake = false;
		
		if (IsPlayerAlive(client))
		{
			new iStaticMaster = SlenderGetFromID(g_iPlayerStaticMaster[client]);
			if (iStaticMaster != -1 && g_iSlenderFlags[iStaticMaster] & SFF_HASVIEWSHAKE)
			{
				bDoShake = true;
			}
		}
		
		if (bDoShake)
		{
			new Float:flPercent = g_flPlayerStaticAmount[client];
			
			new Float:flAmplitudeMax = GetConVarFloat(g_cvPlayerShakeAmplitudeMax);
			new Float:flAmplitude = flAmplitudeMax * flPercent;
			
			new Float:flFrequencyMax = GetConVarFloat(g_cvPlayerShakeFrequencyMax);
			new Float:flFrequency = flFrequencyMax * flPercent;
			
			UTIL_ScreenShake(client, flAmplitude, 0.5, flFrequency);
		}
	}
	
	/*
	// Moved this section of code to OnGameFrame().
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
	*/
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
					new iMaster = SlenderGetFromID(g_iPlayerProxyMaster[attacker]);
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
					new iMaster = SlenderGetFromID(g_iPlayerProxyMaster[victim]);
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

ClientResetStatic(client)
{
	g_iPlayerStaticMaster[client] = -1;
	g_hPlayerStaticTimer[client] = INVALID_HANDLE;
	g_flPlayerStaticIncreaseRate[client] = 0.0;
	g_flPlayerStaticDecreaseRate[client] = 0.0;
	g_hPlayerLastStaticTimer[client] = INVALID_HANDLE;
	g_flPlayerLastStaticTime[client] = 0.0;
	g_flPlayerLastStaticVolume[client] = 0.0;
	g_bPlayerInStaticShake[client] = false;
	g_iPlayerStaticShakeMaster[client] = -1;
	g_flPlayerStaticShakeMinVolume[client] = 0.0;
	g_flPlayerStaticShakeMaxVolume[client] = 0.0;
	g_flPlayerStaticAmount[client] = 0.0;
	
	if (IsClientInGame(client))
	{
		if (g_strPlayerStaticSound[client][0]) StopSound(client, SNDCHAN_STATIC, g_strPlayerStaticSound[client]);
		if (g_strPlayerLastStaticSound[client][0]) StopSound(client, SNDCHAN_STATIC, g_strPlayerLastStaticSound[client]);
		if (g_strPlayerStaticShakeSound[client][0]) StopSound(client, SNDCHAN_STATIC, g_strPlayerStaticShakeSound[client]);
	}
	
	strcopy(g_strPlayerStaticSound[client], sizeof(g_strPlayerStaticSound[]), "");
	strcopy(g_strPlayerLastStaticSound[client], sizeof(g_strPlayerLastStaticSound[]), "");
	strcopy(g_strPlayerStaticShakeSound[client], sizeof(g_strPlayerStaticShakeSound[]), "");
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
	
	
	
	g_iPlayerPageCount[client] = 0;
	
	ClientResetStatic(client);
	ClientResetSlenderStats(client);
	ClientResetFlashlight(client);
	ClientResetCampingStats(client);
	ClientResetBlink(client);
	ClientResetOverlay(client);
	ClientResetJumpScare(client);
	ClientUpdateListeningFlags(client);
	ClientUpdateMusicSystem(client);
	ClientChaseMusicReset(client);
	ClientChaseMusicSeeReset(client);
	ClientAlertMusicReset(client);
	Client20DollarsMusicReset(client);
	ClientMusicReset(client);
	ClientResetGlow(client);
	ClientResetPvP(client);
	ClientResetProxy(client);
	ClientResetProxyGlow(client);
	ClientResetSprint(client);
	ClientResetBreathing(client);
	ClientResetHints(client);
	ClientResetScare(client);
	ClientDisableFakeLagCompensation(client);
	
	g_flPlayerDangerBoostTime[client] = -1.0;
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("END InitializeClient(%d)", client);
#endif
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

ClientEscape(client)
{
#if defined DEBUG
	DebugMessage("START ClientEscape(%d)", client);
#endif

	if (!g_bPlayerEscaped[client])
	{
		ClientResetBreathing(client);
		ClientDeactivateFlashlight(client);
		
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

//	==========================================================
//	FLASHLIGHT / ULTRAVISION FUNCTIONS
//	==========================================================

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
		
		ClientAddStress(client, 0.2);
		
		Call_StartForward(fOnClientBreakFlashlight);
		Call_PushCell(client);
		Call_Finish();
		
		return Plugin_Stop;
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

ClientActivateFlashlight(client)
{
	ClientDeactivateFlashlight(client);
	
	new Float:flDrainRate = SF2_FLASHLIGHT_DRAIN_RATE;
	if (TF2_GetPlayerClass(client) == TFClass_Engineer) flDrainRate *= 1.33;
	
	g_bPlayerFlashlight[client] = true;
	g_hPlayerFlashlightTimer[client] = CreateTimer(flDrainRate, Timer_DrainFlashlight, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	decl Float:flPos[3];
	GetClientEyePosition(client, flPos);
	
	new ent = CreateEntityByName("light_dynamic");
	if (ent != -1)
	{
		TeleportEntity(ent, flPos, NULL_VECTOR, NULL_VECTOR);
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
	}
	
	// Create.
	ent = CreateEntityByName("point_spotlight");
	if (ent != -1)
	{
		TeleportEntity(ent, flPos, NULL_VECTOR, NULL_VECTOR);
		
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
	}
	
	if (g_bPlayerFlashlightProjected[client])
	{
		new iEffects = GetEntProp(client, Prop_Send, "m_fEffects");
		if (!(iEffects & (1 << 2)))
		{
			SetEntProp(client, Prop_Send, "m_fEffects", iEffects | (1 << 2));
		}
	}
	
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
	if (ent && ent != INVALID_ENT_REFERENCE) 
	{
		AcceptEntityInput(ent, "TurnOff");
		AcceptEntityInput(ent, "Kill");
	}
	
	ent = EntRefToEntIndex(g_iPlayerFlashlightEntAng[client]);
	g_iPlayerFlashlightEntAng[client] = INVALID_ENT_REFERENCE;
	if (ent && ent != INVALID_ENT_REFERENCE) 
	{
		AcceptEntityInput(ent, "LightOff");
		CreateTimer(0.1, Timer_KillEntity, g_iPlayerFlashlightEntAng[client], TIMER_FLAG_NO_MAPCHANGE);
	}
	
	if (IsClientInGame(client))
	{
		g_hPlayerFlashlightTimer[client] = CreateTimer(SF2_FLASHLIGHT_RECHARGE_RATE, Timer_RechargeFlashlight, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
		if (g_bPlayerFlashlightProjected[client])
		{
			new iEffects = GetEntProp(client, Prop_Send, "m_fEffects");
			if (iEffects & (1 << 2))
			{
				SetEntProp(client, Prop_Send, "m_fEffects", iEffects &= ~(1 << 2));
			}
		}
	}
	else
	{
		g_hPlayerFlashlightTimer[client] = INVALID_HANDLE;
	}
	
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
	
	if (g_bPlayerEliminated[client])
	{
		SetVariantFloat(GetConVarFloat(g_cvUltravisionRadiusBlue));
	}
	else
	{
		SetVariantFloat(GetConVarFloat(g_cvUltravisionRadiusRed));
	}
	
	AcceptEntityInput(ent, "spotlight_radius");
	
	if (g_bPlayerEliminated[client])
	{
		SetVariantFloat(GetConVarFloat(g_cvUltravisionRadiusBlue));
	}
	else
	{
		SetVariantFloat(GetConVarFloat(g_cvUltravisionRadiusRed));
	}
	
	AcceptEntityInput(ent, "distance");
	SetVariantInt(-15); // Start dark, then fade in via timer.
	AcceptEntityInput(ent, "brightness");
	
	// Convert WU to inches.
	new Float:cone = SF2_ULTRAVISION_CONE;
	cone *= 0.75;
	
	SetVariantInt(RoundToFloor(cone));
	AcceptEntityInput(ent, "_inner_cone");
	SetVariantInt(0);
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
	CreateTimer(0.0, Timer_UltravisionFadeInEffect, g_iPlayerUltravisionEnt[client], TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_UltravisionFadeInEffect(Handle:timer, any:entref)
{
	new ent = EntRefToEntIndex(entref);
	if (!ent || ent == INVALID_ENT_REFERENCE) return Plugin_Stop;
	
	new iBrightness = GetEntProp(ent, Prop_Send, "m_Exponent");
	if (iBrightness >= GetConVarInt(g_cvUltravisionBrightness)) return Plugin_Stop;
	
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

// Static shaking should only affect the x, y portion of the player's view, not roll.
// This is purely for cosmetic effect.

ClientProcessStaticShake(client)
{
	if (!IsClientInGame(client) || !IsPlayerAlive(client)) return;
	
	new bool:bOldStaticShake = g_bPlayerInStaticShake[client];
	new iOldStaticShakeMaster = SlenderGetFromID(g_iPlayerStaticShakeMaster[client]);
	new iNewStaticShakeMaster = -1;
	new Float:flNewStaticShakeMasterAnger = -1.0;
	
	new Float:flOldPunchAng[3], Float:flOldPunchAngVel[3];
	GetEntDataVector(client, g_offsPlayerPunchAngle, flOldPunchAng);
	GetEntDataVector(client, g_offsPlayerPunchAngleVel, flOldPunchAngVel);
	
	new Float:flNewPunchAng[3], Float:flNewPunchAngVel[3];
	
	for (new i = 0; i < 3; i++)
	{
		flNewPunchAng[i] = flOldPunchAng[i];
		flNewPunchAngVel[i] = flOldPunchAngVel[i];
	}
	
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		if (g_iSlenderID[i] == -1) continue;
		
		if (g_iPlayerStaticMode[client][i] != Static_Increase) continue;
		if (!(g_iSlenderFlags[i] & SFF_HASSTATICSHAKE)) continue;
		
		if (g_flSlenderAnger[i] > flNewStaticShakeMasterAnger)
		{
			new iMaster = SlenderGetFromID(g_iSlenderCopyMaster[i]);
			if (iMaster == -1) iMaster = i;
			
			iNewStaticShakeMaster = iMaster;
			flNewStaticShakeMasterAnger = g_flSlenderAnger[iMaster];
		}
	}
	
	if (iNewStaticShakeMaster != -1)
	{
		g_iPlayerStaticShakeMaster[client] = g_iSlenderID[iNewStaticShakeMaster];
		
		if (iNewStaticShakeMaster != iOldStaticShakeMaster)
		{
			if (g_strPlayerStaticShakeSound[client][0])
			{
				StopSound(client, SNDCHAN_STATIC, g_strPlayerStaticShakeSound[client]);
			}
			
			g_flPlayerStaticShakeMinVolume[client] = GetProfileFloat(g_strSlenderProfile[iNewStaticShakeMaster], "sound_static_shake_local_volume_min", 0.0);
			g_flPlayerStaticShakeMaxVolume[client] = GetProfileFloat(g_strSlenderProfile[iNewStaticShakeMaster], "sound_static_shake_local_volume_max", 1.0);
			
			decl String:sStaticSound[PLATFORM_MAX_PATH];
			GetRandomStringFromProfile(g_strSlenderProfile[iNewStaticShakeMaster], "sound_static_shake_local", sStaticSound, sizeof(sStaticSound));
			if (sStaticSound[0])
			{
				strcopy(g_strPlayerStaticShakeSound[client], sizeof(g_strPlayerStaticShakeSound[]), sStaticSound);
			}
			else
			{
				strcopy(g_strPlayerStaticShakeSound[client], sizeof(g_strPlayerStaticShakeSound[]), "");
			}
		}
	}
	
	if (g_bPlayerInStaticShake[client])
	{
		if (g_flPlayerStaticAmount[client] <= 0.0)
		{
			g_bPlayerInStaticShake[client] = false;
		}
	}
	else
	{
		if (iNewStaticShakeMaster != -1)
		{
			g_bPlayerInStaticShake[client] = true;
		}
	}
	
	if (g_bPlayerInStaticShake[client] && !bOldStaticShake)
	{	
		for (new i = 0; i < 2; i++)
		{
			flNewPunchAng[i] = 0.0;
			flNewPunchAngVel[i] = 0.0;
		}
		
		SetEntDataVector(client, g_offsPlayerPunchAngle, flNewPunchAng, true);
		SetEntDataVector(client, g_offsPlayerPunchAngleVel, flNewPunchAngVel, true);
	}
	else if (!g_bPlayerInStaticShake[client] && bOldStaticShake)
	{
		for (new i = 0; i < 2; i++)
		{
			flNewPunchAng[i] = 0.0;
			flNewPunchAngVel[i] = 0.0;
		}
	
		g_iPlayerStaticShakeMaster[client] = -1;
		
		if (g_strPlayerStaticShakeSound[client][0])
		{
			StopSound(client, SNDCHAN_STATIC, g_strPlayerStaticShakeSound[client]);
		}
		
		strcopy(g_strPlayerStaticShakeSound[client], sizeof(g_strPlayerStaticShakeSound[]), "");
		
		g_flPlayerStaticShakeMinVolume[client] = 0.0;
		g_flPlayerStaticShakeMaxVolume[client] = 0.0;
		
		SetEntDataVector(client, g_offsPlayerPunchAngle, flNewPunchAng, true);
		SetEntDataVector(client, g_offsPlayerPunchAngleVel, flNewPunchAngVel, true);
	}
	
	if (g_bPlayerInStaticShake[client])
	{
		if (g_strPlayerStaticShakeSound[client][0])
		{
			new Float:flVolume = g_flPlayerStaticAmount[client];
			if (GetRandomFloat(0.0, 1.0) <= 0.35)
			{
				flVolume = 0.0;
			}
			else
			{
				if (flVolume < g_flPlayerStaticShakeMinVolume[client])
				{
					flVolume = g_flPlayerStaticShakeMinVolume[client];
				}
				
				if (flVolume > g_flPlayerStaticShakeMaxVolume[client])
				{
					flVolume = g_flPlayerStaticShakeMaxVolume[client];
				}
			}
			
			EmitSoundToClient(client, g_strPlayerStaticShakeSound[client], _, SNDCHAN_STATIC, SNDLEVEL_NONE, SND_CHANGEVOL | SND_STOP, flVolume);
		}
		
		// Spazz our view all over the place.
		for (new i = 0; i < 2; i++) flNewPunchAng[i] = AngleNormalize(GetRandomFloat(0.0, 360.0));
		NormalizeVector(flNewPunchAng, flNewPunchAng);
		
		new Float:flAngVelocityScalar = 5.0 * g_flPlayerStaticAmount[client];
		if (flAngVelocityScalar < 1.0) flAngVelocityScalar = 1.0;
		ScaleVector(flNewPunchAng, flAngVelocityScalar);
		
		if (!IsFakeClient(client))
		{
			// Latency compensation.
			new Float:flLatency = GetClientLatency(client, NetFlow_Outgoing);
			new Float:flLatencyCalcDiff = 85.0 * Pow(flLatency, 2.0);
			
			for (new i = 0; i < 2; i++) flNewPunchAng[i] += (flNewPunchAng[i] * flLatencyCalcDiff);
		}
		
		for (new i = 0; i < 2; i++) flNewPunchAngVel[i] = 0.0;
		
		SetEntDataVector(client, g_offsPlayerPunchAngle, flNewPunchAng, true);
		SetEntDataVector(client, g_offsPlayerPunchAngleVel, flNewPunchAngVel, true);
	}
}

ClientProcessVisibility(client)
{
	if (!IsClientInGame(client) || !IsPlayerAlive(client)) return;
	
	new String:sProfile[SF2_MAX_PROFILE_NAME_LENGTH];
	
	new bool:bWasSeeingSlender[MAX_BOSSES];
	new iOldStaticMode[MAX_BOSSES];
	
	decl Float:flSlenderPos[3];
	decl Float:flSlenderEyePos[3];
	decl Float:flSlenderOBBCenterPos[3];
	
	decl Float:flMyPos[3];
	GetClientAbsOrigin(client, flMyPos);
	
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		bWasSeeingSlender[i] = g_bPlayerSeesSlender[client][i];
		iOldStaticMode[i] = g_iPlayerStaticMode[client][i];
		g_bPlayerSeesSlender[client][i] = false;
		g_iPlayerStaticMode[client][i] = Static_None;
		
		if (g_iSlenderID[i] == -1) continue;
		
		strcopy(sProfile, sizeof(sProfile), g_strSlenderProfile[i]);
		if (!sProfile[0]) continue;
		
		new iBoss = EntRefToEntIndex(g_iSlender[i]);
		
		if (iBoss && iBoss != INVALID_ENT_REFERENCE)
		{
			SlenderGetAbsOrigin(i, flSlenderPos);
			SlenderGetEyePosition(i, flSlenderEyePos);
			
			decl Float:flSlenderMins[3], Float:flSlenderMaxs[3];
			GetEntPropVector(iBoss, Prop_Send, "m_vecMins", flSlenderMins);
			GetEntPropVector(iBoss, Prop_Send, "m_vecMaxs", flSlenderMaxs);
			
			for (new i2 = 0; i2 < 3; i2++) flSlenderOBBCenterPos[i2] = flSlenderPos[i2] + ((flSlenderMins[i2] + flSlenderMaxs[i2]) / 2.0);
		}
		
		if (g_bPlayerGhostMode[client])
		{
		}
		else if (!g_bPlayerDeathCam[client])
		{
			if (iBoss && iBoss != INVALID_ENT_REFERENCE)
			{
				new iCopyMaster = SlenderGetFromID(g_iSlenderCopyMaster[i]);
				
				if (!IsPointVisibleToPlayer(client, flSlenderEyePos, true, SlenderUsesBlink(i)))
				{
					g_bPlayerSeesSlender[client][i] = IsPointVisibleToPlayer(client, flSlenderOBBCenterPos, true, SlenderUsesBlink(i));
				}
				else
				{
					g_bPlayerSeesSlender[client][i] = true;
				}
				
				if ((GetGameTime() - g_flPlayerSeesSlenderLastTime[client][i]) > GetProfileFloat(sProfile, "static_on_look_gracetime", 1.0) ||
					(iOldStaticMode[i] == Static_Increase && g_flPlayerStaticAmount[client] > 0.1))
				{
					if ((g_iSlenderFlags[i] & SFF_STATICONLOOK) && 
						g_bPlayerSeesSlender[client][i])
					{
						if (iCopyMaster != -1)
						{
							g_iPlayerStaticMode[client][iCopyMaster] = Static_Increase;
						}
						else
						{
							g_iPlayerStaticMode[client][i] = Static_Increase;
						}
					}
					else if ((g_iSlenderFlags[i] & SFF_STATICONRADIUS) && 
						GetVectorDistance(flMyPos, flSlenderPos) <= g_flSlenderStaticRadius[i])
					{
						new bool:bNoObstacles = IsPointVisibleToPlayer(client, flSlenderEyePos, false, false);
						if (!bNoObstacles) bNoObstacles = IsPointVisibleToPlayer(client, flSlenderOBBCenterPos, false, false);
						
						if (bNoObstacles)
						{
							if (iCopyMaster != -1)
							{
								g_iPlayerStaticMode[client][iCopyMaster] = Static_Increase;
							}
							else
							{
								g_iPlayerStaticMode[client][i] = Static_Increase;
							}
						}
					}
				}
				
				// Process death cam sequence conditions
				if (SlenderKillsOnNear(i))
				{
					if (g_flPlayerStaticAmount[client] >= 1.0 ||
						GetVectorDistance(flMyPos, flSlenderPos) <= g_flSlenderInstaKillRange[i])
					{
						new bool:bKillPlayer = true;
						if (g_flPlayerStaticAmount[client] < 1.0)
						{
							bKillPlayer = IsPointVisibleToPlayer(client, flSlenderEyePos, false, SlenderUsesBlink(i));
						}
						
						if (!bKillPlayer) bKillPlayer = IsPointVisibleToPlayer(client, flSlenderOBBCenterPos, false, SlenderUsesBlink(i));
						
						if (bKillPlayer)
						{
							g_flSlenderLastKill[i] = GetGameTime();
							
							if (g_flPlayerStaticAmount[client] >= 1.0)
							{
								ClientStartDeathCam(client, SlenderGetFromID(g_iPlayerStaticMaster[client]), flSlenderPos);
							}
							else
							{
								ClientStartDeathCam(client, i, flSlenderPos);
							}
						}
					}
				}
			}
		}
		
		new iMaster = SlenderGetFromID(g_iSlenderCopyMaster[i]);
		if (iMaster == -1) iMaster = i;
		
		// Boss visiblity.
		if (g_bPlayerSeesSlender[client][i] && !bWasSeeingSlender[i])
		{
			g_flPlayerSeesSlenderLastTime[client][iMaster] = GetGameTime();
			
			if (GetGameTime() >= g_flPlayerScareNextTime[client][iMaster])
			{
				if (GetVectorDistance(flMyPos, flSlenderPos) <= g_flSlenderScareRadius[i])
				{
					ClientPerformScare(client, iMaster);
					
					if (SlenderHasAttribute(iMaster, "ignite player on scare"))
					{
						new Float:flValue = SlenderGetAttributeValue(iMaster, "ignite player on scare");
						if (flValue > 0.0) TF2_IgnitePlayer(client, client);
					}
				}
				else
				{
					g_flPlayerScareNextTime[client][iMaster] = GetGameTime() + GetProfileFloat(sProfile, "scare_cooldown");
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
			g_flPlayerScareLastTime[client][iMaster] = GetGameTime();
			
			Call_StartForward(fOnClientLooksAwayFromBoss);
			Call_PushCell(client);
			Call_PushCell(i);
			Call_Finish();
		}
		
		if (g_bPlayerSeesSlender[client][i])
		{
			if (GetGameTime() >= g_flPlayerSightSoundNextTime[client][iMaster])
			{
				ClientPerformSightSound(client, i);
			}
		}
		
		if (g_iPlayerStaticMode[client][i] == Static_Increase &&
			iOldStaticMode[i] != Static_Increase)
		{
			if (g_iSlenderFlags[i] & SFF_HASSTATICLOOPLOCALSOUND)
			{
				decl String:sLoopSound[PLATFORM_MAX_PATH];
				GetRandomStringFromProfile(sProfile, "sound_static_loop_local", sLoopSound, sizeof(sLoopSound), 1);
				
				if (sLoopSound[0])
				{
					EmitSoundToClient(client, sLoopSound, iBoss, SNDCHAN_STATIC, GetProfileNum(sProfile, "sound_static_loop_local_level", SNDLEVEL_NORMAL), SND_CHANGEVOL, 1.0);
					ClientAddStress(client, 0.03);
				}
				else
				{
					LogError("Warning! Boss %s supports static loop local sounds, but was given a blank sound path!", sProfile);
				}
			}
		}
		else if (g_iPlayerStaticMode[client][i] != Static_Increase &&
			iOldStaticMode[i] == Static_Increase)
		{
			if (g_iSlenderFlags[i] & SFF_HASSTATICLOOPLOCALSOUND)
			{
				if (iBoss && iBoss != INVALID_ENT_REFERENCE)
				{
					decl String:sLoopSound[PLATFORM_MAX_PATH];
					GetRandomStringFromProfile(sProfile, "sound_static_loop_local", sLoopSound, sizeof(sLoopSound), 1);
					
					if (sLoopSound[0])
					{
						EmitSoundToClient(client, sLoopSound, iBoss, SNDCHAN_STATIC, _, SND_CHANGEVOL | SND_STOP, 0.0);
					}
				}
			}
		}
	}
	
	// Initialize static timers.
	new iBossLastStatic = SlenderGetFromID(g_iPlayerStaticMaster[client]);
	new iBossNewStatic = -1;
	if (iBossLastStatic != -1 && g_iPlayerStaticMode[client][iBossLastStatic] == Static_Increase)
	{
		iBossNewStatic = iBossLastStatic;
	}
	
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		new iStaticMode = g_iPlayerStaticMode[client][i];
		
		// Determine new static rates.
		if (iStaticMode != Static_Increase) continue;
		
		if (iBossLastStatic == -1 || 
			g_iPlayerStaticMode[client][iBossLastStatic] != Static_Increase || 
			g_flSlenderAnger[i] > g_flSlenderAnger[iBossLastStatic])
		{
			iBossNewStatic = i;
		}
	}
	
	if (iBossNewStatic != -1)
	{
		new iCopyMaster = SlenderGetFromID(g_iSlenderCopyMaster[iBossNewStatic]);
		if (iCopyMaster != -1)
		{
			iBossNewStatic = iCopyMaster;
			g_iPlayerStaticMaster[client] = g_iSlenderID[iCopyMaster];
		}
		else
		{
			g_iPlayerStaticMaster[client] = g_iSlenderID[iBossNewStatic];
		}
	}
	else
	{
		g_iPlayerStaticMaster[client] = -1;
	}
	
	if (iBossNewStatic != iBossLastStatic)
	{
		if (!StrEqual(g_strPlayerLastStaticSound[client], g_strPlayerStaticSound[client], false))
		{
			// Stop last-last static sound entirely.
			if (g_strPlayerLastStaticSound[client][0])
			{
				StopSound(client, SNDCHAN_STATIC, g_strPlayerLastStaticSound[client]);
			}
		}
		
		// Move everything down towards the last arrays.
		if (g_strPlayerStaticSound[client][0])
		{
			strcopy(g_strPlayerLastStaticSound[client], sizeof(g_strPlayerLastStaticSound[]), g_strPlayerStaticSound[client]);
		}
		
		if (iBossNewStatic == -1)
		{
			// No one is the static master.
			g_hPlayerStaticTimer[client] = CreateTimer(g_flPlayerStaticDecreaseRate[client], 
				Timer_ClientDecreaseStatic, 
				GetClientUserId(client), 
				TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
				
			TriggerTimer(g_hPlayerStaticTimer[client], true);
		}
		else
		{
			strcopy(g_strPlayerStaticSound[client], sizeof(g_strPlayerStaticSound[]), "");
			
			new String:sStaticSound[PLATFORM_MAX_PATH];
			GetRandomStringFromProfile(g_strSlenderProfile[iBossNewStatic], "sound_static", sStaticSound, sizeof(sStaticSound), 1);
			
			if (sStaticSound[0]) 
			{
				strcopy(g_strPlayerStaticSound[client], sizeof(g_strPlayerStaticSound[]), sStaticSound);
			}
			
			// Cross-fade out the static sounds.
			g_flPlayerLastStaticVolume[client] = g_flPlayerStaticAmount[client];
			g_flPlayerLastStaticTime[client] = GetGameTime();
			
			g_hPlayerLastStaticTimer[client] = CreateTimer(0.0, 
				Timer_ClientFadeOutLastStaticSound, 
				GetClientUserId(client), 
				TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
			
			TriggerTimer(g_hPlayerLastStaticTimer[client], true);
			
			// Start up our own static timer.
			new Float:flStaticIncreaseRate = GetProfileFloat(g_strSlenderProfile[iBossNewStatic], "static_rate") / g_flRoundDifficultyModifier;
			new Float:flStaticDecreaseRate = GetProfileFloat(g_strSlenderProfile[iBossNewStatic], "static_rate_decay");
			
			g_flPlayerStaticIncreaseRate[client] = flStaticIncreaseRate;
			g_flPlayerStaticDecreaseRate[client] = flStaticDecreaseRate;
			
			g_hPlayerStaticTimer[client] = CreateTimer(flStaticIncreaseRate, 
				Timer_ClientIncreaseStatic, 
				GetClientUserId(client), 
				TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
			
			TriggerTimer(g_hPlayerStaticTimer[client], true);
		}
	}
}

ClientProcessViewAngles(client)
{
	if ((!g_bPlayerEliminated[client] || g_bPlayerProxy[client]) && 
		!g_bPlayerEscaped[client])
	{
		// Process view bobbing, if enabled.
		// This code is based on the code in this page: https://developer.valvesoftware.com/wiki/Camera_Bob
		// Many thanks to whomever created it in the first place.
		
		if (IsPlayerAlive(client))
		{
			if (g_bPlayerViewbobEnabled)
			{
				new Float:flPunchVel[3];
			
				if (!g_bPlayerViewbobSprintEnabled || !ClientSprintIsValid(client))
				{
					if (GetEntityFlags(client) & FL_ONGROUND)
					{
						decl Float:flVelocity[3];
						GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", flVelocity);
						new Float:flSpeed = GetVectorLength(flVelocity);
						
						new Float:flPunchIdle[3];
						
						if (flSpeed > 0.0)
						{
							if (flSpeed >= 60.0)
							{
								flPunchIdle[0] = Sine(GetGameTime() * SF2_PLAYER_VIEWBOB_TIMER) * flSpeed * SF2_PLAYER_VIEWBOB_SCALE_X / 400.0;
								flPunchIdle[1] = Sine(2.0 * GetGameTime() * SF2_PLAYER_VIEWBOB_TIMER) * flSpeed * SF2_PLAYER_VIEWBOB_SCALE_Y / 400.0;
								flPunchIdle[2] = Sine(1.6 * GetGameTime() * SF2_PLAYER_VIEWBOB_TIMER) * flSpeed * SF2_PLAYER_VIEWBOB_SCALE_Z / 400.0;
								
								AddVectors(flPunchVel, flPunchIdle, flPunchVel);
							}
							
							// Calculate roll.
							decl Float:flForward[3], Float:flVelocityDirection[3];
							GetClientEyeAngles(client, flForward);
							GetVectorAngles(flVelocity, flVelocityDirection);
							
							new Float:flYawDiff = AngleDiff(flForward[1], flVelocityDirection[1]);
							if (FloatAbs(flYawDiff) > 90.0) flYawDiff = AngleDiff(flForward[1] + 180.0, flVelocityDirection[1]) * -1.0;
							
							new Float:flWalkSpeed = ClientGetDefaultWalkSpeed(client);
							new Float:flRollScalar = flSpeed / flWalkSpeed;
							if (flRollScalar > 1.0) flRollScalar = 1.0;
							
							new Float:flRollScale = (flYawDiff / 90.0) * 0.25 * flRollScalar;
							flPunchIdle[0] = 0.0;
							flPunchIdle[1] = 0.0;
							flPunchIdle[2] = flRollScale * -1.0;
							
							AddVectors(flPunchVel, flPunchIdle, flPunchVel);
						}
						
						/*
						if (flSpeed < 60.0) 
						{
							flPunchIdle[0] = FloatAbs(Cosine(GetGameTime() * 1.25) * 0.047);
							flPunchIdle[1] = Sine(GetGameTime() * 1.25) * 0.075;
							flPunchIdle[2] = 0.0;
							
							AddVectors(flPunchVel, flPunchIdle, flPunchVel);
						}
						*/
					}
				}
				
				if (g_bPlayerViewbobHurtEnabled)
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
}

public Action:Timer_ClientIncreaseStatic(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client <= 0) return Plugin_Stop;
	
	if (timer != g_hPlayerStaticTimer[client]) return Plugin_Stop;
	
	g_flPlayerStaticAmount[client] += 0.05;
	if (g_flPlayerStaticAmount[client] > 1.0) g_flPlayerStaticAmount[client] = 1.0;
	
	if (g_strPlayerStaticSound[client][0])
	{
		EmitSoundToClient(client, g_strPlayerStaticSound[client], _, SNDCHAN_STATIC, SNDLEVEL_NONE, SND_CHANGEVOL, g_flPlayerStaticAmount[client]);
		
		if (g_flPlayerStaticAmount[client] >= 0.5) ClientAddStress(client, 0.03);
		else
		{
			ClientAddStress(client, 0.02);
		}
	}
	
	return Plugin_Continue;
}

public Action:Timer_ClientDecreaseStatic(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client <= 0) return Plugin_Stop;
	
	if (timer != g_hPlayerStaticTimer[client]) return Plugin_Stop;
	
	g_flPlayerStaticAmount[client] -= 0.05;
	if (g_flPlayerStaticAmount[client] < 0.0) g_flPlayerStaticAmount[client] = 0.0;
	
	if (g_strPlayerLastStaticSound[client][0])
	{
		new Float:flVolume = g_flPlayerStaticAmount[client];
		if (flVolume > 0.0)
		{
			EmitSoundToClient(client, g_strPlayerLastStaticSound[client], _, SNDCHAN_STATIC, SNDLEVEL_NONE, SND_CHANGEVOL, flVolume);
		}
	}
	
	if (g_flPlayerStaticAmount[client] <= 0.0)
	{
		// I've done my job; no point to keep on doing it.
		StopSound(client, SNDCHAN_STATIC, g_strPlayerLastStaticSound[client]);
		g_hPlayerStaticTimer[client] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public Action:Timer_ClientFadeOutLastStaticSound(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client <= 0) return Plugin_Stop;
	
	if (timer != g_hPlayerLastStaticTimer[client]) return Plugin_Stop;
	
	if (StrEqual(g_strPlayerLastStaticSound[client], g_strPlayerStaticSound[client], false)) 
	{
		// Wait, the player's current static sound is the same one we're stopping. Abort!
		g_hPlayerLastStaticTimer[client] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	if (g_strPlayerLastStaticSound[client][0])
	{
		new Float:flDiff = (GetGameTime() - g_flPlayerLastStaticTime[client]) / 1.0;
		if (flDiff > 1.0) flDiff = 1.0;
		
		new Float:flVolume = g_flPlayerLastStaticVolume[client] - flDiff;
		if (flVolume < 0.0) flVolume = 0.0;
		
		if (flVolume <= 0.0)
		{
			// I've done my job; no point to keep on doing it.
			StopSound(client, SNDCHAN_STATIC, g_strPlayerLastStaticSound[client]);
			g_hPlayerLastStaticTimer[client] = INVALID_HANDLE;
			return Plugin_Stop;
		}
		else
		{
			EmitSoundToClient(client, g_strPlayerLastStaticSound[client], _, SNDCHAN_STATIC, SNDLEVEL_NONE, SND_CHANGEVOL, flVolume);
		}
	}
	else
	{
		// I've done my job; no point to keep on doing it.
		g_hPlayerLastStaticTimer[client] = INVALID_HANDLE;
		return Plugin_Stop;
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

//	==========================================================
//	INTERACTIVE GLOW FUNCTIONS
//	==========================================================

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

//	==========================================================
//	BREATHING FUNCTIONS
//	==========================================================

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

//	==========================================================
//	SPRINTING FUNCTIONS
//	==========================================================

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

//	==========================================================
//	PROXY / GHOST AND GLOW FUNCTIONS
//	==========================================================

ClientResetProxy(client, bool:bResetFull=true)
{
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("START ClientResetProxy(%d)", client);
#endif

	new iOldMaster = SlenderGetFromID(g_iPlayerProxyMaster[client]);
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

ClientStartProxyAvailableTimer(client)
{
	g_bPlayerProxyAvailable[client] = false;
	g_hPlayerProxyAvailableTimer[client] = CreateTimer(GetConVarFloat(g_cvPlayerProxyWaitTime), Timer_ClientProxyAvailable, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

ClientStartProxyForce(client, iSlenderID, const Float:flPos[3])
{
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("START ClientStartProxyForce(%d, %d, flPos)", client, iSlenderID);
#endif

	g_iPlayerProxyAskMaster[client] = iSlenderID;
	for (new i = 0; i < 3; i++) g_iPlayerProxyAskPosition[client][i] = flPos[i];

	g_iPlayerProxyAvailableCount[client] = 0;
	g_bPlayerProxyAvailableInForce[client] = true;
	g_hPlayerProxyAvailableTimer[client] = CreateTimer(1.0, Timer_ClientForceProxy, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	TriggerTimer(g_hPlayerProxyAvailableTimer[client], true);
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("END ClientStartProxyForce(%d, %d, flPos)", client, iSlenderID);
#endif
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
				if (SlenderGetFromID(g_iPlayerProxyMaster[iClient]) != iBossIndex) continue;
				
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
						if (SlenderGetFromID(g_iPlayerProxyMaster[iClient]) != iBossIndex) continue;
						
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
	if (g_iSlenderID[iBossIndex] == -1) return;
	if (!(g_iSlenderFlags[iBossIndex] & SFF_PROXIES)) return;
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
	g_iPlayerProxyMaster[client] = g_iSlenderID[iBossIndex];
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
	
	CreateTimer(0.33, Timer_ApplyCustomModel, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	
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

ClientResetProxyGlow(client)
{
	ClientRemoveProxyGlow(client);
}

ClientRemoveProxyGlow(client)
{
	if (!g_bPlayerHasProxyGlow[client]) return;
	
	g_bPlayerHasProxyGlow[client] = false;
	
	new iGlow = EntRefToEntIndex(g_iPlayerProxyGlowEntity[client]);
	if (iGlow && iGlow != INVALID_ENT_REFERENCE) AcceptEntityInput(iGlow, "Kill");
	
	g_iPlayerProxyGlowEntity[client] = INVALID_ENT_REFERENCE;
}

bool:ClientCreateProxyGlow(client, const String:sAttachment[]="")
{
	ClientRemoveProxyGlow(client);
	
	g_bPlayerHasProxyGlow[client] = true;
	
	new String:sBuffer[PLATFORM_MAX_PATH];
	GetEntPropString(client, Prop_Send, "m_iszCustomModel", sBuffer, sizeof(sBuffer));
	if (!sBuffer[0])
	{
		GetEntPropString(client, Prop_Data, "m_ModelName", sBuffer, sizeof(sBuffer));
	}
	
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
		new iFlags = GetEntProp(iGlow, Prop_Send, "m_usSolidFlags");
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

ClientOnButtonPress(client, button)
{
	switch (button)
	{
		case IN_ATTACK2:
		{
			if (IsPlayerAlive(client))
			{
				if (!g_bRoundWarmup &&
					!g_bRoundIntro &&
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
		case IN_RELOAD:
		{
			if (IsPlayerAlive(client))
			{
				if (!g_bPlayerEliminated[client])
				{
					if (!g_bRoundEnded && 
					!g_bRoundWarmup &&
					!g_bRoundIntro &&
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
							ClientStopSprint(client);
						}
					}
				}
			}
		}
	}
}

//	==========================================================
//	DEATH CAM FUNCTIONS
//	==========================================================

public Action:Hook_DeathCamSetTransmit(slender, other)
{
	if (!g_bEnabled) return Plugin_Continue;

	if (EntRefToEntIndex(g_iPlayerDeathCamEnt2[other]) != slender) return Plugin_Handled;
	return Plugin_Continue;
}

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
	if (iBossIndex < 0 || iBossIndex >= MAX_BOSSES) return;

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

//	==========================================================
//	GHOST MODE FUNCTIONS
//	==========================================================

ClientEnableGhostMode(client)
{
	if (!IsClientInGame(client)) return;
	
	g_bPlayerGhostMode[client] = true;
	
	/*
	// Set solid flags.
	new iFlags = GetEntProp(client, Prop_Send, "m_usSolidFlags");
	if (!(iFlags & FSOLID_NOT_SOLID)) iFlags |= FSOLID_NOT_SOLID;
	if (!(iFlags & FSOLID_TRIGGER)) iFlags |= FSOLID_TRIGGER;
	
	SetEntProp(client, Prop_Send, "m_usSolidFlags", iFlags);
	SetEntProp(client, Prop_Send, "m_CollisionGroup", 1); // COLLISION_GROUP_DEBRIS
	SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", -1);
	SetEntPropEnt(client, Prop_Send, "m_hLastWeapon", -1);
	*/
	
	TF2_AddCondition(client, TFCond_HalloweenGhostMode, -1.0);
	SetEntProp(client, Prop_Send, "m_CollisionGroup", 1); // COLLISION_GROUP_DEBRIS
	
	/*
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
	*/
	
	// Set first observer target.
	ClientGhostModeNextTarget(client);
	ClientActivateUltravision(client);
}

ClientDisableGhostMode(client)
{
	if (!g_bPlayerGhostMode[client]) return;
	
	g_bPlayerGhostMode[client] = false;
	
	if (!IsClientInGame(client)) return;
	
	TF2_RemoveCondition(client, TFCond_HalloweenGhostMode);
	SetEntProp(client, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_PLAYER);
	
	/*
	// Set solid flags.
	new iFlags = GetEntProp(client, Prop_Send, "m_usSolidFlags");
	if (iFlags & FSOLID_NOT_SOLID) iFlags &= ~FSOLID_NOT_SOLID;
	if (iFlags & FSOLID_TRIGGER) iFlags &= ~FSOLID_TRIGGER;
	
	SetEntProp(client, Prop_Send, "m_usSolidFlags", iFlags);
	SetEntProp(client, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_PLAYER);
	
	SetVariantString("");
	AcceptEntityInput(client, "SetCustomModel");
	
	SetEntityRenderMode(client, RENDER_NORMAL);
	SetEntityRenderColor(client, 255, 255, 255, 255);
	
	// Set viewmodel visible.
	new ent = -1;
	while ((ent = FindEntityByClassname(ent, "tf_viewmodel")) != -1)
	{
		if (GetEntPropEnt(ent, Prop_Send, "m_hOwner") == client)
		{
			iFlags = GetEntProp(ent, Prop_Send, "m_fEffects");
			iFlags &= ~32;
			SetEntProp(ent, Prop_Send, "m_fEffects", iFlags);
		}
	}
	*/
}

ClientGhostModeNextTarget(client)
{
	new iLastTarget = EntRefToEntIndex(g_iPlayerGhostModeTarget[client]);
	new iNextTarget = -1;
	new iFirstTarget = -1;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && (!g_bPlayerEliminated[i] || g_bPlayerProxy[i]) && !g_bPlayerGhostMode[i] && !g_bPlayerEscaped[i] && IsPlayerAlive(i))
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
		GetClientEyeAngles(iTarget, flAng);
		GetEntPropVector(iTarget, Prop_Data, "m_vecAbsVelocity", flVelocity);
		TeleportEntity(client, flPos, flAng, flVelocity);
	}
}

//	==========================================================
//	SCARE FUNCTIONS
//	==========================================================

ClientPerformScare(client, iBossIndex)
{
	if (g_iSlenderID[iBossIndex] == -1)
	{
		LogError("Could not perform scare on client %d: boss does not exist!", client);
		return;
	}
	
	decl String:sProfile[SF2_MAX_PROFILE_NAME_LENGTH];
	strcopy(sProfile, sizeof(sProfile), g_strSlenderProfile[iBossIndex]);
	
	g_flPlayerScareLastTime[client][iBossIndex] = GetGameTime();
	g_flPlayerScareNextTime[client][iBossIndex] = GetGameTime() + GetProfileFloat(sProfile, "scare_cooldown");
	
	// See how much Sanity should be drained from a scare.
	new Float:flStaticAmount = GetProfileFloat(sProfile, "scare_static_amount", 0.0);
	g_flPlayerStaticAmount[client] += flStaticAmount;
	if (g_flPlayerStaticAmount[client] > 1.0) g_flPlayerStaticAmount[client] = 1.0;
	
	decl String:sScareSound[PLATFORM_MAX_PATH];
	GetRandomStringFromProfile(sProfile, "sound_scare_player", sScareSound, sizeof(sScareSound));
	
	if (sScareSound[0])
	{
		EmitSoundToClient(client, sScareSound, _, MUSIC_CHAN, SNDLEVEL_NONE);
		
		if (g_iSlenderFlags[iBossIndex] & SFF_HASSIGHTSOUNDS)
		{
			new Float:flCooldownMin = GetProfileFloat(sProfile, "sound_sight_cooldown_min", 8.0);
			new Float:flCooldownMax = GetProfileFloat(sProfile, "sound_sight_cooldown_max", 14.0);
			
			g_flPlayerSightSoundNextTime[client][iBossIndex] = GetGameTime() + GetRandomFloat(flCooldownMin, flCooldownMax);
		}
		
		if (g_flPlayerStress[client] > 0.4)
		{
			ClientAddStress(client, 0.4);
		}
		else
		{
			ClientAddStress(client, 0.66);
		}
	}
	else
	{
		if (g_flPlayerStress[client] > 0.4)
		{
			ClientAddStress(client, 0.3);
		}
		else
		{
			ClientAddStress(client, 0.45);
		}
	}
}

ClientPerformSightSound(client, iBossIndex)
{
	if (g_iSlenderID[iBossIndex] == -1)
	{
		LogError("Could not perform sight sound on client %d: boss does not exist!", client);
		return;
	}
	
	if (!(g_iSlenderFlags[iBossIndex] & SFF_HASSIGHTSOUNDS)) return;
	
	new iMaster = SlenderGetFromID(g_iSlenderCopyMaster[iBossIndex]);
	if (iMaster == -1) iMaster = iBossIndex;
	
	decl String:sProfile[SF2_MAX_PROFILE_NAME_LENGTH];
	strcopy(sProfile, sizeof(sProfile), g_strSlenderProfile[iMaster]);
	
	decl String:sSightSound[PLATFORM_MAX_PATH];
	GetRandomStringFromProfile(sProfile, "sound_sight", sSightSound, sizeof(sSightSound));
	
	if (sSightSound[0])
	{
		EmitSoundToClient(client, sSightSound, _, MUSIC_CHAN, SNDLEVEL_NONE);
		
		new Float:flCooldownMin = GetProfileFloat(sProfile, "sound_sight_cooldown_min", 8.0);
		new Float:flCooldownMax = GetProfileFloat(sProfile, "sound_sight_cooldown_max", 14.0);
		
		g_flPlayerSightSoundNextTime[client][iMaster] = GetGameTime() + GetRandomFloat(flCooldownMin, flCooldownMax);
		
		decl Float:flBossPos[3], Float:flMyPos[3];
		new iBoss = EntRefToEntIndex(g_iSlender[iBossIndex]);
		GetClientAbsOrigin(client, flMyPos);
		GetEntPropVector(iBoss, Prop_Data, "m_vecAbsOrigin", flBossPos);
		new Float:flDistUnComfortZone = 400.0;
		new Float:flBossDist = GetVectorDistance(flMyPos, flBossPos);
		
		new Float:flStressScalar = 1.0 + (flDistUnComfortZone / flBossDist);
		
		ClientAddStress(client, 0.1 * flStressScalar);
	}
	else
	{
		LogError("Warning! %s supports sight sounds, but was given a blank sound!", sProfile);
	}
}

ClientResetScare(client)
{
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("START ClientResetScare(%d)", client);
#endif

	for (new i = 0; i < MAX_BOSSES; i++)
	{
		g_flPlayerScareNextTime[client][i] = -1.0;
		g_flPlayerScareLastTime[client][i] = -1.0;
	}
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("END ClientResetScare(%d)", client);
#endif
}

//	==========================================================
//	ANTI-CAMPING FUNCTIONS
//	==========================================================

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
		new iClosestBoss = -1;
		
		for (new i = 0; i < MAX_BOSSES; i++)
		{
			if (g_iSlenderID[i] == -1) continue;
			
			new iSlender = EntRefToEntIndex(g_iSlender[i]);
			if (!iSlender || iSlender == INVALID_ENT_REFERENCE) continue;
			
			decl Float:flSlenderPos[3];
			SlenderGetAbsOrigin(i, flSlenderPos);
			
			new Float:flDist = GetVectorDistance(flSlenderPos, flPos);
			if (flDist < flDistFromClosestBoss)
			{
				iClosestBoss = i;
				flDistFromClosestBoss = flDist;
			}
		}
		
		if (GetConVarBool(g_cvCampingEnabled) && 
			!g_bRoundGrace && 
			!IsSpaceOccupiedIgnorePlayers(flPos, flMins, flMaxs, client) && 
			g_flPlayerStaticAmount[client] <= GetConVarFloat(g_cvCampingNoStrikeSanity) && 
			(iClosestBoss == -1 || flDistFromClosestBoss >= GetConVarFloat(g_cvCampingNoStrikeBossDistance)) &&
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

//	==========================================================
//	PVP FUNCTIONS
//	==========================================================

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

//	==========================================================
//	BLINK FUNCTIONS
//	==========================================================

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

stock Float:GetClientBlinkRate(client)
{
	new Float:flValue = GetConVarFloat(g_cvPlayerBlinkRate);
	if (GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 3) flValue *= 0.75;
	
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		if (g_bPlayerSeesSlender[client][i]) 
		{
			flValue *= GetProfileFloat(g_strSlenderProfile[i], "blink_look_rate_multiply", 1.0);
		}
		
		else if (g_iPlayerStaticMode[client][i] == Static_Increase)
		{
			flValue *= GetProfileFloat(g_strSlenderProfile[i], "blink_static_rate_multiply", 1.0);
		}
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

//	==========================================================
//	SCREEN OVERLAY FUNCTIONS
//	==========================================================

ClientAddStress(client, Float:flStressAmount)
{
	g_flPlayerStress[client] += flStressAmount;
	if (g_flPlayerStress[client] < 0.0) g_flPlayerStress[client] = 0.0;
	if (g_flPlayerStress[client] > 1.0) g_flPlayerStress[client] = 1.0;
	
	//PrintCenterText(client, "g_flPlayerStress[%d] = %f", client, g_flPlayerStress[client]);
	
	SlenderOnClientStressUpdate(client);
}

stock ClientResetOverlay(client)
{
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("START ClientResetOverlay(%d)", client);
#endif
	
	g_hPlayerOverlayCheck[client] = INVALID_HANDLE;
	
	if (IsClientInGame(client))
	{
		ClientCommand(client, "r_screenoverlay \"\"");
	}
	
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
		return Plugin_Continue;
	}
	else
	{
		strcopy(sMaterial, sizeof(sMaterial), BLACK_OVERLAY);
	}
	
	ClientCommand(client, "r_screenoverlay %s", sMaterial);
	return Plugin_Continue;
}

//	==========================================================
//	MUSIC SYSTEM FUNCTIONS
//	==========================================================

stock ClientUpdateMusicSystem(client, bool:bInitialize=false)
{
	new iOldPageMusicMaster = EntRefToEntIndex(g_iPlayerPageMusicMaster[client]);
	new iOldMusicFlags = g_iPlayerMusicFlags[client];
	new iChasingBoss = -1;
	new iChasingSeeBoss = -1;
	new iAlertBoss = -1;
	new i20DollarsBoss = -1;
	
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
			if (StrEqual(sName, "sf2_escape_custommusic", false))
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
		
		if (g_iPageCount == g_iPageMax && g_bRoundMustEscape && !bPlayMusicOnEscape) 
		{
			ClientRemoveMusicFlag(client, MUSICF_PAGES75PERCENT);
			g_iPlayerPageMusicMaster[client] = INVALID_ENT_REFERENCE;
		}
		
		new iOldChasingBoss = g_iPlayerChaseMusicMaster[client];
		new iOldChasingSeeBoss = g_iPlayerChaseMusicSeeMaster[client];
		new iOldAlertBoss = g_iPlayerAlertMusicMaster[client];
		new iOld20DollarsBoss = g_iPlayer20DollarsMusicMaster[client];
		
		new Float:flAnger = -1.0;
		new Float:flSeeAnger = -1.0;
		new Float:flAlertAnger = -1.0;
		new Float:fl20DollarsAnger = -1.0;
		
		decl Float:flBuffer[3], Float:flBuffer2[3], Float:flBuffer3[3];
		for (new i = 0; i < MAX_BOSSES; i++)
		{
			if (!g_strSlenderProfile[i][0]) continue;
			if (SlenderArrayIndexToEntIndex(i) == INVALID_ENT_REFERENCE) continue;
			
			new iBossType = g_iSlenderType[i];
			
			switch (iBossType)
			{
				case 2:
				{
					GetClientAbsOrigin(client, flBuffer);
					SlenderGetAbsOrigin(i, flBuffer3);
					
					new iTarget = EntRefToEntIndex(g_iSlenderTarget[i]);
					if (iTarget != -1)
					{
						GetEntPropVector(iTarget, Prop_Data, "m_vecAbsOrigin", flBuffer2);
						
						if ((g_iSlenderState[i] == STATE_CHASE || g_iSlenderState[i] == STATE_ATTACK || g_iSlenderState[i] == STATE_STUN) &&
							!(g_iSlenderFlags[i] & SFF_MARKEDASFAKE) && 
							(iTarget == client || GetVectorDistance(flBuffer, flBuffer2) <= 850.0 || GetVectorDistance(flBuffer, flBuffer3) <= 850.0 || GetVectorDistance(flBuffer, g_flSlenderGoalPos[i]) <= 850.0))
						{
							decl String:sPath[PLATFORM_MAX_PATH];
							GetRandomStringFromProfile(g_strSlenderProfile[i], "sound_chase_music", sPath, sizeof(sPath), 1);
							if (sPath[0])
							{
								if (g_flSlenderAnger[i] > flAnger)
								{
									flAnger = g_flSlenderAnger[i];
									iChasingBoss = i;
								}
							}
							
							if ((g_iSlenderState[i] == STATE_CHASE || g_iSlenderState[i] == STATE_ATTACK) &&
								PlayerCanSeeSlender(client, i, false))
							{
								if (iOldChasingSeeBoss == -1 || !PlayerCanSeeSlender(client, iOldChasingSeeBoss, false) || (g_flSlenderAnger[i] > flSeeAnger))
								{
									GetRandomStringFromProfile(g_strSlenderProfile[i], "sound_chase_visible", sPath, sizeof(sPath), 1);
									
									if (sPath[0])
									{
										flSeeAnger = g_flSlenderAnger[i];
										iChasingSeeBoss = i;
									}
								}
								
								if (g_b20Dollars)
								{
									if (iOld20DollarsBoss == -1 || !PlayerCanSeeSlender(client, iOld20DollarsBoss, false) || (g_flSlenderAnger[i] > fl20DollarsAnger))
									{
										GetRandomStringFromProfile(g_strSlenderProfile[i], "sound_20dollars_music", sPath, sizeof(sPath), 1);
										
										if (sPath[0])
										{
											fl20DollarsAnger = g_flSlenderAnger[i];
											i20DollarsBoss = i;
										}
									}
								}
							}
						}
					}
					
					if (g_iSlenderState[i] == STATE_ALERT)
					{
						decl String:sPath[PLATFORM_MAX_PATH];
						GetRandomStringFromProfile(g_strSlenderProfile[i], "sound_alert_music", sPath, sizeof(sPath), 1);
						if (!sPath[0]) continue;
					
						if (!(g_iSlenderFlags[i] & SFF_MARKEDASFAKE))
						{
							if (GetVectorDistance(flBuffer, flBuffer3) <= 850.0 || GetVectorDistance(flBuffer, g_flSlenderGoalPos[i]) <= 850.0)
							{
								if (g_flSlenderAnger[i] > flAlertAnger)
								{
									flAlertAnger = g_flSlenderAnger[i];
									iAlertBoss = i;
								}
							}
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
		
		if (iAlertBoss != iOldAlertBoss)
		{
			if (iAlertBoss != -1)
			{
				ClientAddMusicFlag(client, MUSICF_ALERT);
			}
			else
			{
				ClientRemoveMusicFlag(client, MUSICF_ALERT);
			}
		}
		
		if (i20DollarsBoss != iOld20DollarsBoss)
		{
			if (i20DollarsBoss != -1)
			{
				ClientAddMusicFlag(client, MUSICF_20DOLLARS);
			}
			else
			{
				ClientRemoveMusicFlag(client, MUSICF_20DOLLARS);
			}
		}
	}
	
	if (IsValidClient(client))
	{
		new bool:bWasChase = ClientHasMusicFlag2(iOldMusicFlags, MUSICF_CHASE);
		new bool:bChase = ClientHasMusicFlag(client, MUSICF_CHASE);
		new bool:bWasChaseSee = ClientHasMusicFlag2(iOldMusicFlags, MUSICF_CHASEVISIBLE);
		new bool:bChaseSee = ClientHasMusicFlag(client, MUSICF_CHASEVISIBLE);
		new bool:bAlert = ClientHasMusicFlag(client, MUSICF_ALERT);
		new bool:bWasAlert = ClientHasMusicFlag2(iOldMusicFlags, MUSICF_ALERT);
		new bool:b20Dollars = ClientHasMusicFlag(client, MUSICF_20DOLLARS);
		new bool:bWas20Dollars = ClientHasMusicFlag2(iOldMusicFlags, MUSICF_20DOLLARS);
		
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
							ClientMusicStart(client, sPath, _, MUSIC_PAGE_VOLUME, bChase || bAlert);
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
			ClientMusicStart(client, MUSIC_GOTPAGES1_SOUND, _, MUSIC_PAGE_VOLUME, bChase || bAlert);
		}
		
		if ((bInitialize || ClientHasMusicFlag2(iOldMusicFlags, MUSICF_PAGES25PERCENT)) && !ClientHasMusicFlag(client, MUSICF_PAGES25PERCENT))
		{
			StopSound(client, MUSIC_CHAN, MUSIC_GOTPAGES2_SOUND);
		}
		else if ((bInitialize || !ClientHasMusicFlag2(iOldMusicFlags, MUSICF_PAGES25PERCENT)) && ClientHasMusicFlag(client, MUSICF_PAGES25PERCENT))
		{
			ClientMusicStart(client, MUSIC_GOTPAGES2_SOUND, _, MUSIC_PAGE_VOLUME, bChase || bAlert);
		}
		
		if ((bInitialize || ClientHasMusicFlag2(iOldMusicFlags, MUSICF_PAGES50PERCENT)) && !ClientHasMusicFlag(client, MUSICF_PAGES50PERCENT))
		{
			StopSound(client, MUSIC_CHAN, MUSIC_GOTPAGES3_SOUND);
		}
		else if ((bInitialize || !ClientHasMusicFlag2(iOldMusicFlags, MUSICF_PAGES50PERCENT)) && ClientHasMusicFlag(client, MUSICF_PAGES50PERCENT))
		{
			ClientMusicStart(client, MUSIC_GOTPAGES3_SOUND, _, MUSIC_PAGE_VOLUME, bChase || bAlert);
		}
		
		if ((bInitialize || ClientHasMusicFlag2(iOldMusicFlags, MUSICF_PAGES75PERCENT)) && !ClientHasMusicFlag(client, MUSICF_PAGES75PERCENT))
		{
			StopSound(client, MUSIC_CHAN, MUSIC_GOTPAGES4_SOUND);
		}
		else if ((bInitialize || !ClientHasMusicFlag2(iOldMusicFlags, MUSICF_PAGES75PERCENT)) && ClientHasMusicFlag(client, MUSICF_PAGES75PERCENT))
		{
			ClientMusicStart(client, MUSIC_GOTPAGES4_SOUND, _, MUSIC_PAGE_VOLUME, bChase || bAlert);
		}
		
		new iMainMusicState = 0;
		
		if (bAlert != bWasAlert || iAlertBoss != g_iPlayerAlertMusicMaster[client])
		{
			if (bAlert && !bChase)
			{
				ClientAlertMusicStart(client, iAlertBoss);
				if (!bWasAlert) iMainMusicState = -1;
			}
			else
			{
				ClientAlertMusicStop(client, g_iPlayerAlertMusicMaster[client]);
				if (!bChase && bWasAlert) iMainMusicState = 1;
			}
		}
		
		if (bChase != bWasChase || iChasingBoss != g_iPlayerChaseMusicMaster[client])
		{
			if (bChase)
			{
				ClientMusicChaseStart(client, iChasingBoss);
				
				if (!bWasChase)
				{
					iMainMusicState = -1;
					
					if (bAlert)
					{
						ClientAlertMusicStop(client, g_iPlayerAlertMusicMaster[client]);
					}
				}
			}
			else
			{
				ClientMusicChaseStop(client, g_iPlayerChaseMusicMaster[client]);
				if (bWasChase)
				{
					if (bAlert)
					{
						ClientAlertMusicStart(client, iAlertBoss);
					}
					else
					{
						iMainMusicState = 1;
					}
				}
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
		
		if (b20Dollars != bWas20Dollars || i20DollarsBoss != g_iPlayer20DollarsMusicMaster[client])
		{
			if (b20Dollars)
			{
				Client20DollarsMusicStart(client, i20DollarsBoss);
			}
			else
			{
				Client20DollarsMusicStop(client, g_iPlayer20DollarsMusicMaster[client]);
			}
		}
		
		if (iMainMusicState == 1)
		{
			ClientMusicStart(client, g_strPlayerMusic[client], _, MUSIC_PAGE_VOLUME, bChase || bAlert);
		}
		else if (iMainMusicState == -1)
		{
			ClientMusicStop(client);
		}
		
		if (bChase || bAlert)
		{
			new iBossToUse = -1;
			if (bChase)
			{
				iBossToUse = iChasingBoss;
			}
			else
			{
				iBossToUse = iAlertBoss;
			}
			
			if (iBossToUse != -1)
			{
				// We got some alert/chase music going on! The player's excitement will no doubt go up!
				// Excitement, though, really depends on how close the boss is in relation to the
				// player.
				
				new Float:flBossDist = SlenderGetDistanceFromPlayer(iBossToUse, client);
				new Float:flScalar = flBossDist / 700.0
				if (flScalar > 1.0) flScalar = 1.0;
				new Float:flStressAdd = 0.1 * (1.0 - flScalar);
				
				ClientAddStress(client, flStressAdd);
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

stock Client20DollarsMusicReset(client)
{
	new String:sOldMusic[PLATFORM_MAX_PATH];
	strcopy(sOldMusic, sizeof(sOldMusic), g_strPlayer20DollarsMusic[client]);
	strcopy(g_strPlayer20DollarsMusic[client], sizeof(g_strPlayer20DollarsMusic[]), "");
	if (IsClientInGame(client) && sOldMusic[0]) StopSound(client, MUSIC_CHAN, sOldMusic);
	
	g_iPlayer20DollarsMusicMaster[client] = -1;
	
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		g_hPlayer20DollarsMusicTimer[client][i] = INVALID_HANDLE;
		g_flPlayer20DollarsMusicVolumes[client][i] = 0.0;
		
		if (g_strSlenderProfile[i][0])
		{
			if (IsClientInGame(client))
			{
				GetRandomStringFromProfile(g_strSlenderProfile[i], "sound_20dollars_music", sOldMusic, sizeof(sOldMusic), 1);
				if (sOldMusic[0]) StopSound(client, MUSIC_CHAN, sOldMusic);
			}
		}
	}
}

stock Client20DollarsMusicStart(client, iBossIndex)
{
	if (!IsClientInGame(client)) return;
	
	new iOldMaster = g_iPlayer20DollarsMusicMaster[client];
	if (iOldMaster == iBossIndex) return;
	
	new String:sBuffer[PLATFORM_MAX_PATH];
	GetRandomStringFromProfile(g_strSlenderProfile[iBossIndex], "sound_20dollars_music", sBuffer, sizeof(sBuffer), 1);
	
	if (!sBuffer[0]) return;
	
	g_iPlayer20DollarsMusicMaster[client] = iBossIndex;
	strcopy(g_strPlayer20DollarsMusic[client], sizeof(g_strPlayer20DollarsMusic[]), sBuffer);
	g_hPlayer20DollarsMusicTimer[client][iBossIndex] = CreateTimer(0.01, Timer_PlayerFadeIn20DollarsMusic, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	TriggerTimer(g_hPlayer20DollarsMusicTimer[client][iBossIndex], true);
	
	if (iOldMaster != -1)
	{
		ClientAlertMusicStop(client, iOldMaster);
	}
}

stock Client20DollarsMusicStop(client, iBossIndex)
{
	if (!IsClientInGame(client)) return;
	if (iBossIndex == -1) return;
	
	if (iBossIndex == g_iPlayer20DollarsMusicMaster[client])
	{
		g_iPlayer20DollarsMusicMaster[client] = -1;
		strcopy(g_strPlayer20DollarsMusic[client], sizeof(g_strPlayer20DollarsMusic[]), "");
	}
	
	g_hPlayer20DollarsMusicTimer[client][iBossIndex] = CreateTimer(0.01, Timer_PlayerFadeOut20DollarsMusic, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	TriggerTimer(g_hPlayer20DollarsMusicTimer[client][iBossIndex], true);
}

stock ClientAlertMusicReset(client)
{
	new String:sOldMusic[PLATFORM_MAX_PATH];
	strcopy(sOldMusic, sizeof(sOldMusic), g_strPlayerAlertMusic[client]);
	strcopy(g_strPlayerAlertMusic[client], sizeof(g_strPlayerAlertMusic[]), "");
	if (IsClientInGame(client) && sOldMusic[0]) StopSound(client, MUSIC_CHAN, sOldMusic);
	
	g_iPlayerAlertMusicMaster[client] = -1;
	
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		g_hPlayerAlertMusicTimer[client][i] = INVALID_HANDLE;
		g_flPlayerAlertMusicVolumes[client][i] = 0.0;
		
		if (g_strSlenderProfile[i][0])
		{
			if (IsClientInGame(client))
			{
				GetRandomStringFromProfile(g_strSlenderProfile[i], "sound_alert_music", sOldMusic, sizeof(sOldMusic), 1);
				if (sOldMusic[0]) StopSound(client, MUSIC_CHAN, sOldMusic);
			}
		}
	}
}

stock ClientAlertMusicStart(client, iBossIndex)
{
	if (!IsClientInGame(client)) return;
	
	new iOldMaster = g_iPlayerAlertMusicMaster[client];
	if (iOldMaster == iBossIndex) return;
	
	new String:sBuffer[PLATFORM_MAX_PATH];
	GetRandomStringFromProfile(g_strSlenderProfile[iBossIndex], "sound_alert_music", sBuffer, sizeof(sBuffer), 1);
	
	if (!sBuffer[0]) return;
	
	g_iPlayerAlertMusicMaster[client] = iBossIndex;
	strcopy(g_strPlayerAlertMusic[client], sizeof(g_strPlayerAlertMusic[]), sBuffer);
	g_hPlayerAlertMusicTimer[client][iBossIndex] = CreateTimer(0.01, Timer_PlayerFadeInAlertMusic, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	TriggerTimer(g_hPlayerAlertMusicTimer[client][iBossIndex], true);
	
	if (iOldMaster != -1)
	{
		ClientAlertMusicStop(client, iOldMaster);
	}
}

stock ClientAlertMusicStop(client, iBossIndex)
{
	if (!IsClientInGame(client)) return;
	if (iBossIndex == -1) return;
	
	if (iBossIndex == g_iPlayerAlertMusicMaster[client])
	{
		g_iPlayerAlertMusicMaster[client] = -1;
		strcopy(g_strPlayerAlertMusic[client], sizeof(g_strPlayerAlertMusic[]), "");
	}
	
	g_hPlayerAlertMusicTimer[client][iBossIndex] = CreateTimer(0.01, Timer_PlayerFadeOutAlertMusic, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	TriggerTimer(g_hPlayerAlertMusicTimer[client][iBossIndex], true);
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
				GetRandomStringFromProfile(g_strSlenderProfile[i], "sound_chase_music", sOldMusic, sizeof(sOldMusic), 1);
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
	GetRandomStringFromProfile(g_strSlenderProfile[iBossIndex], "sound_chase_music", sBuffer, sizeof(sBuffer), 1);
	
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

public Action:Timer_PlayerFadeIn20DollarsMusic(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client <= 0) return Plugin_Stop;
	
	new iBossIndex = -1;
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		if (g_hPlayer20DollarsMusicTimer[client][i] == timer)
		{
			iBossIndex = i;
			break;
		}
	}
	
	if (iBossIndex == -1) return Plugin_Stop;
	
	g_flPlayer20DollarsMusicVolumes[client][iBossIndex] += 0.07;
	if (g_flPlayer20DollarsMusicVolumes[client][iBossIndex] > 1.0) g_flPlayer20DollarsMusicVolumes[client][iBossIndex] = 1.0;

	if (g_strPlayer20DollarsMusic[client][0]) EmitSoundToClient(client, g_strPlayer20DollarsMusic[client], _, MUSIC_CHAN, _, SND_CHANGEVOL, g_flPlayer20DollarsMusicVolumes[client][iBossIndex]);
	
	if (g_flPlayer20DollarsMusicVolumes[client][iBossIndex] >= 1.0)
	{
		g_hPlayer20DollarsMusicTimer[client][iBossIndex] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public Action:Timer_PlayerFadeOut20DollarsMusic(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client <= 0) return Plugin_Stop;

	new iBossIndex = -1;
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		if (g_hPlayer20DollarsMusicTimer[client][i] == timer)
		{
			iBossIndex = i;
			break;
		}
	}
	
	if (iBossIndex == -1) return Plugin_Stop;
	
	decl String:sBuffer[PLATFORM_MAX_PATH];
	GetRandomStringFromProfile(g_strSlenderProfile[iBossIndex], "sound_20dollars_music", sBuffer, sizeof(sBuffer), 1);

	if (StrEqual(sBuffer, g_strPlayer20DollarsMusic[client], false))
	{
		g_hPlayer20DollarsMusicTimer[client][iBossIndex] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	g_flPlayer20DollarsMusicVolumes[client][iBossIndex] -= 0.07;
	if (g_flPlayer20DollarsMusicVolumes[client][iBossIndex] < 0.0) g_flPlayer20DollarsMusicVolumes[client][iBossIndex] = 0.0;

	if (sBuffer[0]) EmitSoundToClient(client, sBuffer, _, MUSIC_CHAN, _, SND_CHANGEVOL, g_flPlayer20DollarsMusicVolumes[client][iBossIndex]);
	
	if (g_flPlayer20DollarsMusicVolumes[client][iBossIndex] <= 0.0)
	{
		g_hPlayer20DollarsMusicTimer[client][iBossIndex] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public Action:Timer_PlayerFadeInAlertMusic(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client <= 0) return Plugin_Stop;

	new iBossIndex = -1;
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		if (g_hPlayerAlertMusicTimer[client][i] == timer)
		{
			iBossIndex = i;
			break;
		}
	}
	
	if (iBossIndex == -1) return Plugin_Stop;
	
	g_flPlayerAlertMusicVolumes[client][iBossIndex] += 0.07;
	if (g_flPlayerAlertMusicVolumes[client][iBossIndex] > 1.0) g_flPlayerAlertMusicVolumes[client][iBossIndex] = 1.0;

	if (g_strPlayerAlertMusic[client][0]) EmitSoundToClient(client, g_strPlayerAlertMusic[client], _, MUSIC_CHAN, _, SND_CHANGEVOL, g_flPlayerAlertMusicVolumes[client][iBossIndex]);
	
	if (g_flPlayerAlertMusicVolumes[client][iBossIndex] >= 1.0)
	{
		g_hPlayerAlertMusicTimer[client][iBossIndex] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public Action:Timer_PlayerFadeOutAlertMusic(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client <= 0) return Plugin_Stop;

	new iBossIndex = -1;
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		if (g_hPlayerAlertMusicTimer[client][i] == timer)
		{
			iBossIndex = i;
			break;
		}
	}
	
	if (iBossIndex == -1) return Plugin_Stop;
	
	decl String:sBuffer[PLATFORM_MAX_PATH];
	GetRandomStringFromProfile(g_strSlenderProfile[iBossIndex], "sound_alert_music", sBuffer, sizeof(sBuffer), 1);

	if (StrEqual(sBuffer, g_strPlayerAlertMusic[client], false))
	{
		g_hPlayerAlertMusicTimer[client][iBossIndex] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	g_flPlayerAlertMusicVolumes[client][iBossIndex] -= 0.07;
	if (g_flPlayerAlertMusicVolumes[client][iBossIndex] < 0.0) g_flPlayerAlertMusicVolumes[client][iBossIndex] = 0.0;

	if (sBuffer[0]) EmitSoundToClient(client, sBuffer, _, MUSIC_CHAN, _, SND_CHANGEVOL, g_flPlayerAlertMusicVolumes[client][iBossIndex]);
	
	if (g_flPlayerAlertMusicVolumes[client][iBossIndex] <= 0.0)
	{
		g_hPlayerAlertMusicTimer[client][iBossIndex] = INVALID_HANDLE;
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
	GetRandomStringFromProfile(g_strSlenderProfile[iBossIndex], "sound_chase_music", sBuffer, sizeof(sBuffer), 1);

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

//	==========================================================
//	MISC FUNCTIONS
//	==========================================================

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

stock ClientUpdateListeningFlags(client, bool:bReset=false)
{
	if (!IsClientInGame(client)) return;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (i == client || !IsClientInGame(i)) continue;
		
		if (bReset || g_bRoundEnded || GetConVarBool(g_cvAllChat))
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

stock ClientResetSlenderStats(client)
{
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("START ClientResetSlenderStats(%d)", client);
#endif
	
	g_flPlayerStress[client] = 0.0;
	g_flPlayerStressNextUpdateTime[client] = -1.0;
	
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		g_bPlayerSeesSlender[client][i] = false;
		g_flPlayerSeesSlenderLastTime[client][i] = -1.0;
		g_flPlayerSightSoundNextTime[client][i] = -1.0;
	}
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("END ClientResetSlenderStats(%d)", client);
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
	Format(s, sizeof(s), "%d ; %d ; %d ; 0 ; %d", g_iPlayerQueuePoints[client], g_bPlayerShowHints[client], g_iPlayerMuteMode[client], g_bPlayerWantsTheP[client]);
	SetClientCookie(client, g_hCookie, s);
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

stock ClientViewPunch(client, const Float:angleOffset[3])
{
	if (g_offsPlayerPunchAngleVel == -1) return;
	
	decl Float:flOffset[3];
	for (new i = 0; i < 3; i++) flOffset[i] = angleOffset[i];
	ScaleVector(flOffset, 20.0);
	
	if (!IsFakeClient(client))
	{
		// Latency compensation.
		new Float:flLatency = GetClientLatency(client, NetFlow_Outgoing);
		new Float:flLatencyCalcDiff = 60.0 * Pow(flLatency, 2.0);
		
		for (new i = 0; i < 3; i++) flOffset[i] += (flOffset[i] * flLatencyCalcDiff);
	}
	
	decl Float:flAngleVel[3];
	GetEntDataVector(client, g_offsPlayerPunchAngleVel, flAngleVel);
	AddVectors(flAngleVel, flOffset, flOffset);
	SetEntDataVector(client, g_offsPlayerPunchAngleVel, flOffset, true);
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
		if (!IsPlayerAlive(other) || (!g_bPlayerProxy[other] && !g_bPlayerGhostMode[other])) return Plugin_Handled;
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

#define EF_DIMLIGHT (1 << 2)

stock ClientSDKFlashlightTurnOn(client)
{
	if (!IsValidClient(client)) return;
	
	new iEffects = GetEntProp(client, Prop_Send, "m_fEffects");
	if (iEffects & EF_DIMLIGHT) return;

	iEffects |= EF_DIMLIGHT;
	
	SetEntProp(client, Prop_Send, "m_fEffects", iEffects);
}

stock ClientSDKFlashlightTurnOff(client)
{
	if (!IsValidClient(client)) return;
	
	new iEffects = GetEntProp(client, Prop_Send, "m_fEffects");
	if (!(iEffects & EF_DIMLIGHT)) return;

	iEffects &= ~EF_DIMLIGHT;
	
	SetEntProp(client, Prop_Send, "m_fEffects", iEffects);
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
	GetClientEyePosition(client, eyePos);
	
	// Check fog, if we can.
	if (g_offsPlayerFogCtrl != -1 && g_offsFogCtrlEnable != -1 && g_offsFogCtrlEnd != -1)
	{
		new iFogEntity = GetEntDataEnt2(client, g_offsPlayerFogCtrl);
		if (IsValidEdict(iFogEntity))
		{
			if (GetEntData(iFogEntity, g_offsFogCtrlEnable) &&
				GetVectorDistance(eyePos, pos) >= GetEntDataFloat(iFogEntity, g_offsFogCtrlEnd)) 
			{
				return false;
			}
		}
	}
	
	new Handle:hTrace = TR_TraceRayFilterEx(eyePos, pos, CONTENTS_SOLID | CONTENTS_MOVEABLE | CONTENTS_MIST, RayType_EndPoint, TraceRayDontHitPlayersOrEntity, client);
	new bool:bHit = TR_DidHit(hTrace);
	CloseHandle(hTrace);
	
	if (bHit) return false;
	
	if (bCheckFOV)
	{
		decl Float:eyeAng[3], Float:reqVisibleAng[3];
		GetClientEyeAngles(client, eyeAng);
		
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

// Removes wearables such as botkillers from weapons.
stock TF2_RemoveWeaponSlotAndWearables(client, iSlot)
{
	new iWeapon = GetPlayerWeaponSlot(client, iSlot);
	if (!IsValidEntity(iWeapon)) return;
	
	new iWearable = INVALID_ENT_REFERENCE;
	while ((iWearable = FindEntityByClassname(iWearable, "tf_wearable")) != -1)
	{
		new iWeaponAssociated = GetEntPropEnt(iWearable, Prop_Send, "m_hWeaponAssociatedWith");
		if (iWeaponAssociated == iWeapon)
		{
			AcceptEntityInput(iWearable, "Kill");
		}
	}
	
	iWearable = INVALID_ENT_REFERENCE;
	while ((iWearable = FindEntityByClassname(iWearable, "tf_wearable_vm")) != -1)
	{
		new iWeaponAssociated = GetEntPropEnt(iWearable, Prop_Send, "m_hWeaponAssociatedWith");
		if (iWeaponAssociated == iWeapon)
		{
			AcceptEntityInput(iWearable, "Kill");
		}
	}
	
	TF2_RemoveWeaponSlot(client, iSlot);
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
			
			/*
			if (g_bPlayerGhostMode[client]) 
			{
				bRemoveWeapons = true;
				
				// Set viewmodel invisible.
				new ent = -1;
				while ((ent = FindEntityByClassname(ent, "tf_viewmodel")) != -1)
				{
					if (GetEntPropEnt(ent, Prop_Send, "m_hOwner") == client)
					{
						new iFlags = GetEntProp(ent, Prop_Send, "m_fEffects");
						iFlags |= 32;
						SetEntProp(ent, Prop_Send, "m_fEffects", iFlags);
					}
				}
			}
			
			if (bRemoveActionSlotItem)
			{
				new ent = -1;
				while ((ent = FindEntityByClassname(ent, "tf_wearable")) != -1)
				{
					if (GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity") == client)
					{
						new iItemDef = GetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex");
						switch (iItemDef)
						{
							case 167, 438, 463, 477:
							{
								AcceptEntityInput(ent, "Kill");
							}
						}
					}
				}
			}
			*/
			
			if (bRemoveWeapons)
			{
				for (new i = 0; i <= 5; i++)
				{
					if (i == TFWeaponSlot_Melee) continue;
					TF2_RemoveWeaponSlotAndWearables(client, i);
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
				
				ClientSwitchToWeaponSlot(client, TFWeaponSlot_Melee);
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
								TF2_RemoveWeaponSlotAndWearables(client, iSlot);
								
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
		}
	}
}

public Action:Timer_ApplyCustomModel(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client <= 0) return;
	
	new iMaster = SlenderGetFromID(g_iPlayerProxyMaster[client]);
	
	if (g_bPlayerProxy[client] && iMaster != -1)
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
		
		if (IsPlayerAlive(client))
		{
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
			if (!StrContains(sName, "sf2_escape_spawnpoint", false))
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