#if defined _sf2_stocks_included
 #endinput
#endif
#define _sf2_stocks_included


// Hud Element hiding flags (possibly outdated)
#define	HIDEHUD_WEAPONSELECTION		( 1<<0 )	// Hide ammo count & weapon selection
#define	HIDEHUD_FLASHLIGHT			( 1<<1 )
#define	HIDEHUD_ALL					( 1<<2 )
#define HIDEHUD_HEALTH				( 1<<3 )	// Hide health & armor / suit battery
#define HIDEHUD_PLAYERDEAD			( 1<<4 )	// Hide when local player's dead
#define HIDEHUD_NEEDSUIT			( 1<<5 )	// Hide when the local player doesn't have the HEV suit
#define HIDEHUD_MISCSTATUS			( 1<<6 )	// Hide miscellaneous status elements (trains, pickup history, death notices, etc)
#define HIDEHUD_CHAT				( 1<<7 )	// Hide all communication elements (saytext, voice icon, etc)
#define	HIDEHUD_CROSSHAIR			( 1<<8 )	// Hide crosshairs
#define	HIDEHUD_VEHICLE_CROSSHAIR	( 1<<9 )	// Hide vehicle crosshair
#define HIDEHUD_INVEHICLE			( 1<<10 )
#define HIDEHUD_BONUS_PROGRESS		( 1<<11 )	// Hide bonus progress display (for bonus map challenges)

#define FFADE_IN            0x0001        // Just here so we don't pass 0 into the function
#define FFADE_OUT           0x0002        // Fade out (not in)
#define FFADE_MODULATE      0x0004        // Modulate (don't blend)
#define FFADE_STAYOUT       0x0008        // ignores the duration, stays faded out until new ScreenFade message received
#define FFADE_PURGE         0x0010        // Purges all other fades, replacing them with this one

#define MAX_BUTTONS 25

#define FSOLID_CUSTOMRAYTEST 0x0001
#define FSOLID_CUSTOMBOXTEST 0x0002
#define FSOLID_NOT_SOLID 0x0004
#define FSOLID_TRIGGER 0x0008

#define COLLISION_GROUP_DEBRIS 1
#define COLLISION_GROUP_PLAYER 5

#define EFL_FORCE_CHECK_TRANSMIT (1 << 7)

stock ForceTeamWin(team)
{
	new ent = FindEntityByClassname(-1, "team_control_point_master");
	if (ent == -1)
	{
		ent = CreateEntityByName("team_control_point_master");
		DispatchSpawn(ent);
		AcceptEntityInput(ent, "Enable");
	}
	
	SetVariantInt(team);
	AcceptEntityInput(ent, "SetWinner");
}

stock GameTextTFMessage(const String:message[], const String:icon[]="")
{
	new ent = CreateEntityByName("game_text_tf");
	DispatchKeyValue(ent, "message", message);
	DispatchKeyValue(ent, "display_to_team", "0");
	DispatchKeyValue(ent, "icon", icon);
	DispatchSpawn(ent);
	AcceptEntityInput(ent, "Display");
	AcceptEntityInput(ent, "Kill");
}

stock FloatToTimeHMS(Float:time, &h, &m, &s)
{
	s = RoundFloat(time);
	h = s / 3600;
	s -= h * 3600;
	m = s / 60;
	s = s % 60;
}

stock bool:IsSpaceOccupied(const Float:pos[3], const Float:mins[3], const Float:maxs[3], entity=-1, &ref=-1)
{
	new Handle:hTrace = TR_TraceHullFilterEx(pos, pos, mins, maxs, MASK_VISIBLE, TraceRayDontHitEntity, entity);
	new bool:bHit = TR_DidHit(hTrace);
	ref = TR_GetEntityIndex(hTrace);
	CloseHandle(hTrace);
	return bHit;
}

stock bool:IsSpaceOccupiedPlayer(const Float:pos[3], const Float:mins[3], const Float:maxs[3], entity=-1, &ref=-1)
{
	new Handle:hTrace = TR_TraceHullFilterEx(pos, pos, mins, maxs, MASK_PLAYERSOLID, TraceRayDontHitEntity, entity);
	new bool:bHit = TR_DidHit(hTrace);
	ref = TR_GetEntityIndex(hTrace);
	CloseHandle(hTrace);
	return bHit;
}

