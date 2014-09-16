#if defined _sf2_npc_adv_chaser_included
 #endinput
#endif
#define _sf2_npc_adv_chaser_included

/*	
 *	=====================================================
 *	GLOBAL VARIABLES
 *	=====================================================
 */

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
	SF2AdvChaserActivity_Custom,
	SF2AdvChaserActivity_Max
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
	Float:SF2NPCAdvChaser_BaseAttackAnimationPlaybackRate
};

// Generic stuff.
static SF2AdvChaserState:g_iNPCState[MAX_BOSSES] = { -1, ... };
static SF2AdvChaserState:g_iNPCPreferredState[MAX_BOSSES] = { -1, ... };
static SF2AdvChaserActivity:g_iNPCActivity[MAX_BOSSES] = { -1, ... };
static SF2AdvChaserActivity:g_iNPCPreferredActivity[MAX_BOSSES] = { -1, ... };
static bool:g_iNPCShouldSelectNewActivity[MAX_BOSSES] = { true, ... };
static bool:g_iNPCAnimationNeedsUpdate[MAX_BOSSES] = { true, ... };

static g_iNPCDamageAccumulated[MAX_BOSSES] = { 0, ... };
static g_iNPCDamageAccumulatedForStun[MAX_BOSSES] = { 0, ... };

static Float:g_flNPCStepSize[MAX_BOSSES];

static Float:g_flNPCWalkSpeed[MAX_BOSSES][Difficulty_Max];
static Float:g_flNPCAirSpeed[MAX_BOSSES][Difficulty_Max];

static Float:g_flNPCMaxWalkSpeed[MAX_BOSSES][Difficulty_Max];
static Float:g_flNPCMaxAirSpeed[MAX_BOSSES][Difficulty_Max];

static Float:g_flNPCWakeRadius[MAX_BOSSES];

static g_NPCBaseAttackData[MAX_BOSSES][SF2_ADV_CHASER_BOSS_MAX_ATTACKS][SF2NPCAdvChaser_BaseAttack];

// Nav stuff.
static Handle:g_hNPCPath[MAX_BOSSES] = { INVALID_HANDLE, ... };
static g_iNPCPathNodeIndex[MAX_BOSSES] = { -1, ... };
static g_iNPCPathBehindNodeIndex[MAX_BOSSES] = { -1, ... };
static Float:g_flNPCPathToleranceDistance[MAX_BOSSES] = { 32.0, ... };
static Float:g_flNPCMovePosition[MAX_BOSSES][3];

/*	
 *	=====================================================
 *	SCHEDULE FUNCTIONS AND DEFINES
 *	=====================================================
 */

enum ScheduleStruct
{
	ScheduleStruct_TaskListHeadIndex = 0,
	ScheduleStruct_TaskListTailIndex,
	ScheduleStruct_InterruptConditions,
	ScheduleStruct_MaxStats
};

enum ScheduleTaskStruct
{
	ScheduleTaskStruct_ID = 0,
	ScheduleTaskStruct_Data,
	ScheduleTaskStruct_MaxStats
};

enum ScheduleTask
{
	TASK_WAIT = 0,
	TASK_WAIT_FOR_MOVEMENT,
	TASK_WAIT_FOR_ATTACK,
	
	TASK_SET_SCHEDULE,
	TASK_SET_FAIL_SCHEDULE,
	
	TASK_SET_PREFERRED_ACTIVITY,
	
	TASK_FACE_ENEMY,
	TASK_FACE_TARGET,
	
	TASK_GET_PATH_TO_ENEMY,
	TASK_GET_CHASE_PATH_TO_ENEMY,
	TASK_GET_PATH_TO_TARGET,
	TASK_GET_CHASE_PATH_TO_TARGET,
	TASK_SET_PATH_TOLERANCE_DIST,
	
	TASK_SET_ANIMATION,
	
	TASK_MAX
};

enum ScheduleTaskState
{
	ScheduleTaskState_Invalid = 1,
	ScheduleTaskState_Failed = 0,
	ScheduleTaskState_Complete,
	ScheduleTaskState_Running
};

