#if defined _sf2_npc_adv_chaser_included
 #endinput
#endif
#define _sf2_npc_adv_chaser_included

/*	
 *	=====================================================
 *	GLOBAL VARIABLES
 *	=====================================================
 */

#define SF2_NPC_ADVCHASER_NEARESTAREA_RADIUS 256.0
#define SF2_NPC_ADVCHASER_THINK_RATE GetTickInterval() 

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

// Generic stuff.
static SF2AdvChaserState:g_iNPCState[MAX_BOSSES] = { -1, ... };
static SF2AdvChaserState:g_iNPCPreferredState[MAX_BOSSES] = { -1, ... };
static SF2AdvChaserActivity:g_iNPCActivity[MAX_BOSSES] = { -1, ... };
static SF2AdvChaserActivity:g_iNPCPreferredActivity[MAX_BOSSES] = { -1, ... };
static bool:g_iNPCAnimationNeedsUpdate[MAX_BOSSES] = { true, ... };

static g_iNPCDamageAccumulated[MAX_BOSSES] = { 0, ... };
static g_iNPCDamageAccumulatedForStun[MAX_BOSSES] = { 0, ... };

static Float:g_flNPCStepSize[MAX_BOSSES];

static Float:g_flNPCWalkSpeed[MAX_BOSSES][Difficulty_Max];
static Float:g_flNPCAirSpeed[MAX_BOSSES][Difficulty_Max];

static Float:g_flNPCMaxWalkSpeed[MAX_BOSSES][Difficulty_Max];
static Float:g_flNPCMaxAirSpeed[MAX_BOSSES][Difficulty_Max];

static Float:g_flNPCWakeRadius[MAX_BOSSES];

// Nav stuff.
static Handle:g_hNPCPath[MAX_BOSSES] = { INVALID_HANDLE, ... };
static g_iNPCPathNodeIndex[MAX_BOSSES] = { -1, ... };
static g_iNPCPathBehindNodeIndex[MAX_BOSSES] = { -1, ... };
static Float:g_flNPCPathToleranceDistance[MAX_BOSSES] = { 32.0, ... };
static Float:g_flNPCMovePosition[MAX_BOSSES][3];
static g_iNPCPathGoalEntity[MAX_BOSSES] = { INVALID_ENT_REFERENCE, ... };
static g_iNPCPathGoalEntityLastKnownAreaIndex[MAX_BOSSES] = { -1, ... };
static g_iNPCPathGoalType[MAX_BOSSES] = { SF2NPCAdvChaserGoalType_Invalid, ... }:

static Float:g_flNPCSavePosition[MAX_BOSSES][3];

#if defined DEBUG

static Handle:g_cvDebugScheduleThink = INVALID_HANDLE;
static Handle:g_cvDebugAwareness = INVALID_HANDLE;

#endif

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
	TASK_TRAVERSE_PATH,
	TASK_DO_BEST_ATTACK,
	
	TASK_SET_SCHEDULE,
	TASK_SET_FAIL_SCHEDULE,
	
	TASK_SET_PREFERRED_ACTIVITY,
	
	TASK_FACE_SAVEPOSITION,
	TASK_FACE_ENEMY,
	TASK_FACE_TARGET,
	
	TASK_GET_PATH_TO_SAVEPOSITION,
	TASK_GET_PATH_TO_ENEMY,
	TASK_GET_PATH_TO_TARGET,
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

static const g_ScheduleTaskNames[][] =
{
	"TASK_WAIT",
	"TASK_TRAVERSE_PATH",
	"TASK_DO_BEST_ATTACK",
	
	"TASK_SET_SCHEDULE",
	"TASK_SET_FAIL_SCHEDULE",
	
	"TASK_SET_PREFERRED_ACTIVITY",
	
	"TASK_FACE_SAVEPOSITION",
	"TASK_FACE_ENEMY",
	"TASK_FACE_TARGET",
	
	"TASK_GET_PATH_TO_SAVEPOSITION",
	"TASK_GET_PATH_TO_ENEMY",
	"TASK_GET_PATH_TO_TARGET",
	"TASK_SET_PATH_TOLERANCE_DIST",
	
	"TASK_SET_ANIMATION"
};

enum Schedule
{
	INVALID_SCHEDULE = -1
};

static Schedule:g_iNPCSchedule[MAX_BOSSES] = { INVALID_SCHEDULE, ... };
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
	AddTaskToSchedule(SCHED_CHASE_ENEMY, TASK_TRAVERSE_PATH);
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
	if (_:schedule < 0 || _:schedule >= GetArraySize(g_hSchedules))
	{
		strcopy(buffer, bufferlen, "INVALID_SCHEDULE");
		return;
	}

	GetArrayString(g_hScheduleNames, _:schedule, buffer, bufferlen);
}


/*	
 *	=====================================================
 *	ENEMY FUNCTIONS AND DEFINES
 *	=====================================================
 */

enum EnemyMemoryType
{
	EnemyMemoryType_Invalid = -1,
	EnemyMemoryType_Scent = 0,		// "Smells" this entity. Used for patrolling around enemies that "get away".
	EnemyMemoryType_Glimpse,		// Saw this entity, but not enough for the NPC to go into full chase mode.
	EnemyMemoryType_Sight			// LET'S GO MUTHATFUCKA!
};

enum
{
	EnemyMemoryStruct_EntRef = 0,
	EnemyMemoryStruct_Type,
	EnemyMemoryStruct_LastKnownTime,
	EnemyMemoryStruct_LastKnownPosX,
	EnemyMemoryStruct_LastKnownPosY,
	EnemyMemoryStruct_LastKnownPosZ,
	EnemyMemoryStruct_LastKnownAreaIndex,
	EnemyMemoryStruct_Awareness,
	EnemyMemoryStruct_AwarenessDecayRate,
	EnemyMemoryStruct_NextAwarenessDecayTime,
	EnemyMemoryStruct_AwarenessIncreaseRate,
	EnemyMemoryStruct_NextAwarenessIncreaseTime,
	EnemyMemoryStruct_MaxStats
};

static Handle:g_hNPCEnemyMemory[MAX_BOSSES] =  { INVALID_HANDLE, ... };

static NPCAdvChaser_InitializeEnemyMemory(iNPCIndex)
{
	// Free up memory in case it wasn't freed earlier.
	NPCAdvChaser_FreeEnemyMemory(iNPCIndex);
	
	g_hNPCEnemyMemory[iNPCIndex] = CreateArray(EnemyMemoryStruct_MaxStats);
}

static NPCAdvChaser_ClearEnemyMemory(iNPCIndex)
{
	ClearArray(g_hNPCEnemyMemory[iNPCIndex]);
}

static NPCAdvChaser_FreeEnemyMemory(iNPCIndex)
{
	new Handle:hMemory = g_hNPCEnemyMemory[iNPCIndex];
	if (hMemory != INVALID_HANDLE)
	{
		CloseHandle(g_hNPCEnemyMemory[iNPCIndex]);
		g_hNPCEnemyMemory[iNPCIndex] = INVALID_HANDLE;
	}
}

static NPCAdvChaser_GetMemoryIndexOfEntity(iNPCIndex, ent)
{
	if (!IsValidEntity(ent)) return -1;
	
	return FindValueInArray(g_hNPCEnemyMemory[iNPCIndex], EntIndexToEntRef(ent));
}

static bool:NPCAdvChaser_IsEntityInMemory(iNPCIndex, ent)
{
	return bool:(NPCAdvChaser_GetMemoryIndexOfEntity(iNPCIndex, ent) != -1)
}

static NPCAdvChaser_AddEnemyToMemory(iNPCIndex, enemy, EnemyMemoryType:memoryType, awareness=0, Float:awarenessIncreaseRate=1.0, Float:awarenessDecayRate=1.0)
{
	new memoryIndex = NPCAdvChaser_GetMemoryIndexOfEntity(iNPCIndex, enemy);
	if (memoryIndex != -1)
	{
		return memoryIndex;
	}
	
	memoryIndex = PushArrayCell(g_hNPCEnemyMemory[iNPCIndex], EntIndexToEntRef(enemy));
	SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, memoryType, EnemyMemoryStruct_Type);
	SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, GetGameTime(), EnemyMemoryStruct_LastKnownTime);
	
	decl Float:flPos[3];
	GetEntPropVector(enemy, Prop_Data, "m_vecAbsOrigin", flPos);
	
	SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, flPos[0], EnemyMemoryStruct_LastKnownPosX);
	SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, flPos[1], EnemyMemoryStruct_LastKnownPosY);
	SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, flPos[2], EnemyMemoryStruct_LastKnownPosZ);
	
	new areaIndex = NavMesh_GetNearestArea(flPos, _, SF2_NPC_ADVCHASER_NEARESTAREA_RADIUS);
	
	SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, areaIndex, EnemyMemoryStruct_LastKnownAreaIndex);
	
	SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, awareness, EnemyMemoryStruct_Awareness);
	SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, awarenessIncreaseRate, EnemyMemoryStruct_AwarenessIncreaseRate);
	SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, awarenessDecayRate, EnemyMemoryStruct_AwarenessDecayRate);
	
	new Float:nextAwarenessDecayTime = GetGameTime() + (1.0 / awarenessDecayRate);
	SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, nextAwarenessDecayTime, EnemyMemoryStruct_NextAwarenessDecayTime);
	SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, -1.0, EnemyMemoryStruct_NextAwarenessIncreaseTime);
	
	return memoryIndex;
}

static NPCAdvChaser_UpdateEnemyPosInMemory(iNPCIndex, enemy, const Float:flPos[3])
{
	new memoryIndex = NPCAdvChaser_GetMemoryIndexOfEntity(iNPCIndex, enemy);
	if (memoryIndex == -1)
	{
		return;
	}
	
	SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, GetGameTime(), EnemyMemoryStruct_LastKnownTime);
	SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, flPos[0], EnemyMemoryStruct_LastKnownPosX);
	SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, flPos[1], EnemyMemoryStruct_LastKnownPosY);
	SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, flPos[2], EnemyMemoryStruct_LastKnownPosZ);
	
	new areaIndex = NavMesh_GetNearestArea(flPos, _, SF2_NPC_ADVCHASER_NEARESTAREA_RADIUS);
	
	SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, areaIndex, EnemyMemoryStruct_LastKnownAreaIndex);
}