stock bool:IsSpaceOccupiedNPC(const Float:pos[3], const Float:mins[3], const Float:maxs[3], entity=-1, &ref=-1)
{
	new Handle:hTrace = TR_TraceHullFilterEx(pos, pos, mins, maxs, MASK_NPCSOLID, TraceRayDontHitEntity, entity);
	new bool:bHit = TR_DidHit(hTrace);
	ref = TR_GetEntityIndex(hTrace);
	CloseHandle(hTrace);
	return bHit;
}

stock ClientSwitchToWeaponSlot(client, iSlot)
{
	new iWeapon = GetPlayerWeaponSlot(client, iSlot);
	if (iWeapon == -1) return;
	
	// EquipPlayerWeapon(client, iWeapon); // doesn't work with TF2 that well.
	SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", iWeapon);
}

stock Float:GetClassBaseSpeed(TFClassType:class)
{
	switch (class)
	{
		case TFClass_Scout:
		{
			return 400.0;
		}
		case TFClass_Soldier:
		{
			return 240.0;
		}
		case TFClass_Pyro:
		{
			return 300.0;
		}
		case TFClass_DemoMan:
		{
			return 280.0;
		}
		case TFClass_Heavy:
		{
			return 230.0;
		}
		case TFClass_Engineer:
		{
			return 300.0;
		}
		case TFClass_Medic:
		{
			return 320.0;
		}
		case TFClass_Sniper:
		{
			return 300.0;
		}
		case TFClass_Spy:
		{
			return 300.0;
		}
	}
	
	return 0.0;
}

stock Float:EntityDistanceFromEntity(ent1, ent2)
{
	if (!IsValidEntity(ent1) || !IsValidEntity(ent2)) return -1.0;
	
	decl Float:flMyPos[3], Float:flHisPos[3];
	GetEntPropVector(ent1, Prop_Data, "m_vecAbsOrigin", flMyPos);
	GetEntPropVector(ent2, Prop_Data, "m_vecAbsOrigin", flHisPos);
	return GetVectorDistance(flMyPos, flHisPos);
}

stock bool:IsEntityClassname(iEnt, const String:classname[], bool:bCaseSensitive=true)
{
	if (!IsValidEntity(iEnt)) return false;
	
	decl String:sBuffer[256];
	GetEntityClassname(iEnt, sBuffer, sizeof(sBuffer));
	
	return StrEqual(sBuffer, classname, bCaseSensitive);
}

stock TE_SetupTFParticleEffect(iParticleSystemIndex, const Float:flOrigin[3], const Float:flStart[3]=NULL_VECTOR, iAttachType=0, iEntIndex=-1, iAttachmentPointIndex=0, bool:bControlPoint1=false, const Float:flControlPoint1Offset[3]=NULL_VECTOR)
{
	TE_Start("TFParticleEffect");
	TE_WriteFloat("m_vecOrigin[0]", flOrigin[0]);
	TE_WriteFloat("m_vecOrigin[1]", flOrigin[1]);
	TE_WriteFloat("m_vecOrigin[2]", flOrigin[2]);
	TE_WriteFloat("m_vecStart[0]", flStart[0]);
	TE_WriteFloat("m_vecStart[1]", flStart[1]);
	TE_WriteFloat("m_vecStart[2]", flStart[2]);
	TE_WriteNum("m_iParticleSystemIndex", iParticleSystemIndex);
	TE_WriteNum("m_iAttachType", iAttachType);
	TE_WriteNum("entindex", iEntIndex);
	TE_WriteNum("m_iAttachmentPointIndex", iAttachmentPointIndex);
	TE_WriteNum("m_bControlPoint1", bControlPoint1);
	TE_WriteFloat("m_ControlPoint1.m_vecOffset[0]", flControlPoint1Offset[0]);
	TE_WriteFloat("m_ControlPoint1.m_vecOffset[1]", flControlPoint1Offset[1]);
	TE_WriteFloat("m_ControlPoint1.m_vecOffset[2]", flControlPoint1Offset[2]);
}

