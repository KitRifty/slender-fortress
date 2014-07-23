#if defined _sf2_npc_chaser_included
 #endinput
#endif
#define _sf2_npc_chaser_included

static Float:g_flNPCStepSize[MAX_BOSSES];

static Float:g_flNPCWalkSpeed[MAX_BOSSES][Difficulty_Max];
static Float:g_flNPCAirSpeed[MAX_BOSSES][Difficulty_Max];

static Float:g_flNPCMaxWalkSpeed[MAX_BOSSES][Difficulty_Max];
static Float:g_flNPCMaxAirSpeed[MAX_BOSSES][Difficulty_Max];

static Float:g_flNPCWakeRadius[MAX_BOSSES];

static bool:g_bNPCStunEnabled[MAX_BOSSES];
static Float:g_flNPCStunDuration[MAX_BOSSES];
static bool:g_bNPCStunFlashlightEnabled[MAX_BOSSES];
static Float:g_flNPCStunFlashlightDamage[MAX_BOSSES];
static Float:g_flNPCStunInitialHealth[MAX_BOSSES];
static Float:g_flNPCStunHealth[MAX_BOSSES];

enum SF2BossAttackStructure
{
	SF2BossAttackType,
	Float:SF2BossAttackDamage,
	Float:SF2BossAttackDamageVsProps,
	Float:SF2BossAttackDamageForce,
	SF2BossAttackDamageType,
	Float:SF2BossAttackDamageDelay,
	Float:SF2BossAttackRange,
	Float:SF2BossAttackDuration,
	Float:SF2BossAttackSpread,
	Float:SF2BossAttackBeginRange,
	Float:SF2BossAttackBeginFOV,
	Float:SF2BossAttackCooldown,
	Float:SF2BossAttackNextAttackTime
};

static g_NPCAttacks[MAX_BOSSES][SF2_CHASER_BOSS_MAX_ATTACKS][SF2BossAttackStructure];

#if defined _sf2_npc_methodmap_included
 #include "sf2/npc/npc_chaser_methodmap.sp"
#endif

public NPCChaserInitialize()
{
	for (new iNPCIndex = 0; iNPCIndex < MAX_BOSSES; iNPCIndex++)
	{
		NPCChaserResetValues(iNPCIndex);
	}
}

Float:NPCChaserGetWalkSpeed(iNPCIndex, iDifficulty)
{
	return g_flNPCWalkSpeed[iNPCIndex][iDifficulty];
}

NPCChaserSetWalkSpeed(iNPCIndex, iDifficulty, Float:flAmount)
{
	g_flNPCWalkSpeed[iNPCIndex][iDifficulty] = flAmount;
}

Float:NPCChaserGetAirSpeed(iNPCIndex, iDifficulty)
{
	return g_flNPCAirSpeed[iNPCIndex][iDifficulty];
}

NPCChaserSetAirSpeed(iNPCIndex, iDifficulty, Float:flAmount)
{
	g_flNPCAirSpeed[iNPCIndex][iDifficulty] = flAmount;
}

Float:NPCChaserGetMaxWalkSpeed(iNPCIndex, iDifficulty)
{
	return g_flNPCMaxWalkSpeed[iNPCIndex][iDifficulty];
}

NPCChaserSetMaxWalkSpeed(iNPCIndex, iDifficulty, Float:flAmount)
{
	g_flNPCMaxWalkSpeed[iNPCIndex][iDifficulty] = flAmount;
}

Float:NPCChaserGetMaxAirSpeed(iNPCIndex, iDifficulty)
{
	return g_flNPCMaxAirSpeed[iNPCIndex][iDifficulty];
}

NPCChaserSetMaxAirSpeed(iNPCIndex, iDifficulty, Float:flAmount)
{
	g_flNPCMaxAirSpeed[iNPCIndex][iDifficulty] = flAmount;
}

Float:NPCChaserGetWakeRadius(iNPCIndex)
{
	return g_flNPCWakeRadius[iNPCIndex];
}

Float:NPCChaserGetStepSize(iNPCIndex)
{
	return g_flNPCStepSize[iNPCIndex];
}

NPCChaserGetAttackType(iNPCIndex, iAttackIndex)
{
	return g_NPCAttacks[iNPCIndex][iAttackIndex][SF2BossAttackType];
}

Float:NPCChaserGetAttackDamage(iNPCIndex, iAttackIndex)
{
	return g_NPCAttacks[iNPCIndex][iAttackIndex][SF2BossAttackDamage];
}

Float:NPCChaserGetAttackDamageVsProps(iNPCIndex, iAttackIndex)
{
	return g_NPCAttacks[iNPCIndex][iAttackIndex][SF2BossAttackDamageVsProps];
}

Float:NPCChaserGetAttackDamageForce(iNPCIndex, iAttackIndex)
{
	return g_NPCAttacks[iNPCIndex][iAttackIndex][SF2BossAttackDamageForce];
}