static bool:NPCAdvChaser_GetEnemyPosInMemory(iNPCIndex, enemy, Float:buffer[3])
{
	new memoryIndex = NPCAdvChaser_GetMemoryIndexOfEntity(iNPCIndex, enemy);
	if (memoryIndex == -1)
	{
		return false;
	}
	
	buffer[0] = Float:GetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, EnemyMemoryStruct_LastKnownPosX);
	buffer[1] = Float:GetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, EnemyMemoryStruct_LastKnownPosY);
	buffer[2] = Float:GetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, EnemyMemoryStruct_LastKnownPosZ);
	
	return true;
}

static NPCAdvChaser_GetEnemyAreaIndexInMemory(iNPCIndex, enemy)
{
	new memoryIndex = NPCAdvChaser_GetMemoryIndexOfEntity(iNPCIndex, enemy);
	if (memoryIndex == -1)
	{
		return -1;
	}
	
	return GetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, EnemyMemoryStruct_LastKnownAreaIndex);
}

static NPCAdvChaser_UpdateEnemyMemoryType(iNPCIndex, enemy, EnemyMemoryType:memoryType)
{
	new memoryIndex = NPCAdvChaser_GetMemoryIndexOfEntity(iNPCIndex, enemy);
	if (memoryIndex == -1)
	{
		return;
	}
	
	SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, memoryType, EnemyMemoryStruct_Type);
}

static EnemyMemoryType:NPCAdvChaser_GetEnemyMemoryType(iNPCIndex, enemy)
{
	new memoryIndex = NPCAdvChaser_GetMemoryIndexOfEntity(iNPCIndex, enemy);
	if (memoryIndex == -1)
	{
		return EnemyMemoryType_Invalid;
	}
	
	return EnemyMemoryType:GetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, EnemyMemoryStruct_Type);
}

static NPCAdvChaser_UpdateEnemyAwareness(iNPCIndex, enemy, awareness)
{
	new memoryIndex = NPCAdvChaser_GetMemoryIndexOfEntity(iNPCIndex, enemy);
	if (memoryIndex == -1)
	{
		return;
	}
	
	SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, awareness, EnemyMemoryStruct_Awareness);
}

static NPCAdvChaser_GetEnemyAwareness(iNPCIndex, enemy)
{
	new memoryIndex = NPCAdvChaser_GetMemoryIndexOfEntity(iNPCIndex, enemy);
	if (memoryIndex == -1)
	{
		return 0;
	}
	
	return GetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, EnemyMemoryStruct_Awareness);
}

static NPCAdvChaser_UpdateEnemyAwarenessDecayRate(iNPCIndex, enemy, Float:awarenessDecayRate)
{
	new memoryIndex = NPCAdvChaser_GetMemoryIndexOfEntity(iNPCIndex, enemy);
	if (memoryIndex == -1)
	{
		return;
	}

	SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, awarenessDecayRate, EnemyMemoryStruct_AwarenessDecayRate);
}

static Float:NPCAdvChaser_GetEnemyAwarenessDecayRate(iNPCIndex, enemy)
{
	new memoryIndex = NPCAdvChaser_GetMemoryIndexOfEntity(iNPCIndex, enemy);
	if (memoryIndex == -1)
	{
		return 0.0;
	}
	
	return Float:GetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, EnemyMemoryStruct_AwarenessDecayRate);
}

static NPCAdvChaser_UpdateEnemyAwarenessIncreaseRate(iNPCIndex, enemy, Float:awarenessIncreaseRate)
{
	new memoryIndex = NPCAdvChaser_GetMemoryIndexOfEntity(iNPCIndex, enemy);
	if (memoryIndex == -1)
	{
		return;
	}

	SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, awarenessIncreaseRate, EnemyMemoryStruct_AwarenessIncreaseRate);
}

static Float:NPCAdvChaser_GetEnemyAwarenessIncreaseRate(iNPCIndex, enemy)
{
	new memoryIndex = NPCAdvChaser_GetMemoryIndexOfEntity(iNPCIndex, enemy);
	if (memoryIndex == -1)
	{
		return 0.0;
	}
	
	return Float:GetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, EnemyMemoryStruct_AwarenessIncreaseRate);
}

static NPCAdvChaser_GatherEnemies(iNPCIndex)
{
	// @TODO: Define the variables in the config file instead of hardcoding the values.
	
	// Initial values for EnemyMemoryType_Sight
	new Float:awarenessIncreaseRateOnSight = 5.0;	// how much awareness to increase per second
	new Float:awarenessDecayDelayOnSight = 1.0;	//  how much to delay awareness decay upon sight (delay does not stack! delay is reset to initial amount every frame upon seeing the enemy!)
	new Float:awarenessDecayRateOnSight = 1.0; // how much awareness to decrease per second
	new awarenessInitialAmountOnSight = 50; // awareness will be set to this amount upon entering a certain memory type for the first time
	
	// Initial values for EnemyMemoryType_Glimpse
	new Float:awarenessIncreaseRateOnGlimpse = 5.0;
	new Float:awarenessDecayDelayOnGlimpse = 1.0;
	new Float:awarenessDecayRateOnGlimpse = 1.0;
	new awarenessInitialAmountOnGlimpse = 25;
	
	// Initial values for EnemyMemoryType_Scent
	new Float:awarenessIncreaseRateOnScent = 15.0;
	new Float:awarenessDecayDelayOnScent = 1.0;
	new Float:awarenessDecayRateOnScent = 1.0;
	new awarenessInitialAmountOnScent = 25;
	
	// Update clients first.
	for (new client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || !IsPlayerAlive(client)) continue;
		
		new bool:enemyIsVisible = false;
		
		if (enemyIsVisible) // I see this player...
		{
			new memoryIndex = NPCAdvChaser_GetMemoryIndexOfEntity(iNPCIndex, client);
			if (memoryIndex != -1)
			{
				new awareness = NPCAdvChaser_GetEnemyAwareness(iNPCIndex, client);
				
				new EnemyMemoryType:memoryType = NPCAdvChaser_GetEnemyMemoryType(iNPCIndex, client);
				switch (memoryType)
				{
					case EnemyMemoryType_Scent:
					{
						if (awareness >= 100)
						{
							// TRANSITION: SCENT -------> GLIMPSE
							
							NPCAdvChaser_UpdateEnemyMemoryType(iNPCIndex, client, EnemyMemoryType_Glimpse);
							NPCAdvChaser_UpdateEnemyAwareness(iNPCIndex, client, awarenessInitialAmountOnGlimpse);
							
							decl Float:flPos[3];
							GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", flPos);
							
							NPCAdvChaser_UpdateEnemyPosInMemory(iNPCIndex, client, flPos);
							NPCAdvChaser_UpdateEnemyAwarenessDecayRate(iNPCIndex, client, awarenessDecayRateOnGlimpse);
							NPCAdvChaser_UpdateEnemyAwarenessIncreaseRate(iNPCIndex, client, awarenessIncreaseRateOnGlimpse);
							
							new Float:nextAwarenessDecayTime = GetGameTime() + (1.0 / awarenessDecayRateOnGlimpse) + awarenessDecayDelayOnGlimpse;
							SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, nextAwarenessDecayTime, EnemyMemoryStruct_NextAwarenessDecayTime);
							
							new Float:nextAwarenessIncreaseTime = GetGameTime() + (1.0 / awarenessDecayRateOnGlimpse) + awarenessDecayDelayOnGlimpse;
							SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, nextAwarenessIncreaseTime, EnemyMemoryStruct_NextAwarenessIncreaseTime);
							
#if defined DEBUG
							if (GetConVarBool(g_cvDebugAwareness))
							{
								decl String:sProfile[SF2_MAX_PROFILE_NAME_LENGTH];
								NPCGetProfile(iNPCIndex, sProfile, sizeof(sProfile));
							
								DebugMessage("Boss %d (%s): AW -> START TRANSITION: SCENT -------> GLIMPSE", iNPCIndex, sProfile);
								DebugMessage("-> ent: %d", client);
								DebugMessage("-> memtype: %d", NPCAdvChaser_GetEnemyMemoryType(iNPCIndex, client));
								DebugMessage("-> aw: %d", NPCAdvChaser_GetEnemyAwareness(iNPCIndex, client));
								DebugMessage("-> area: %d", NPCAdvChaser_GetEnemyAreaIndexInMemory(iNPCIndex, client));
								DebugMessage("-> decay rate: %f", NPCAdvChaser_GetEnemyAwarenessDecayRate(iNPCIndex, client));
								DebugMessage("-> increase rate: %f", NPCAdvChaser_GetEnemyAwarenessIncreaseRate(iNPCIndex, client));
								DebugMessage("-> next decay: %f", nextAwarenessDecayTime);
								DebugMessage("-> next increase: %f", nextAwarenessIncreaseTime);
								DebugMessage("Boss %d (%s): AW -> END TRANSITION", iNPCIndex, sProfile);
							}
#endif
						}
						else
						{
							// STAY: -------> SCENT <-------
							
							new Float:nextAwarenessDecayTime = GetGameTime() + (1.0 / awarenessDecayRateOnScent) + awarenessDecayDelayOnScent;
							SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, nextAwarenessDecayTime, EnemyMemoryStruct_NextAwarenessDecayTime);
							
							new Float:nextAwarenessIncreaseTime = Float:GetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, EnemyMemoryStruct_NextAwarenessIncreaseTime);
							if (nextAwarenessIncreaseTime < 0.0)
							{
								new Float:currentAwarenessIncreaseRate = NPCAdvChaser_GetEnemyAwarenessIncreaseRate(iNPCIndex, client);
								nextAwarenessIncreaseTime = GetGameTime() + (1.0 / currentAwarenessIncreaseRate);
								SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, nextAwarenessIncreaseTime, EnemyMemoryStruct_NextAwarenessIncreaseTime);
							}
						}
					}
					case EnemyMemoryType_Glimpse:
					{
						if (awareness >= 100)
						{
							// TRANSITION: GLIMPSE -------> SIGHT
							
							NPCAdvChaser_UpdateEnemyMemoryType(iNPCIndex, client, EnemyMemoryType_Sight);
							NPCAdvChaser_UpdateEnemyAwareness(iNPCIndex, client, awarenessInitialAmountOnSight);
							
							decl Float:flPos[3];
							GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", flPos);
							
							NPCAdvChaser_UpdateEnemyPosInMemory(iNPCIndex, client, flPos);
							NPCAdvChaser_UpdateEnemyAwarenessDecayRate(iNPCIndex, client, awarenessDecayRateOnSight);
							NPCAdvChaser_UpdateEnemyAwarenessIncreaseRate(iNPCIndex, client, awarenessIncreaseRateOnSight);
							
							new Float:nextAwarenessDecayTime = GetGameTime() + (1.0 / awarenessDecayRateOnSight) + awarenessDecayDelayOnSight;
							SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, nextAwarenessDecayTime, EnemyMemoryStruct_NextAwarenessDecayTime);
							
							new Float:nextAwarenessIncreaseTime = GetGameTime() + (1.0 / awarenessDecayRateOnSight) + awarenessDecayDelayOnSight;
							SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, nextAwarenessIncreaseTime, EnemyMemoryStruct_NextAwarenessIncreaseTime);
							
