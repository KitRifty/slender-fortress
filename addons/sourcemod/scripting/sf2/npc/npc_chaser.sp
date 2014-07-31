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

static g_iNPCState[MAX_BOSSES] = { -1, ... };
static g_iNPCMovementActivity[MAX_BOSSES] = { -1, ... };

enum SF2NPCChaser_BaseAttackStructure
{
	SF2NPCChaser_BaseAttackType,
	Float:SF2NPCChaser_BaseAttackDamage,
	Float:SF2NPCChaser_BaseAttackDamageVsProps,
	Float:SF2NPCChaser_BaseAttackDamageForce,
	SF2NPCChaser_BaseAttackDamageType,
	Float:SF2NPCChaser_BaseAttackDamageDelay,
	Float:SF2NPCChaser_BaseAttackRange,
	Float:SF2NPCChaser_BaseAttackDuration,
	Float:SF2NPCChaser_BaseAttackSpread,
	Float:SF2NPCChaser_BaseAttackBeginRange,
	Float:SF2NPCChaser_BaseAttackBeginFOV,
	Float:SF2NPCChaser_BaseAttackCooldown,
	Float:SF2NPCChaser_BaseAttackNextAttackTime
};

static g_NPCBaseAttacks[MAX_BOSSES][SF2_CHASER_BOSS_MAX_ATTACKS][SF2NPCChaser_BaseAttackStructure];

#if defined METHODMAPS
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
	return g_NPCBaseAttacks[iNPCIndex][iAttackIndex][SF2NPCChaser_BaseAttackType];
}

Float:NPCChaserGetAttackDamage(iNPCIndex, iAttackIndex)
{
	return g_NPCBaseAttacks[iNPCIndex][iAttackIndex][SF2NPCChaser_BaseAttackDamage];
}

Float:NPCChaserGetAttackDamageVsProps(iNPCIndex, iAttackIndex)
{
	return g_NPCBaseAttacks[iNPCIndex][iAttackIndex][SF2NPCChaser_BaseAttackDamageVsProps];
}

Float:NPCChaserGetAttackDamageForce(iNPCIndex, iAttackIndex)
{
	return g_NPCBaseAttacks[iNPCIndex][iAttackIndex][SF2NPCChaser_BaseAttackDamageForce];
}

NPCChaserGetAttackDamageType(iNPCIndex, iAttackIndex)
{
	return g_NPCBaseAttacks[iNPCIndex][iAttackIndex][SF2NPCChaser_BaseAttackDamageType];
}

Float:NPCChaserGetAttackDamageDelay(iNPCIndex, iAttackIndex)
{
	return g_NPCBaseAttacks[iNPCIndex][iAttackIndex][SF2NPCChaser_BaseAttackDamageDelay];
}

Float:NPCChaserGetAttackRange(iNPCIndex, iAttackIndex)
{
	return g_NPCBaseAttacks[iNPCIndex][iAttackIndex][SF2NPCChaser_BaseAttackRange];
}

Float:NPCChaserGetAttackDuration(iNPCIndex, iAttackIndex)
{
	return g_NPCBaseAttacks[iNPCIndex][iAttackIndex][SF2NPCChaser_BaseAttackDuration];
}

Float:NPCChaserGetAttackSpread(iNPCIndex, iAttackIndex)
{
	return g_NPCBaseAttacks[iNPCIndex][iAttackIndex][SF2NPCChaser_BaseAttackSpread];
}

Float:NPCChaserGetAttackBeginRange(iNPCIndex, iAttackIndex)
{
	return g_NPCBaseAttacks[iNPCIndex][iAttackIndex][SF2NPCChaser_BaseAttackBeginRange];
}