stock PrecacheParticleSystem(const String:particleSystem[])
{
	static particleEffectNames = INVALID_STRING_TABLE;

	if (particleEffectNames == INVALID_STRING_TABLE) {
		if ((particleEffectNames = FindStringTable("ParticleEffectNames")) == INVALID_STRING_TABLE) {
			return INVALID_STRING_INDEX;
		}
	}

	new index = FindStringIndex2(particleEffectNames, particleSystem);
	if (index == INVALID_STRING_INDEX) {
		new numStrings = GetStringTableNumStrings(particleEffectNames);
		if (numStrings >= GetStringTableMaxStrings(particleEffectNames)) {
			return INVALID_STRING_INDEX;
		}
		
		AddToStringTable(particleEffectNames, particleSystem);
		index = numStrings;
	}
	
	return index;
}

stock FindStringIndex2(tableidx, const String:str[])
{
	decl String:buf[1024];
	
	new numStrings = GetStringTableNumStrings(tableidx);
	for (new i=0; i < numStrings; i++) {
		ReadStringTable(tableidx, i, buf, sizeof(buf));
		
		if (StrEqual(buf, str)) {
			return i;
		}
	}
	
	return INVALID_STRING_INDEX;
}

stock Handle:PrepareItemHandle(String:classname[], index, level, quality, String:att[])
{
	new Handle:hItem = TF2Items_CreateItem(OVERRIDE_ALL | FORCE_GENERATION);
	TF2Items_SetClassname(hItem, classname);
	TF2Items_SetItemIndex(hItem, index);
	TF2Items_SetLevel(hItem, level);
	TF2Items_SetQuality(hItem, quality);
	
	// Set attributes.
	new String:atts[32][32];
	new count = ExplodeString(att, " ; ", atts, 32, 32);
	if (count > 0)
	{
		TF2Items_SetNumAttributes(hItem, count / 2);
		new i2 = 0;
		for (new i = 0; i < count; i+= 2)
		{
			TF2Items_SetAttribute(hItem, i2, StringToInt(atts[i]), StringToFloat(atts[i+1]));
			i2++;
		}
	}
	else
	{
		TF2Items_SetNumAttributes(hItem, 0);
	}
	
	return hItem;
}

stock Float:ApproachAngle(Float:target, Float:value, Float:speed)
{
	new Float:delta = AngleDiff(value, target);
	
	if (speed < 0.0) speed = -speed;
	
	if (delta > speed) value += speed;
	else if (delta < -speed) value -= speed;
	else value = target;
	
	return AngleNormalize(value);
}

stock Float:AngleNormalize(Float:angle)
{
	while (angle > 180.0) angle -= 360.0;
	while (angle < -180.0) angle += 360.0;
	return angle;
}

stock Float:AngleDiff(Float:firstAngle, Float:secondAngle)
{
	new Float:diff = secondAngle - firstAngle;
	return AngleNormalize(diff);
}

stock PrecacheSound2(const String:path[])
{
	PrecacheSound(path, true);
	decl String:buffer[PLATFORM_MAX_PATH];
	Format(buffer, sizeof(buffer), "sound/%s", path);
	AddFileToDownloadsTable(buffer);
}

stock PrecacheMaterial2(const String:path[])
{
	decl String:buffer[PLATFORM_MAX_PATH];
	Format(buffer, sizeof(buffer), "materials/%s.vmt", path);
	AddFileToDownloadsTable(buffer);
	Format(buffer, sizeof(buffer), "materials/%s.vtf", path);
	AddFileToDownloadsTable(buffer);
}

// For use with annotations.
stock BuildAnnotationBitString(const clients[], iMaxClients)
{
	new iBitString = 1;
	for (new i = 0; i < maxClients; i++)
	{
		new client = clients[i];
		if (!IsClientInGame(client) || !IsPlayerAlive(client)) continue;
	
		iBitString |= RoundFloat(Pow(2.0, float(client)));
	}
	
	return iBitString;
}