static const g_ScheduleTaskNames[TASK_MAX][] =
{
	"TASK_WAIT",
	"TASK_WAIT_FOR_MOVEMENT",
	"TASK_WAIT_FOR_ATTACK",
	
	"TASK_SET_SCHEDULE",
	"TASK_SET_FAIL_SCHEDULE",
	
	"TASK_SET_PREFERRED_ACTIVITY",
	
	"TASK_FACE_ENEMY",
	"TASK_FACE_TARGET",
	
	"TASK_GET_PATH_TO_ENEMY",
	"TASK_GET_CHASE_PATH_TO_ENEMY",
	"TASK_GET_PATH_TO_TARGET",
	"TASK_GET_CHASE_PATH_TO_TARGET",
	"TASK_SET_PATH_TOLERANCE_DIST",
	
	"TASK_SET_ANIMATION"
};

static const Schedule:INVALID_SCHEDULE = Schedule:-1;

static Schedule:g_iNPCSchedule[MAX_BOSSES] = { -1, ... };
static g_iNPCScheduleTaskPosition[MAX_BOSSES] = { -1, ... };
static ScheduleTaskState:g_iNPCScheduleTaskState[MAX_BOSSES] = { -1, ... };
static bool:g_bNPCScheduleTaskStarted[MAX_BOSSES] = { false, ... };
static bool:g_bNPCScheduleInterrupted[MAX_BOSSES] = { false, ... };
static g_iNPCScheduleInterruptConditions[MAX_BOSSES] = { 0, ... };

static g_iNPCNextSchedule[MAX_BOSSES] = { INVALID_SCHEDULE, ... };
static g_iNPCFailSchedule[MAX_BOSSES] = { INVALID_SCHEDULE, ... };

static g_iNPCInterruptConditions[MAX_BOSSES] = { 0, ... };

// Wait
static Float:g_flNPCWaitFinishTime[MAX_BOSSES] = { -1.0, ... };

// Animation
static Float:g_flNPCAnimationFinishTime[MAX_BOSSES] = { -1.0, ... };

// Interrupt conditions.
#define SF2_INTERRUPTCOND_NEW_ENEMY (1 << 0)
#define SF2_INTERRUPTCOND_SAW_ENEMY (1 << 1)
#define SF2_INTERRUPTCOND_ENEMY_UNREACHABLE (1 << 2)
#define SF2_INTERRUPTCOND_ENEMY_OCCLUDED (1 << 3)
#define SF2_INTERRUPTCOND_LOST_ENEMY (1 << 4)
#define SF2_INTERRUPTCOND_CAN_USE_ATTACK_BEST (1 << 5)
#define SF2_INTERRUPTCOND_DAMAGED (1 << 6)
#define SF2_INTERRUPTCOND_STUNNED (1 << 7)

static Handle:g_hSchedules = INVALID_HANDLE;
static Handle:g_hScheduleNames = INVALID_HANDLE;
static Handle:g_hScheduleTaskLists = INVALID_HANDLE;

new Schedule:SCHED_NONE;
new Schedule:SCHED_IDLE_STAND;
new Schedule:SCHED_CHASE_ENEMY;

static InitializeScheduleSystem()
{
	g_hSchedules = CreateArray(ScheduleStruct_MaxStats);
	g_hScheduleTaskLists = CreateArray(ScheduleTaskStruct_MaxStats);
	
	// Define schedule presets.
	SCHED_IDLE_STAND = StartScheduleDefinition("SCHED_IDLE_STAND");
	AddTaskToSchedule(SCHED_IDLE_STAND, TASK_SET_PREFERRED_ACTIVITY, SF2AdvChaserActivity_Stand);
	AddTaskToSchedule(SCHED_IDLE_STAND, TASK_WAIT, 5.0);
	
	SCHED_CHASE_ENEMY = StartScheduleDefinition("SCHED_CHASE_ENEMY");
	AddTaskToSchedule(SCHED_CHASE_ENEMY, TASK_GET_CHASE_PATH_TO_ENEMY);
	AddTaskToSchedule(SCHED_CHASE_ENEMY, TASK_SET_PREFERRED_ACTIVITY, SF2AdvChaserActivity_Run);
	AddTaskToSchedule(SCHED_CHASE_ENEMY, TASK_WAIT_FOR_MOVEMENT);
	AddTaskToSchedule(SCHED_CHASE_ENEMY, TASK_FACE_ENEMY);
}

