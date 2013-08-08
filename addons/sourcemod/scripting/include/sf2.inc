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

forward Action:SF2_OnGroupGiveQueuePoints(iGroupIndex, &iAddAmount);

forward SF2_OnClientDamagedByBoss(client, iBossIndex, inflictor, Float:flDamage, iDamageType);

forward SF2_OnClientSpawnedAsProxy(client);


/**
 * Returns a bool about the gamemode's state.
 *
 * @return				True if the gamemode is running, false if it is not.
 */
native bool:SF2_IsRunning();

/**
 * Returns the current difficulty of the round.
 *
 * @return				Integer of the difficulty.
 */
native SF2_GetCurrentDifficulty();

/**
 * Returns the current difficulty of the round.
 *
 * @param iDifficulty	Difficulty number.
 * @return				Modifier float value of the indicated difficulty number.
 */
native Float:SF2_GetDifficultyModifier(iDifficulty);

/**
 * Returns a bool about the client's elimination state.
 *
 * @param client		Client index.
 * @return				True if the player is eliminated, false if they're not.
 */
native bool:SF2_IsClientEliminated(client);

/**
 * Returns a bool about the client's ghost mode state.
 *
 * @param client		Client index.
 * @return				True if the player is in Ghost Mode, false if they're not.
 */
native bool:SF2_IsClientInGhostMode(client);

/**
 * Returns a bool if the client is in a Player vs. Player zone or not.
 *
 * @param client		Client index.
 * @return				True if the player is in a PvP zone, false if not.
 */
native bool:SF2_IsClientInPvP(client);

/**
 * Tells whether if the client is a Proxy or not.
 *
 * @param client		Client index.
 * @return				True if the player is a Proxy, false if not.
 */
native bool:SF2_IsClientProxy(client);

/**
 * Tells whether or not the client is looking at the boss.
 *
 * @param client		Client index.
 * @param iBossIndex	Boss index.
 * @return				True if the player is a Proxy, false if not.
 */
native bool:SF2_IsClientLookingAtBoss(client, iBossIndex);

/**
 * Gives the amount of times the client has blinked in one life. This count will reset upon spawn.
 *
 * @param client		Client index.
 * @return				Number of times the client has blinked in one life.
 */
native SF2_GetClientBlinkCount(client);

/**
 * If the client is a Proxy, then this returns the boss index that the client is associated with.
 *
 * @param client		Client index.
 * @return				If the client is a proxy, then this will return a boss index, -1 if not.
 */
native SF2_GetClientProxyMaster(client);

/**
 * If the client is a Proxy, then this returns the amount of Control points the client has left.
 *
 * @param client		Client index.
 * @return				If the client is a proxy, then this will return the amount of Control Points out of 100, else 0.
 */
native SF2_GetClientProxyControlAmount(client);

/**
 * If the client is a Proxy, then this returns the rate which each Control point will drain for the client.
 *
 * @param client		Client index.
 * @return				If the client is a proxy, then this will return a boss index, -1 if not.
 */
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