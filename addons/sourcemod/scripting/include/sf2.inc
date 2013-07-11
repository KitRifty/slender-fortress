#if defined _sf2_included
 #endinput
#endif
#define _sf2_included

// Some defines.
#define SF2_MAX_PROFILE_NAME_LENGTH 64
#define SF2_MAX_NAME_LENGTH 32

// Difficulty modifiers.
#define DIFFICULTY_EASY 0.75
#define DIFFICULTY_NORMAL 1.0
#define DIFFICULTY_HARD 2.0
#define DIFFICULTY_INSANE 3.5

// Music system flags.
#define MUSICF_PAGES1PERCENT (1 << 0)
#define MUSICF_PAGES25PERCENT (1 << 1)
#define MUSICF_PAGES50PERCENT (1 << 2)
#define MUSICF_PAGES75PERCENT (1 << 3)
#define MUSICF_DEATH (1 << 4)
#define MUSICF_CHASE (1 << 5)
#define MUSICF_CHASEVISIBLE (1 << 6)

// Special round enumerations.
enum
{
	SPECIALROUND_DOUBLETROUBLE = 1,
	SPECIALROUND_INSANEDIFFICULTY,
	SPECIALROUND_SINGLEPLAYER,
	SPECIALROUND_DOUBLEMAXPLAYERS,
	SPECIALROUND_LIGHTSOUT,
	SPECIALROUND_MAXROUNDS
};

// Boss state enumerations.
enum
{
	STATE_IDLE = 0,
	STATE_WANDER,
	STATE_ALERT,
	STATE_CHASE,
	STATE_ATTACK,
	STATE_STUN
};

enum SoundType
{
	SoundType_None = 0,
	SoundType_Footstep,
	SoundType_Voice,
	SoundType_Weapon
};

enum
{
	Difficulty_Easy = 0,
	Difficulty_Normal,
	Difficulty_Hard,
	Difficulty_Insane,
	Difficulty_Max
};

// Boss flags.
#define SFF_SPAWNONCE (1 << 0)
#define SFF_NOTELEPORT (1 << 1)
#define SFF_FAKE (1 << 2)
#define SFF_MARKEDASFAKE (1 << 3)
#define SFF_ATTACKWAITERS (1 << 4)


forward SF2_OnBossAdded(iBossIndex);

forward SF2_OnBossSpawn(iBossIndex);

forward SF2_OnBossChangeState(iBossIndex, iOldState, iNewState);

forward SF2_OnClientBlinked(client);

forward SF2_OnClientCaughtByBoss(client, iBossIndex);

forward Action:SF2_OnClientGiveQueuePoints(client, &iAddAmount);

forward SF2_OnClientActivateFlashlight(client);

forward SF2_OnClientDeactivateFlashlight(client);

forward SF2_OnClientBreakFlashlight(client);

forward SF2_OnClientEscape(client);

forward SF2_OnClientLooksAtBoss(client, iBossIndex);

forward SF2_OnClientLooksAwayFromBoss(client, iBossIndex);

forward SF2_OnClientStartDeathCam(client, iBossIndex);

forward SF2_OnClientEndDeathCam(client, iBossIndex);

forward Action:SF2_OnClientGetDefaultWalkSpeed(client, &Float:flDefault);

forward Action:SF2_OnClientGetDefaultSprintSpeed(client, &Float:flDefault);


native bool:SF2_IsRunning();

native SF2_GetCurrentDifficulty();

native Float:SF2_GetDifficultyModifier(iDifficulty);

native bool:SF2_IsClientEliminated(client);

native bool:SF2_IsClientInGhostMode(client);

native bool:SF2_IsClientInPvP(client);

native bool:SF2_IsClientProxy(client);

native bool:SF2_IsClientLookingAtBoss(client, iBossIndex);

native SF2_GetClientBlinkCount(client);

native SF2_GetClientProxyMaster(client);

native SF2_GetClientProxyControlAmount(client);

native Float:SF2_GetClientProxyControlRate(client);

native SF2_SetClientProxyMaster(client, iBossIndex);

native SF2_SetClientProxyControlAmount(client, iAmount);

native SF2_SetClientProxyControlRate(client, Float:flAmount);

native SF2_GetMaxBossCount();

native SF2_EntIndexToBossIndex(iEntIndex);

native SF2_BossIndexToEntIndex(iBossIndex);

native SF2_GetBossName(iBossIndex, String:sBuffer[], iBufferLen);

native SF2_GetBossTarget(iBossIndex);

native SF2_GetBossMaster(iBossIndex);

native SF2_GetBossState(iBossIndex);


public SharedPlugin:__pl_sf2 = 
{
	name = "sf2",
	file = "sf2.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};