#if defined DEBUG
							if (GetConVarBool(g_cvDebugAwareness))
							{
								decl String:sProfile[SF2_MAX_PROFILE_NAME_LENGTH];
								NPCGetProfile(iNPCIndex, sProfile, sizeof(sProfile));
							
								DebugMessage("Boss %d (%s): AW -> START TRANSITION: GLIMPSE -------> SIGHT", iNPCIndex, sProfile);
								DebugMessage("-> ent: %d", client);
								DebugMessage("-> memtype: %d", NPCAdvChaser_GetEnemyMemoryType(iNPCIndex, client));
								DebugMessage("-> aw: %d", NPCAdvChaser_GetEnemyAwareness(iNPCIndex, client));
								DebugMessage("-> area: %d", NPCAdvChaser_GetEnemyAreaIndexInMemory(iNPCIndex, client));
								DebugMessage("-> decay rate: %f", NPCAdvChaser_GetEnemyAwarenessDecayRate(iNPCIndex, client));
								DebugMessage("-> increase rate: %f", NPCAdvChaser_GetEnemyAwarenessIncreaseRate(iNPCIndex, client));
								DebugMessage("-> next decay: %f", nextAwarenessDecayTime);
								DebugMessage("-> next increase: %f", nextAwarenessIncreaseTime);
								DebugMessage("Boss %d (%s): AW -> END TRANSITION", iNPCIndex, sProfile);
							}
#endif
						}
						else
						{
							// STAY: -------> GLIMPSE <-------
							
							new Float:nextAwarenessDecayTime = GetGameTime() + (1.0 / awarenessDecayRateOnGlimpse) + awarenessDecayDelayOnGlimpse;
							SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, nextAwarenessDecayTime, EnemyMemoryStruct_NextAwarenessDecayTime);
							
							new Float:nextAwarenessIncreaseTime = Float:GetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, EnemyMemoryStruct_NextAwarenessIncreaseTime);
							if (nextAwarenessIncreaseTime < 0.0)
							{
								new Float:currentAwarenessIncreaseRate = NPCAdvChaser_GetEnemyAwarenessIncreaseRate(iNPCIndex, client);
								nextAwarenessIncreaseTime = GetGameTime() + (1.0 / currentAwarenessIncreaseRate);
								SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, nextAwarenessIncreaseTime, EnemyMemoryStruct_NextAwarenessIncreaseTime);
							}
							
							// Update enemy position!
							decl Float:flPos[3];
							GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", flPos);
							
							NPCAdvChaser_UpdateEnemyPosInMemory(iNPCIndex, client, flPos);
						}
					}
					case EnemyMemoryType_Sight:
					{
						// STAY: -------> SIGHT <-------
						
						new Float:nextAwarenessDecayTime = GetGameTime() + (1.0 / awarenessDecayRateOnSight) + awarenessDecayDelayOnSight;
						SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, nextAwarenessDecayTime, EnemyMemoryStruct_NextAwarenessDecayTime);
						
						new Float:nextAwarenessIncreaseTime = Float:GetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, EnemyMemoryStruct_NextAwarenessIncreaseTime);
						if (nextAwarenessIncreaseTime < 0.0)
						{
							new Float:currentAwarenessIncreaseRate = NPCAdvChaser_GetEnemyAwarenessIncreaseRate(iNPCIndex, client);
							nextAwarenessIncreaseTime = GetGameTime() + (1.0 / currentAwarenessIncreaseRate);
							SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, nextAwarenessIncreaseTime, EnemyMemoryStruct_NextAwarenessIncreaseTime);
						}
						
						// Update enemy position!
						decl Float:flPos[3];
						GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", flPos);
						
						NPCAdvChaser_UpdateEnemyPosInMemory(iNPCIndex, client, flPos);
					}
				}
			}
			else
			{
				// JUMP: -------> SCENT
				
				memoryIndex = NPCAdvChaser_AddEnemyToMemory(iNPCIndex, client, EnemyMemoryType_Scent, awarenessInitialAmountOnScent, awarenessIncreaseRateOnScent, awarenessDecayRateOnScent);
				if (memoryIndex != -1)
				{
					new Float:nextAwarenessDecayTime = GetGameTime() + (1.0 / awarenessDecayRateOnScent) + awarenessDecayDelayOnScent;
					SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, nextAwarenessDecayTime, EnemyMemoryStruct_NextAwarenessDecayTime);
				
					new Float:nextAwarenessIncreaseTime = GetGameTime() + (1.0 / awarenessIncreaseRateOnScent);
					SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, nextAwarenessIncreaseTime, EnemyMemoryStruct_NextAwarenessIncreaseTime);
					
#if defined DEBUG
					if (GetConVarBool(g_cvDebugAwareness))
					{
						decl String:sProfile[SF2_MAX_PROFILE_NAME_LENGTH];
						NPCGetProfile(iNPCIndex, sProfile, sizeof(sProfile));
						
						DebugMessage("Boss %d (%s): AW -> START JUMP: -------> SCENT", iNPCIndex, sProfile);
						DebugMessage("-> ent: %d", client);
						DebugMessage("-> memtype: %d", NPCAdvChaser_GetEnemyMemoryType(iNPCIndex, client));
						DebugMessage("-> aw: %d", NPCAdvChaser_GetEnemyAwareness(iNPCIndex, client));
						DebugMessage("-> area: %d", NPCAdvChaser_GetEnemyAreaIndexInMemory(iNPCIndex, client));
						DebugMessage("-> decay rate: %f", NPCAdvChaser_GetEnemyAwarenessDecayRate(iNPCIndex, client));
						DebugMessage("-> increase rate: %f", NPCAdvChaser_GetEnemyAwarenessIncreaseRate(iNPCIndex, client));
						DebugMessage("-> next decay: %f", nextAwarenessDecayTime);
						DebugMessage("-> next increase: %d", nextAwarenessIncreaseTime);
						DebugMessage("Boss %d (%s): AW -> END JUMP", iNPCIndex, sProfile);
					}
#endif
				}
			}
		}
		else // I don't see this player...
		{
			new memoryIndex = NPCAdvChaser_GetMemoryIndexOfEntity(iNPCIndex, client);
			if (memoryIndex != -1)
			{
				new awareness = NPCAdvChaser_GetEnemyAwareness(iNPCIndex, client);
				
				new EnemyMemoryType:memoryType = NPCAdvChaser_GetEnemyMemoryType(iNPCIndex, client);
				switch (memoryType)
				{
					case EnemyMemoryType_Sight:
					{
						if (awareness <= 0)
						{
							// TRANSITION: GLIMPSE <------- SIGHT
							
							NPCAdvChaser_UpdateEnemyMemoryType(iNPCIndex, client, EnemyMemoryType_Glimpse);
							NPCAdvChaser_UpdateEnemyAwareness(iNPCIndex, client, 99);
							
							NPCAdvChaser_UpdateEnemyAwarenessDecayRate(iNPCIndex, client, awarenessDecayRateOnGlimpse);
							NPCAdvChaser_UpdateEnemyAwarenessIncreaseRate(iNPCIndex, client, awarenessIncreaseRateOnGlimpse);
							
							new Float:nextAwarenessDecayTime = GetGameTime() + (1.0 / awarenessDecayRateOnGlimpse);
							SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, nextAwarenessDecayTime, EnemyMemoryStruct_NextAwarenessDecayTime);
							
							SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, -1.0, EnemyMemoryStruct_NextAwarenessIncreaseTime);
							
#if defined DEBUG
							if (GetConVarBool(g_cvDebugAwareness))
							{
								decl String:sProfile[SF2_MAX_PROFILE_NAME_LENGTH];
								NPCGetProfile(iNPCIndex, sProfile, sizeof(sProfile));
							
								DebugMessage("Boss %d (%s): AW -> START TRANSITION: GLIMPSE <------- SIGHT", iNPCIndex, sProfile);
								DebugMessage("-> ent: %d", client);
								DebugMessage("-> memtype: %d", NPCAdvChaser_GetEnemyMemoryType(iNPCIndex, client));
								DebugMessage("-> aw: %d", NPCAdvChaser_GetEnemyAwareness(iNPCIndex, client));
								DebugMessage("-> area: %d", NPCAdvChaser_GetEnemyAreaIndexInMemory(iNPCIndex, client));
								DebugMessage("-> decay rate: %f", NPCAdvChaser_GetEnemyAwarenessDecayRate(iNPCIndex, client));
								DebugMessage("-> increase rate: %f", NPCAdvChaser_GetEnemyAwarenessIncreaseRate(iNPCIndex, client));
								DebugMessage("-> next decay: %f", nextAwarenessDecayTime);
								DebugMessage("-> next increase: -1.0");
								DebugMessage("Boss %d (%s): AW -> END TRANSITION", iNPCIndex, sProfile);
							}
#endif
						}
					}
					case EnemyMemoryType_Glimpse:
					{
						if (awareness <= 0)
						{
							// TRANSITION: SCENT <------- GLIMPSE
							
							NPCAdvChaser_UpdateEnemyMemoryType(iNPCIndex, client, EnemyMemoryType_Scent);
							NPCAdvChaser_UpdateEnemyAwareness(iNPCIndex, client, 99);
							
							NPCAdvChaser_UpdateEnemyAwarenessDecayRate(iNPCIndex, client, awarenessDecayRateOnScent);
							NPCAdvChaser_UpdateEnemyAwarenessIncreaseRate(iNPCIndex, client, awarenessIncreaseRateOnScent);
							
							new Float:nextAwarenessDecayTime = GetGameTime() + (1.0 / awarenessDecayRateOnScent);
							SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, nextAwarenessDecayTime, EnemyMemoryStruct_NextAwarenessDecayTime);
							
							SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, -1.0, EnemyMemoryStruct_NextAwarenessIncreaseTime);
							
#if defined DEBUG
							if (GetConVarBool(g_cvDebugAwareness))
							{
								decl String:sProfile[SF2_MAX_PROFILE_NAME_LENGTH];
								NPCGetProfile(iNPCIndex, sProfile, sizeof(sProfile));
							
								DebugMessage("Boss %d (%s): AW -> START TRANSITION: SCENT <------- GLIMPSE", iNPCIndex, sProfile);
								DebugMessage("-> ent: %d", client);
								DebugMessage("-> memtype: %d", NPCAdvChaser_GetEnemyMemoryType(iNPCIndex, client));
								DebugMessage("-> aw: %d", NPCAdvChaser_GetEnemyAwareness(iNPCIndex, client));
								DebugMessage("-> area: %d", NPCAdvChaser_GetEnemyAreaIndexInMemory(iNPCIndex, client));
								DebugMessage("-> decay rate: %f", NPCAdvChaser_GetEnemyAwarenessDecayRate(iNPCIndex, client));
								DebugMessage("-> increase rate: %f", NPCAdvChaser_GetEnemyAwarenessIncreaseRate(iNPCIndex, client));
								DebugMessage("-> next decay: %f", nextAwarenessDecayTime);
								DebugMessage("-> next increase: -1.0");
								DebugMessage("Boss %d (%s): AW -> END TRANSITION", iNPCIndex, sProfile);
							}
#endif
						}
					}
					case EnemyMemoryType_Scent:
					{
						if (awareness <= 0)
						{
							// FORGET
							
							RemoveFromArray(g_hNPCEnemyMemory[iNPCIndex], memoryIndex);
							
#if defined DEBUG
							if (GetConVarBool(g_cvDebugAwareness))
							{
								decl String:sProfile[SF2_MAX_PROFILE_NAME_LENGTH];
								NPCGetProfile(iNPCIndex, sProfile, sizeof(sProfile));
							
								DebugMessage("Boss %d (%s): AW -> FORGET Entity(%d)", iNPCIndex, sProfile, client);
							}
#endif
						}
					}
				}
			}
		}
	}
}

