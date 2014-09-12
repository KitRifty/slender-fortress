#if defined _sf2_npc_adv_chaser_included
 #endinput
#endif
#define _sf2_npc_adv_chaser_included

enum SF2AdvChaserState
{
	SF2AdvChaserState_Invalid = -1,
	SF2AdvChaserState_Idle,
	SF2AdvChaserState_Alert,
	SF2AdvChaserState_Combat,
	SF2AdvChaserState_Scripting
};

enum SF2AdvChaserActivity
{
	SF2AdvChaserActivity_None = 0,
	SF2AdvChaserActivity_Stand,
	SF2AdvChaserActivity_Walk,
	SF2AdvChaserActivity_Run,
	SF2AdvChaserActivity_Jump,
	SF2AdvChaserActivity_Climb,
	SF2AdvChaserActivity_Attack,
	SF2AdvChaserActivity_Stun,
	SF2AdvChaserActivity_Custom
};

enum SF2NPCAdvChaserAttackType
{
	SF2NPCAdvChaserAttackType_Melee = 0,
	SF2NPCAdvChaserAttackType_Ranged,
	SF2NPCAdvChaserAttackType_Projectile,
	SF2NPCAdvChaserAttackType_Grab
};

enum SF2NPCAdvChaser_BaseAttack
{
	SF2NPCAdvChaserAttackType:SF2NPCAdvChaser_BaseAttackType,
	Float:SF2NPCAdvChaser_BaseAttackDamage,
	Float:SF2NPCAdvChaser_BaseAttackDamageVsProps,
	Float:SF2NPCAdvChaser_BaseAttackDamageForce,
	SF2NPCAdvChaser_BaseAttackDamageType,
	Float:SF2NPCAdvChaser_BaseAttackDamageDelay,
	Float:SF2NPCAdvChaser_BaseAttackRange,
	Float:SF2NPCAdvChaser_BaseAttackDuration,
	Float:SF2NPCAdvChaser_BaseAttackSpread,
	Float:SF2NPCAdvChaser_BaseAttackBeginRange,
	Float:SF2NPCAdvChaser_BaseAttackBeginFOV,
	Float:SF2NPCAdvChaser_BaseAttackCooldown,
	Float:SF2NPCAdvChaser_BaseAttackNextAttackTime,
	String:SF2NPCAdvChaser_BaseAttackAnimation[64]
};

// Generic stuff.
static SF2AdvChaserState:g_iNPCState[MAX_BOSSES] = { -1, ... };
static SF2AdvChaserActivity:g_iNPCActivity[MAX_BOSSES] = { -1, ... };
static SF2AdvChaserActivity:g_iNPCPreferredActivity[MAX_BOSSES] = { -1, ... };
static bool:g_iNPCActivityFinished[MAX_BOSSES] = { true, ... };

static g_iNPCDamageAccumulated[MAX_BOSSES] = { 0, ... };
static g_iNPCDamageAccumulatedForStun[MAX_BOSSES] = { 0, ... };

static Float:g_flNPCStepSize[MAX_BOSSES];

static Float:g_flNPCWalkSpeed[MAX_BOSSES][Difficulty_Max];
static Float:g_flNPCAirSpeed[MAX_BOSSES][Difficulty_Max];

static Float:g_flNPCMaxWalkSpeed[MAX_BOSSES][Difficulty_Max];
static Float:g_flNPCMaxAirSpeed[MAX_BOSSES][Difficulty_Max];

static Float:g_flNPCWakeRadius[MAX_BOSSES];

static g_NPCBaseAttackData[MAX_BOSSES][SF2_ADV_CHASER_BOSS_MAX_ATTACKS][SF2NPCAdvChaser_BaseAttack];

// Schedules.
static g_iNPCSchedule[MAX_BOSSES] = { -1, ... };
static g_iNPCScheduleTaskPosition[MAX_BOSSES] = { -1, ... };
static g_iNPCScheduleInterruptConditions[MAX_BOSSES] = { 0, ... };

static g_iNPCInterruptConditions[MAX_BOSSES] = { 0, ... };

// Nav stuff.
static Handle:g_hNPCPath[MAX_BOSSES] = { INVALID_HANDLE, ... };
static g_iNPCPathNodeIndex[MAX_BOSSES] = { -1, ... };
static g_iNPCPathBehindNodeIndex[MAX_BOSSES] = { -1, ... };
static Float:g_flNPCMovePosition[MAX_BOSSES][3];

SF2AdvChaserState:NPCAdvChaser_GetState(iNPCIndex)
{
	return g_iNPCState[iNPCIndex];
}

NPCAdvChaser_SetState(iNPCIndex, SF2AdvChaserState:iState)
{
	g_iNPCState[iNPCIndex] = iState;
}

NPCAdvChaser_SelectPreferredState(iNPCIndex)
{
	return SF2AdvChaserState_Idle;
}

SF2AdvChaserActivity:NPCAdvChaser_GetPreferredActivity(iNPCIndex)
{
	return g_iNPCPreferredActivity[iNPCIndex];
}

NPCAdvChaser_SetPreferredActivity(iNPCIndex, SF2AdvChaserActivity:iActivity)
{
	g_iNPCPreferredActivity[iNPCIndex] = iActivity;
}