stock SpawnAnnotation(client, entity, const Float:pos[3], const String:message[], Float:lifetime)
{
	new Handle:event = CreateEvent("show_annotation", true);
	if (event != INVALID_HANDLE)
	{
		new bitstring = BuildAnnotationBitString(id, pos, type, team);
		if (bitstring > 1)
		{
			pos[2] -= 35.0;
			SetEventFloat(event, "worldPosX", pos[0]);
			SetEventFloat(event, "worldPosY", pos[1]);
			SetEventFloat(event, "worldPosZ", pos[2]);
			SetEventFloat(event, "lifetime", lifetime);
			SetEventInt(event, "id", id);
			SetEventString(event, "text", message);
			SetEventInt(event, "visibilityBitfield", bitstring);
			FireEvent(event);
			KillTimer(event);
		}
		
	}
}

stock InsertNodesAroundPoint(Handle:hArray, const Float:flOrigin[3], Float:flDist, Float:flAddAng, Function:iCallback=INVALID_FUNCTION, any:data=-1)
{
	decl Float:flDirection[3];
	decl Float:flPos[3];
	
	for (new Float:flAng = 0.0; flAng < 360.0; flAng += flAddAng)
	{
		flDirection[0] = 0.0;
		flDirection[1] = flAng;
		flDirection[2] = 0.0;
		
		GetAngleVectors(flDirection, flDirection, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(flDirection, flDirection);
		ScaleVector(flDirection, flDist);
		AddVectors(flDirection, flOrigin, flPos);
		
		new Float:flPos2[3];
		for (new i = 0; i < 2; i++) flPos2[i] = flPos[i];
		
		if (iCallback != INVALID_FUNCTION)
		{
			new Action:iAction = Plugin_Continue;
			
			Call_StartFunction(INVALID_HANDLE, iCallback);
			Call_PushArray(flOrigin, 3);
			Call_PushArrayEx(flPos2, 3, SM_PARAM_COPYBACK);
			Call_PushCell(data);
			Call_Finish(iAction);
			
			if (iAction == Plugin_Stop || iAction == Plugin_Handled) continue;
			else if (iAction == Plugin_Changed)
			{
				for (new i = 0; i < 2; i++) flPos[i] = flPos2[i];
			}
		}
		
		PushArrayArray(hArray, flPos, 3);
	}
}

stock SetAnimation(iEntity, const String:sAnimation[], bool:bDefaultAnimation=true, Float:flPlaybackRate=1.0)
{
	SetEntProp(iEntity, Prop_Send, "m_nSequence", 0);

	if (bDefaultAnimation)
	{
		SetVariantString(sAnimation);
		AcceptEntityInput(iEntity, "SetDefaultAnimation");
	}
	
	SetVariantString(sAnimation);
	AcceptEntityInput(iEntity, "SetAnimation");
	SetVariantFloat(flPlaybackRate);
	AcceptEntityInput(iEntity, "SetPlaybackRate");
}

public bool:TraceRayDontHitEntity(entity, mask, any:data)
{
	if (entity == data) return false;
	return true;
}

public bool:TraceRayDontHitPlayers(entity, mask, any:data)
{
	if (IsValidClient(entity)) return false;
	
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		new ent = EntRefToEntIndex(g_iSlender[i]);
		if (ent && ent != INVALID_ENT_REFERENCE)
		{
			if (entity == ent) return false;
		}
	}
	
	return true;
}

public bool:TraceRayDontHitPlayersOrEntity(entity, mask, any:data)
{
	if (entity == data || IsValidClient(entity)) return false;
	
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		new ent = EntRefToEntIndex(g_iSlender[i]);
		if (ent && ent != INVALID_ENT_REFERENCE)
		{
			if (entity == ent) return false;
		}
	}
	
	return true;
}

public Action:Timer_KillEntity(Handle:timer, any:entref)
{
	new ent = EntRefToEntIndex(entref);
	if (ent == INVALID_ENT_REFERENCE) return;
	
	AcceptEntityInput(ent, "Kill");
}