static NPCAdvChaser_CheckEnemyMemory(iNPCIndex)
{
	for (new memoryIndex = 0; memoryIndex < GetArraySize(g_hNPCEnemyMemory[iNPCIndex]); memoryIndex++)
	{
		new awareness = GetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, EnemyMemoryStruct_Awareness);
		
		new Float:nextIncreaseTime = Float:GetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, EnemyMemoryStruct_NextAwarenessIncreaseTime);
		if (nextIncreaseTime >= 0.0 && GetGameTime() >= nextIncreaseTime)
		{
			awareness++;
			if (awareness > 100) awareness = 100;
			
			SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, awareness, EnemyMemoryStruct_Awareness);
			
			// Immediately reset. GatherEnemies will set this to a positive timestamp if need be.
			SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, -1.0, EnemyMemoryStruct_NextAwarenessIncreaseTime);
		}
		else
		{
			if (awareness > 0)
			{
				new Float:nextDecayTime = Float:GetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, EnemyMemoryStruct_NextAwarenessDecayTime);
				if (GetGameTime() >= nextDecayTime)
				{
					awareness--;
					SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, awareness, EnemyMemoryStruct_Awareness);
					
					new Float:awarenessDecayRate = Float:GetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, EnemyMemoryStruct_AwarenessDecayRate);
					
					new Float:nextAwarenessDecayTime = GetGameTime() + (1.0 / awarenessDecayRate);
					SetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, nextAwarenessDecayTime, EnemyMemoryStruct_NextAwarenessDecayTime);
				}
			}
		}
	}
}

static NPCAdvChaser_SelectEnemy(iNPCIndex, EnemyMemoryType:memoryType=EnemyMemoryType_Sight)
{
	new npc = NPCGetEntIndex(iNPCIndex);
	if (!npc || npc == INVALID_ENT_REFERENCE)
	{
		return INVALID_ENT_REFERENCE;
	}

	decl Float:vPos[3], Float:vEnemyPos[3];
	GetEntPropVector(npc, Prop_Data, "m_vecAbsOrigin", vPos);
	
	new bestEnemy = INVALID_ENT_REFERENCE;
	new Float:bestPriority = -1.0;
	
	for (new memoryIndex = 0; memoryIndex < GetArraySize(g_hNPCEnemyMemory[iNPCIndex]); memoryIndex++)
	{
		new enemy = EntRefToEntIndex(GetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, EnemyMemoryStruct_EntRef));
		if (!enemy || enemy == INVALID_ENT_REFERENCE) continue;
		
		new EnemyMemoryType:type = EnemyMemoryType:GetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, EnemyMemoryStruct_Type);
		if (type != memoryType) continue;
		
		vEnemyPos[0] = Float:GetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, EnemyMemoryStruct_LastKnownPosX);
		vEnemyPos[1] = Float:GetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, EnemyMemoryStruct_LastKnownPosY);
		vEnemyPos[2] = Float:GetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, EnemyMemoryStruct_LastKnownPosZ);
		
		new Float:dist = GetVectorDistance(vPos, vEnemyPos);
		new awareness = GetArrayCell(g_hNPCEnemyMemory[iNPCIndex], memoryIndex, EnemyMemoryStruct_Awareness);
		new Float:priority = dist * (1.0 - (float(awareness) / 100.0))
		if (priority < 0.0)
		{
			priority = 0.0;
		}
		
		if (bestPriority < 0.0 || priority < bestPriority)
		{
			bestEnemy = enemy;
			bestPriority = priority;
		}
	}
	
	return bestEnemy;
}

static NPCAdvChaser_GetEnemy(iNPCIndex)
{
	return NPCGetEnemy(iNPCIndex);
}

static NPCAdvChaser_SetEnemy(iNPCIndex, enemy)
{
	NPCSetEnemy(iNPCIndex, enemy);
}

static NPCAdvChaser_GetGlimpseTarget(iNPCIndex)
{
	return EntRefToEntIndex(g_iNPCGlimpseTarget[iNPCIndex]);
}

static NPCAdvChaser_SetGlimpseTarget(iNPCIndex, target)
{
	g_iNPCGlimpseTarget[iNPCIndex] = IsValidEntity(target) ? EntIndexToEntRef(target) : INVALID_ENT_REFERENCE;
}

static NPCAdvChaser_GetScentTarget(iNPCIndex)
{
	return EntRefToEntIndex(g_iNPCScentTarget[iNPCIndex]);
}

static NPCAdvChaser_SetScentTarget(iNPCIndex, target)
{
	g_iNPCScentTarget[iNPCIndex] = IsValidEntity(target) ? EntIndexToEntRef(target) : INVALID_ENT_REFERENCE;
}

/*	
 *	=====================================================
 *	ATTACK FUNCTIONS
 *	=====================================================
 */

enum SF2NPCAdvChaserAttackType
{
	SF2NPCAdvChaserAttackType_Invalid = -1,
	SF2NPCAdvChaserAttackType_Melee = 0,
	SF2NPCAdvChaserAttackType_Ranged,
	SF2NPCAdvChaserAttackType_Projectile,
	SF2NPCAdvChaserAttackType_Grab
};

enum SF2NPCAdvChaserGoalType
{
	SF2NPCAdvChaserGoalType_Invalid = -1,
	SF2NPCAdvChaserGoalType_Point,
	SF2NPCAdvChaserGoalType_Enemy,
	SF2NPCAdvChaserGoalType_Target
};

enum SF2NPCAdvChaser_BaseAttackData
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
	Float:SF2NPCAdvChaser_BaseAttackViewPunch[3],
	String:SF2NPCAdvChaser_BaseAttackAnimation[64]
	Float:SF2NPCAdvChaser_BaseAttackAnimationPlaybackRate
};

static Handle:g_hNPCAttackDurationTimer[MAX_BOSSES] = { INVALID_HANDLE, ... };
static g_iNPCAttackIndex[MAX_BOSSES] = { -1, ... };

// Base attack data

static g_NPCBaseAttackData[MAX_BOSSES][SF2_ADV_CHASER_BOSS_MAX_ATTACKS][SF2NPCAdvChaser_BaseAttackData];