static Schedule:StartScheduleDefinition(const String:scheduleName[])
{
	new scheduleIndex = PushArrayCell(g_hSchedules, -1);
	SetArrayCell(g_hSchedules, scheduleIndex, -1, ScheduleStruct_TaskListHeadIndex);
	SetArrayCell(g_hSchedules, scheduleIndex, -1, ScheduleStruct_TaskListTailIndex);
	SetArrayCell(g_hSchedules, scheduleIndex, 0, ScheduleStruct_InterruptConditions);
	
	PushArrayString(g_hScheduleNames, scheduleName);
	
	return Schedule:scheduleIndex;
}

static AddTaskToSchedule(Schedule:schedule, ScheduleTask:taskID, any:data=-1)
{
	if (task < 0 || task >= TASK_MAX)
	{
		return;
	}
	
	new taskListHeadIndex = GetArrayCell(g_hSchedules, _:schedule, ScheduleStruct_TaskListHeadIndex);
	new taskListTailIndex = GetArrayCell(g_hSchedules, _:schedule, ScheduleStruct_TaskListTailIndex);
	
	taskListTailIndex = PushArrayCell(g_hScheduleTaskLists, -1);
	SetArrayCell(g_hScheduleTaskLists, taskListTailIndex, taskID, ScheduleTaskStruct_ID);
	SetArrayCell(g_hScheduleTaskLists, taskListTailIndex, data, ScheduleTaskStruct_Data);
	
	if (taskListHeadIndex < 0)
	{
		taskListHeadIndex = taskListTailIndex;
	}
	
	SetArrayCell(g_hSchedules, _:schedule, taskListHeadIndex, ScheduleStruct_TaskListHeadIndex);
	SetArrayCell(g_hSchedules, _:schedule, taskListTailIndex, ScheduleStruct_TaskListTailIndex);
}

static SetScheduleInterruptConditions(Schedule:schedule, conditions)
{
	SetArrayCell(g_hSchedule, _:schedule, conditions, ScheduleStruct_InterruptConditions);
}

static GetScheduleName(Schedule:schedule, String:buffer[], bufferlen)
{
	GetArrayString(g_hScheduleNames, _:schedule, buffer, bufferlen);
}

/*	
 *	=====================================================
 *	GENERIC FUNCTIONS
 *	=====================================================
 */

SF2AdvChaserState:NPCAdvChaser_GetState(iNPCIndex)
{
	return g_iNPCState[iNPCIndex];
}

NPCAdvChaser_SetState(iNPCIndex, SF2AdvChaserState:iState)
{
	g_iNPCState[iNPCIndex] = iState;
}

SF2AdvChaserState:NPCAdvChaser_GetPreferredState(iNPCIndex)
{
	return g_iNPCPreferredState[iNPCIndex];
}

NPCAdvChaser_SetPreferredState(iNPCIndex, SF2AdvChaserState:iState)
{
	g_iNPCPreferredState[iNPCIndex] = iState;
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
	g_iNPCShouldSelectNewActivity[iNPCIndex] = false;
	g_iNPCAnimationNeedsUpdate[iNPCIndex] = true;
}

static SF2AdvChaserActivity:NPCAdvChaser_SelectActivity(iNPCIndex)
{
	return SF2AdvChaserActivity_Stand;
}