Float:NPCChaserGetAttackBeginFOV(iNPCIndex, iAttackIndex)
{
	return g_NPCBaseAttacks[iNPCIndex][iAttackIndex][SF2NPCChaser_BaseAttackBeginFOV];
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

NPCChaserGetState(iNPCIndex)
{
	return g_iNPCState[iNPCIndex];
}

NPCChaserSetState(iNPCIndex, iState)
{
	g_iNPCState[iNPCIndex] = iState;
}

NPCChaserGetMovementActivity(iNPCIndex)
{
	return g_iNPCMovementActivity[iNPCIndex];
}

NPCChaserSetMovementActivity(iNPCIndex, iMovementActivity)
{
	g_iNPCMovementActivity[iNPCIndex] = iMovementActivity;
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
		g_NPCBaseAttacks[iNPCIndex][i][SF2NPCChaser_BaseAttackType] = GetChaserProfileAttackType(iUniqueProfileIndex, i);
		g_NPCBaseAttacks[iNPCIndex][i][SF2NPCChaser_BaseAttackDamage] = GetChaserProfileAttackDamage(iUniqueProfileIndex, i);
		g_NPCBaseAttacks[iNPCIndex][i][SF2NPCChaser_BaseAttackDamageVsProps] = GetChaserProfileAttackDamageVsProps(iUniqueProfileIndex, i);
		g_NPCBaseAttacks[iNPCIndex][i][SF2NPCChaser_BaseAttackDamageForce] = GetChaserProfileAttackDamageForce(iUniqueProfileIndex, i);
		g_NPCBaseAttacks[iNPCIndex][i][SF2NPCChaser_BaseAttackDamageType] = GetChaserProfileAttackDamageType(iUniqueProfileIndex, i);
		g_NPCBaseAttacks[iNPCIndex][i][SF2NPCChaser_BaseAttackDamageDelay] = GetChaserProfileAttackDamageDelay(iUniqueProfileIndex, i);
		g_NPCBaseAttacks[iNPCIndex][i][SF2NPCChaser_BaseAttackRange] = GetChaserProfileAttackRange(iUniqueProfileIndex, i);
		g_NPCBaseAttacks[iNPCIndex][i][SF2NPCChaser_BaseAttackDuration] = GetChaserProfileAttackDuration(iUniqueProfileIndex, i);
		g_NPCBaseAttacks[iNPCIndex][i][SF2NPCChaser_BaseAttackSpread] = GetChaserProfileAttackSpread(iUniqueProfileIndex, i);
		g_NPCBaseAttacks[iNPCIndex][i][SF2NPCChaser_BaseAttackBeginRange] = GetChaserProfileAttackBeginRange(iUniqueProfileIndex, i);
		g_NPCBaseAttacks[iNPCIndex][i][SF2NPCChaser_BaseAttackBeginFOV] = GetChaserProfileAttackBeginFOV(iUniqueProfileIndex, i);
		g_NPCBaseAttacks[iNPCIndex][i][SF2NPCChaser_BaseAttackCooldown] = GetChaserProfileAttackCooldown(iUniqueProfileIndex, i);
		g_NPCBaseAttacks[iNPCIndex][i][SF2NPCChaser_BaseAttackNextAttackTime] = -1.0;
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
		// Base attack data.
		g_NPCBaseAttacks[iNPCIndex][i][SF2NPCChaser_BaseAttackType] = SF2BossAttackType_Invalid;
		g_NPCBaseAttacks[iNPCIndex][i][SF2NPCChaser_BaseAttackDamage] = 0.0;
		g_NPCBaseAttacks[iNPCIndex][i][SF2NPCChaser_BaseAttackDamageVsProps] = 0.0;
		g_NPCBaseAttacks[iNPCIndex][i][SF2NPCChaser_BaseAttackDamageForce] = 0.0;
		g_NPCBaseAttacks[iNPCIndex][i][SF2NPCChaser_BaseAttackDamageType] = 0;
		g_NPCBaseAttacks[iNPCIndex][i][SF2NPCChaser_BaseAttackDamageDelay] = 0.0;
		g_NPCBaseAttacks[iNPCIndex][i][SF2NPCChaser_BaseAttackRange] = 0.0;
		g_NPCBaseAttacks[iNPCIndex][i][SF2NPCChaser_BaseAttackDuration] = 0.0;
		g_NPCBaseAttacks[iNPCIndex][i][SF2NPCChaser_BaseAttackSpread] = 0.0;
		g_NPCBaseAttacks[iNPCIndex][i][SF2NPCChaser_BaseAttackBeginRange] = 0.0;
		g_NPCBaseAttacks[iNPCIndex][i][SF2NPCChaser_BaseAttackBeginFOV] = 0.0;
		g_NPCBaseAttacks[iNPCIndex][i][SF2NPCChaser_BaseAttackCooldown] = 0.0;
		g_NPCBaseAttacks[iNPCIndex][i][SF2NPCChaser_BaseAttackNextAttackTime] = -1.0;
	}
	
	g_bNPCStunEnabled[iNPCIndex] = false;
	g_flNPCStunDuration[iNPCIndex] = 0.0;
	g_bNPCStunFlashlightEnabled[iNPCIndex] = false;
	g_flNPCStunInitialHealth[iNPCIndex] = 0.0;
	
	NPCChaserSetStunHealth(iNPCIndex, 0.0);
	
	g_iNPCState[iNPCIndex] = -1;
	g_iNPCMovementActivity[iNPCIndex] = -1;
}