SF2NPCAdvChaserAttackType:NPCAdvChaser_GetAttackType(iNPCIndex, iAttackIndex)
{
	return SF2NPCAdvChaserAttackType:g_NPCBaseAttackData[iNPCIndex][iAttackIndex][SF2NPCAdvChaser_BaseAttackType];
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

Float:NPCAdvChaser_GetAttackCooldown(iNPCIndex, iAttackIndex)
{
	return g_NPCBaseAttackData[iNPCIndex][iAttackIndex][SF2NPCAdvChaser_BaseAttackCooldown];
}

Float:NPCAdvChaser_GetNextAttackTime(iNPCIndex, iAttackIndex)
{
	return g_NPCBaseAttackData[iNPCIndex][iAttackIndex][SF2NPCAdvChaser_BaseAttackNextAttackTime];
}

NPCAdvChaser_SetNextAttackTime(iNPCIndex, iAttackIndex, Float:time)
{
	g_NPCBaseAttackData[iNPCIndex][iAttackIndex][SF2NPCAdvChaser_BaseAttackNextAttackTime] = time;
}

NPCAdvChaser_GetAttackViewPunch(iNPCIndex, iAttackIndex, Float:buffer[3])
{
	CopyVector(g_NPCBaseAttackData[iNPCIndex][SF2NPCAdvChaser_BaseAttackViewPunch], buffer);
}

NPCAdvChaser_GetAttackAnimation(iNPCIndex, iAttackIndex, String:buffer[], bufferlen)
{
	strcopy(buffer, bufferlen, g_NPCBaseAttackData[iNPCIndex][iAttackIndex][SF2NPCAdvChaser_BaseAttackAnimation]);
}

Float:NPCAdvChaser_GetAttackAnimationPlaybackRate(iNPCIndex, iAttackIndex)
{
	return g_NPCBaseAttackData[iNPCIndex][iAttackIndex][SF2NPCAdvChaser_BaseAttackAnimationPlaybackRate];
}

// MELEE ATTACK
static Handle:g_hNPCMeleeAttackDamageDelayTimer[MAX_BOSSES] = { INVALID_HANDLE, ... };

static NPCAdvChaser_StartMeleeAttack(iNPCIndex, attackIndex)
{
	NPCAdvChaser_SetPreferredActivity(iNPCIndex, SF2AdvChaserActivity_Attack);
	
	new Float:damageDelay = NPCAdvChaser_GetAttackDamageDelay(iNPCIndex, attackIndex);
	new Float:attackDuration = NPCAdvChaser_GetAttackDuration(iNPCIndex, attackIndex);
	
	new Handle:damageTimer = CreateTimer(damageDelay, Timer_NPCAdvChaser_MeleeAttackDamage, iNPCIndex, TIMER_FLAG_NO_MAPCHANGE);
	
	new Handle:durationTimer = CreateTimer(attackDuration, Timer_NPCAdvChaser_MeleeAttackEnd, iNPCIndex, TIMER_FLAG_NO_MAPCHANGE);
	
	g_hNPCMeleeAttackDamageDelayTimer[iNPCIndex] = damageTimer;
	g_hNPCAttackDurationTimer[iNPCIndex] = durationTimer;
	g_iNPCAttackIndex[iNPCIndex] = attackIndex;
	
	// @TODO: Set animation of the boss's model.
	
	// @TODO: Play the starting attack sound of the boss...?
	
	if (damageDelay <= 0.0)
	{
		TriggerTimer(damageTimer);
	}
}

static NPCAdvChaser_EndMeleeAttack(iNPCIndex, bool:wasInterrupted)
{
	NPCAdvChaser_SetPreferredActivity(iNPCIndex, SF2AdvChaserActivity_Stand);
	
	g_hNPCAttackDurationTimer[iNPCIndex] = INVALID_HANDLE;
	g_iNPCAttackIndex[iNPCIndex] = -1;
	g_hNPCMeleeAttackDamageDelayTimer[iNPCIndex] = INVALID_HANDLE;
}

public Action:Timer_NPCAdvChaser_MeleeAttackEnd(Handle:timer, any:iNPCIndex)
{
	if (timer != g_hNPCAttackDurationTimer[iNPCIndex]) return;
	
	g_hNPCAttackDurationTimer[iNPCIndex] = INVALID_HANDLE;
	NPCAdvChaser_EndMeleeAttack(iNPCIndex, false);
}

public Action:Timer_NPCAdvChaser_MeleeAttackDamage(Handle:timer, any:iNPCIndex)
{
	if (timer != g_hNPCMeleeAttackDamageDelayTimer[iNPCIndex]) return;
	
	g_hNPCMeleeAttackDamageDelayTimer[iNPCIndex] = INVALID_HANDLE;
	
	new npc = NPCGetEntIndex(iNPCIndex);
	if (!npc || npc == INVALID_ENT_REFERENCE) return;
	
	new attackIndex = g_iNPCAttackIndex[iNPCIndex];
	
	new Float:attackSpread = NPCAdvChaser_GetAttackSpread(iNPCIndex, attackIndex);
	new Float:attackRange = NPCAdvChaser_GetAttackRange(iNPCIndex, attackIndex);
	new Float:attackDamage = NPCAdvChaser_GetAttackDamage(iNPCIndex, attackIndex);
	new attackDamageType = NPCAdvChaser_GetAttackDamageType(iNPCIndex, attackIndex);
	
	decl Float:vPos[3], Float:eyeAng[3];
	GetEntPropVector(npc, Prop_Data, "m_vecAbsOrigin", vPos);
	GetEntPropVector(npc, Prop_Data, "m_angAbsRotation", eyeAng);
	
	decl Float:vDir[3];
	GetAngleVectors(eyeAng, vDir, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(vDir, vDir);
	
	// Loop through all players (and some prop entities) to check if we hit something.
	new bool:hitSomething = false;
	
	decl Float:vTargetPos[3], Float:vTargetMins[3], Float:vTargetMaxs[3], Float:vCentroid[3], Float:vTo[3];
	
	new Handle:targetList = CreateArray();
	
	// Gather potential hit targets.
	for (new client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || !IsPlayerAlive(client)) continue;
		
		PushArrayCell(targetList, client);
	}
	
	new ent = -1;
	while ((ent = FindEntityByClassname(ent, "prop_physics")) != -1)
	{
		PushArrayCell(targetList, ent);
	}
	
	ent = -1;
	while ((ent = FindEntityByClassname(ent, "prop_dynamic")) != -1)
	{
		PushArrayCell(targetList, ent);
	}
	
	new Float:cosAng = Cosine(DegToRad(attackSpread / 2.0));
	
	// Loop through target list.
	for (new i = 0; i < GetArraySize(targetList); i++)
	{
		new target = GetArrayCell(targetList, i);
	
		// First check if the point is within our FOV.
		GetEntPropVector(target, Prop_Data, "m_vecAbsOrigin", vTargetPos);
		GetEntPropVector(target, Prop_Send, "m_vecMins", vTargetMins);
		GetEntPropVector(target, Prop_Send, "m_vecMaxs", vTargetMaxs);
		AddVectors(vTargetMins, vTargetMaxs, vCentroid);
		ScaleVector(vCentroid, 0.5);
		AddVector(vTargetPos, vCentroid, vTargetPos);
		
		MakeVectorFromPoints(vPos, vTargetPos, vTo);
		NormalizeVector(vTo, vTo);
		if (GetVectorDotProduct(vDir, vTo) >= cosAng)
		{
			// Next, check distance.
			if (GetVectorDistance(vPos, vTargetPos) < attackRange)
			{
				// Finally, do trace check.
				new Handle:trace = TR_TraceRayFilterEx(vPos,
					vTargetPos,
					MASK_NPCSOLID,
					RayType_EndPoint,
					TraceRayDontHitEntity,
					npc);
				
				if (!TR_DidHit(trace) || TR_GetEntityIndex(trace) == target)
				{
					hitSomething = true;
					SDKHooks_TakeDamage(target, npc, npc, attackDamage, attackDamageType, _, _, vPos);
					
					// Apply attributes, if applicable.
					if (IsValidClient(target))
					{
						if (NPCHasAttribute(iNPCIndex, "bleed player on hit"))
						{
							new Float:bleedDuration = NPCGetAttributeValue(iNPCIndex, "bleed player on hit");
							if (bleedDuration > 0.0)
							{
								TF2_MakeBleed(target, npc, bleedDuration);
							}
						}
					}
				}
				
				CloseHandle(trace);
			}
		}
	}
	
	CloseHandle(targetList);
	
	// @TODO: Grab random sounds from a section INSIDE the attack.
	decl String:npcProfile[SF2_MAX_PROFILE_NAME_LENGTH];
	new String:soundPath[PLATFORM_MAX_PATH];
	NPCGetProfile(iNPCIndex, npcProfile, sizeof(npcProfile));
	
	if (hitSomething)
	{
		//GetRandomStringFromProfile(npcProfile, "sound_hitenemy", soundPath, sizeof(soundPath));
		if (soundPath[0]) EmitSoundToAll(soundPath, npc, SNDCHAN_AUTO, SNDLEVEL_SCREAMING);
	}
	else
	{
		//GetRandomStringFromProfile(npcProfile, "sound_missenemy", soundPath, sizeof(soundPath));
		if (soundPath[0]) EmitSoundToAll(soundPath, npc, SNDCHAN_AUTO, SNDLEVEL_SCREAMING);
	}
}

// RANGED ATTACK

enum SF2NPCAdvChaser_RangedAttackData
{
	SF2NPCAdvChaser_RangedAttackNumBulletsPerShot,
	SF2NPCAdvChaser_RangedAttackBurstNum,
	Float:SF2NPCAdvChaser_RangedAttackBurstDuration,
	Float:SF2NPCAdvChaser_RangedAttackNextBurstShotTime,
	SF2NPCAdvChaser_RangedAttackBurstShotsLeft,
	Float:SF2NPCAdvChaser_RangedAttackShootRelativePos[3],
	String:SF2NPCAdvChaser_RangedAttackShootAttachment[64],
	SF2NPCAdvChaser_RangedAttackShootPosEntity,
	String:SF2NPCAdvChaser_RangedAttackTracerParticle[64]
};

static g_NPCRangedAttackData[MAX_BOSSES][SF2_ADV_CHASER_BOSS_MAX_ATTACKS][SF2NPCAdvChaser_RangedAttackData];

static NPCAdvChaser_StartRangedAttack(iNPCIndex, attackIndex)
{
	new Float:attackDuration = NPCAdvChaser_GetAttackDuration(iNPCIndex, attackIndex);

	new Handle:durationTimer = CreateTimer(attackDuration, Timer_NPCAdvChaser_RangedAttackEnd, iNPCIndex, TIMER_FLAG_NO_MAPCHANGE);
	
	g_hNPCAttackDurationTimer[iNPCIndex] = durationTimer;
	g_iNPCAttackIndex[iNPCIndex] = attackIndex;

	new burstShotsNum = g_NPCRangedAttackData[iNPCIndex][attackIndex][SF2NPCAdvChaser_RangedAttackBurstNum];
	
	g_NPCRangedAttackData[iNPCIndex][attackIndex][SF2NPCAdvChaser_RangedAttackNextBurstShotTime] = GetGameTime();
	g_NPCRangedAttackData[iNPCIndex][attackIndex][SF2NPCAdvChaser_RangedAttackBurstShotsLeft] = burstShotsNum;
}

static NPCAdvChaser_RangedAttackThink(iNPCIndex)
{
	new npc = NPCGetEntIndex(iNPCIndex);
	if (!npc || npc == INVALID_ENT_REFERENCE) return;	// this should NEVER happen.

	new attackIndex = g_iNPCAttackIndex[iNPCIndex];
	
	new burstShotsLeft = g_NPCRangedAttackData[iNPCIndex][attackIndex][SF2NPCAdvChaser_RangedAttackBurstShotsLeft];
	if (burstShotsLeft > 0)
	{
		if (GetGameTime() >= g_NPCRangedAttackData[iNPCIndex][attackIndex][SF2NPCAdvChaser_RangedAttackNextBurstShotTime])
		{
			g_NPCRangedAttackData[iNPCIndex][attackIndex][SF2NPCAdvChaser_RangedAttackBurstShotsLeft] = --burstShotsLeft;
			
			if (burstShotsLeft > 0)
			{
				// We still got another bullet to fire in the burst.
				
				new Float:burstDuration = g_NPCRangedAttackData[iNPCIndex][attackIndex][SF2NPCAdvChaser_RangedAttackBurstDuration];
				new burstNum = g_NPCRangedAttackData[iNPCIndex][attackIndex][SF2NPCAdvChaser_RangedAttackBurstNum];
				
				g_NPCRangedAttackData[iNPCIndex][attackIndex][SF2NPCAdvChaser_RangedAttackNextBurstShotTime] = GetGameTime() + (burstDuration / float(burstNum));
			}
			
			// @TODO: Fire the bullets.
			
			new shootPosEnt = EntRefToEntIndex(g_NPCRangedAttackData[iNPCIndex][attackIndex][SF2NPCAdvChaser_RangedAttackShootPosEntity]);
			if (!shootPosEnt || shootPosEnt == INVALID_ENT_REFERENCE)
			{
				shootPosEnt = NPCAdvChaser_CreateShootPosEntity(iNPCIndex, g_NPCRangedAttackData[iNPCIndex][attackIndex][SF2NPCAdvChaser_RangedAttackShootAttachment]);
				g_NPCRangedAttackData[iNPCIndex][attackIndex][SF2NPCAdvChaser_RangedAttackShootPosEntity] = IsValidEntity(shootPosEnt) ? EntIndexToEntRef(shootPosEnt) : INVALID_ENT_REFERENCE;
				
				TeleportEntity(shootPosEnt, g_NPCRangedAttackData[iNPCIndex][attackIndex][SF2NPCAdvChaser_RangedAttackShootRelativePos], NULL_VECTOR, NULL_VECTOR);
			}
			
			if (shootPosEnt && shootPosEnt != INVALID_ENT_REFERENCE)
			{
				new Float:attackRange = NPCAdvChaser_GetAttackRange(iNPCIndex, attackIndex);
				new Float:attackSpread = NPCAdvChaser_GetAttackSpread(iNPCIndex, attackIndex);
			
				decl Float:vStartPos[3];
				GetEntPropVector(shootPosEnt, Prop_Data, "m_vecAbsOrigin", vStartPos);
				
				// @TODO: Base aim by direction towards the target, not by current direction that I'm facing (add target global var for target?)
				
				decl Float:vBulletAng[3], Float:vBulletDir[3];
				GetEntPropVector(npc, Prop_Data, "m_angAbsRotation", vBulletAng);
				
				vBulletAng[0] += GetRandomFloat(-attackSpread, attackSpread);
				vBulletAng[1] += GetRandomFloat(-attackSpread, attackSpread);
				
				GetAngleVectors(vBulletAng, vBulletDir, NULL_VECTOR, NULL_VECTOR);
				NormalizeVector(vBulletDir, vBulletDir);
				
				decl Float:vEndPos[3];
				CopyVector(vBulletDir, vEndPos);
				ScaleVector(vEndPos, attackRange);
				AddVectors(vStartPos, vEndPos, vEndPos);
				
				new Handle:trace = TR_TraceRayFilterEx(vStartPos,
					vEndPos,
					MASK_NPCSOLID,
					RayType_EndPoint,
					TraceRayDontHitEntity,
					npc);
				
				TR_GetEndPosition(vEndPos, trace);
				
				if (TR_DidHit(trace))
				{
					// @TODO: Damage the hit entity.
				}
				
				CloseHandle(trace);
				
				// @TODO: Add tracers.
			}
		}
	}
}

static NPCAdvChaser_CreateShootPosEntity(iNPCIndex, const String:attachName[]="")
{
	new npc = NPCGetEntIndex(iNPCIndex);
	if (!npc || npc == INVALID_ENT_REFERENCE) return INVALID_ENT_REFERENCE;
	
	new ent = CreateEntityByName("info_particle_system");
	if (ent == -1) return INVALID_ENT_REFERENCE;
	
	DispatchKeyValue(ent, "effect_name", "default");
	SetVariantString("!activator");
	AcceptEntityInput(ent, "SetParent", npc);
	SetVariantString(attachName);
	AcceptEntityInput(ent, "SetParentAttachment");
	
	return ent;
}

static NPCAdvChaser_EndRangedAttack(iNPCIndex, bool:wasInterrupted)
{
}

public Action:Timer_NPCAdvChaser_RangedAttackEnd(Handle:timer, any:iNPCIndex)
{
	if (timer != g_hNPCAttackDurationTimer[iNPCIndex]) return;
	
	g_hNPCAttackDurationTimer[iNPCIndex] = INVALID_HANDLE;
	NPCAdvChaser_EndRangedAttack(iNPCIndex, false);
}

/*	
 *	=====================================================
 *	GENERIC FUNCTIONS
 *	=====================================================
 */

InitializeAdvChaserSystem()
{
	InitializeScheduleSystem();
	
#if defined DEBUG
	g_cvDebugScheduleThink = CreateConVar("sf2_debug_advchaser_schedule", "0");
	g_cvDebugAwareness = CreateConVar("sf2_debug_advchaser_awareness", "0");
#endif
}

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
	g_iNPCAnimationNeedsUpdate[iNPCIndex] = true;
}