NPCChaserGetAttackDamageType(iNPCIndex, iAttackIndex)
{
	return g_NPCAttacks[iNPCIndex][iAttackIndex][SF2BossAttackDamageType];
}

Float:NPCChaserGetAttackDamageDelay(iNPCIndex, iAttackIndex)
{
	return g_NPCAttacks[iNPCIndex][iAttackIndex][SF2BossAttackDamageDelay];
}

Float:NPCChaserGetAttackRange(iNPCIndex, iAttackIndex)
{
	return g_NPCAttacks[iNPCIndex][iAttackIndex][SF2BossAttackRange];
}

Float:NPCChaserGetAttackDuration(iNPCIndex, iAttackIndex)
{
	return g_NPCAttacks[iNPCIndex][iAttackIndex][SF2BossAttackDuration];
}

Float:NPCChaserGetAttackSpread(iNPCIndex, iAttackIndex)
{
	return g_NPCAttacks[iNPCIndex][iAttackIndex][SF2BossAttackSpread];
}

Float:NPCChaserGetAttackBeginRange(iNPCIndex, iAttackIndex)
{
	return g_NPCAttacks[iNPCIndex][iAttackIndex][SF2BossAttackBeginRange];
}

Float:NPCChaserGetAttackBeginFOV(iNPCIndex, iAttackIndex)
{
	return g_NPCAttacks[iNPCIndex][iAttackIndex][SF2BossAttackBeginFOV];
}

bool:NPCChaserIsStunEnabled(iNPCIndex)
{
	return g_bNPCStunEnabled[iNPCIndex];
}

bool:NPCChaserIsStunByFlashlightEnabled(iNPCIndex)
{
	return g_bNPCStunFlashlightEnabled[iNPCIndex];
}

Float:NPCChaserGetStunFlashlightDamage(iNPCIndex)
{
	return g_flNPCStunFlashlightDamage[iNPCIndex];
}

Float:NPCChaserGetStunDuration(iNPCIndex)
{
	return g_flNPCStunDuration[iNPCIndex];
}

Float:NPCChaserGetStunHealth(iNPCIndex)
{
	return g_flNPCStunHealth[iNPCIndex];
}

NPCChaserSetStunHealth(iNPCIndex, Float:flAmount)
{
	g_flNPCStunHealth[iNPCIndex] = flAmount;
}

NPCChaserAddStunHealth(iNPCIndex, Float:flAmount)
{
	NPCChaserSetStunHealth(iNPCIndex, NPCChaserGetStunHealth(iNPCIndex) + flAmount);
}

Float:NPCChaserGetStunInitialHealth(iNPCIndex)
{
	return g_flNPCStunInitialHealth[iNPCIndex];
}

NPCChaserOnSelectProfile(iNPCIndex)
{
	new iUniqueProfileIndex = NPCGetUniqueProfileIndex(iNPCIndex);

	g_flNPCWakeRadius[iNPCIndex] = GetChaserProfileWakeRadius(iUniqueProfileIndex);
	g_flNPCStepSize[iNPCIndex] = GetChaserProfileStepSize(iUniqueProfileIndex);
	
	for (new iDifficulty = 0; iDifficulty < Difficulty_Max; iDifficulty++)
	{
		g_flNPCWalkSpeed[iNPCIndex][iDifficulty] = GetChaserProfileWalkSpeed(iUniqueProfileIndex, iDifficulty);
		g_flNPCAirSpeed[iNPCIndex][iDifficulty] = GetChaserProfileAirSpeed(iUniqueProfileIndex, iDifficulty);
		
		g_flNPCMaxWalkSpeed[iNPCIndex][iDifficulty] = GetChaserProfileMaxWalkSpeed(iUniqueProfileIndex, iDifficulty);
		g_flNPCMaxAirSpeed[iNPCIndex][iDifficulty] = GetChaserProfileMaxAirSpeed(iUniqueProfileIndex, iDifficulty);
	}
	
	// Get attack data.
	for (new i = 0; i < GetChaserProfileAttackCount(iUniqueProfileIndex); i++)
	{
		g_NPCAttacks[iNPCIndex][i][SF2BossAttackType] = GetChaserProfileAttackType(iUniqueProfileIndex, i);
		g_NPCAttacks[iNPCIndex][i][SF2BossAttackDamage] = GetChaserProfileAttackDamage(iUniqueProfileIndex, i);
		g_NPCAttacks[iNPCIndex][i][SF2BossAttackDamageVsProps] = GetChaserProfileAttackDamageVsProps(iUniqueProfileIndex, i);
		g_NPCAttacks[iNPCIndex][i][SF2BossAttackDamageForce] = GetChaserProfileAttackDamageForce(iUniqueProfileIndex, i);
		g_NPCAttacks[iNPCIndex][i][SF2BossAttackDamageType] = GetChaserProfileAttackDamageType(iUniqueProfileIndex, i);
		g_NPCAttacks[iNPCIndex][i][SF2BossAttackDamageDelay] = GetChaserProfileAttackDamageDelay(iUniqueProfileIndex, i);
		g_NPCAttacks[iNPCIndex][i][SF2BossAttackRange] = GetChaserProfileAttackRange(iUniqueProfileIndex, i);
		g_NPCAttacks[iNPCIndex][i][SF2BossAttackDuration] = GetChaserProfileAttackDuration(iUniqueProfileIndex, i);
		g_NPCAttacks[iNPCIndex][i][SF2BossAttackSpread] = GetChaserProfileAttackSpread(iUniqueProfileIndex, i);
		g_NPCAttacks[iNPCIndex][i][SF2BossAttackBeginRange] = GetChaserProfileAttackBeginRange(iUniqueProfileIndex, i);
		g_NPCAttacks[iNPCIndex][i][SF2BossAttackBeginFOV] = GetChaserProfileAttackBeginFOV(iUniqueProfileIndex, i);
		g_NPCAttacks[iNPCIndex][i][SF2BossAttackCooldown] = GetChaserProfileAttackCooldown(iUniqueProfileIndex, i);
		g_NPCAttacks[iNPCIndex][i][SF2BossAttackNextAttackTime] = -1.0;
	}
	
	// Get stun data.
	g_bNPCStunEnabled[iNPCIndex] = GetChaserProfileStunState(iUniqueProfileIndex);
	g_flNPCStunDuration[iNPCIndex] = GetChaserProfileStunDuration(iUniqueProfileIndex);
	g_bNPCStunFlashlightEnabled[iNPCIndex] = GetChaserProfileStunFlashlightState(iUniqueProfileIndex);
	g_flNPCStunFlashlightDamage[iNPCIndex] = GetChaserProfileStunFlashlightDamage(iUniqueProfileIndex);
	g_flNPCStunInitialHealth[iNPCIndex] = GetChaserProfileStunHealth(iUniqueProfileIndex);
	
	NPCChaserSetStunHealth(iNPCIndex, NPCChaserGetStunInitialHealth(iNPCIndex));
}

