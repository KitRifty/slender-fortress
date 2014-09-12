#if defined _sf2_npc_adv_chaser_included
 #endinput
#endif
#define _sf2_npc_adv_chaser_included


static g_iNPCState[MAX_BOSSES] = { -1, ... };
static g_iNPCMovementActivity[MAX_BOSSES] = { -1, ... };

static g_iNPCSchedule[MAX_BOSSES] = { -1, ... };
static g_iNPCScheduleTaskPosition[MAX_BOSSES] = { -1, ... };


NPCAdvChaser_GetState(iNPCIndex)
{
	return g_iNPCState[iNPCIndex];
}

NPCAdvChaser_SetState(iNPCIndex, iState)
{
	g_iNPCState[iNPCIndex] = iState;
}

NPCAdvChaser_GetMovementActivity(iNPCIndex)
{
	return g_iNPCMovementActivity[iNPCIndex];
}

NPCAdvChaser_SetMovementActivity(iNPCIndex, iMovementActivity)
{
	g_iNPCMovementActivity[iNPCIndex] = iMovementActivity;
}

NPCAdvChaser_GetSchedule(iNPCIndex)
{
	return g_iNPCSchedule[iNPCIndex];
}

NPCAdvChaser_SetSchedule(iNPCIndex, iSchedule)
{
	g_iNPCSchedule[iNPCIndex] = iSchedule;
}

NPCAdvChaser_OnSelectProfile(iNPCIndex)
{
}