static SF2AdvChaserActivity:NPCAdvChaser_SelectActivity(iNPCIndex)
{
	new SF2AdvChaserActivity:activity = NPCAdvChaser_GetActivity(iNPCIndex);
	new SF2AdvChaserActivity:preferredActivity = NPCAdvChaser_GetPreferredActivity(iNPCIndex)
	
	switch (preferredActivity)
	{
		case SF2AdvChaserActivity_Walk, SF2AdvChaserActivity_Run:
		{
			new npc = NPCGetEntIndex(iNPCIndex);
			if (npc && npc != INVALID_ENT_REFERENCE)
			{
				if (activity != SF2AdvChaserActivity_Jump)
				{
					new Handle:hPath = g_hNPCPath[iNPCIndex];
					if (hPath != INVALID_HANDLE && GetArraySize(hPath) > 0)
					{
						new behindPathNodeIndex = g_iNPCPathBehindNodeIndex[iNPCIndex];
						if (behindPathNodeIndex != -1)
						{
							new areaIndex = NavPathGetNodeAreaIndex(hPath, behindPathNodeIndex);
							if (areaIndex != -1)
							{
								new areaFlags = NavMeshArea_GetFlags(areaIndex);
								if (areaFlags & NAV_MESH_JUMP)
								{
									if (NPCAdvChaser_IsOnGround(iNPCIndex))
									{
										return SF2AdvChaserActivity_Jump;
									}
								}
							}
						}
					}
				}
				else
				{
					if (!NPCAdvChaser_IsOnGround(iNPCIndex))
					{
						// We're still in the air; maintain this activity.
						return SF2AdvChaserActivity_Jump;
					}
				}
			}
		}
	}

	return preferredActivity;
}

static bool:NPCAdvChaser_IsOnGround(iNPCIndex)
{
	new npc = NPCGetEntIndex(iNPCIndex);
	if (!npc || npc == INVALID_ENT_REFERENCE) return false;
	
	// Check if the NPC is on the ground first.
	decl Float:vPos[3], Float:vFloorPos[3], Float:vMins[3], Float:vMaxs[3];
	GetEntPropVector(npc, Prop_Data, "m_vecAbsOrigin", vPos);
	GetEntPropVector(npc, Prop_Send, "m_vecMins", vMins);
	GetEntPropVector(npc, Prop_Send, "m_vecMaxs", vMaxs);
	CopyVector(vPos, vFloorPos);
	vFloorPos[2] -= 1.0;
	
	new Handle:trace = TR_TraceHullFilterEx(vPos, vFloorPos, vMins, vMaxs, MASK_NPCSOLID_BRUSHONLY, RayType_EndPoint, TraceRayDontHitEntity, npc);
	new bool:traceDidHit = TR_DidHit(trace);
	CloseHandle(hTrace);
	
	return traceDidHit;
}

static NPCAdvChaser_StopMoving(iNPCIndex)
{
	NPCAdvChaser_SetPreferredActivity(iNPCIndex, SF2AdvChaserActivity_Stand);
	NPCAdvChaser_ClearPath(iNPCIndex);
}

Float:NPCAdvChaser_GetWakeRadius(iNPCIndex)
{
	return g_flNPCWakeRadius[iNPCIndex];
}