NPCChaserOnRemoveProfile(iNPCIndex)
{
	NPCChaserResetValues(iNPCIndex);
}

/**
 *	Resets all global variables on a specified NPC. Usually this should be done last upon removing a boss from the game.
 */
static NPCChaserResetValues(iNPCIndex)
{
	g_flNPCWakeRadius[iNPCIndex] = 0.0;
	g_flNPCStepSize[iNPCIndex] = 0.0;
	
	for (new iDifficulty = 0; iDifficulty < Difficulty_Max; iDifficulty++)
	{
		g_flNPCWalkSpeed[iNPCIndex][iDifficulty] = 0.0;
		g_flNPCAirSpeed[iNPCIndex][iDifficulty] = 0.0;
		
		g_flNPCMaxWalkSpeed[iNPCIndex][iDifficulty] = 0.0;
		g_flNPCMaxAirSpeed[iNPCIndex][iDifficulty] = 0.0;
	}
	
	// Clear attack data.
	for (new i = 0; i < SF2_CHASER_BOSS_MAX_ATTACKS; i++)
	{
		g_NPCAttacks[iNPCIndex][i][SF2BossAttackType] = SF2BossAttackType_Invalid;
		g_NPCAttacks[iNPCIndex][i][SF2BossAttackDamage] = 0.0;
		g_NPCAttacks[iNPCIndex][i][SF2BossAttackDamageVsProps] = 0.0;
		g_NPCAttacks[iNPCIndex][i][SF2BossAttackDamageForce] = 0.0;
		g_NPCAttacks[iNPCIndex][i][SF2BossAttackDamageType] = 0;
		g_NPCAttacks[iNPCIndex][i][SF2BossAttackDamageDelay] = 0.0;
		g_NPCAttacks[iNPCIndex][i][SF2BossAttackRange] = 0.0;
		g_NPCAttacks[iNPCIndex][i][SF2BossAttackDuration] = 0.0;
		g_NPCAttacks[iNPCIndex][i][SF2BossAttackSpread] = 0.0;
		g_NPCAttacks[iNPCIndex][i][SF2BossAttackBeginRange] = 0.0;
		g_NPCAttacks[iNPCIndex][i][SF2BossAttackBeginFOV] = 0.0;
		g_NPCAttacks[iNPCIndex][i][SF2BossAttackCooldown] = 0.0;
		g_NPCAttacks[iNPCIndex][i][SF2BossAttackNextAttackTime] = -1.0;
	}
	
	g_bNPCStunEnabled[iNPCIndex] = false;
	g_flNPCStunDuration[iNPCIndex] = 0.0;
	g_bNPCStunFlashlightEnabled[iNPCIndex] = false;
	g_flNPCStunInitialHealth[iNPCIndex] = 0.0;
	
	NPCChaserSetStunHealth(iNPCIndex, 0.0);
}