SF2AdvChaserActivity:NPCAdvChaser_GetActivity(iNPCIndex)
{
	return g_iNPCActivity[iNPCIndex];
}

NPCAdvChaser_SetActivity(iNPCIndex, SF2AdvChaserActivity:iActivity)
{
	g_iNPCActivity[iNPCIndex] = iActivity;
}

Float:NPCAdvChaser_GetWakeRadius(iNPCIndex)
{
	return g_flNPCWakeRadius[iNPCIndex];
}

Float:NPCAdvChaser_GetStepSize(iNPCIndex)
{
	return g_flNPCStepSize[iNPCIndex];
}

NPCAdvChaser_GetAttackType(iNPCIndex, iAttackIndex)
{
	return g_NPCBaseAttackData[iNPCIndex][iAttackIndex][SF2NPCAdvChaser_BaseAttackType];
}

Float:NPCAdvChaser_GetAttackDamage(iNPCIndex, iAttackIndex)
{
	return g_NPCBaseAttackData[iNPCIndex][iAttackIndex][SF2NPCAdvChaser_BaseAttackDamage];
}

Float:NPCAdvChaser_GetAttackDamageVsProps(iNPCIndex, iAttackIndex)
{
	return g_NPCBaseAttackData[iNPCIndex][iAttackIndex][SF2NPCAdvChaser_BaseAttackDamageVsProps];
}

Float:NPCAdvChaser_GetAttackDamageForce(iNPCIndex, iAttackIndex)
{
	return g_NPCBaseAttackData[iNPCIndex][iAttackIndex][SF2NPCAdvChaser_BaseAttackDamageForce];
}

NPCAdvChaser_GetAttackDamageType(iNPCIndex, iAttackIndex)
{
	return g_NPCBaseAttackData[iNPCIndex][iAttackIndex][SF2NPCAdvChaser_BaseAttackDamageType];
}

Float:NPCAdvChaser_GetAttackDamageDelay(iNPCIndex, iAttackIndex)
{
	return g_NPCBaseAttackData[iNPCIndex][iAttackIndex][SF2NPCAdvChaser_BaseAttackDamageDelay];
}

Float:NPCAdvChaser_GetAttackRange(iNPCIndex, iAttackIndex)
{
	return g_NPCBaseAttackData[iNPCIndex][iAttackIndex][SF2NPCAdvChaser_BaseAttackRange];
}

Float:NPCAdvChaser_GetAttackDuration(iNPCIndex, iAttackIndex)
{
	return g_NPCBaseAttackData[iNPCIndex][iAttackIndex][SF2NPCAdvChaser_BaseAttackDuration];
}

Float:NPCAdvChaser_GetAttackSpread(iNPCIndex, iAttackIndex)
{
	return g_NPCBaseAttackData[iNPCIndex][iAttackIndex][SF2NPCAdvChaser_BaseAttackSpread];
}

Float:NPCAdvChaser_GetAttackBeginRange(iNPCIndex, iAttackIndex)
{
	return g_NPCBaseAttackData[iNPCIndex][iAttackIndex][SF2NPCAdvChaser_BaseAttackBeginRange];
}

Float:NPCAdvChaser_GetAttackBeginFOV(iNPCIndex, iAttackIndex)
{
	return g_NPCBaseAttackData[iNPCIndex][iAttackIndex][SF2NPCAdvChaser_BaseAttackBeginFOV];
}

NPCAdvChaser_GetAttackAnimation(iNPCIndex, iAttackIndex, String:buffer[], bufferlen)
{
	strcopy(buffer, bufferlen, g_NPCBaseAttackData[iNPCIndex][iAttackIndex][SF2NPCAdvChaser_BaseAttackAnimation]);
}

NPCAdvChaser_GetInterruptConditions(iNPCIndex)
{
	return g_iNPCInterruptConditions[iNPCIndex];
}

NPCAdvChaser_SetInterruptConditions(iNPCIndex, iConditions)
{
	g_iNPCInterruptConditions[iNPCIndex] = iConditions;
}

bool:NPCAdvChaser_HasInterruptConditionSet(iNPCIndex, iCondition)
{
	return bool:(NPCAdvChaser_GetInterruptConditions(iNPCIndex) & iCondition);
}

NPCAdvChaser_AddInterruptCondition(iNPCIndex, iCondition)
{
	g_iNPCInterruptConditions[iNPCIndex] |= iCondition;
}

NPCAdvChaser_RemoveInterruptCondition(iNPCIndex, iCondition)
{
	g_iNPCInterruptConditions[iNPCIndex] &= ~iCondition;
}

NPCAdvChaser_GetSchedule(iNPCIndex)
{
	return g_iNPCSchedule[iNPCIndex];
}

NPCAdvChaser_SetSchedule(iNPCIndex, iSchedule)
{
	g_iNPCSchedule[iNPCIndex] = iSchedule;
}

NPCAdvChaser_ScheduleThink(iNPCIndex)
{
}

NPCAdvChaser_OnSelectProfile(iNPCIndex)
{
}

NPCAdvChaser_Think(iNPCIndex)
{
}