static NPCAdvChaser_StopMoving(iNPCIndex)
{
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

Float:NPCAdvChaser_GetAttackAnimationPlaybackRate(iNPCIndex, iAttackIndex)
{
	return g_NPCBaseAttackData[iNPCIndex][iAttackIndex][SF2NPCAdvChaser_BaseAttackAnimationPlaybackRate];
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

Schedule:NPCAdvChaser_GetSchedule(iNPCIndex)
{
	return g_iNPCSchedule[iNPCIndex];
}

NPCAdvChaser_SetSchedule(iNPCIndex, Schedule:schedule)
{
	NPCAdvChaser_ClearSchedule(iNPCIndex);
	
	if (_:schedule < 0 || _:schedule >= GetArraySize(g_hSchedules))
	{
		return;
	}
	
	g_iNPCSchedule[iNPCIndex] = schedule;
	g_iNPCScheduleTaskPosition[iNPCIndex] = 0;
}

static NPCAdvChaser_ClearSchedule(iNPCIndex)
{
	g_iNPCSchedule[iNPCIndex] = INVALID_SCHEDULE;
	g_iNPCNextSchedule[iNPCIndex] = INVALID_SCHEDULE;
	g_iNPCFailSchedule[iNPCIndex] = INVALID_SCHEDULE;
	g_bNPCScheduleInterrupted[iNPCIndex] = false;
	g_iNPCScheduleInterruptConditions[iNPCIndex] = 0;
	g_iNPCScheduleTaskState[iNPCIndex] = ScheduleTaskState_Invalid;
	g_bNPCScheduleTaskStarted[iNPCIndex] = false;
	g_iNPCScheduleTaskPosition[iNPCIndex] = -1;
}

static Schedule:NPCAdvChaser_SelectSchedule(iNPCIndex)
{
	return INVALID_SCHEDULE;
}

static NPCAdvChaser_MaintainSchedule(iNPCIndex)
{
	new Schedule:currentSchedule = NPCAdvChaser_GetSchedule(iNPCIndex);
	new Schedule:idealSchedule = INVALID_SCHEDULE;
	new bool:changeSchedule = true;
	
	if (currentSchedule != INVALID_SCHEDULE || NPCAdvChaser_GetState(iNPCIndex) != NPCAdvChaser_GetPreferredState(iNPCIndex))
	{
		new SF2AdvChaserState:preferredState = AIChaser_SelectPreferredState(iNPCIndex);
		NPCAdvChaser_SetPreferredState(iNPCIndex, preferredState);
	}
	
	if (currentSchedule != INVALID_SCHEDULE)
	{
		new bool:scheduleInterrupted = g_bNPCScheduleInterrupted[iNPCIndex];
		if (!scheduleInterrupted)
		{
			if (g_iNPCScheduleInterruptConditions[iNPCIndex] & NPCAdvChaser_GetInterruptConditions(iNPCIndex))
			{
				scheduleInterrupted = true;
				g_bNPCScheduleInterrupted[iNPCIndex] = true;
			}
		}
		
		{
			new ScheduleTaskState:scheduleTaskState = g_iNPCScheduleTaskState[iNPCIndex];
			
			new scheduleTaskPosition = g_iNPCScheduleTaskPosition[iNPCIndex];
			new scheduleTaskListHeadIndex = GetArrayCell(g_hSchedules, _:currentSchedule, ScheduleStruct_TaskListHeadIndex);
			new scheduleTaskListTailIndex = GetArrayCell(g_hSchedules, _:currentSchedule, ScheduleStruct_TaskListTailIndex);
			
			if (scheduleTaskState != ScheduleTaskState_Running)
			{
				if (scheduleTaskState == ScheduleTaskState_Complete)
				{
					new Schedule:nextSchedule = g_iNPCNextSchedule[iNPCIndex];
					if (nextSchedule != INVALID_SCHEDULE)
					{
						idealSchedule = nextSchedule;
					}
					else
					{
						if (scheduleTaskPosition == (scheduleTaskListTailIndex - scheduleTaskListHeadIndex))
						{
							// Reached end of schedule!
							idealSchedule = NPCAdvChaser_SelectSchedule(iNPCIndex);
						}
						else
						{
							g_iNPCScheduleTaskPosition[iNPCIndex] = ++scheduleTaskPosition;
							idealSchedule = currentSchedule
							changeSchedule = false;
						}
					}
				}
				else if (scheduleTaskState == ScheduleTaskState_Failed)
				{
					new Schedule:failSchedule = g_iNPCFailSchedule[iNPCIndex];
					if (failSchedule != INVALID_SCHEDULE)
					{
						idealSchedule = failSchedule;
					}
					else
					{
						// No fail schedule set.
						idealSchedule = NPCAdvChaser_SelectSchedule(iNPCIndex);
					}
				}
			}
			else
			{
				if (scheduleInterrupted)
				{
					new ScheduleTask:taskID = GetArrayCell(g_hScheduleTaskLists, scheduleTaskListHeadIndex + scheduleTaskPosition, ScheduleTaskStruct_ID);
					new taskData = GetArrayCell(g_hScheduleTaskLists, scheduleTaskListHeadIndex + scheduleTaskPosition, ScheduleTaskStruct_Data);
					
					NPCAdvChaser_OnTaskInterrupted(iNPCIndex, taskID, taskData);
					
					idealSchedule = NPCAdvChaser_SelectSchedule(iNPCIndex);
				}
				else
				{
					idealSchedule = currentSchedule;
					changeSchedule = false;
				}
			}
		}
	}
	else
	{
		idealSchedule = NPCAdvChaser_SelectSchedule(iNPCIndex);
	}
	
	if (idealSchedule != INVALID_SCHEDULE)
	{
		if (changeSchedule)
		{
			new SF2AdvChaserState:oldState = NPCAdvChaser_GetState(iNPCIndex);
			new SF2AdvChaserState:newState = NPCAdvChaser_GetPreferredState(iNPCIndex);
			
			NPCAdvChaser_SetState(iNPCIndex, newState);
			NPCAdvChaser_OnStateChanged(iNPCIndex, oldState, newState);
			
			NPCAdvChaser_SetSchedule(iNPCIndex, idealSchedule);
		}
		
		NPCAdvChaser_ScheduleThink(iNPCIndex);
	}
	else
	{
		NPCAdvChaser_ClearSchedule(iNPCIndex);
		NPCAdvChaser_StopMoving(iNPCIndex);
	}
}

static NPCAdvChaser_ScheduleThink(iNPCIndex)
{
	new Schedule:schedule = NPCAdvChaser_GetSchedule(iNPCIndex);
	
	new scheduleTaskPosition = g_iNPCScheduleTaskPosition[iNPCIndex];
	new scheduleTaskListHeadIndex = GetArrayCell(g_hSchedules, _:schedule, ScheduleStruct_TaskListHeadIndex);
	new scheduleTaskListTailIndex = GetArrayCell(g_hSchedules, _:schedule, ScheduleStruct_TaskListTailIndex);
	
	if (scheduleTaskListHeadIndex < 0 || scheduleTaskListTailIndex < 0)
	{
		return;
	}
	
	new ScheduleTaskState:scheduleTaskState = g_iNPCScheduleTaskState[iNPCIndex];
	
	new ScheduleTask:taskID = GetArrayCell(g_hScheduleTaskLists, scheduleTaskListHeadIndex + scheduleTaskPosition, ScheduleTaskStruct_ID);
	new taskData = GetArrayCell(g_hScheduleTaskLists, scheduleTaskListHeadIndex + scheduleTaskPosition, ScheduleTaskStruct_Data);
	
	new String:failReasonMsg[512];
	
	if (!g_bNPCScheduleTaskStarted[iNPCIndex])
	{
		g_bNPCScheduleTaskStarted[iNPCIndex] = true;
		scheduleTaskState = NPCAdvChaser_StartTask(iNPCIndex, taskID, taskData, failReasonMsg, sizeof(failReasonMsg));
	}
	
	if (scheduleTaskState == ScheduleTaskState_Running)
	{
		scheduleTaskState = NPCAdvChaser_RunTask(iNPCIndex, taskID, taskData, failReasonMsg, sizeof(failReasonMsg));
	}
	
	if (strlen(failReasonMsg) > 0)
	{
		// @TODO: Print the reason for the task failing.
	}
	
	g_iNPCScheduleTaskState[iNPCIndex] = scheduleTaskState;
}

static ScheduleTaskState:NPCAdvChaser_StartTask(iNPCIndex, ScheduleTask:taskID, any:taskData, String:failReasonMsg[], failReasonMsgLen)
{
	switch (taskID)
	{
		case TASK_WAIT:
		{
			g_flNPCWaitFinishTime[iNPCIndex] = GetGameTime() + Float:taskData;
			return ScheduleTaskState_Running;
		}
		case TASK_WAIT_FOR_MOVEMENT:
		{
		}
		case TASK_SET_SCHEDULE:
		{
			new scheduleIndex = taskData;
			if (scheduleIndex < 0 || scheduleIndex >= GetArraySize(g_hSchedules))
			{
				Format(failReasonMsg, failReasonMsgLen, "Schedule ID %d does not exist.", scheduleIndex);
				return ScheduleTaskState_Failed;
			}
			
			g_iNPCNextSchedule[iNPCIndex] = Schedule:scheduleIndex;
			return ScheduleTaskState_Completed;
		}
		case TASK_SET_FAIL_SCHEDULE:
		{
			new scheduleIndex = taskData;
			if (scheduleIndex < 0 || scheduleIndex >= GetArraySize(g_hSchedules))
			{
				Format(failReasonMsg, failReasonMsgLen, "Schedule ID %d does not exist.", scheduleIndex);
				return ScheduleTaskState_Failed;
			}
			
			g_iNPCFailSchedule[iNPCIndex] = Schedule:scheduleIndex;
			return ScheduleTaskState_Completed;
		}
		case TASK_SET_PREFERRED_ACTIVITY:
		{
			new SF2AdvChaserActivity:activity = SF2AdvChaserActivity:taskData;
			if (activity == SF2AdvChaserActivity_None || activity >= SF2AdvChaserActivity_Max)
			{
				Format(failReasonMsg, failReasonMsgLen, "Activity %d does not exist.", _:activity);
				return ScheduleTaskState_Failed;
			}
			
			NPCAdvChaser_SetPreferredActivity(iNPCIndex, SF2AdvChaserActivity:taskData);
			return ScheduleTaskState_Completed;
		}
		case TASK_SET_ANIMATION:
		{
			new Handle:pack = Handle:taskData;
			ResetPack(pack);
			
			decl String:animationName[64];
			ReadPackString(pack, animationName, sizeof(animationName));
			
			new Float:animationPlaybackRate = ReadPackFloat(pack);
			new Float:animationDuration = ReadPackFloat(pack);
			
			g_flNPCAnimationFinishTime[iNPCIndex] = GetGameTime() + animationDuration;
			
			NPCAdvChaser_SetPreferredActivity(iNPCIndex, SF2AdvChaserActivity_Custom);
			
			// @TODO: Set the animation of the boss's model.
			
			
			return ScheduleTaskState_Running;
		}
	}
	
	Format(failReasonMsg, failReasonMsgLen, "Task ID %d does not exist.", _:taskID);

	return ScheduleTaskState_Failed;
}

static ScheduleTaskState:NPCAdvChaser_RunTask(iNPCIndex, ScheduleTask:taskID, any:taskData)
{
	switch (taskID)
	{
		case TASK_WAIT:
		{
			if (GetGameTime() >= g_flNPCWaitFinishTime[iNPCIndex])
			{
				return ScheduleTaskState_Complete;
			}
			
			return ScheduleTaskState_Running;
		}
		case TASK_WAIT_FOR_MOVEMENT:
		{
		}
		case TASK_SET_ANIMATION:
		{
			if (GetGameTime() >= g_flNPCAnimationFinishTime[iNPCIndex])
			{
				g_iNPCShouldSelectNewActivity[iNPCIndex] = true;
				
				return ScheduleTaskState_Complete;
			}
			
			return ScheduleTaskState_Running;
		}
	}
	
	Format(failReasonMsg, failReasonMsgLen, "Task ID %d does not exist.", _:taskID);
	return ScheduleTaskState_Failed;
}

static NPCAdvChaser_OnTaskInterrupted(iNPCIndex, ScheduleTask:taskID, any:taskData)
{
	switch (taskID)
	{
		case TASK_WAIT_FOR_MOVEMENT:
		{
			
		}
		case TASK_SET_ANIMATION:
		{
			g_iNPCShouldSelectNewActivity[iNPCIndex] = true;
		}
	}
}

NPCAdvChaser_OnSelectProfile(iNPCIndex)
{
}

NPCAdvChaser_Think(iNPCIndex)
{
	// Gather and select enemies.
	
	// Maintain schedule (preset list of instructions for a specific situation). A new schedule could be chosen during this time, or just maintain the current one.
	
	// Select the activity to be in. Running, standing, jumping, or something else, etc. The preferred activity is the main activity to be in.
	
	// Handle movement. If the current activity is about movement, move the NPC towards MovePosition, change angles, speed, etc.
	
	// Handle animations. Some animations are directly associated with the current activity.
	
	// Reset for the next frame.
	
	g_iNPCInterruptConditions[iNPCIndex] = 0;
	g_iNPCAnimationNeedsUpdate[iNPCIndex] = false;
}