Float:NPCAdvChaser_GetStepSize(iNPCIndex)
{
	return g_flNPCStepSize[iNPCIndex];
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
		
		if (scheduleTaskState == ScheduleTaskState_Failed)
		{
			if (strlen(failReasonMsg) > 0)
			{
#if defined DEBUG
				if (GetConVarBool(g_cvDebugScheduleThink))
				{
					decl String:sProfile[SF2_MAX_PROFILE_NAME_LENGTH];
					NPCGetProfile(iNPCIndex, sProfile, sizeof(sProfile));
					
					decl String:scheduleName[64];
					GetScheduleName(schedule, scheduleName, sizeof(scheduleName));
					
					DebugMessage("Boss %d (%s): schedule %s failed at task %s in StartTask! (%s)", iNPCIndex, sProfile, scheduleName, g_ScheduleTaskNames[_:taskID], failReasonMsg);
				}
#endif
			}
		}
	}
	
	if (scheduleTaskState == ScheduleTaskState_Running)
	{
		scheduleTaskState = NPCAdvChaser_RunTask(iNPCIndex, taskID, taskData, failReasonMsg, sizeof(failReasonMsg));
		
		if (scheduleTaskState == ScheduleTaskState_Failed)
		{
			if (strlen(failReasonMsg) > 0)
			{
#if defined DEBUG
				if (GetConVarBool(g_cvDebugScheduleThink))
				{
					decl String:sProfile[SF2_MAX_PROFILE_NAME_LENGTH];
					NPCGetProfile(iNPCIndex, sProfile, sizeof(sProfile));
					
					decl String:scheduleName[64];
					GetScheduleName(schedule, scheduleName, sizeof(scheduleName));
					
					DebugMessage("Boss %d (%s): schedule %s failed at task %s in RunTask! (%s)", iNPCIndex, sProfile, scheduleName, g_ScheduleTaskNames[_:taskID], failReasonMsg);
				}
#endif
			}
		}
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
		case TASK_TRAVERSE_PATH:
		{
			new Handle:hPath = g_hNPCPath[iNPCIndex];
			if (hPath == INVALID_HANDLE || !GetArraySize(hPath))
			{
				NPCAdvChaser_StopMoving(iNPCIndex);
			
				strcopy(failReasonMsg, failReasonMsgLen, "Path is invalid.");
				return ScheduleTaskState_Failed;
			}
			
			return ScheduleTaskState_Running;
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
		case TASK_GET_PATH_TO_SAVEPOSITION:
		{
			new npc = NPCGetEntIndex(iNPCIndex);
			if (!npc || npc == INVALID_ENT_REFERENCE)
			{
				Format(failReasonMsg, failReasonMsgLen, "NPC entity does not exist");
				return ScheduleTaskState_Failed;
			}
			
			NPCAdvChaser_ClearPath(iNPCIndex);
			
			// g_flNPCSavePosition
			
			decl Float:flStartPos[3];
			GetEntPropVector(npc, Prop_Data, "m_vecAbsOrigin", flStartPos);
			
			new Handle:hPath = CreateNavPath();
			if (!NavPathConstructPathFromPoints(hPath, flStartPos, flEndPos, SF2_NPC_ADVCHASER_NEARESTAREA_RADIUS, NPCAdvChaser_ShortestPathCost, NPCAdvChaser_GetStepSize(iNPCIndex)))
			{
				CloseHandle(hPath);
				Format(failReasonMsg, failReasonMsgLen, "Failed to construct path to saveposition.");
				return ScheduleTaskState_Failed;
			}
			
			g_hNPCPath[iNPCIndex] = hPath;
			g_iNPCPathNodeIndex[iNPCIndex] = 1;
			g_iNPCPathBehindNodeIndex[iNPCIndex] = 0;
			
			g_iNPCPathGoalType[iNPCIndex] = SF2NPCAdvChaserGoalType_Point;
			g_iNPCPathGoalEntity[iNPCIndex] = INVALID_ENT_REFERENCE;
			g_iNPCPathGoalEntityLastKnownAreaIndex[iNPCIndex] = -1;
			
			return ScheduleTaskState_Completed;
			
		}
		case TASK_GET_PATH_TO_ENEMY:
		{
			new npc = NPCGetEntIndex(iNPCIndex);
			if (!npc || npc == INVALID_ENT_REFERENCE)
			{
				Format(failReasonMsg, failReasonMsgLen, "NPC entity does not exist");
				return ScheduleTaskState_Failed;
			}
			
			NPCAdvChaser_ClearPath(iNPCIndex);
			
			new enemy = NPCGetEnemy(iNPCIndex);
			if (!enemy || enemy == INVALID_ENT_REFERENCE)
			{
				Format(failReasonMsg, failReasonMsgLen, "NPC does not have an enemy.");
				return ScheduleTaskState_Failed;
			}
			
			decl Float:flEndPos[3];
			if (!NPCAdvChaser_GetEnemyPosInMemory(iNPCIndex, enemy, flEndPos))
			{
				Format(failReasonMsg, failReasonMsgLen, "Enemy is not in memory.");
				return ScheduleTaskState_Failed;
			}
			
			decl Float:flStartPos[3];
			GetEntPropVector(npc, Prop_Data, "m_vecAbsOrigin", flStartPos);
			
			new Handle:hPath = CreateNavPath();
			if (!NavPathConstructPathFromPoints(hPath, flStartPos, flEndPos, SF2_NPC_ADVCHASER_NEARESTAREA_RADIUS, NPCAdvChaser_ShortestPathCost, NPCAdvChaser_GetStepSize(iNPCIndex)))
			{
				CloseHandle(hPath);
				Format(failReasonMsg, failReasonMsgLen, "Failed to construct path to enemy.");
				return ScheduleTaskState_Failed;
			}
			
			g_hNPCPath[iNPCIndex] = hPath;
			g_iNPCPathNodeIndex[iNPCIndex] = 1;
			g_iNPCPathBehindNodeIndex[iNPCIndex] = 0;
			
			g_iNPCPathGoalType[iNPCIndex] = SF2NPCAdvChaserGoalType_Enemy;
			g_iNPCPathGoalEntity[iNPCIndex] = EntIndexToEntRef(entity);
			
			new lastAreaIndex = NavPathGetNodeAreaIndex(hPath, GetArraySize(hPath) - 1);
			g_iNPCPathGoalEntityLastKnownAreaIndex[iNPCIndex] = lastAreaIndex;
			
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

static ScheduleTaskState:NPCAdvChaser_RunTask(iNPCIndex, ScheduleTask:taskID, any:taskData, String:failReasonMsg[], failReasonMsgLen)
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
		case TASK_TRAVERSE_PATH:
		{
			new Handle:hPath = g_hNPCPath[iNPCIndex];
			if (hPath == INVALID_HANDLE || !GetArraySize(hPath))
			{
				NPCAdvChaser_StopMoving(iNPCIndex);
				
				strcopy(failReasonMsg, failReasonMsgLen, "Path is invalid.");
				return ScheduleTaskState_Failed;
			}
			
			new npc = NPCGetEntIndex(iNPCIndex);
			if (!npc || npc == INVALID_ENT_REFERENCE)
			{
				NPCAdvChaser_StopMoving(iNPCIndex);
				
				strcopy(failReasonMsg, failReasonMsgLen, "NPC entity does not exist.");
				return ScheduleTaskState_Failed;
			}
			
			// If applicable, validate our goal entity and check if we need to repath.
			switch (g_iNPCPathGoalType[iNPCIndex])
			{
				case SF2NPCAdvChaserGoalType_Enemy:
				{
					new enemy = EntRefToEntIndex(g_iNPCPathGoalEntity[iNPCIndex]);
					if (!enemy || enemy == INVALID_ENT_REFERENCE)
					{
						// No enemy selected? Abort.
						NPCAdvChaser_StopMoving(iNPCIndex);
						
						strcopy(failReasonMsg, failReasonMsgLen, "Goal entity (enemy) does not exist.");
						return ScheduleTaskState_Failed;
					}
					
					decl Float:flEnemyLKP[3];
					if (NPCAdvChaser_GetEnemyPosInMemory(iNPCIndex, enemy, flEnemyLKP))
					{
						new areaIndex = NPCAdvChaser_GetEnemyAreaIndexInMemory(iNPCIndex, enemy);
						if (areaIndex != -1)
						{
							new lastAreaIndex = g_iNPCPathGoalEntityLastKnownAreaIndex[iNPCIndex];
							g_iNPCPathGoalEntityLastKnownAreaIndex[iNPCIndex] = areaIndex;
							
							if (areaIndex != lastAreaIndex)
							{
								// The entity moved to a different area. Attempt to repath.
								new Handle:hNewPath = CreateNavPath();
								if (!NavPathConstructPathFromPoints(hNewPath, flStartPos, flEnemyLKP, SF2_NPC_ADVCHASER_NEARESTAREA_RADIUS, NPCAdvChaser_ShortestPathCost, NPCAdvChaser_GetStepSize(iNPCIndex)))
								{
									// Repath failed. Enemy is unreachable.
									CloseHandle(hNewPath);
									NPCAdvChaser_StopMoving(iNPCIndex);
									
									strcopy(failReasonMsg, failReasonMsgLen, "Attempt to repath to goal entity (enemy) failed.");
									return ScheduleTaskState_Failed;
								}
								
								// Repath successful. Set our path to the new path.
								CloseHandle(g_hNPCPath[iNPCIndex]);
								
								g_hNPCPath[iNPCIndex] = hNewPath;
								g_iNPCPathNodeIndex[iNPCIndex] = 1;
								g_iNPCPathBehindNodeIndex[iNPCIndex] = 0;
								
								hPath = hNewPath;
							}
							else
							{
								decl Float:flEndPos[3];
								CopyVector(flEnemyLKP, flEndPos);
								flEndPos[2] = NavMeshArea_GetZ(areaIndex, flEnemyLKP);
								
								// Entity might have moved but is still in the same area. Don't repath; just update the goal position.
								NavPathSetNodePosition(hPath, GetArraySize(hPath) - 1, flEndPos);
							}
						}
						else
						{
							NPCAdvChaser_StopMoving(iNPCIndex);
							
							strcopy(failReasonMsg, failReasonMsgLen, "Goal entity (enemy) deemed unreachable due to invalid area index.");
							return ScheduleTaskState_Failed;
						}
					}
				}
			}
			
			// Check if the NPC has made it to the goal.
			new pathNodeIndex = g_iNPCPathNodeIndex[iNPCIndex];
			if (pathNodeIndex < 0 || pathNodeIndex >= GetArraySize(hPath))
			{
				strcopy(failReasonMsg, failReasonMsgLen, "NPC path index is out of range.");
				return ScheduleTaskState_Failed;
			}
			
			decl Float:vPathNodePos[3];
			NavPathGetNodePosition(hPath, pathNodeIndex, vPathNodePos);
			
			decl Float:vFeetPos[3];
			GetEntPropVector(iNPCIndex, Prop_Data, "m_vecAbsOrigin", vFeetPos);
			
			decl Float:vEyePos[3];
			NPCGetEyePosition(iNPCIndex, vEyePos);
			
			decl Float:vCentroidPos[3];
			AddVectors(vFeetPos, vEyePos, vCentroidPos);
			ScaleVector(vCentroidPos, 0.5);
			
			new pathNodeLadderIndex = NavPathGetNodeLadderIndex(hPath, pathNodeIndex);
			if (pathNodeLadderIndex != -1)
			{
				// @TODO: Traverse ladders, maybe?
			}
			
			if (GetVectorDistance(vFeetPos, vPathNodePos) < g_flNPCPathToleranceDistance[iNPCIndex])
			{
				g_iNPCPathNodeIndex[iNPCIndex] = ++pathNodeIndex;
				
				if (pathNodeIndex >= GetArraySize(hPath))
				{
					NPCAdvChaser_StopMoving(iNPCIndex);
					return ScheduleTaskState_Complete;
				}
				
				NavPathGetNodePosition(hPath, pathNodeIndex, vPathNodePos);
			}
			
			CopyVector(vPathNodePos, g_flNPCMovePosition[iNPCIndex]);
			
			new pathBehindNodeIndex = 0;
			
			static const Float:aheadRange = 300.0;
			
			pathNodeIndex = FindAheadPathPoint(hPath, aheadRange, pathNodeIndex, vFeetPos, vCentroidPos, vEyePos, g_flNPCMovePosition[iNPCIndex], pathBehindNodeIndex);
			
			// Clamp point to the path.
			if (pathNodeIndex >= GetArraySize(hPath))
			{
				pathNodeIndex = GetArraySize(hPath) - 1;
			}
			
			g_iNPCPathNodeIndex[iNPCIndex] = pathNodeIndex;
			g_iNPCPathBehindNodeIndex[iNPCIndex] = pathBehindNodeIndex;
			
			new bool:approachingJumpArea = false;
			
			{
				for (new i = pathNodeIndex; i < GetArraySize(hPath); i++)
				{
					new toAreaIndex = NavPathGetNodeAreaIndex(hPath, i);
					if (NavMeshArea_GetFlags(iAreaIndex) & NAV_MESH_JUMP)
					{
						approachingJumpArea = true;
						break;
					}
				}
			}
			
			if ((g_flNPCMovePosition[iNPCIndex][2] - vFeetPos[2]) > JumpCrouchHeight)
			{
				static const Float:jumpCloseRange = 50.0;
				
				decl Float:vTo2D[3];
				MakeVectorFromPoints(vFeetPos, g_flNPCMovePosition[iNPCIndex], vTo2D);
				vTo2D[2] = 0.0;
				
				if (GetVectorLength(vTo2D) < jumpCloseRange)
				{
					new pathNextNodeIndex = pathBehindNodeIndex + 1;
					if (pathBehindNodeIndex >= 0 && pathNextNodeIndex < GetArraySize(hPath))
					{
						decl Float:vNextPathNodePos[3];
						NavPathGetNodePosition(hPath, pathNextNodeIndex, vNextPathNodePos);
						
						if ((vNextPathNodePos[2] - vFeetPos[2]) > JumpCrouchHeight)
						{
							NPCAdvChaser_StopMoving(iNPCIndex);
							Format(failReasonMsg, failReasonMsgLen, "NPC fell off the path.");
							return ScheduleTaskState_Failed;
						}
					}
					else
					{
						NPCAdvChaser_StopMoving(iNPCIndex);
						Format(failReasonMsg, failReasonMsgLen, "NPC fell off the path (out of range).");
						return ScheduleTaskState_Failed;
					}
				}
			}
			
			if (pathNodeIndex < (GetArraySize(hPath) - 1))
			{
				new Float:vFloorNormalDir[3] = { 0.0, 0.0, 1.0 };
				
				decl Float:vFloorPos[3];
				CopyVector(vFeetPos, vFloorPos);
				vFloorPos[2] -= 10.0;
				
				new Handle:trace = TR_TraceRayFilterEx(vFeetPos, vFloorPos, MASK_NPCSOLID_BRUSHONLY, RayType_EndPoint, TraceRayDontHitEntity, npc);
				new bool:traceDidHit = TR_DidHit(trace);
				TR_GetPlaneNormal(trace, vFloorNormalDir);
				CloseHandle(hTrace);
				
				if (traceDidHit)
				{
					NormalizeVector(flFloorNormalDir, flFloorNormalDir);
					CalculateFeelerReflexAdjustment(g_flNPCMovePosition[iNPCIndex], vFeetPos, vFloorNormalDir, NPCAdvChaser_GetStepSize(iNPCIndex), 16.0, 120.0, 300.0, g_flNPCMovePosition[iNPCIndex], _, TraceRayDontHitEntity, npc);
				}
			}
			
			return ScheduleTaskState_Running;
		}
		case TASK_SET_ANIMATION:
		{
			if (GetGameTime() >= g_flNPCAnimationFinishTime[iNPCIndex])
			{
				NPCAdvChaser_StopMoving(iNPCIndex);
				
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
		case TASK_TRAVERSE_PATH:
		{
			NPCAdvChaser_StopMoving(iNPCIndex);
		}
		case TASK_SET_ANIMATION:
		{
			NPCAdvChaser_StopMoving(iNPCIndex);
		}
	}
}

static NPCAdvChaser_ClearPath(iNPCIndex)
{
	if (g_hNPCPath[iNPCIndex] != INVALID_HANDLE)
	{
		CloseHandle(g_hNPCPath[iNPCIndex]);
		g_hNPCPath[iNPCIndex] = INVALID_HANDLE;
	}
	
	g_iNPCPathNodeIndex[iNPCIndex] = -1;
	g_iNPCPathBehindNodeIndex[iNPCIndex] = -1;
	g_flNPCPathToleranceDistance[iNPCIndex] = 32.0;
	g_flNPCMovePosition[iNPCIndex][0] = 0.0;
	g_flNPCMovePosition[iNPCIndex][1] = 0.0;
	g_flNPCMovePosition[iNPCIndex][2] = 0.0;
	g_iNPCPathGoalEntity[iNPCIndex] = INVALID_ENT_REFERENCE;
	g_iNPCPathGoalEntityLastKnownAreaIndex[iNPCIndex] = -1;
	g_iNPCPathGoalType[iNPCIndex] = SF2NPCAdvChaserGoalType_Invalid;
}

// Shortest-path cost function for NavMesh_BuildPath.
public NPCAdvChaser_ShortestPathCost(iAreaIndex, iFromAreaIndex, iLadderIndex, any:iStepSize)
{
	if (iFromAreaIndex == -1)
	{
		return 0;
	}
	else
	{
		new iDist;
		decl Float:flAreaCenter[3], Float:flFromAreaCenter[3];
		NavMeshArea_GetCenter(iAreaIndex, flAreaCenter);
		NavMeshArea_GetCenter(iFromAreaIndex, flFromAreaCenter);
		
		if (iLadderIndex != -1)
		{
			iDist = RoundFloat(NavMeshLadder_GetLength(iLadderIndex));
		}
		else
		{
			iDist = RoundFloat(GetVectorDistance(flAreaCenter, flFromAreaCenter));
		}
		
		new iCost = iDist + NavMeshArea_GetCostSoFar(iFromAreaIndex);
		
		new iAreaFlags = NavMeshArea_GetFlags(iAreaIndex);
		if (iAreaFlags & NAV_MESH_CROUCH) iCost += 20;
		if (iAreaFlags & NAV_MESH_JUMP) iCost += (5 * iDist);
		
		if ((flAreaCenter[2] - flFromAreaCenter[2]) > iStepSize) iCost += iStepSize;
		
		return iCost;
	}
}

NPCAdvChaser_OnSelectProfile(iNPCIndex)
{
}

NPCAdvChaser_Think(iNPCIndex)
{
	// 1. Gather and select enemies.
	
	NPCAdvChaser_GatherEnemies(iNPCIndex);
	NPCAdvChaser_CheckEnemyMemory(iNPCIndex);
	
	new preferredEnemy = NPCAdvChaser_SelectEnemy(iNPCIndex, EnemyMemoryType_Sight);
	new enemy = NPCAdvChaser_GetEnemy(iNPCIndex);
	
	if (enemy != preferredEnemy)
	{
		if (preferredEnemy != INVALID_ENT_REFERENCE)
		{
			NPCAdvChaser_AddInterruptCondition(iNPCIndex, SF2_INTERRUPTCOND_NEW_ENEMY);
		}
		else
		{
			if (enemy != INVALID_ENT_REFERENCE)
			{
				NPCAdvChaser_AddInterruptCondition(iNPCIndex, SF2_INTERRUPTCOND_LOST_ENEMY);
			}
		}
	}
	
	NPCAdvChaser_SetEnemy(iNPCIndex, preferredEnemy);
	enemy = preferredEnemy;
	
	if (!enemy || enemy == INVALID_ENT_REFERENCE)
	{
		new target = NPCAdvChaser_SelectEnemy(iNPCIndex, EnemyMemoryType_Glimpse);
		NPCAdvChaser_SetGlimpseTarget(iNPCIndex, target);
		
		if (!target || target == INVALID_ENT_REFERENCE)
		{
			target = NPCAdvChaser_SelectEnemy(iNPCIndex, EnemyMemoryType_Scent);
			NPCAdvChaser_SetScentTarget(iNPCIndex, target);
		}
		else
		{
			NPCAdvChaser_SetScentTarget(iNPCIndex, INVALID_ENT_REFERENCE);
		}
	}
	else
	{
		NPCAdvChaser_SetScentTarget(iNPCIndex, INVALID_ENT_REFERENCE);
		NPCAdvChaser_SetGlimpseTarget(iNPCIndex, INVALID_ENT_REFERENCE);
	}
	
	// 2. Select and execute/maintain schedules.
	
	NPCAdvChaser_MaintainSchedule(iNPCIndex);
	
	// 3. Select the activity to be in. Running, standing, jumping, or something else, etc. The preferred activity is the main activity to be in.
	
	new SF2AdvChaserActivity:preferredActivity = NPCAdvChaser_SelectActivity(iNPCIndex);
	new SF2AdvChaserActivity:activity = NPCAdvChaser_GetActivity(iNPCIndex);
	
	NPCAdvChaser_SetActivity(iNPCIndex, preferredActivity);
	
	if (activity != preferredActivity)
	{
		// @TODO: Add a response to change of activities
	}
	
	// 4. Handle movement. If the current activity is about movement, move the NPC towards MovePosition, change angles, speed, etc.
	
	// 5. Handle animations. Some animations are directly associated with the current activity.
	
	// 6. Finally, reset for the next think.
	
	g_iNPCInterruptConditions[iNPCIndex] = 0;
	g_iNPCAnimationNeedsUpdate[iNPCIndex] = false;
}