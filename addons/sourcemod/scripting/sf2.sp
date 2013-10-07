#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <steamtools>
#include <tf2items>
#include <dhooks>
#include <navmesh>

#include <tf2_stocks>
#include <morecolors>
#include <sf2>

#undef REQUIRE_PLUGIN
#include <adminmenu>
#tryinclude <store/store-tf2footprints>
#define REQUIRE_PLUGIN

//#define DEBUG

#define PLUGIN_VERSION "0.1.9 Dev"

public Plugin:myinfo = 
{
    name = "Slender Fortress",
    author	= "KitRifty",
    description	= "Based on the game Slender: The Eight Pages.",
    version = PLUGIN_VERSION,
    url = "http://steamcommunity.com/groups/SlenderFortress"
}

#define FILE_RESTRICTEDWEAPONS "configs/sf2/restrictedweapons.cfg"

#define BOSS_THINKRATE 0.1 // doesn't really matter much since timers go at a minimum of 0.1 seconds anyways

#define CRIT_SOUND "player/crit_hit.wav"
#define CRIT_PARTICLENAME "crit_text"

#define PAGE_MODEL "models/slender/sheet.mdl"
#define PAGE_MODELSCALE 1.1

#define FLASHLIGHT_CLICKSOUND "slender/newflashlight.wav"
#define FLASHLIGHT_BREAKSOUND "ambient/energy/spark6.wav"
#define FLASHLIGHT_NOSOUND "player/suit_denydevice.wav"
#define PAGE_GRABSOUND "slender/newgrabpage.wav"
#define TWENTYDOLLARS_SOUND "slender/20dollars.wav"

#define MUSIC_CHAN SNDCHAN_AUTO

#define MUSIC_GOTPAGES1_SOUND "slender/newambience_1.wav"
#define MUSIC_GOTPAGES2_SOUND "slender/newambience_2.wav"
#define MUSIC_GOTPAGES3_SOUND "slender/newambience_3.wav"
#define MUSIC_GOTPAGES4_SOUND "slender/newambience_4.wav"
#define MUSIC_PAGE_VOLUME 1.0

#define PVP_SPAWN_SOUND "items/spawn_item.wav"

#define SF2_HUD_TEXT_COLOR_R 127
#define SF2_HUD_TEXT_COLOR_G 167
#define SF2_HUD_TEXT_COLOR_B 141
#define SF2_HUD_TEXT_COLOR_A 255

#define DEBUG_BOSS_TELEPORTATION (1 << 0)
#define DEBUG_BOSS_CHASE (1 << 1)
#define DEBUG_PLAYER_STRESS (1 << 2)

enum MuteMode
{
	MuteMode_Normal = 0,
	MuteMode_DontHearOtherTeam,
	MuteMode_DontHearOtherTeamIfNotProxy
};

// Offsets.
new g_offsPlayerFOV = -1;
new g_offsPlayerDefaultFOV = -1;
new g_offsPlayerFogCtrl = -1;
new g_offsPlayerPunchAngle = -1;
new g_offsPlayerPunchAngleVel = -1;
new g_offsFogCtrlEnable = -1;
new g_offsFogCtrlEnd = -1;

new g_iParticleCriticalHit = -1;

new bool:g_bEnabled;

new Handle:g_hConfig;
new Handle:g_hRestrictedWeaponsConfig;
new Handle:g_hSpecialRoundsConfig;

new Handle:g_hPageMusicRanges;

new g_iSlenderGlobalID = -1;

new String:g_strSlenderProfile[MAX_BOSSES][SF2_MAX_PROFILE_NAME_LENGTH];
new g_iSlenderID[MAX_BOSSES] = { -1, ... };
new g_iSlenderFlags[MAX_BOSSES];
new g_iSlender[MAX_BOSSES] = { INVALID_ENT_REFERENCE, ... };
new g_iSlenderModel[MAX_BOSSES] = { INVALID_ENT_REFERENCE, ... };
new g_iSlenderPoseEnt[MAX_BOSSES] = { INVALID_ENT_REFERENCE, ... };
new g_iSlenderCopyMaster[MAX_BOSSES] = { -1, ... };
new Float:g_flSlenderEyePosOffset[MAX_BOSSES][3];
new Float:g_flSlenderDetectMins[MAX_BOSSES][3];
new Float:g_flSlenderDetectMaxs[MAX_BOSSES][3];
new Handle:g_hSlenderThink[MAX_BOSSES];
new Handle:g_hSlenderEntityThink[MAX_BOSSES];
new Handle:g_hSlenderFakeTimer[MAX_BOSSES];
new Float:g_flSlenderAnger[MAX_BOSSES];
new Float:g_flSlenderLastKill[MAX_BOSSES];
new g_iSlenderType[MAX_BOSSES];
new g_iSlenderState[MAX_BOSSES];
new g_iSlenderTarget[MAX_BOSSES] = { INVALID_ENT_REFERENCE, ... };
new Float:g_flSlenderSpeed[MAX_BOSSES];
new Float:g_flSlenderAcceleration[MAX_BOSSES];
new Float:g_flSlenderWalkSpeed[MAX_BOSSES];
new Float:g_flSlenderAirSpeed[MAX_BOSSES];
new Float:g_flSlenderTurnRate[MAX_BOSSES];
new Float:g_flSlenderFOV[MAX_BOSSES];
new Float:g_flSlenderGoalPos[MAX_BOSSES][3];
new Float:g_flSlenderSearchRange[MAX_BOSSES];
new Float:g_flSlenderWakeRange[MAX_BOSSES];
new Float:g_flSlenderInstaKillRange[MAX_BOSSES];
new Float:g_flSlenderScareRadius[MAX_BOSSES];
new Float:g_flSlenderStaticRadius[MAX_BOSSES];
new Float:g_flSlenderChaseDeathPosition[MAX_BOSSES][3];
new bool:g_bSlenderChaseDeathPosition[MAX_BOSSES];
new Float:g_flSlenderIdleAnimationPlaybackRate[MAX_BOSSES];
new Float:g_flSlenderWalkAnimationPlaybackRate[MAX_BOSSES];
new Float:g_flSlenderRunAnimationPlaybackRate[MAX_BOSSES];
new Float:g_flSlenderJumpSpeed[MAX_BOSSES];
new Float:g_flSlenderPathNodeTolerance[MAX_BOSSES];
new Float:g_flSlenderPathNodeLookAhead[MAX_BOSSES];
new Float:g_flSlenderStepSize[MAX_BOSSES];
new bool:g_bSlenderFeelerReflexAdjustment[MAX_BOSSES];
new Float:g_flSlenderFeelerReflexAdjustmentPos[MAX_BOSSES][3];

new g_iSlenderTeleportTarget[MAX_BOSSES] = { INVALID_ENT_REFERENCE, ... };

new g_iSlenderTeleportType[MAX_BOSSES] = { -1, ... };
new Float:g_flSlenderNextTeleportTime[MAX_BOSSES] = { -1.0, ... };
new Float:g_flSlenderTeleportTargetTime[MAX_BOSSES] = { -1.0, ... };
new Float:g_flSlenderTeleportMinRange[MAX_BOSSES] = { -1.0, ... };
new Float:g_flSlenderTeleportMaxRange[MAX_BOSSES] = { -1.0, ... };
new Float:g_flSlenderTeleportMaxTargetTime[MAX_BOSSES] = { -1.0, ... };
new Float:g_flSlenderTeleportMaxTargetStress[MAX_BOSSES] = { 0.0, ... };
new Float:g_flSlenderTeleportPlayersRestTime[MAX_BOSSES][MAXPLAYERS + 1];

// For boss type 2
// General variables
new g_iSlenderHealth[MAX_BOSSES];
new g_iSlenderHealthUntilStun[MAX_BOSSES];
new Handle:g_hSlenderPath[MAX_BOSSES];
new g_iSlenderCurrentPathNode[MAX_BOSSES] = { -1, ... };
new bool:g_bSlenderAttacking[MAX_BOSSES];
new Handle:g_hSlenderAttackTimer[MAX_BOSSES];
new Float:g_flSlenderNextJump[MAX_BOSSES] = { -1.0, ... };
new g_iSlenderInterruptConditions[MAX_BOSSES];
new Float:g_flSlenderLastFoundPlayer[MAX_BOSSES][MAXPLAYERS + 1];
new Float:g_flSlenderLastFoundPlayerPos[MAX_BOSSES][MAXPLAYERS + 1][3];
new Float:g_flSlenderNextPathTime[MAX_BOSSES] = { -1.0, ... };
new Float:g_flSlenderCalculatedWalkSpeed[MAX_BOSSES];
new Float:g_flSlenderCalculatedSpeed[MAX_BOSSES];
new Float:g_flSlenderTimeUntilNoPersistence[MAX_BOSSES];

// Sound variables
new Float:g_flSlenderTargetSoundLastTime[MAX_BOSSES] = { -1.0, ... };
new Float:g_flSlenderTargetSoundMasterPos[MAX_BOSSES][3]; // to determine hearing focus
new Float:g_flSlenderTargetSoundTempPos[MAX_BOSSES][3];
new Float:g_flSlenderTargetSoundDiscardMasterPosTime[MAX_BOSSES];
new bool:g_bSlenderInvestigatingSound[MAX_BOSSES];
new SoundType:g_iSlenderTargetSoundType[MAX_BOSSES] = { SoundType_None, ... };
new g_iSlenderTargetSoundCount[MAX_BOSSES];
new Float:g_flSlenderLastHeardVoice[MAX_BOSSES];
new Float:g_flSlenderLastHeardFootstep[MAX_BOSSES];
new Float:g_flSlenderLastHeardWeapon[MAX_BOSSES];


new Float:g_flSlenderNextJumpScare[MAX_BOSSES] = { -1.0, ... };
new Float:g_flSlenderNextVoiceSound[MAX_BOSSES] = { -1.0, ... };
new Float:g_flSlenderNextMoanSound[MAX_BOSSES] = { -1.0, ... };
new Float:g_flSlenderNextWanderPos[MAX_BOSSES] = { -1.0, ... };


new Float:g_flSlenderTimeUntilRecover[MAX_BOSSES] = { -1.0, ... };
new Float:g_flSlenderTimeUntilAlert[MAX_BOSSES] = { -1.0, ... };
new Float:g_flSlenderTimeUntilIdle[MAX_BOSSES] = { -1.0, ... };
new Float:g_flSlenderTimeUntilChase[MAX_BOSSES] = { -1.0, ... };
new Float:g_flSlenderTimeUntilKill[MAX_BOSSES] = { -1.0, ... };
new Float:g_flSlenderTimeUntilNextProxy[MAX_BOSSES] = { -1.0, ... };

// Page data.
new g_iPageCount;
new g_iPageMax;
new Float:g_flPageFoundLastTime;
new bool:g_bPageRef;
new String:g_strPageRefModel[PLATFORM_MAX_PATH];
new Float:g_flPageRefModelScale;

// Seeing Mr. Slendy data.
new bool:g_bPlayerSeesSlender[MAXPLAYERS + 1][MAX_BOSSES];
new Float:g_flPlayerSeesSlenderLastTime[MAXPLAYERS + 1][MAX_BOSSES];

new Float:g_flPlayerSightSoundNextTime[MAXPLAYERS + 1][MAX_BOSSES];

new Float:g_flPlayerScareLastTime[MAXPLAYERS + 1][MAX_BOSSES];
new Float:g_flPlayerScareNextTime[MAXPLAYERS + 1][MAX_BOSSES];
new Float:g_flPlayerStaticAmount[MAXPLAYERS + 1];

new Float:g_flPlayerLastChaseBossEncounterTime[MAXPLAYERS + 1][MAX_BOSSES];

new g_iPlayerDebugFlags[MAXPLAYERS + 1];

// Player static data.
new g_iPlayerStaticMode[MAXPLAYERS + 1][MAX_BOSSES];
new Float:g_flPlayerStaticIncreaseRate[MAXPLAYERS + 1];
new Float:g_flPlayerStaticDecreaseRate[MAXPLAYERS + 1];
new Handle:g_hPlayerStaticTimer[MAXPLAYERS + 1];
new g_iPlayerStaticMaster[MAXPLAYERS + 1] = { -1, ... };
new String:g_strPlayerStaticSound[MAXPLAYERS + 1][PLATFORM_MAX_PATH];
new String:g_strPlayerLastStaticSound[MAXPLAYERS + 1][PLATFORM_MAX_PATH];
new Float:g_flPlayerLastStaticTime[MAXPLAYERS + 1];
new Float:g_flPlayerLastStaticVolume[MAXPLAYERS + 1];
new Handle:g_hPlayerLastStaticTimer[MAXPLAYERS + 1];

// Static shake data.
new g_iPlayerStaticShakeMaster[MAXPLAYERS + 1];
new bool:g_bPlayerInStaticShake[MAXPLAYERS + 1];
new String:g_strPlayerStaticShakeSound[MAXPLAYERS + 1][PLATFORM_MAX_PATH];
new Float:g_flPlayerStaticShakeMinVolume[MAXPLAYERS + 1];
new Float:g_flPlayerStaticShakeMaxVolume[MAXPLAYERS + 1];

// Flashlight data.
new bool:g_bPlayerFlashlight[MAXPLAYERS + 1];
new bool:g_bPlayerFlashlightBroken[MAXPLAYERS + 1];
new g_iPlayerFlashlightEnt[MAXPLAYERS + 1] = { INVALID_ENT_REFERENCE, ... };
new g_iPlayerFlashlightEntAng[MAXPLAYERS + 1] = { INVALID_ENT_REFERENCE, ... };
new Float:g_flPlayerFlashlightMeter[MAXPLAYERS + 1];
new Handle:g_hPlayerFlashlightTimer[MAXPLAYERS + 1];
new Float:g_flPlayerFlashlightLastEnable[MAXPLAYERS + 1];
new bool:g_bPlayerFlashlightProjected[MAXPLAYERS + 1];

// Sprint data.
new bool:g_bPlayerSprint[MAXPLAYERS + 1];
new g_iPlayerSprintPoints[MAXPLAYERS + 1];
new Handle:g_hPlayerSprintTimer[MAXPLAYERS + 1];

// Breathing data.
new bool:g_bPlayerBreath[MAXPLAYERS + 1];
new Handle:g_hPlayerBreathTimer[MAXPLAYERS + 1];

// Fake lag compensation for FF.
new bool:g_bPlayerLagCompensation[MAXPLAYERS + 1];
new g_iPlayerLagCompensationTeam[MAXPLAYERS + 1];

// Hint data.
enum
{
	PlayerHint_Sprint = 0,
	PlayerHint_Flashlight,
	PlayerHint_MainMenu,
	PlayerHint_Blink,
	PlayerHint_MaxNum
};

new bool:g_bPlayerHints[MAXPLAYERS + 1][PlayerHint_MaxNum];

// Ultravision data.
new bool:g_bPlayerUltravision[MAXPLAYERS + 1];
new g_iPlayerUltravisionEnt[MAXPLAYERS + 1] = { INVALID_ENT_REFERENCE, ... };

// Deathcam data.
new g_iPlayerDeathCamBoss[MAXPLAYERS + 1] = { -1, ... };
new bool:g_bPlayerDeathCam[MAXPLAYERS + 1];
new bool:g_bPlayerDeathCamShowOverlay[MAXPLAYERS + 1];
new g_iPlayerDeathCamEnt[MAXPLAYERS + 1];
new g_iPlayerDeathCamEnt2[MAXPLAYERS + 1];
new Handle:g_hPlayerDeathCamTimer[MAXPLAYERS + 1];

// Glow data.
new g_iPlayerGlowEntity[MAXPLAYERS + 1] = { INVALID_ENT_REFERENCE, ... };
new g_iPlayerGlowLookAtEntity[MAXPLAYERS + 1] = { INVALID_ENT_REFERENCE, ... };

// Jumpscare data.
new g_iPlayerJumpScareMaster[MAXPLAYERS + 1] = { -1, ... };
new Float:g_flPlayerJumpScareLifeTime[MAXPLAYERS + 1] = { -1.0, ... };

// Player data. Holy crap this is a lot of data.
new g_iPlayerLastButtons[MAXPLAYERS + 1];
new Float:g_flPlayerLastEyeAngles[MAXPLAYERS + 1][3];
new Float:g_flPlayerEyeAngleVelocity[MAXPLAYERS + 1][3];
new bool:g_bPlayerChoseTeam[MAXPLAYERS + 1];
new bool:g_bPlayerGhostMode[MAXPLAYERS + 1];
new g_iPlayerGhostModeTarget[MAXPLAYERS + 1];
new bool:g_bPlayerEliminated[MAXPLAYERS + 1];
new bool:g_bPlayerEscaped[MAXPLAYERS + 1];
new g_iPlayerPageCount[MAXPLAYERS + 1];
new g_iPlayerQueuePoints[MAXPLAYERS + 1];
new bool:g_bPlayerPlaying[MAXPLAYERS + 1];
new Handle:g_hPlayerOverlayCheck[MAXPLAYERS + 1];

// Anti-camping data.
new g_iPlayerCampingStrikes[MAXPLAYERS + 1];
new Handle:g_hPlayerCampingTimer[MAXPLAYERS + 1];
new Float:g_flPlayerCampingLastPosition[MAXPLAYERS + 1][3];
new bool:g_bPlayerCampingFirstTime[MAXPLAYERS + 1];

// Player Blink data.
new Handle:g_hPlayerBlinkTimer[MAXPLAYERS + 1];
new bool:g_bPlayerBlink[MAXPLAYERS + 1];
new Float:g_flPlayerBlinkMeter[MAXPLAYERS + 1];
new g_iPlayerBlinkCount[MAXPLAYERS + 1];
new Handle:g_hPlayerSwitchBlueTimer[MAXPLAYERS + 1];

// Player PVP data.
new bool:g_bPlayerInPvP[MAXPLAYERS + 1];
new bool:g_bPlayerInPvPSpawning[MAXPLAYERS + 1];
new bool:g_bPlayerInPvPTrigger[MAXPLAYERS + 1];
new Handle:g_hPlayerPvPTimer[MAXPLAYERS + 1];
new g_iPlayerPvPTimerCount[MAXPLAYERS + 1];
new Float:g_flPlayerLastScareFromBoss[MAXPLAYERS + 1][MAX_BOSSES];

// Player stress data.
new Float:g_flPlayerStress[MAXPLAYERS + 1];
new Float:g_flPlayerStressNextUpdateTime[MAXPLAYERS + 1];

// Proxy data.
new bool:g_bPlayerProxy[MAXPLAYERS + 1];
new bool:g_bPlayerProxyAvailable[MAXPLAYERS + 1];
new Handle:g_hPlayerProxyAvailableTimer[MAXPLAYERS + 1];
new bool:g_bPlayerProxyAvailableInForce[MAXPLAYERS + 1];
new g_iPlayerProxyAvailableCount[MAXPLAYERS + 1];
new g_iPlayerProxyMaster[MAXPLAYERS + 1];
new g_iPlayerProxyControl[MAXPLAYERS + 1];
new g_iPlayerProxyGlowEntity[MAXPLAYERS + 1] = { INVALID_ENT_REFERENCE, ... };
new bool:g_bPlayerHasProxyGlow[MAXPLAYERS + 1] = { false, ... };
new Handle:g_hPlayerProxyControlTimer[MAXPLAYERS + 1];
new Float:g_flPlayerProxyControlRate[MAXPLAYERS + 1];
new Handle:g_flPlayerProxyVoiceTimer[MAXPLAYERS + 1];
new g_iPlayerProxyAskMaster[MAXPLAYERS + 1] = { -1, ... };
new Float:g_iPlayerProxyAskPosition[MAXPLAYERS + 1][3];

new bool:g_bPlayerWantsTheP[MAXPLAYERS + 1];

new bool:g_bPlayerShowHints[MAXPLAYERS + 1];
new MuteMode:g_iPlayerMuteMode[MAXPLAYERS + 1];
new g_iPlayerDesiredFOV[MAXPLAYERS + 1];

// Music system.
new g_iPlayerMusicFlags[MAXPLAYERS + 1];
new String:g_strPlayerMusic[MAXPLAYERS + 1][PLATFORM_MAX_PATH];
new Float:g_flPlayerMusicVolume[MAXPLAYERS + 1];
new Float:g_flPlayerMusicTargetVolume[MAXPLAYERS + 1];
new Handle:g_hPlayerMusicTimer[MAXPLAYERS + 1];
new g_iPlayerPageMusicMaster[MAXPLAYERS + 1];

// Chase music system, which apparently also uses the alert song system. And the idle sound system.
new String:g_strPlayerChaseMusic[MAXPLAYERS + 1][PLATFORM_MAX_PATH];
new String:g_strPlayerChaseMusicSee[MAXPLAYERS + 1][PLATFORM_MAX_PATH];
new Float:g_flPlayerChaseMusicVolumes[MAXPLAYERS + 1][MAX_BOSSES];
new Float:g_flPlayerChaseMusicSeeVolumes[MAXPLAYERS + 1][MAX_BOSSES];
new Handle:g_hPlayerChaseMusicTimer[MAXPLAYERS + 1][MAX_BOSSES];
new Handle:g_hPlayerChaseMusicSeeTimer[MAXPLAYERS + 1][MAX_BOSSES];
new g_iPlayerChaseMusicMaster[MAXPLAYERS + 1] = { -1, ... };
new g_iPlayerChaseMusicSeeMaster[MAXPLAYERS + 1] = { -1, ... };

new String:g_strPlayerAlertMusic[MAXPLAYERS + 1][PLATFORM_MAX_PATH];
new Float:g_flPlayerAlertMusicVolumes[MAXPLAYERS + 1][MAX_BOSSES];
new Handle:g_hPlayerAlertMusicTimer[MAXPLAYERS + 1][MAX_BOSSES];
new g_iPlayerAlertMusicMaster[MAXPLAYERS + 1] = { -1, ... };

new bool:g_bRoundGrace;
new bool:g_bRoundWaitingForPlayers;
new bool:g_bRoundWarmup;
new bool:g_bRoundMustEscape;
new Handle:g_hRoundGraceTimer;
new Float:g_flRoundDifficultyModifier = DIFFICULTY_NORMAL;
new bool:g_bRoundEnded;
new g_iRoundCount;
new bool:g_bRoundInfiniteFlashlight;
new bool:g_bRoundInfiniteBlink;
new g_iRoundTime;
new g_iRoundTimeLimit;
new g_iRoundEscapeTimeLimit;
new g_iRoundTimeGainFromPage;
new Handle:g_hRoundTimer;
new Handle:g_hVoteTimer;

new bool:g_bSpecialRound;
new bool:g_bSpecialRoundNew;
new g_iSpecialRound;
new Handle:g_hSpecialRoundTimer;
new g_iSpecialRoundCycleNum;
new Float:g_flSpecialRoundCycleEndTime;
new g_iSpecialRoundCount;
new bool:g_bPlayerDidSpecialRound[MAXPLAYERS + 1];

new bool:g_bBossRound;
new g_iBossRoundCount;
new bool:g_bPlayerDidBossRound[MAXPLAYERS + 1];
new String:g_strBossRoundProfile[64];

new Float:g_flPlayerDangerBoostTime[MAXPLAYERS + 1];

new Handle:g_hRoundMessagesTimer;
new g_iRoundMessagesNum;

// Server variables.
new Handle:g_cvEnabled;
new Handle:g_cvSlenderMapsOnly;
new Handle:g_cvPlayerViewbobEnabled;
new Handle:g_cvPlayerShakeEnabled;
new Handle:g_cvPlayerShakeFrequencyMax;
new Handle:g_cvPlayerShakeAmplitudeMax;
new Handle:g_cvGraceTime;
new Handle:g_cvAllChat;
new Handle:g_cv20Dollars;
new Handle:g_cvMaxPlayers;
new Handle:g_cvCampingEnabled;
new Handle:g_cvCampingMaxStrikes;
new Handle:g_cvCampingStrikesWarn;
new Handle:g_cvCampingMinDistance;
new Handle:g_cvCampingNoStrikeSanity;
new Handle:g_cvCampingNoStrikeBossDistance;
new Handle:g_cvDifficulty;
new Handle:g_cvBossMain;
new Handle:g_cvBossAppearChanceOverride;
new Handle:g_cvProfileOverride;
new Handle:g_cvPlayerBlinkRate;
new Handle:g_cvPlayerBlinkHoldTime;
new Handle:g_cvSpecialRoundBehavior;
new Handle:g_cvSpecialRoundForce;
new Handle:g_cvSpecialRoundOverride;
new Handle:g_cvSpecialRoundInterval;
new Handle:g_cvBossRoundBehavior;
new Handle:g_cvBossRoundInterval;
new Handle:g_cvBossRoundForce;
new Handle:g_cvPlayerVoiceDistance;
new Handle:g_cvPlayerVoiceWallScale;
new Handle:g_cvUltravisionEnabled;
new Handle:g_cvUltravisionRadiusRed;
new Handle:g_cvUltravisionRadiusBlue;
new Handle:g_cvUltravisionBrightness;
new Handle:g_cvTimeLimit;
new Handle:g_cvTimeLimitEscape;
new Handle:g_cvTimeGainFromPageGrab;
new Handle:g_cvPvPArenaLeaveTime;
new Handle:g_cvWarmupRound;
new Handle:g_cvPlayerViewbobHurtEnabled;
new Handle:g_cvPlayerViewbobSprintEnabled;
new Handle:g_cvPlayerFakeLagCompensation;
new Handle:g_cvPlayerProxyWaitTime;
new Handle:g_cvPlayerProxyAsk;
new Handle:g_cvHalfZatoichiHealthGain;

new Handle:g_cvGravity;
new Float:g_flGravity;

new bool:g_bPlayerShakeEnabled;
new bool:g_bPlayerViewbobEnabled;
new bool:g_bPlayerViewbobHurtEnabled;
new bool:g_bPlayerViewbobSprintEnabled;

#if defined DEBUG
new Handle:g_cvDebugDetail;
new Handle:g_cvDebugBosses;
#endif

new Handle:g_hMenuMain;
new Handle:g_hMenuVoteDifficulty;
new Handle:g_hMenuGhostMode;
new Handle:g_hMenuHelp;
new Handle:g_hMenuHelpObjective;
new Handle:g_hMenuHelpObjective2;
new Handle:g_hMenuHelpCommands;
new Handle:g_hMenuHelpGhostMode;
new Handle:g_hMenuHelpSprinting;
new Handle:g_hMenuHelpControls;
new Handle:g_hMenuHelpClassInfo;
new Handle:g_hMenuSettings;
new Handle:g_hMenuSettingsPvP;
new Handle:g_hMenuCredits;
new Handle:g_hMenuCredits2;

new Handle:g_hHudSync;
new Handle:g_hHudSync2;
new Handle:g_hRoundTimerSync;

new Handle:g_hCookie;

// Global forwards.
new Handle:fOnBossAdded;
new Handle:fOnBossSpawn;
new Handle:fOnBossChangeState;
new Handle:fOnBossRemoved;
new Handle:fOnPagesSpawned;
new Handle:fOnClientBlink;
new Handle:fOnClientCaughtByBoss;
new Handle:fOnClientGiveQueuePoints;
new Handle:fOnClientActivateFlashlight;
new Handle:fOnClientDeactivateFlashlight;
new Handle:fOnClientBreakFlashlight;
new Handle:fOnClientEscape;
new Handle:fOnClientLooksAtBoss;
new Handle:fOnClientLooksAwayFromBoss;
new Handle:fOnClientStartDeathCam;
new Handle:fOnClientEndDeathCam;
new Handle:fOnClientGetDefaultWalkSpeed;
new Handle:fOnClientGetDefaultSprintSpeed;
new Handle:fOnClientSpawnedAsProxy;
new Handle:fOnClientDamagedByBoss;
new Handle:fOnGroupGiveQueuePoints;

new Handle:g_hSDKWeaponScattergun;
new Handle:g_hSDKWeaponPistolScout;
new Handle:g_hSDKWeaponBat;
new Handle:g_hSDKWeaponSniperRifle;
new Handle:g_hSDKWeaponSMG;
new Handle:g_hSDKWeaponKukri;
new Handle:g_hSDKWeaponRocketLauncher;
new Handle:g_hSDKWeaponShotgunSoldier;
new Handle:g_hSDKWeaponShovel;
new Handle:g_hSDKWeaponGrenadeLauncher;
new Handle:g_hSDKWeaponStickyLauncher;
new Handle:g_hSDKWeaponBottle;
new Handle:g_hSDKWeaponMinigun;
new Handle:g_hSDKWeaponShotgunHeavy;
new Handle:g_hSDKWeaponFists;
new Handle:g_hSDKWeaponSyringeGun;
new Handle:g_hSDKWeaponMedigun;
new Handle:g_hSDKWeaponBonesaw;
new Handle:g_hSDKWeaponFlamethrower;
new Handle:g_hSDKWeaponShotgunPyro;
new Handle:g_hSDKWeaponFireaxe;
new Handle:g_hSDKWeaponRevolver;
new Handle:g_hSDKWeaponKnife;
new Handle:g_hSDKWeaponInvis;
new Handle:g_hSDKWeaponShotgunPrimary;
new Handle:g_hSDKWeaponPistol;
new Handle:g_hSDKWeaponWrench;

new Handle:g_hSDKGetMaxHealth;
new Handle:g_hSDKWantsLagCompensationOnEntity;
new Handle:g_hSDKShouldTransmit;


#include "sf2/stocks.sp"
#include "sf2/profiles.sp"
#include "sf2/effects.sp"
#include "sf2/client.sp"
#include "sf2/slender_stocks.sp"
#include "sf2/specialround.sp"
#include "sf2/attributes.sp"
#include "sf2/adminmenu.sp"
#include "sf2/playergroups.sp"


#define PJSOUND "ui/item_acquired.wav"

//	==========================================================
//	GENERAL PLUGIN HOOK FUNCTIONS
//	==========================================================

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	RegPluginLibrary("sf2");
	
	fOnBossAdded = CreateGlobalForward("SF2_OnBossAdded", ET_Ignore, Param_Cell);
	fOnBossSpawn = CreateGlobalForward("SF2_OnBossSpawn", ET_Ignore, Param_Cell);
	fOnBossChangeState = CreateGlobalForward("SF2_OnBossChangeState", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	fOnBossRemoved = CreateGlobalForward("SF2_OnBossRemoved", ET_Ignore, Param_Cell);
	fOnPagesSpawned = CreateGlobalForward("SF2_OnPagesSpawned", ET_Ignore);
	fOnClientBlink = CreateGlobalForward("SF2_OnClientBlink", ET_Ignore, Param_Cell);
	fOnClientCaughtByBoss = CreateGlobalForward("SF2_OnClientCaughtByBoss", ET_Ignore, Param_Cell, Param_Cell);
	fOnClientGiveQueuePoints = CreateGlobalForward("SF2_OnClientGiveQueuePoints", ET_Hook, Param_Cell, Param_CellByRef);
	fOnClientActivateFlashlight = CreateGlobalForward("SF2_OnClientActivateFlashlight", ET_Ignore, Param_Cell);
	fOnClientDeactivateFlashlight = CreateGlobalForward("SF2_OnClientDeactivateFlashlight", ET_Ignore, Param_Cell);
	fOnClientBreakFlashlight = CreateGlobalForward("SF2_OnClientBreakFlashlight", ET_Ignore, Param_Cell);
	fOnClientEscape = CreateGlobalForward("SF2_OnClientEscape", ET_Ignore, Param_Cell);
	fOnClientLooksAtBoss = CreateGlobalForward("SF2_OnClientLooksAtBoss", ET_Ignore, Param_Cell, Param_Cell);
	fOnClientLooksAwayFromBoss = CreateGlobalForward("SF2_OnClientLooksAwayFromBoss", ET_Ignore, Param_Cell, Param_Cell);
	fOnClientStartDeathCam = CreateGlobalForward("SF2_OnClientStartDeathCam", ET_Ignore, Param_Cell, Param_Cell);
	fOnClientEndDeathCam = CreateGlobalForward("SF2_OnClientEndDeathCam", ET_Ignore, Param_Cell, Param_Cell);
	fOnClientGetDefaultWalkSpeed = CreateGlobalForward("SF2_OnClientGetDefaultWalkSpeed", ET_Hook, Param_Cell, Param_CellByRef);
	fOnClientGetDefaultSprintSpeed = CreateGlobalForward("SF2_OnClientGetDefaultSprintSpeed", ET_Hook, Param_Cell, Param_CellByRef);
	fOnClientSpawnedAsProxy = CreateGlobalForward("SF2_OnClientSpawnedAsProxy", ET_Ignore, Param_Cell);
	fOnClientDamagedByBoss = CreateGlobalForward("SF2_OnClientDamagedByBoss", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_Cell);
	fOnGroupGiveQueuePoints = CreateGlobalForward("SF2_OnGroupGiveQueuePoints", ET_Hook, Param_Cell, Param_CellByRef);
	
	CreateNative("SF2_IsRunning", Native_IsRunning);
	CreateNative("SF2_GetCurrentDifficulty", Native_GetCurrentDifficulty);
	CreateNative("SF2_GetDifficultyModifier", Native_GetDifficultyModifier);
	CreateNative("SF2_IsClientEliminated", Native_IsClientEliminated);
	CreateNative("SF2_IsClientInGhostMode", Native_IsClientInGhostMode);
	CreateNative("SF2_IsClientInPvP", Native_IsClientInPvP);
	CreateNative("SF2_IsClientProxy", Native_IsClientProxy);
	CreateNative("SF2_GetClientBlinkCount", Native_GetClientBlinkCount);
	CreateNative("SF2_GetClientProxyMaster", Native_GetClientProxyMaster);
	CreateNative("SF2_GetClientProxyControlAmount", Native_GetClientProxyControlAmount);
	CreateNative("SF2_GetClientProxyControlRate", Native_GetClientProxyControlRate);
	CreateNative("SF2_SetClientProxyMaster", Native_SetClientProxyMaster);
	CreateNative("SF2_SetClientProxyControlAmount", Native_SetClientProxyControlAmount);
	CreateNative("SF2_SetClientProxyControlRate", Native_SetClientProxyControlRate);
	CreateNative("SF2_IsClientLookingAtBoss", Native_IsClientLookingAtBoss);
	CreateNative("SF2_GetMaxBossCount", Native_GetMaxBosses);
	CreateNative("SF2_EntIndexToBossIndex", Native_EntIndexToBossIndex);
	CreateNative("SF2_BossIndexToEntIndex", Native_BossIndexToEntIndex);
	CreateNative("SF2_BossIDToBossIndex", Native_BossIDToBossIndex);
	CreateNative("SF2_BossIndexToBossID", Native_BossIndexToBossID);
	CreateNative("SF2_GetBossName", Native_GetBossName);
	CreateNative("SF2_GetBossModelEntity", Native_GetBossModelEntity);
	CreateNative("SF2_GetBossTarget", Native_GetBossTarget);
	CreateNative("SF2_GetBossMaster", Native_GetBossMaster);
	CreateNative("SF2_GetBossState", Native_GetBossState);
	CreateNative("SF2_IsBossProfileValid", Native_IsBossProfileValid);
	CreateNative("SF2_GetBossProfileNum", Native_GetBossProfileNum);
	CreateNative("SF2_GetBossProfileFloat", Native_GetBossProfileFloat);
	CreateNative("SF2_GetBossProfileString", Native_GetBossProfileString);
	CreateNative("SF2_GetBossProfileVector", Native_GetBossProfileVector);
	CreateNative("SF2_GetRandomStringFromBossProfile", Native_GetRandomStringFromBossProfile);
	
	return APLRes_Success;
}

public OnPluginStart()
{
	LoadTranslations("core.phrases");
	LoadTranslations("common.phrases");
	LoadTranslations("sf2.phrases");
	
	// Get offsets.
	g_offsPlayerFOV = FindSendPropInfo("CBasePlayer", "m_iFOV");
	if (g_offsPlayerFOV == -1) SetFailState("Couldn't find CBasePlayer offset for m_iFOV.");
	
	g_offsPlayerDefaultFOV = FindSendPropInfo("CBasePlayer", "m_iDefaultFOV");
	if (g_offsPlayerDefaultFOV == -1) SetFailState("Couldn't find CBasePlayer offset for m_iDefaultFOV.");
	
	g_offsPlayerFogCtrl = FindSendPropInfo("CBasePlayer", "m_PlayerFog.m_hCtrl");
	if (g_offsPlayerFogCtrl == -1) LogError("Couldn't find CBasePlayer offset for m_PlayerFog.m_hCtrl!");
	
	g_offsPlayerPunchAngle = FindSendPropInfo("CBasePlayer", "m_vecPunchAngle");
	if (g_offsPlayerPunchAngle == -1) LogError("Couldn't find CBasePlayer offset for m_vecPunchAngle!");
	
	g_offsPlayerPunchAngleVel = FindSendPropInfo("CBasePlayer", "m_vecPunchAngleVel");
	if (g_offsPlayerPunchAngleVel == -1) LogError("Couldn't find CBasePlayer offset for m_vecPunchAngleVel!");
	
	g_offsFogCtrlEnable = FindSendPropInfo("CFogController", "m_fog.enable");
	if (g_offsFogCtrlEnable == -1) LogError("Couldn't find CFogController offset for m_fog.enable!");
	
	g_offsFogCtrlEnd = FindSendPropInfo("CFogController", "m_fog.end");
	if (g_offsFogCtrlEnd == -1) LogError("Couldn't find CFogController offset for m_fog.end!");
	
	g_hPageMusicRanges = CreateArray(3);
	
	// Register console variables.
	CreateConVar("sf2_version", PLUGIN_VERSION, "The current version of Slender Fortress. DO NOT TOUCH!", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_NOTIFY);
	
	g_cvEnabled = CreateConVar("sf2_enabled", "1", "Enable/Disable the Slender Fortress gamemode. This will take effect on map change.");
	g_cvSlenderMapsOnly = CreateConVar("sf2_slendermapsonly", "1", "Only enable the Slender Fortress gamemode on map names prefixed with \"slender_\" or \"sf2_\".");
	
	g_cvGraceTime = CreateConVar("sf2_gracetime", "30.0");
	
	g_cvAllChat = CreateConVar("sf2_alltalk", "0");
	
	g_cvPlayerVoiceDistance = CreateConVar("sf2_player_voice_distance", "800.0", "The maximum distance RED can communicate in voice chat. Set to 0 if you want them to be heard at all times.");
	g_cvPlayerVoiceWallScale = CreateConVar("sf2_player_voice_scale_blocked", "0.5", "The distance required to hear RED in voice chat will be multiplied by this amount if something is blocking them.");
	
	g_cvPlayerViewbobEnabled = CreateConVar("sf2_player_viewbob_enabled", "1", "Enable/Disable player viewbobbing.");
	HookConVarChange(g_cvPlayerViewbobEnabled, OnConVarChanged);
	g_cvPlayerViewbobHurtEnabled = CreateConVar("sf2_player_viewbob_hurt_enabled", "0", "Enable/Disable player view tilting when hurt.");
	HookConVarChange(g_cvPlayerViewbobHurtEnabled, OnConVarChanged);
	g_cvPlayerViewbobSprintEnabled = CreateConVar("sf2_player_viewbob_sprint_enabled", "0", "Enable/Disable player step viewbobbing when sprinting.");
	HookConVarChange(g_cvPlayerViewbobSprintEnabled, OnConVarChanged);
	g_cvGravity = FindConVar("sv_gravity");
	HookConVarChange(g_cvGravity, OnConVarChanged);
	
	g_cvPlayerFakeLagCompensation = CreateConVar("sf2_player_fakelagcompensation", "0", "(EXPERIMENTAL) Enable/Disable fake lag compensation for some hitscan weapons such as the Sniper Rifle.");
	
	g_cvPlayerShakeEnabled = CreateConVar("sf2_player_shake_enabled", "1", "Enable/Disable player view shake during boss encounters.");
	HookConVarChange(g_cvPlayerShakeEnabled, OnConVarChanged);
	g_cvPlayerShakeFrequencyMax = CreateConVar("sf2_player_shake_frequency_max", "255", "Maximum frequency value of the shake. Should be a value between 1-255.");
	g_cvPlayerShakeAmplitudeMax = CreateConVar("sf2_player_shake_amplitude_max", "5", "Maximum amplitude value of the shake. Should be a value between 1-16.");
	
	g_cvPlayerBlinkRate = CreateConVar("sf2_player_blink_rate", "0.33", "How long (in seconds) each bar on the player's Blink meter lasts.");
	g_cvPlayerBlinkHoldTime = CreateConVar("sf2_player_blink_holdtime", "0.15", "How long (in seconds) a player will stay in Blink mode when he or she blinks.");
	
	g_cvUltravisionEnabled = CreateConVar("sf2_player_ultravision_enabled", "1", "Enable/Disable player Ultravision. This helps players see in the dark when their Flashlight is off or unavailable.");
	g_cvUltravisionRadiusRed = CreateConVar("sf2_player_ultravision_radius_red", "512.0");
	g_cvUltravisionRadiusBlue = CreateConVar("sf2_player_ultravision_radius_blue", "800.0");
	g_cvUltravisionBrightness = CreateConVar("sf2_player_ultravision_brightness", "-4");
	
	g_cv20Dollars = CreateConVar("sf2_20dollarmode", "0", "Enable/Disable $20 mode.");
	
	g_cvMaxPlayers = CreateConVar("sf2_maxplayers", "5", "The maximum amount of players than can be in one round.");
	HookConVarChange(g_cvMaxPlayers, OnConVarChanged);
	
	g_cvCampingEnabled = CreateConVar("sf2_anticamping_enabled", "1", "Enable/Disable anti-camping system for RED.");
	g_cvCampingMaxStrikes = CreateConVar("sf2_anticamping_maxstrikes", "4", "How many 5-second intervals players are allowed to stay in one spot before he/she is forced to suicide.");
	g_cvCampingStrikesWarn = CreateConVar("sf2_anticamping_strikeswarn", "2", "The amount of strikes left where the player will be warned of camping.");
	g_cvCampingMinDistance = CreateConVar("sf2_anticamping_mindistance", "128.0", "Every 5 seconds the player has to be at least this far away from his last position 5 seconds ago or else he'll get a strike.");
	g_cvCampingNoStrikeSanity = CreateConVar("sf2_anticamping_no_strike_sanity", "0.1", "The camping system will NOT give any strikes under any circumstances if the players's Sanity is missing at least this much of his maximum Sanity (max is 1.0).");
	g_cvCampingNoStrikeBossDistance = CreateConVar("sf2_anticamping_no_strike_boss_distance", "512.0", "The camping system will NOT give any strikes under any circumstances if the player is this close to a boss (ignoring LOS).");
	g_cvBossAppearChanceOverride = CreateConVar("sf2_boss_appear_chance_override", "-1.0", "Overrides the chance which any boss will appear. Set to -1 to disable the override.");
	g_cvBossMain = CreateConVar("sf2_boss_main", "slenderman", "The name of the main boss (its profile name, not its display name)");
	g_cvProfileOverride = CreateConVar("sf2_boss_profile_override", "", "Overrides which boss will be chosen next. Only applies to the first boss being chosen.");
	g_cvDifficulty = CreateConVar("sf2_difficulty", "1", "Difficulty of the game. 1 = Normal, 2 = Hard, 3 = Insane.", _, true, 1.0, true, 3.0);
	HookConVarChange(g_cvDifficulty, OnConVarChanged);
	
#if defined DEBUG
	g_cvDebugDetail = CreateConVar("sf2_debug_detail", "0", "0 = off, 1 = debug only large, expensive functions, 2 = debug more events, 3 = debug client functions");
	g_cvDebugBosses = CreateConVar("sf2_debug_bosses", "0");
#endif
	
	g_cvSpecialRoundBehavior = CreateConVar("sf2_specialround_mode", "0", "0 = Special Round resets on next round, 1 = Special Round keeps going until all players have played (not counting spectators, recently joined players, and those who reset their queue points during the round)");
	g_cvSpecialRoundForce = CreateConVar("sf2_specialround_forceenable", "-1", "Sets whether a Special Round will occur on the next round or not.");
	g_cvSpecialRoundOverride = CreateConVar("sf2_specialround_forcetype", "-1", "Sets the type of Special Round that will be chosen on the next Special Round. Set to -1 to let the game choose.");
	g_cvSpecialRoundInterval = CreateConVar("sf2_specialround_interval", "5", "If this many rounds are completed, the next round will be a Special Round.");
	
	g_cvBossRoundBehavior = CreateConVar("sf2_newbossround_mode", "0", "0 = boss selection will return to normal after the boss round, 1 = the new boss will continue being the boss until all players in the server have played against it (not counting spectators, recently joined players, and those who reset their queue points during the round).");
	g_cvBossRoundInterval = CreateConVar("sf2_newbossround_interval", "3", "If this many around are completed, the next round's boss will be randomly chosen.");
	g_cvBossRoundForce = CreateConVar("sf2_newbossround_forceenable", "-1", "Sets whether a new boss will be chosen on the next round or not. Set to -1 to let the game choose.");
	
	g_cvTimeLimit = CreateConVar("sf2_timelimit_default", "300", "The time limit of the round. Maps can change the time limit.");
	g_cvTimeLimitEscape = CreateConVar("sf2_timelimit_escape_default", "90", "The time limit to escape. Maps can change the time limit.");
	g_cvTimeGainFromPageGrab = CreateConVar("sf2_time_gain_page_grab", "12", "The time gained from grabbing a page. Maps can change the time gain amount.");
	
	g_cvPvPArenaLeaveTime = CreateConVar("sf2_player_pvparena_leavetime", "3");
	
	g_cvWarmupRound = CreateConVar("sf2_warmupround", "1");
	
	g_cvPlayerProxyWaitTime = CreateConVar("sf2_player_proxy_waittime", "35", "How long (in seconds) after a player was chosen to be a Proxy must the system wait before choosing him again.");
	g_cvPlayerProxyAsk = CreateConVar("sf2_player_proxy_ask", "0", "Set to 1 if the player can choose before becoming a Proxy, set to 0 to force.");
	
	g_cvHalfZatoichiHealthGain = CreateConVar("sf2_halfzatoichi_healthgain", "20", "How much health should be gained from killing a player with the Half-Zatoichi? Set to -1 for default behavior.");
	
	// Register console commands.
	RegConsoleCmd("sm_sf2", Command_MainMenu);
	RegConsoleCmd("sm_slender", Command_MainMenu);
	RegConsoleCmd("sm_slnext", Command_Next);
	RegConsoleCmd("sm_slgroup", Command_Group);
	RegConsoleCmd("sm_slgroupname", Command_GroupName);
	RegConsoleCmd("sm_slghost", Command_GhostMode);
	RegConsoleCmd("sm_slhelp", Command_Help);
	RegConsoleCmd("sm_slsettings", Command_Settings);
	RegConsoleCmd("sm_slcredits", Command_Credits);
	RegConsoleCmd("sm_flashlight", Command_ToggleFlashlight);
	
	RegAdminCmd("sm_sf2_scare", Command_ClientPerformScare, ADMFLAG_SLAY);
	RegAdminCmd("sm_sf2_spawn_boss", Command_SpawnSlender, ADMFLAG_SLAY);
	RegAdminCmd("sm_sf2_add_boss", Command_AddSlender, ADMFLAG_SLAY);
	RegAdminCmd("sm_sf2_add_boss_fake", Command_AddSlenderFake, ADMFLAG_SLAY);
	RegAdminCmd("sm_sf2_remove_boss", Command_RemoveSlender, ADMFLAG_SLAY);
	RegAdminCmd("sm_sf2_getbossindexes", Command_GetBossIndexes, ADMFLAG_SLAY);
	RegAdminCmd("sm_sf2_setplaystate", Command_ForceState, ADMFLAG_SLAY);
	RegAdminCmd("sm_sf2_boss_attack_waiters", Command_SlenderAttackWaiters, ADMFLAG_SLAY);
	RegAdminCmd("sm_sf2_boss_no_teleport", Command_SlenderNoTeleport, ADMFLAG_SLAY);
	RegAdminCmd("sm_sf2_force_proxy", Command_ForceProxy, ADMFLAG_SLAY);
	
	RegAdminCmd("sm_sf2_debug_boss_teleport", Command_DebugBossTeleport, ADMFLAG_CHEATS);
	RegAdminCmd("sm_sf2_debug_boss_chase", Command_DebugBossChase, ADMFLAG_CHEATS);
	RegAdminCmd("sm_sf2_debug_player_stress", Command_DebugPlayerStress, ADMFLAG_CHEATS);
	
	// Hook onto existing console commands.
	AddCommandListener(Hook_CommandBuild, "build");
	AddCommandListener(Hook_CommandBlockInGhostMode, "taunt");
	AddCommandListener(Hook_CommandBlockInGhostMode, "+taunt");
	AddCommandListener(Hook_CommandBlockInGhostMode, "use_action_slot_item_server");
	AddCommandListener(Hook_CommandActionSlotItemOn, "+use_action_slot_item_server");
	AddCommandListener(Hook_CommandActionSlotItemOff, "-use_action_slot_item_server");
	AddCommandListener(Hook_CommandBlockInGhostMode, "kill");
	AddCommandListener(Hook_CommandBlockInGhostMode, "explode");
	AddCommandListener(Hook_CommandBlockInGhostMode, "joinclass");
	AddCommandListener(Hook_CommandBlockInGhostMode, "join_class");
	AddCommandListener(Hook_CommandBlockInGhostMode, "jointeam");
	AddCommandListener(Hook_CommandBlockInGhostMode, "spectate");
	AddCommandListener(Hook_CommandVoiceMenu, "voicemenu");
	AddCommandListener(Hook_CommandSay, "say");
	
	// Hook events.
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("teamplay_round_win", Event_RoundEnd);
	HookEvent("player_team", Event_TrueBroadcast, EventHookMode_Pre);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("post_inventory_application", Event_PostInventoryApplication);
	HookEvent("item_found", Event_TrueBroadcast, EventHookMode_Pre);
	HookEvent("teamplay_teambalanced_player", Event_TrueBroadcast, EventHookMode_Pre);
	HookEvent("fish_notice", Event_PlayerDeathPre, EventHookMode_Pre);
	HookEvent("fish_notice__arm", Event_PlayerDeathPre, EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeathPre, EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeath);
	
	// Hook entities.
	HookEntityOutput("trigger_multiple", "OnStartTouch", Hook_TriggerOnStartTouch);
	HookEntityOutput("trigger_multiple", "OnEndTouch", Hook_TriggerOnEndTouch);
	
	// Hook usermessages.
	HookUserMessage(GetUserMessageId("VoiceSubtitle"), Hook_BlockUserMessage, true);
	
	// Hook sounds.
	AddNormalSoundHook(Hook_NormalSound);
	
	decl String:buffer[512];
	
	// Create menus.
	g_hMenuMain = CreateMenu(Menu_Main);
	SetMenuTitle(g_hMenuMain, "%t%t\n \n", "SF2 Prefix", "SF2 Main Menu Title");
	Format(buffer, sizeof(buffer), "%t (!slhelp)", "SF2 Help Menu Title");
	AddMenuItem(g_hMenuMain, "0", buffer);
	Format(buffer, sizeof(buffer), "%t (!slnext)", "SF2 Queue Menu Title");
	AddMenuItem(g_hMenuMain, "0", buffer);
	Format(buffer, sizeof(buffer), "%t (!slgroup)", "SF2 Group Main Menu Title");
	AddMenuItem(g_hMenuMain, "0", buffer);
	Format(buffer, sizeof(buffer), "%t (!slghost)", "SF2 Ghost Mode Menu Title");
	AddMenuItem(g_hMenuMain, "0", buffer);
	Format(buffer, sizeof(buffer), "%t (!slsettings)", "SF2 Settings Menu Title");
	AddMenuItem(g_hMenuMain, "0", buffer);
	strcopy(buffer, sizeof(buffer), "Credits (!slcredits)");
	AddMenuItem(g_hMenuMain, "0", buffer);
	
	g_hMenuVoteDifficulty = CreateMenu(Menu_VoteDifficulty);
	SetMenuTitle(g_hMenuVoteDifficulty, "%t%t\n \n", "SF2 Prefix", "SF2 Difficulty Vote Menu Title");
	Format(buffer, sizeof(buffer), "%t", "SF2 Normal Difficulty");
	AddMenuItem(g_hMenuVoteDifficulty, "1", buffer);
	Format(buffer, sizeof(buffer), "%t", "SF2 Hard Difficulty");
	AddMenuItem(g_hMenuVoteDifficulty, "2", buffer);
	Format(buffer, sizeof(buffer), "%t", "SF2 Insane Difficulty");
	AddMenuItem(g_hMenuVoteDifficulty, "3", buffer);
	
	g_hMenuGhostMode = CreateMenu(Menu_GhostMode);
	SetMenuTitle(g_hMenuGhostMode, "%t%t\n \n", "SF2 Prefix", "SF2 Ghost Mode Menu Title");
	Format(buffer, sizeof(buffer), "Enable");
	AddMenuItem(g_hMenuGhostMode, "0", buffer);
	Format(buffer, sizeof(buffer), "Disable");
	AddMenuItem(g_hMenuGhostMode, "1", buffer);
	
	g_hMenuHelp = CreateMenu(Menu_Help);
	SetMenuTitle(g_hMenuHelp, "%t%t\n \n", "SF2 Prefix", "SF2 Help Menu Title");
	Format(buffer, sizeof(buffer), "%t", "SF2 Help Objective Menu Title");
	AddMenuItem(g_hMenuHelp, "0", buffer);
	Format(buffer, sizeof(buffer), "%t", "SF2 Help Commands Menu Title");
	AddMenuItem(g_hMenuHelp, "1", buffer);
	Format(buffer, sizeof(buffer), "%t", "SF2 Help Class Info Menu Title");
	AddMenuItem(g_hMenuHelp, "2", buffer);
	Format(buffer, sizeof(buffer), "%t", "SF2 Help Ghost Mode Menu Title");
	AddMenuItem(g_hMenuHelp, "3", buffer);
	Format(buffer, sizeof(buffer), "%t", "SF2 Help Sprinting And Stamina Menu Title");
	AddMenuItem(g_hMenuHelp, "4", buffer);
	Format(buffer, sizeof(buffer), "%t", "SF2 Help Controls Menu Title");
	AddMenuItem(g_hMenuHelp, "5", buffer);
	SetMenuExitBackButton(g_hMenuHelp, true);
	
	g_hMenuHelpObjective = CreateMenu(Menu_HelpObjective);
	SetMenuTitle(g_hMenuHelpObjective, "%t%t\n \n%t\n \n", "SF2 Prefix", "SF2 Help Objective Menu Title", "SF2 Help Objective Description");
	AddMenuItem(g_hMenuHelpObjective, "0", "Next");
	AddMenuItem(g_hMenuHelpObjective, "1", "Back");
	
	g_hMenuHelpObjective2 = CreateMenu(Menu_HelpObjective2);
	SetMenuTitle(g_hMenuHelpObjective2, "%t%t\n \n%t\n \n", "SF2 Prefix", "SF2 Help Objective Menu Title", "SF2 Help Objective Description 2");
	AddMenuItem(g_hMenuHelpObjective2, "0", "Back");
	
	g_hMenuHelpCommands = CreateMenu(Menu_BackButtonOnly);
	SetMenuTitle(g_hMenuHelpCommands, "%t%t\n \n%t\n \n", "SF2 Prefix", "SF2 Help Commands Menu Title", "SF2 Help Commands Description");
	AddMenuItem(g_hMenuHelpCommands, "0", "Back");
	
	g_hMenuHelpGhostMode = CreateMenu(Menu_BackButtonOnly);
	SetMenuTitle(g_hMenuHelpGhostMode, "%t%t\n \n%t\n \n", "SF2 Prefix", "SF2 Help Ghost Mode Menu Title", "SF2 Help Ghost Mode Description");
	AddMenuItem(g_hMenuHelpGhostMode, "0", "Back");
	
	g_hMenuHelpSprinting = CreateMenu(Menu_BackButtonOnly);
	SetMenuTitle(g_hMenuHelpSprinting, "%t%t\n \n%t\n \n", "SF2 Prefix", "SF2 Help Sprinting And Stamina Menu Title", "SF2 Help Sprinting And Stamina Description");
	AddMenuItem(g_hMenuHelpSprinting, "0", "Back");
	
	g_hMenuHelpControls = CreateMenu(Menu_BackButtonOnly);
	SetMenuTitle(g_hMenuHelpControls, "%t%t\n \n%t\n \n", "SF2 Prefix", "SF2 Help Controls Menu Title", "SF2 Help Controls Description");
	AddMenuItem(g_hMenuHelpControls, "0", "Back");
	
	g_hMenuHelpClassInfo = CreateMenu(Menu_ClassInfo);
	SetMenuTitle(g_hMenuHelpClassInfo, "%t%t\n \n%t\n \n", "SF2 Prefix", "SF2 Help Class Info Menu Title", "SF2 Help Class Info Description");
	Format(buffer, sizeof(buffer), "%t", "SF2 Help Scout Class Info Menu Title");
	AddMenuItem(g_hMenuHelpClassInfo, "Scout", buffer);
	Format(buffer, sizeof(buffer), "%t", "SF2 Help Sniper Class Info Menu Title");
	AddMenuItem(g_hMenuHelpClassInfo, "Sniper", buffer);
	Format(buffer, sizeof(buffer), "%t", "SF2 Help Soldier Class Info Menu Title");
	AddMenuItem(g_hMenuHelpClassInfo, "Soldier", buffer);
	Format(buffer, sizeof(buffer), "%t", "SF2 Help Demoman Class Info Menu Title");
	AddMenuItem(g_hMenuHelpClassInfo, "Demoman", buffer);
	Format(buffer, sizeof(buffer), "%t", "SF2 Help Heavy Class Info Menu Title");
	AddMenuItem(g_hMenuHelpClassInfo, "Heavy", buffer);
	Format(buffer, sizeof(buffer), "%t", "SF2 Help Medic Class Info Menu Title");
	AddMenuItem(g_hMenuHelpClassInfo, "Medic", buffer);
	Format(buffer, sizeof(buffer), "%t", "SF2 Help Pyro Class Info Menu Title");
	AddMenuItem(g_hMenuHelpClassInfo, "Pyro", buffer);
	Format(buffer, sizeof(buffer), "%t", "SF2 Help Spy Class Info Menu Title");
	AddMenuItem(g_hMenuHelpClassInfo, "Spy", buffer);
	Format(buffer, sizeof(buffer), "%t", "SF2 Help Engineer Class Info Menu Title");
	AddMenuItem(g_hMenuHelpClassInfo, "Engineer", buffer);
	SetMenuExitBackButton(g_hMenuHelpClassInfo, true);
	
	g_hMenuSettings = CreateMenu(Menu_Settings);
	SetMenuTitle(g_hMenuSettings, "%t%t\n \n", "SF2 Prefix", "SF2 Settings Menu Title");
	Format(buffer, sizeof(buffer), "%t", "SF2 Settings PvP Menu Title");
	AddMenuItem(g_hMenuSettings, "0", buffer);
	Format(buffer, sizeof(buffer), "%t", "SF2 Settings Hints Menu Title");
	AddMenuItem(g_hMenuSettings, "0", buffer);
	Format(buffer, sizeof(buffer), "%t", "SF2 Settings Mute Mode Menu Title");
	AddMenuItem(g_hMenuSettings, "0", buffer);
	Format(buffer, sizeof(buffer), "%t", "SF2 Settings Proxy Menu Title");
	AddMenuItem(g_hMenuSettings, "0", buffer);
	SetMenuExitBackButton(g_hMenuSettings, true);
	
	g_hMenuSettingsPvP = CreateMenu(Menu_SettingsPvP);
	SetMenuTitle(g_hMenuSettingsPvP, "%t%t\n \n", "SF2 Prefix", "SF2 Settings PvP Menu Title");
	AddMenuItem(g_hMenuSettingsPvP, "0", "Toggle automatic spawning");
	SetMenuExitBackButton(g_hMenuSettingsPvP, true);
	
	g_hMenuCredits = CreateMenu(Menu_Credits);
	
	Format(buffer, sizeof(buffer), "%tCredits\n \n", "SF2 Prefix");
	StrCat(buffer, sizeof(buffer), "Coder: Kit o' Rifty\n");
	StrCat(buffer, sizeof(buffer), "Version: ");
	StrCat(buffer, sizeof(buffer), PLUGIN_VERSION);
	StrCat(buffer, sizeof(buffer), "\n \n");
	StrCat(buffer, sizeof(buffer), "Mammoth Mogul - for being a GREAT test subject\n");
	StrCat(buffer, sizeof(buffer), "Egosins - getting the first server to run this mod\n");
	StrCat(buffer, sizeof(buffer), "Somberguy - suggestions and support\n");
	StrCat(buffer, sizeof(buffer), "Voonyl/Tristtess - materials, maps, and other great stuff\n");
	StrCat(buffer, sizeof(buffer), "Narry Gewman - imported Slender Man model that has tentacles\n");
	StrCat(buffer, sizeof(buffer), "Simply Delicious - for the awesome camera overlay!\n");
	StrCat(buffer, sizeof(buffer), "Jason278 - Page models\n");
	StrCat(buffer, sizeof(buffer), "Mark J. Hadley - Creating Slender and the default music ambience\n");
	
	SetMenuTitle(g_hMenuCredits, buffer);
	AddMenuItem(g_hMenuCredits, "0", "Next");
	AddMenuItem(g_hMenuCredits, "1", "Back");
	
	g_hMenuCredits2 = CreateMenu(Menu_Credits2);
	
	Format(buffer, sizeof(buffer), "%tCredits\n \n", "SF2 Prefix");
	StrCat(buffer, sizeof(buffer), "And to all the peeps who alpha-tested this thing!\n \n");
	StrCat(buffer, sizeof(buffer), "Tofu\n");
	StrCat(buffer, sizeof(buffer), "Ace-Dashie\n");
	StrCat(buffer, sizeof(buffer), "Hobbes\n");
	StrCat(buffer, sizeof(buffer), "Diskein\n");
	StrCat(buffer, sizeof(buffer), "111112oo\n");
	StrCat(buffer, sizeof(buffer), "Incoheriant Chipmunk\n");
	StrCat(buffer, sizeof(buffer), "Shrow\n");
	StrCat(buffer, sizeof(buffer), "Liquid Vita\n");
	StrCat(buffer, sizeof(buffer), "Pinkle D Lies\n");
	StrCat(buffer, sizeof(buffer), "Ultimatefry\n \n");
	
	SetMenuTitle(g_hMenuCredits2, buffer);
	AddMenuItem(g_hMenuCredits2, "0", "Back");
	
	g_hHudSync = CreateHudSynchronizer();
	g_hHudSync2 = CreateHudSynchronizer();
	g_hRoundTimerSync = CreateHudSynchronizer();
	g_hCookie = RegClientCookie("slender_cookie", "", CookieAccess_Private);
	
	AddTempEntHook("Fire Bullets", Hook_TEFireBullets);
	
	SetupWeapons();
	SetupAdminMenu();
	SetupPlayerGroups();
}

public Action:Command_DebugBossTeleport(client, args)
{
	new bool:bInMode = bool:(g_iPlayerDebugFlags[client] & DEBUG_BOSS_TELEPORTATION);
	if (!bInMode)
	{
		g_iPlayerDebugFlags[client] |= DEBUG_BOSS_TELEPORTATION;
		PrintToChat(client, "Enabled debugging boss teleportation.");
	}
	else
	{
		g_iPlayerDebugFlags[client] &= ~DEBUG_BOSS_TELEPORTATION;
		PrintToChat(client, "Disabled debugging boss teleportation.");
	}
	
	return Plugin_Handled;
}

public Action:Command_DebugBossChase(client, args)
{
	new bool:bInMode = bool:(g_iPlayerDebugFlags[client] & DEBUG_BOSS_CHASE);
	if (!bInMode)
	{
		g_iPlayerDebugFlags[client] |= DEBUG_BOSS_CHASE;
		PrintToChat(client, "Enabled debugging boss chasing.");
	}
	else
	{
		g_iPlayerDebugFlags[client] &= ~DEBUG_BOSS_CHASE;
		PrintToChat(client, "Disabled debugging boss chasing.");
	}
	
	return Plugin_Handled;
}

public Action:Command_DebugPlayerStress(client, args)
{
	new bool:bInMode = bool:(g_iPlayerDebugFlags[client] & DEBUG_PLAYER_STRESS);
	if (!bInMode)
	{
		g_iPlayerDebugFlags[client] |= DEBUG_PLAYER_STRESS;
		PrintToChat(client, "Enabled debugging player stress.");
	}
	else
	{
		g_iPlayerDebugFlags[client] &= ~DEBUG_PLAYER_STRESS;
		PrintToChat(client, "Enabled debugging player stress.");
	}
	
	return Plugin_Handled;
}

public OnAllPluginsLoaded()
{
	SetupSDK();
}

SetupSDK()
{
	// Check SDKHooks gamedata.
	new Handle:hConfig = LoadGameConfigFile("sdkhooks.games");
	if (hConfig == INVALID_HANDLE) SetFailState("Couldn't find SDKHooks gamedata!");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConfig, SDKConf_Virtual, "GetMaxHealth");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hSDKGetMaxHealth = EndPrepSDKCall()) == INVALID_HANDLE)
	{
		SetFailState("Failed to retrieve GetMaxHealth offset from SDKHooks gamedata!");
	}
	
	CloseHandle(hConfig);
	
	// Check our own gamedata.
	hConfig = LoadGameConfigFile("sf2");
	if (hConfig == INVALID_HANDLE) SetFailState("Could not find SF2 gamedata!");
	
	new iOffset = GameConfGetOffset(hConfig, "WantsLagCompensationOnEntity"); 
	g_hSDKWantsLagCompensationOnEntity = DHookCreate(iOffset, HookType_Entity, ReturnType_Bool, ThisPointer_CBaseEntity, Hook_ClientWantsLagCompensationOnEntity); 
	if (g_hSDKWantsLagCompensationOnEntity == INVALID_HANDLE)
	{
		SetFailState("Failed to hook onto WantsLagCompensationOnEntity offset from SF2 gamedata!");
	}
	
	DHookAddParam(g_hSDKWantsLagCompensationOnEntity, HookParamType_CBaseEntity);
	DHookAddParam(g_hSDKWantsLagCompensationOnEntity, HookParamType_ObjectPtr);
	DHookAddParam(g_hSDKWantsLagCompensationOnEntity, HookParamType_Unknown);
	
	iOffset = GameConfGetOffset(hConfig, "ShouldTransmit");
	g_hSDKShouldTransmit = DHookCreate(iOffset, HookType_Entity, ReturnType_Int, ThisPointer_CBaseEntity, Hook_EntityShouldTransmit);
	if (g_hSDKShouldTransmit == INVALID_HANDLE)
	{
		SetFailState("Failed to hook onto ShouldTransmit offset from SF2 gamedata!");
	}
	
	DHookAddParam(g_hSDKShouldTransmit, HookParamType_ObjectPtr);
	
	CloseHandle(hConfig);
}

SetupWeapons()
{
	// Scout
	g_hSDKWeaponScattergun = PrepareItemHandle("tf_weapon_scattergun", 13, 0, 0, "");
	g_hSDKWeaponPistolScout = PrepareItemHandle("tf_weapon_pistol", 23, 0, 0, "");
	g_hSDKWeaponBat = PrepareItemHandle("tf_weapon_bat", 0, 0, 0, "");
	
	// Sniper
	g_hSDKWeaponSniperRifle = PrepareItemHandle("tf_weapon_sniperrifle", 14, 0, 0, "");
	g_hSDKWeaponPistolScout = PrepareItemHandle("tf_weapon_smg", 16, 0, 0, "");
	g_hSDKWeaponKukri = PrepareItemHandle("tf_weapon_club", 3, 0, 0, "");
	
	// Soldier
	g_hSDKWeaponRocketLauncher = PrepareItemHandle("tf_weapon_rocketlauncher", 18, 0, 0, "");
	g_hSDKWeaponShotgunSoldier = PrepareItemHandle("tf_weapon_shotgun", 10, 0, 0, "");
	g_hSDKWeaponShovel = PrepareItemHandle("tf_weapon_shovel", 6, 0, 0, "");
	
	// Demoman
	g_hSDKWeaponGrenadeLauncher = PrepareItemHandle("tf_weapon_grenadelauncher", 19, 0, 0, "");
	g_hSDKWeaponStickyLauncher = PrepareItemHandle("tf_weapon_pipebomblauncher", 20, 0, 0, "");
	g_hSDKWeaponBottle = PrepareItemHandle("tf_weapon_bottle", 1, 0, 0, "");
	
	// Heavy
	g_hSDKWeaponMinigun = PrepareItemHandle("tf_weapon_minigun", 15, 0, 0, "");
	g_hSDKWeaponShotgunHeavy = PrepareItemHandle("tf_weapon_shotgun", 11, 0, 0, "");
	g_hSDKWeaponFists = PrepareItemHandle("tf_weapon_fists", 5, 0, 0, "");
	
	// Medic
	g_hSDKWeaponSyringeGun = PrepareItemHandle("tf_weapon_syringegun_medic", 17, 0, 0, "");
	g_hSDKWeaponMedigun = PrepareItemHandle("tf_weapon_medigun", 29, 0, 0, "");
	g_hSDKWeaponBonesaw = PrepareItemHandle("tf_weapon_bonesaw", 8, 0, 0, "");
	
	// Pyro
	g_hSDKWeaponFlamethrower = PrepareItemHandle("tf_weapon_flamethrower", 21, 0, 0, "254 ; 4.0");
	g_hSDKWeaponShotgunPyro = PrepareItemHandle("tf_weapon_shotgun", 12, 0, 0, "");
	g_hSDKWeaponFireaxe = PrepareItemHandle("tf_weapon_fireaxe", 2, 0, 0, "");
	
	// Spy
	g_hSDKWeaponRevolver = PrepareItemHandle("tf_weapon_revolver", 24, 0, 0, "");
	g_hSDKWeaponKnife = PrepareItemHandle("tf_weapon_knife", 4, 0, 0, "");
	g_hSDKWeaponInvis = PrepareItemHandle("tf_weapon_invis", 297, 0, 0, "");
	
	// Engineer
	g_hSDKWeaponShotgunPrimary = PrepareItemHandle("tf_weapon_shotgun", 9, 0, 0, "");
	g_hSDKWeaponPistol = PrepareItemHandle("tf_weapon_pistol", 22, 0, 0, "");
	g_hSDKWeaponWrench = PrepareItemHandle("tf_weapon_wrench", 7, 0, 0, "");
}

CheckGamemodeEnable()
{
	if (!GetConVarBool(g_cvEnabled))
	{
		g_bEnabled = false;
	}
	else
	{
		if (GetConVarBool(g_cvSlenderMapsOnly))
		{
			decl String:sMap[256];
			GetCurrentMap(sMap, sizeof(sMap));
			
			if (!StrContains(sMap, "slender_", false) || !StrContains(sMap, "sf2_", false))
			{
				g_bEnabled = true;
			}
			else
			{
				LogMessage("Current map is not a Slender Fortress map. Plugin disabled!");
				g_bEnabled = false;
			}
		}
		else
		{
			g_bEnabled = true;
		}
	}
}

public OnMapStart()
{
	g_iSlenderGlobalID = -1;
	g_bRoundWarmup = true;
	g_iRoundCount = 0;
	g_hRoundMessagesTimer = CreateTimer(200.0, Timer_RoundMessages, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	g_iRoundMessagesNum = 0;
	g_iSpecialRoundCount = 0;
	
	// Reset boss rounds.
	g_bBossRound = false;
	g_iBossRoundCount = 0;
	strcopy(g_strBossRoundProfile, sizeof(g_strBossRoundProfile), "");
}

public OnConfigsExecuted()
{
	CheckGamemodeEnable();

	if (!g_bEnabled) return;
	
	// Handle ConVars.
	new Handle:hCvar = FindConVar("mp_friendlyfire");
	if (hCvar != INVALID_HANDLE) SetConVarBool(hCvar, true);
	
	hCvar = FindConVar("mp_flashlight");
	if (hCvar != INVALID_HANDLE) SetConVarBool(hCvar, true);
	
	hCvar = FindConVar("mat_supportflashlight");
	if (hCvar != INVALID_HANDLE) SetConVarBool(hCvar, true);
	
	hCvar = FindConVar("mp_autoteambalance");
	if (hCvar != INVALID_HANDLE) SetConVarBool(hCvar, false);
	
	g_flGravity = GetConVarFloat(g_cvGravity);
	
	g_bPlayerShakeEnabled = GetConVarBool(g_cvPlayerShakeEnabled);
	g_bPlayerViewbobEnabled = GetConVarBool(g_cvPlayerViewbobEnabled);
	g_bPlayerViewbobHurtEnabled = GetConVarBool(g_cvPlayerViewbobHurtEnabled);
	g_bPlayerViewbobSprintEnabled = GetConVarBool(g_cvPlayerViewbobSprintEnabled);
	
	decl String:sBuffer[64];
	Format(sBuffer, sizeof(sBuffer), "Slender Fortress (%s)", PLUGIN_VERSION);
	Steam_SetGameDescription(sBuffer);
	
	PrecacheStuff();
	
	ReloadProfiles();
	ReloadRestrictedWeapons();
	ReloadSpecialRounds();
	
	CreateTimer(0.2, Timer_HUDUpdate, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(2.0, Timer_BossCountUpdate, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	// Reset special round.
	SpecialRoundReset();
	InitializeNewGame();
	
	// Late load compensation.
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i)) continue;
		OnClientPutInServer(i);
	}
}

PrecacheStuff()
{
	// Initialize particles.
	g_iParticleCriticalHit = PrecacheParticleSystem(CRIT_PARTICLENAME);
	
	PrecacheSound2(CRIT_SOUND);
	
	// simple_bot;
	PrecacheModel("models/humans/group01/female_01.mdl", true);
	
	PrecacheModel(PAGE_MODEL, true);
	if (strlen(GHOST_MODEL) > 0) PrecacheModel(GHOST_MODEL, true);
	
	PrecacheSound2(FLASHLIGHT_CLICKSOUND);
	PrecacheSound2(FLASHLIGHT_BREAKSOUND);
	PrecacheSound2(FLASHLIGHT_NOSOUND);
	PrecacheSound2(TWENTYDOLLARS_SOUND);
	PrecacheSound2(PAGE_GRABSOUND);
	
	PrecacheSound2(MUSIC_GOTPAGES1_SOUND);
	PrecacheSound2(MUSIC_GOTPAGES2_SOUND);
	PrecacheSound2(MUSIC_GOTPAGES3_SOUND);
	PrecacheSound2(MUSIC_GOTPAGES4_SOUND);
	
	PrecacheSound2(PJSOUND);
	
	for (new i = 0; i < sizeof(g_strPlayerBreathSounds); i++)
	{
		PrecacheSound2(g_strPlayerBreathSounds[i]);
	}
	
	// Special round.
	PrecacheSound2(SR_MUSIC);
	PrecacheSound2(SR_SOUND_SELECT);
	
	PrecacheMaterial2(BLACK_OVERLAY);
	
	// PvP Arena
	PrecacheSound2(PVP_SPAWN_SOUND);
	
	AddFileToDownloadsTable("models/slender/sheet.mdl");
	AddFileToDownloadsTable("models/slender/sheet.dx80.vtx");
	AddFileToDownloadsTable("models/slender/sheet.dx90.vtx");
	AddFileToDownloadsTable("models/slender/sheet.phy");
	AddFileToDownloadsTable("models/slender/sheet.sw.vtx");
	AddFileToDownloadsTable("models/slender/sheet.vvd");
	AddFileToDownloadsTable("models/slender/sheet.xbox.vtx");
	
	AddFileToDownloadsTable("materials/models/Jason278/Slender/Sheets/Sheet_1.vtf");
	AddFileToDownloadsTable("materials/models/Jason278/Slender/Sheets/Sheet_1.vmt");
	AddFileToDownloadsTable("materials/models/Jason278/Slender/Sheets/Sheet_2.vtf");
	AddFileToDownloadsTable("materials/models/Jason278/Slender/Sheets/Sheet_2.vmt");
	AddFileToDownloadsTable("materials/models/Jason278/Slender/Sheets/Sheet_3.vtf");
	AddFileToDownloadsTable("materials/models/Jason278/Slender/Sheets/Sheet_3.vmt");
	AddFileToDownloadsTable("materials/models/Jason278/Slender/Sheets/Sheet_4.vtf");
	AddFileToDownloadsTable("materials/models/Jason278/Slender/Sheets/Sheet_4.vmt");
	AddFileToDownloadsTable("materials/models/Jason278/Slender/Sheets/Sheet_5.vtf");
	AddFileToDownloadsTable("materials/models/Jason278/Slender/Sheets/Sheet_5.vmt");
	AddFileToDownloadsTable("materials/models/Jason278/Slender/Sheets/Sheet_6.vtf");
	AddFileToDownloadsTable("materials/models/Jason278/Slender/Sheets/Sheet_6.vmt");
	AddFileToDownloadsTable("materials/models/Jason278/Slender/Sheets/Sheet_7.vtf");
	AddFileToDownloadsTable("materials/models/Jason278/Slender/Sheets/Sheet_7.vmt");
	AddFileToDownloadsTable("materials/models/Jason278/Slender/Sheets/Sheet_8.vtf");
	AddFileToDownloadsTable("materials/models/Jason278/Slender/Sheets/Sheet_8.vmt");
}

public OnMapEnd()
{
	if (!g_bEnabled) return;
	
	new Handle:hCvar = FindConVar("mp_friendlyfire");
	if (hCvar != INVALID_HANDLE) SetConVarBool(hCvar, false);
	
	hCvar = FindConVar("mp_flashlight");
	if (hCvar != INVALID_HANDLE) SetConVarBool(hCvar, false);
	
	hCvar = FindConVar("mat_supportflashlight");
	if (hCvar != INVALID_HANDLE) SetConVarBool(hCvar, false);
}

public OnPluginEnd()
{
	if (!g_bEnabled) return;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		ClientDeactivateFlashlight(i);
	}
}

public OnGameFrame()
{
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		if (g_iSlenderID[i] == -1) continue;
		if (EntRefToEntIndex(g_iSlender[i]) == INVALID_ENT_REFERENCE) continue;
		if (g_iSlenderFlags[i] & SFF_MARKEDASFAKE) continue;
		
		SlenderChaseBossProcessMovement(i);
	}
}

//	==========================================================
//	MAIN MENU FUNCTIONS
//	==========================================================

public Menu_Main(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 0: DisplayMenu(g_hMenuHelp, param1, 30);
			case 1: DisplayQueuePointsMenu(param1);
			case 2:	DisplayGroupMainMenuToClient(param1);
			case 3: DisplayMenu(g_hMenuGhostMode, param1, 30);
			case 4: DisplayMenu(g_hMenuSettings, param1, 30);
			case 5: DisplayMenu(g_hMenuCredits, param1, MENU_TIME_FOREVER);
		}
	}
}

public Menu_VoteDifficulty(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_VoteEnd)
	{
		decl String:sInfo[64], String:sDisplay[256], String:sColor[32];
		GetMenuItem(menu, param1, sInfo, sizeof(sInfo), _, sDisplay, sizeof(sDisplay));
		
		if (g_bSpecialRound && 
			(g_iSpecialRound == SPECIALROUND_INSANEDIFFICULTY || g_iSpecialRound == SPECIALROUND_DOUBLEMAXPLAYERS))
		{
			SetConVarInt(g_cvDifficulty, Difficulty_Insane);
		}
		else
		{
			SetConVarString(g_cvDifficulty, sInfo);
		}
		
		new iDifficulty = GetConVarInt(g_cvDifficulty);
		switch (iDifficulty)
		{
			case Difficulty_Easy:
			{
				Format(sDisplay, sizeof(sDisplay), "%t", "SF2 Easy Difficulty");
				strcopy(sColor, sizeof(sColor), "{green}");
			}
			case Difficulty_Hard:
			{
				Format(sDisplay, sizeof(sDisplay), "%t", "SF2 Hard Difficulty");
				strcopy(sColor, sizeof(sColor), "{orange}");
			}
			case Difficulty_Insane:
			{
				Format(sDisplay, sizeof(sDisplay), "%t", "SF2 Insane Difficulty");
				strcopy(sColor, sizeof(sColor), "{red}");
			}
			default:
			{
				Format(sDisplay, sizeof(sDisplay), "%t", "SF2 Normal Difficulty");
				strcopy(sColor, sizeof(sColor), "{yellow}");
			}
		}
		
		CPrintToChatAll("%t %s%s", "SF2 Difficulty Vote Finished", sColor, sDisplay);
	}
}

public Menu_GhostMode(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		if (g_bRoundEnded ||
			g_bRoundWarmup ||
			!g_bPlayerEliminated[param1] ||
			g_bPlayerProxy[param1])
		{
			CPrintToChat(param1, "{red}%T", "SF2 Ghost Mode Not Allowed", param1);
		}
		else
		{
			switch (param2)
			{
				case 0:
				{
					if (g_bPlayerGhostMode[param1]) CPrintToChat(param1, "{red}%T", "SF2 Ghost Mode Enabled Already", param1);
					else
					{
						TF2_RespawnPlayer(param1);
						ClientEnableGhostMode(param1);
						
						CPrintToChat(param1, "{olive}%T", "SF2 Ghost Mode Enabled", param1);
					}
				}
				case 1:
				{
					if (!g_bPlayerGhostMode[param1]) CPrintToChat(param1, "{red}%T", "SF2 Ghost Mode Disabled Already", param1);
					else
					{
						ClientDisableGhostMode(param1);
						TF2_RespawnPlayer(param1);
						
						CPrintToChat(param1, "{olive}%T", "SF2 Ghost Mode Disabled", param1);
					}
				}
			}
		}
	}
}

public Menu_Help(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 0: DisplayMenu(g_hMenuHelpObjective, param1, 30);
			case 1: DisplayMenu(g_hMenuHelpCommands, param1, 30);
			case 2: DisplayMenu(g_hMenuHelpClassInfo, param1, 30);
			case 3: DisplayMenu(g_hMenuHelpGhostMode, param1, 30);
			case 4: DisplayMenu(g_hMenuHelpSprinting, param1, 30);
			case 5: DisplayMenu(g_hMenuHelpControls, param1, 30);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack)
		{
			DisplayMenu(g_hMenuMain, param1, 30);
		}
	}
}

public Menu_HelpObjective(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 0: DisplayMenu(g_hMenuHelpObjective2, param1, 30);
			case 1: DisplayMenu(g_hMenuHelp, param1, 30);
		}
	}
}

public Menu_HelpObjective2(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 0: DisplayMenu(g_hMenuHelpObjective, param1, 30);
		}
	}
}

public Menu_BackButtonOnly(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 0: DisplayMenu(g_hMenuHelp, param1, 30);
		}
	}
}

public Menu_Credits(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 0: DisplayMenu(g_hMenuCredits2, param1, MENU_TIME_FOREVER);
			case 1: DisplayMenu(g_hMenuMain, param1, 30);
		}
	}
}

public Menu_ClassInfo(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack)
		{
			DisplayMenu(g_hMenuMain, param1, 30);
		}
	}
	else if (action == MenuAction_Select)
	{
		decl String:sInfo[64];
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
		
		new Handle:hMenu = CreateMenu(Menu_ClassInfoBackOnly);
		
		decl String:sTitle[64], String:sDescription[64];
		Format(sTitle, sizeof(sTitle), "SF2 Help %s Class Info Menu Title", sInfo);
		Format(sDescription, sizeof(sDescription), "SF2 Help %s Class Info Description", sInfo);
		
		SetMenuTitle(hMenu, "%t%t\n \n%t\n \n", "SF2 Prefix", sTitle, sDescription);
		AddMenuItem(hMenu, "0", "Back");
		DisplayMenu(hMenu, param1, 30);
	}
}

public Menu_ClassInfoBackOnly(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Select)
	{
		DisplayMenu(g_hMenuHelpClassInfo, param1, 30);
	}
}

public Menu_Settings(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 0: DisplayMenu(g_hMenuSettingsPvP, param1, 30);
			case 1:
			{
				decl String:sBuffer[512];
				Format(sBuffer, sizeof(sBuffer), "%T\n \n", "SF2 Settings Hints Menu Title", param1);
				
				new Handle:hPanel = CreatePanel();
				SetPanelTitle(hPanel, sBuffer);
				
				Format(sBuffer, sizeof(sBuffer), "%T", "Yes", param1);
				DrawPanelItem(hPanel, sBuffer);
				Format(sBuffer, sizeof(sBuffer), "%T", "No", param1);
				DrawPanelItem(hPanel, sBuffer);
				
				SendPanelToClient(hPanel, param1, Panel_SettingsHints, 30);
				CloseHandle(hPanel);
			}
			case 2:
			{
				decl String:sBuffer[512];
				Format(sBuffer, sizeof(sBuffer), "%T\n \n", "SF2 Settings Mute Mode Menu Title", param1);
				
				new Handle:hPanel = CreatePanel();
				SetPanelTitle(hPanel, sBuffer);
				
				DrawPanelItem(hPanel, "Normal");
				DrawPanelItem(hPanel, "Mute opposing team");
				DrawPanelItem(hPanel, "Mute opposing team except when I'm a proxy");
				
				SendPanelToClient(hPanel, param1, Panel_SettingsMuteMode, 30);
				CloseHandle(hPanel);
			}
			case 3:
			{
				decl String:sBuffer[512];
				Format(sBuffer, sizeof(sBuffer), "%T\n \n", "SF2 Settings Proxy Menu Title", param1);
				
				new Handle:hPanel = CreatePanel();
				SetPanelTitle(hPanel, sBuffer);
				
				Format(sBuffer, sizeof(sBuffer), "%T", "Yes", param1);
				DrawPanelItem(hPanel, sBuffer);
				Format(sBuffer, sizeof(sBuffer), "%T", "No", param1);
				DrawPanelItem(hPanel, sBuffer);
				
				SendPanelToClient(hPanel, param1, Panel_SettingsProxy, 30);
				CloseHandle(hPanel);
			}
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack)
		{
			DisplayMenu(g_hMenuMain, param1, 30);
		}
	}
}

public Menu_SettingsPvP(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 0:
			{
				decl String:sBuffer[512];
				Format(sBuffer, sizeof(sBuffer), "%T\n \n", "SF2 Settings PvP Spawn Menu Title", param1);
				
				new Handle:hPanel = CreatePanel();
				SetPanelTitle(hPanel, sBuffer);
				
				Format(sBuffer, sizeof(sBuffer), "%T", "Yes", param1);
				DrawPanelItem(hPanel, sBuffer);
				Format(sBuffer, sizeof(sBuffer), "%T", "No", param1);
				DrawPanelItem(hPanel, sBuffer);
				
				SendPanelToClient(hPanel, param1, Panel_SettingsPvPSpawn, 30);
				CloseHandle(hPanel);
			}
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack)
		{
			DisplayMenu(g_hMenuSettings, param1, 30);
		}
	}
}

public Panel_SettingsPvPSpawn(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 1:
			{
				g_bPlayerInPvPSpawning[param1] = true;
				CPrintToChat(param1, "%T", "SF2 PvP Spawn Accept", param1);
			}
			case 2:
			{
				g_bPlayerInPvPSpawning[param1] = false;
				CPrintToChat(param1, "%T", "SF2 PvP Spawn Decline", param1);
			}
		}
		
		DisplayMenu(g_hMenuSettings, param1, 30);
	}
}

public Panel_SettingsHints(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 1:
			{
				g_bPlayerShowHints[param1] = true;
				ClientSaveCookies(param1);
				CPrintToChat(param1, "%T", "SF2 Enabled Hints", param1);
			}
			case 2:
			{
				g_bPlayerShowHints[param1] = false;
				ClientSaveCookies(param1);
				CPrintToChat(param1, "%T", "SF2 Disabled Hints", param1);
			}
		}
		
		DisplayMenu(g_hMenuSettings, param1, 30);
	}
}

public Panel_SettingsProxy(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 1:
			{
				g_bPlayerWantsTheP[param1] = true;
				ClientSaveCookies(param1);
				CPrintToChat(param1, "%T", "SF2 Enabled Proxy", param1);
			}
			case 2:
			{
				g_bPlayerWantsTheP[param1] = false;
				ClientSaveCookies(param1);
				CPrintToChat(param1, "%T", "SF2 Disabled Proxy", param1);
			}
		}
		
		DisplayMenu(g_hMenuSettings, param1, 30);
	}
}

public Panel_SettingsMuteMode(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 1:
			{
				g_iPlayerMuteMode[param1] = MuteMode_Normal;
				ClientUpdateListeningFlags(param1);
				ClientSaveCookies(param1);
				CPrintToChat(param1, "{lightgreen}Mute mode set to normal.");
			}
			case 2:
			{
				g_iPlayerMuteMode[param1] = MuteMode_DontHearOtherTeam;
				ClientUpdateListeningFlags(param1);
				ClientSaveCookies(param1);
				CPrintToChat(param1, "{lightgreen}Muted opposing team.");
			}
			case 3:
			{
				g_iPlayerMuteMode[param1] = MuteMode_DontHearOtherTeamIfNotProxy;
				ClientUpdateListeningFlags(param1);
				ClientSaveCookies(param1);
				CPrintToChat(param1, "{lightgreen}Muted opposing team, but settings will be automatically set to normal if you're a proxy.");
			}
		}
		
		DisplayMenu(g_hMenuSettings, param1, 30);
	}
}

public Menu_Credits2(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 0: DisplayMenu(g_hMenuCredits, param1, MENU_TIME_FOREVER);
		}
	}
}

DisplayQueuePointsMenu(client)
{
	new Handle:menu = CreateMenu(Menu_QueuePoints);
	new Handle:hQueueList = GetQueueList();
	
	decl String:sBuffer[256];
	
	if (GetArraySize(hQueueList))
	{
		Format(sBuffer, sizeof(sBuffer), "%T\n \n", "SF2 Reset Queue Points Option", client, g_iPlayerQueuePoints[client]);
		AddMenuItem(menu, "ponyponypony", sBuffer);
		
		decl iIndex, String:sGroupName[SF2_MAX_PLAYER_GROUP_NAME_LENGTH];
		decl String:sInfo[256];
		
		for (new i = 0, iSize = GetArraySize(hQueueList); i < iSize; i++)
		{
			if (!GetArrayCell(hQueueList, i, 2))
			{
				iIndex = GetArrayCell(hQueueList, i);
				
				Format(sBuffer, sizeof(sBuffer), "%N - %d", iIndex, g_iPlayerQueuePoints[iIndex]);
				Format(sInfo, sizeof(sInfo), "player_%d", GetClientUserId(iIndex));
				AddMenuItem(menu, sInfo, sBuffer, g_bPlayerPlaying[iIndex] ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
			}
			else
			{
				iIndex = GetArrayCell(hQueueList, i);
				if (GetPlayerGroupMemberCount(iIndex) > 1)
				{
					GetPlayerGroupName(iIndex, sGroupName, sizeof(sGroupName));
					
					Format(sBuffer, sizeof(sBuffer), "[GROUP] %s - %d", sGroupName, GetPlayerGroupQueuePoints(iIndex));
					Format(sInfo, sizeof(sInfo), "group_%d", iIndex);
					AddMenuItem(menu, sInfo, sBuffer, IsPlayerGroupPlaying(iIndex) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
				}
				else
				{
					for (new iClient = 1; iClient <= MaxClients; iClient++)
					{
						if (!IsValidClient(iClient)) continue;
						if (ClientGetPlayerGroup(iClient) == iIndex)
						{
							Format(sBuffer, sizeof(sBuffer), "%N - %d", iClient, g_iPlayerQueuePoints[iClient]);
							Format(sInfo, sizeof(sInfo), "player_%d", GetClientUserId(iClient));
							AddMenuItem(menu, "player", sBuffer, g_bPlayerPlaying[iClient] ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
							break;
						}
					}
				}
			}
		}
	}
	
	CloseHandle(hQueueList);
	
	SetMenuTitle(menu, "%t%T\n \n", "SF2 Prefix", "SF2 Queue Menu Title", client);
	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

DisplayViewGroupMembersQueueMenu(client, iGroupIndex)
{
	if (!IsPlayerGroupActive(iGroupIndex))
	{
		// The group isn't valid anymore. Take him back to the main menu.
		DisplayQueuePointsMenu(client);
		CPrintToChat(client, "%T", "SF2 Group Does Not Exist", client);
		return;
	}
	
	new Handle:hPlayers = CreateArray();
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i)) continue;
		
		new iTempGroup = ClientGetPlayerGroup(i);
		if (!IsPlayerGroupActive(iTempGroup) || iTempGroup != iGroupIndex) continue;
		
		PushArrayCell(hPlayers, i);
	}
	
	new iPlayerCount = GetArraySize(hPlayers);
	if (iPlayerCount)
	{
		decl String:sGroupName[SF2_MAX_PLAYER_GROUP_NAME_LENGTH];
		GetPlayerGroupName(iGroupIndex, sGroupName, sizeof(sGroupName));
		
		new Handle:hMenu = CreateMenu(Menu_ViewGroupMembersQueue);
		SetMenuTitle(hMenu, "%t%T (%s)\n \n", "SF2 Prefix", "SF2 View Group Members Menu Title", client, sGroupName);
		
		decl String:sUserId[32];
		decl String:sName[MAX_NAME_LENGTH * 2];
		
		for (new i = 0; i < iPlayerCount; i++)
		{
			new iClient = GetArrayCell(hPlayers, i);
			IntToString(GetClientUserId(iClient), sUserId, sizeof(sUserId));
			GetClientName(iClient, sName, sizeof(sName));
			if (GetPlayerGroupLeader(iGroupIndex) == iClient) StrCat(sName, sizeof(sName), " (LEADER)");
			
			AddMenuItem(hMenu, sUserId, sName);
		}
		
		SetMenuExitBackButton(hMenu, true);
		DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
	}
	else
	{
		// No players!
		DisplayQueuePointsMenu(client);
	}
	
	CloseHandle(hPlayers);
}

public Menu_ViewGroupMembersQueue(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_End: CloseHandle(menu);
		case MenuAction_Select: DisplayQueuePointsMenu(param1);
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack) DisplayQueuePointsMenu(param1);
		}
	}
}

DisplayResetQueuePointsMenu(client)
{
	decl String:buffer[256];

	new Handle:menu = CreateMenu(Menu_ResetQueuePoints);
	Format(buffer, sizeof(buffer), "%T", "Yes", client);
	AddMenuItem(menu, "0", buffer);
	Format(buffer, sizeof(buffer), "%T", "No", client);
	AddMenuItem(menu, "1", buffer);
	SetMenuTitle(menu, "%T\n \n", "SF2 Should Reset Queue Points", client);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public Menu_QueuePoints(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			new String:sInfo[64];
			GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
			
			if (StrEqual(sInfo, "ponyponypony")) DisplayResetQueuePointsMenu(param1);
			else if (!StrContains(sInfo, "player_"))
			{
			}
			else if (!StrContains(sInfo, "group_"))
			{
				decl String:sIndex[64];
				strcopy(sIndex, sizeof(sIndex), sInfo);
				ReplaceString(sIndex, sizeof(sIndex), "group_", "");
				DisplayViewGroupMembersQueueMenu(param1, StringToInt(sIndex));
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				DisplayMenu(g_hMenuMain, param1, 30);
			}
		}
		case MenuAction_End: CloseHandle(menu);
	}
}

public Menu_ResetQueuePoints(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0:
				{
					ClientSetQueuePoints(param1, 0);
					CPrintToChat(param1, "{olive}%T", "SF2 Queue Points Reset", param1);
					
					// Special round.
					if (g_bSpecialRound) g_bPlayerDidSpecialRound[param1] = true;
					
					// Boss round.
					if (g_bBossRound) g_bPlayerDidBossRound[param1] = true;
				}
			}
			
			DisplayQueuePointsMenu(param1);
		}
		
		case MenuAction_End: CloseHandle(menu);
	}
}

//	==========================================================
//	COMMANDS AND COMMAND HOOK FUNCTIONS
//	==========================================================

public Action:Command_Help(client, args)
{
	if (!g_bEnabled) return Plugin_Continue;
	
	DisplayMenu(g_hMenuHelp, client, 30);
	return Plugin_Handled;
}

public Action:Command_Settings(client, args)
{
	if (!g_bEnabled) return Plugin_Continue;
	
	DisplayMenu(g_hMenuSettings, client, 30);
	return Plugin_Handled;
}

public Action:Command_Credits(client, args)
{
	if (!g_bEnabled) return Plugin_Continue;
	
	DisplayMenu(g_hMenuCredits, client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public Action:Command_ToggleFlashlight(client, args)
{
	if (!g_bEnabled) return Plugin_Continue;
	
	if (!IsClientInGame(client) || !IsPlayerAlive(client)) return Plugin_Handled;
	
	ClientToggleFlashlight(client);
	
	return Plugin_Handled;
}

public Action:Command_MainMenu(client, args)
{
	if (!g_bEnabled) return Plugin_Continue;

	DisplayMenu(g_hMenuMain, client, 30);
	return Plugin_Handled;
}

public Action:Command_Next(client, args)
{
	if (!g_bEnabled) return Plugin_Continue;
	
	DisplayQueuePointsMenu(client);
	return Plugin_Handled;
}

public Action:Command_Group(client, args)
{
	if (!g_bEnabled) return Plugin_Continue;
	
	DisplayGroupMainMenuToClient(client);
	return Plugin_Handled;
}

public Action:Command_GroupName(client, args)
{
	if (!g_bEnabled) return Plugin_Continue;
	
	if (args < 1)
	{
		ReplyToCommand(client, "Usage: sm_slgroupname <name>");
		return Plugin_Handled;
	}
	
	new iGroupIndex = ClientGetPlayerGroup(client);
	if (!IsPlayerGroupActive(iGroupIndex))
	{
		CPrintToChat(client, "%T", "SF2 Group Does Not Exist", client);
		return Plugin_Handled;
	}
	
	if (GetPlayerGroupLeader(iGroupIndex) != client)
	{
		CPrintToChat(client, "%T", "SF2 Not Group Leader", client);
		return Plugin_Handled;
	}
	
	decl String:sGroupName[SF2_MAX_PLAYER_GROUP_NAME_LENGTH];
	GetCmdArg(1, sGroupName, sizeof(sGroupName));
	if (!sGroupName[0])
	{
		CPrintToChat(client, "%T", "SF2 Invalid Group Name", client);
		return Plugin_Handled;
	}
	
	decl String:sOldGroupName[SF2_MAX_PLAYER_GROUP_NAME_LENGTH];
	GetPlayerGroupName(iGroupIndex, sOldGroupName, sizeof(sOldGroupName));
	SetPlayerGroupName(iGroupIndex, sGroupName);
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i)) continue;
		if (ClientGetPlayerGroup(i) != iGroupIndex) continue;
		CPrintToChat(i, "%T", "SF2 Group Name Set", i, sOldGroupName, sGroupName);
	}
	
	return Plugin_Handled;
}

public Action:Command_GhostMode(client, args)
{
	if (!g_bEnabled) return Plugin_Continue;

	DisplayMenu(g_hMenuGhostMode, client, 15);
	return Plugin_Handled;
}

public Action:Hook_CommandSay(client, const String:command[], argc)
{
	if (!g_bEnabled || GetConVarBool(g_cvAllChat)) return Plugin_Continue;
	
	if (!g_bRoundEnded)
	{
		if (g_bPlayerEliminated[client])
		{
			decl String:sMessage[256];
			GetCmdArgString(sMessage, sizeof(sMessage));
			FakeClientCommand(client, "say_team %s", sMessage);
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

public Action:Hook_CommandBlockInGhostMode(client, const String:command[], argc)
{
	if (!g_bEnabled) return Plugin_Continue;
	if (g_bPlayerGhostMode[client]) return Plugin_Handled;
	
	return Plugin_Continue;
}

public Action:Hook_CommandActionSlotItemOn(client, const String:command[], argc)
{
	if (!g_bEnabled) return Plugin_Continue;
	if (g_bPlayerGhostMode[client] || g_bPlayerProxy[client]) return Plugin_Handled;
	
	if (IsPlayerAlive(client))
	{
		if (!g_bPlayerEliminated[client])
		{
			if (!g_bPlayerSprint[client] && !g_bPlayerEscaped[client])
			{
				if (g_iPlayerSprintPoints[client] > 0)
				{
					ClientStartSprint(client);
				}
				else
				{
					EmitSoundToClient(client, FLASHLIGHT_NOSOUND, _, SNDCHAN_ITEM, SNDLEVEL_NONE);
				}
				
				return Plugin_Handled;
			}
		}
	}
	
	return Plugin_Continue;
}

public Action:Hook_CommandActionSlotItemOff(client, const String:command[], argc)
{
	if (!g_bEnabled) return Plugin_Continue;
	
	if (IsPlayerAlive(client))
	{
		if (!g_bPlayerEliminated[client])
		{
			if (g_bPlayerSprint[client])
			{
				ClientStopSprint(client);
			}
			
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

public Action:Hook_CommandVoiceMenu(client, const String:command[], argc)
{
	if (!g_bEnabled) return Plugin_Continue;
	if (g_bPlayerGhostMode[client]) return Plugin_Handled;
	
	if (g_bPlayerProxy[client])
	{
		new iMaster = SlenderGetFromID(g_iPlayerProxyMaster[client]);
		if (iMaster != -1)
		{
			if (!bool:GetProfileNum(g_strSlenderProfile[iMaster], "proxies_allownormalvoices", 1))
			{
				return Plugin_Handled;
			}
		}
	}
	
	return Plugin_Continue;
}

public Action:Command_ClientPerformScare(client, args)
{
	if (!g_bEnabled) return Plugin_Continue;

	if (args < 2)
	{
		ReplyToCommand(client, "Usage: sm_sf2_scare <name|#userid> <bossindex 0-%d>", MAX_BOSSES - 1);
		return Plugin_Handled;
	}
	
	decl String:arg1[32], String:arg2[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	
	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (new i = 0; i < target_count; i++)
	{
		new target = target_list[i];
		ClientPerformScare(target, StringToInt(arg2));
	}
	
	return Plugin_Handled;
}

public Action:Command_SpawnSlender(client, args)
{
	if (!g_bEnabled) return Plugin_Continue;

	if (args == 0)
	{
		ReplyToCommand(client, "Usage: sm_sf2_spawn_boss <bossindex 0-%d>", MAX_BOSSES - 1);
		return Plugin_Handled;
	}
	
	decl String:arg1[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	new iBossIndex = StringToInt(arg1);
	if (!g_strSlenderProfile[iBossIndex][0]) return Plugin_Handled;
	
	decl Float:eyePos[3], Float:eyeAng[3], Float:endPos[3];
	GetClientEyePosition(client, eyePos);
	GetClientEyeAngles(client, eyeAng);
	
	new Handle:hTrace = TR_TraceRayFilterEx(eyePos, eyeAng, MASK_NPCSOLID, RayType_Infinite, TraceRayDontHitEntity, client);
	TR_GetEndPosition(endPos, hTrace);
	CloseHandle(hTrace);

	SpawnSlender(iBossIndex, endPos);
	CPrintToChat(client, "%t%T", "SF2 Prefix", "SF2 Spawned Boss", client);
	LogAction(client, -1, "%N spawned boss %d! (%s)", client, iBossIndex, g_strSlenderProfile[iBossIndex]);
	
	return Plugin_Handled;
}

public Action:Command_RemoveSlender(client, args)
{
	if (!g_bEnabled) return Plugin_Continue;

	if (args == 0)
	{
		ReplyToCommand(client, "Usage: sm_sf2_remove_boss <bossindex 0-%d>", MAX_BOSSES - 1);
		return Plugin_Handled;
	}
	
	decl String:arg1[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	new iBossIndex = StringToInt(arg1);
	if (!g_strSlenderProfile[iBossIndex][0]) return Plugin_Handled;
	
	CPrintToChat(client, "%t%T", "SF2 Prefix", "SF2 Removed Boss", client);
	LogAction(client, -1, "%N removed boss %d! (%s)", client, iBossIndex, g_strSlenderProfile[iBossIndex]);
	RemoveProfile(iBossIndex);
	
	return Plugin_Handled;
}

public Action:Command_GetBossIndexes(client, args)
{
	if (!g_bEnabled) return Plugin_Continue;
	
	decl String:sMessage[512];
	
	ClientCommand(client, "echo Active Boss Indexes:");
	ClientCommand(client, "echo ----------------------------");
	
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		if (!g_strSlenderProfile[i][0]) continue;
		
		Format(sMessage, sizeof(sMessage), "%d - %s", i, g_strSlenderProfile[i]);
		if (g_iSlenderFlags[i] & SFF_FAKE)
		{
			StrCat(sMessage, sizeof(sMessage), " (fake)");
		}
		
		if (g_iSlenderCopyMaster[i] != -1)
		{
			decl String:sCat[64];
			Format(sCat, sizeof(sCat), " (copy of %d)", g_iSlenderCopyMaster[i]);
			StrCat(sMessage, sizeof(sMessage), sCat);
		}
		
		ClientCommand(client, "echo %s", sMessage);
	}
	
	ClientCommand(client, "echo ----------------------------");
	
	ReplyToCommand(client, "Printed active boss indexes to your console!");
	
	return Plugin_Handled;
}

public Action:Command_SlenderAttackWaiters(client, args)
{
	if (!g_bEnabled) return Plugin_Continue;

	if (args < 2)
	{
		ReplyToCommand(client, "Usage: sm_sf2_boss_attack_waiters <bossindex 0-%d> <0/1>", MAX_BOSSES - 1);
		return Plugin_Handled;
	}
	
	decl String:arg1[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	
	new iBossIndex = StringToInt(arg1);
	if (!g_strSlenderProfile[iBossIndex][0]) return Plugin_Handled;
	
	decl String:arg2[32];
	GetCmdArg(2, arg2, sizeof(arg2));
	
	new bool:bState = bool:StringToInt(arg2);
	
	new bool:bOldState = bool:(g_iSlenderFlags[iBossIndex] & SFF_ATTACKWAITERS);
	
	if (bState)
	{
		if (!bOldState)
		{
			g_iSlenderFlags[iBossIndex] |= SFF_ATTACKWAITERS;
			CPrintToChat(client, "%t%T", "SF2 Prefix", "SF2 Boss Attack Waiters", client);
			LogAction(client, -1, "%N forced boss %d to attack waiters! (%s)", client, iBossIndex, g_strSlenderProfile[iBossIndex]);
		}
	}
	else
	{
		if (bOldState)
		{
			g_iSlenderFlags[iBossIndex] &= ~SFF_ATTACKWAITERS;
			CPrintToChat(client, "%t%T", "SF2 Prefix", "SF2 Boss Do Not Attack Waiters", client);
			LogAction(client, -1, "%N forced boss %d to not attack waiters! (%s)", client, iBossIndex, g_strSlenderProfile[iBossIndex]);
		}
	}
	
	return Plugin_Handled;
}

public Action:Command_SlenderNoTeleport(client, args)
{
	if (!g_bEnabled) return Plugin_Continue;

	if (args < 2)
	{
		ReplyToCommand(client, "Usage: sm_sf2_boss_no_teleport <bossindex 0-%d> <0/1>", MAX_BOSSES - 1);
		return Plugin_Handled;
	}
	
	decl String:arg1[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	
	new iBossIndex = StringToInt(arg1);
	if (!g_strSlenderProfile[iBossIndex][0]) return Plugin_Handled;
	
	decl String:arg2[32];
	GetCmdArg(2, arg2, sizeof(arg2));
	
	new bool:bState = bool:StringToInt(arg2);
	
	new bool:bOldState = bool:(g_iSlenderFlags[iBossIndex] & SFF_NOTELEPORT);
	
	if (bState)
	{
		if (!bOldState)
		{
			g_iSlenderFlags[iBossIndex] |= SFF_NOTELEPORT;
			CPrintToChat(client, "%t%T", "SF2 Prefix", "SF2 Boss Should Not Teleport", client);
			LogAction(client, -1, "%N disabled teleportation of boss %d! (%s)", client, iBossIndex, g_strSlenderProfile[iBossIndex]);
		}
	}
	else
	{
		if (bOldState)
		{
			g_iSlenderFlags[iBossIndex] &= ~SFF_NOTELEPORT;
			CPrintToChat(client, "%t%T", "SF2 Prefix", "SF2 Boss Should Teleport", client);
			LogAction(client, -1, "%N enabled teleportation of boss %d! (%s)", client, iBossIndex, g_strSlenderProfile[iBossIndex]);
		}
	}
	
	return Plugin_Handled;
}

public Action:Command_ForceProxy(client, args)
{
	if (!g_bEnabled) return Plugin_Continue;
	
	if (args < 1)
	{
		ReplyToCommand(client, "Usage: sm_sf2_force_proxy <name|#userid> <bossindex 0-%d>", MAX_BOSSES - 1);
		return Plugin_Handled;
	}
	
	if (g_bRoundEnded || g_bRoundWarmup)
	{
		CPrintToChat(client, "%t%T", "SF2 Prefix", "SF2 Cannot Use Command", client);
		return Plugin_Handled;
	}
	
	decl String:arg1[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	
	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			0,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	decl String:arg2[32];
	GetCmdArg(2, arg2, sizeof(arg2));
	
	new iBossIndex = StringToInt(arg2);
	if (iBossIndex < 0 || iBossIndex >= MAX_BOSSES)
	{
		ReplyToCommand(client, "Boss index is out of range!");
		return Plugin_Handled;
	}
	else if (!g_strSlenderProfile[iBossIndex][0])
	{
		ReplyToCommand(client, "Boss index is invalid! Boss index not active!");
		return Plugin_Handled;
	}
	
	for (new i = 0; i < target_count; i++)
	{
		new iTarget = target_list[i];
		
		decl String:sName[MAX_NAME_LENGTH];
		GetClientName(iTarget, sName, sizeof(sName));
		
		if (!g_bPlayerEliminated[iTarget])
		{
			CPrintToChat(client, "%t%T", "SF2 Prefix", "SF2 Unable To Perform Action On Player In Round", client, sName);
			continue;
		}
		
		if (g_bPlayerProxy[iTarget]) continue;
		
		decl Float:flNewPos[3];
		
		if (!SlenderCalculateNewPlace(iBossIndex, flNewPos, true, true, client)) 
		{
			CPrintToChat(client, "%t%T", "SF2 Prefix", "SF2 Player No Place For Proxy", client, sName);
			continue;
		}
		
		ClientEnableProxy(iTarget, iBossIndex);
		TeleportEntity(iTarget, flNewPos, NULL_VECTOR, Float:{ 0.0, 0.0, 0.0 });
		
		LogAction(client, iTarget, "%N forced %N to be a Proxy!", client, iTarget);
	}
	
	return Plugin_Handled;
}

public Action:Command_AddSlender(client, args)
{
	if (!g_bEnabled) return Plugin_Continue;

	if (args < 1)
	{
		ReplyToCommand(client, "Usage: sm_sf2_add_boss <name>");
		return Plugin_Handled;
	}
	
	decl String:sProfile[SF2_MAX_PROFILE_NAME_LENGTH];
	GetCmdArg(1, sProfile, sizeof(sProfile));
	
	KvRewind(g_hConfig);
	if (!KvJumpToKey(g_hConfig, sProfile)) 
	{
		ReplyToCommand(client, "That boss does not exist!");
		return Plugin_Handled;
	}
	
	new iBossIndex = AddProfile(sProfile);
	if (iBossIndex != -1)
	{
		decl Float:eyePos[3], Float:eyeAng[3], Float:flPos[3];
		GetClientEyePosition(client, eyePos);
		GetClientEyeAngles(client, eyeAng);
		
		new Handle:hTrace = TR_TraceRayFilterEx(eyePos, eyeAng, MASK_NPCSOLID, RayType_Infinite, TraceRayDontHitEntity, client);
		TR_GetEndPosition(flPos, hTrace);
		CloseHandle(hTrace);
	
		SpawnSlender(iBossIndex, flPos);
		
		LogAction(client, -1, "%N added a boss! (%s)", client, sProfile);
	}
	
	return Plugin_Handled;
}

public Action:Command_AddSlenderFake(client, args)
{
	if (!g_bEnabled) return Plugin_Continue;

	if (args < 1)
	{
		ReplyToCommand(client, "Usage: sm_sf2_add_boss_fake <name>");
		return Plugin_Handled;
	}
	
	decl String:sProfile[SF2_MAX_PROFILE_NAME_LENGTH];
	GetCmdArg(1, sProfile, sizeof(sProfile));
	
	KvRewind(g_hConfig);
	if (!KvJumpToKey(g_hConfig, sProfile)) 
	{
		ReplyToCommand(client, "That boss does not exist!");
		return Plugin_Handled;
	}
	
	new iBossIndex = AddProfile(sProfile, SFF_FAKE);
	if (iBossIndex != -1)
	{
		decl Float:eyePos[3], Float:eyeAng[3], Float:flPos[3];
		GetClientEyePosition(client, eyePos);
		GetClientEyeAngles(client, eyeAng);
		
		new Handle:hTrace = TR_TraceRayFilterEx(eyePos, eyeAng, MASK_NPCSOLID, RayType_Infinite, TraceRayDontHitEntity, client);
		TR_GetEndPosition(flPos, hTrace);
		CloseHandle(hTrace);
	
		SpawnSlender(iBossIndex, flPos);
		
		LogAction(client, -1, "%N added a fake boss! (%s)", client, sProfile);
	}
	
	return Plugin_Handled;
}

public Action:Command_ForceState(client, args)
{
	if (!g_bEnabled) return Plugin_Continue;

	if (args < 2)
	{
		ReplyToCommand(client, "Usage: sm_sf2_setplaystate <name|#userid> <0/1>");
		return Plugin_Handled;
	}
	
	if (g_bRoundEnded || g_bRoundWarmup)
	{
		CPrintToChat(client, "%t%T", "SF2 Prefix", "SF2 Cannot Use Command", client);
		return Plugin_Handled;
	}
	
	decl String:arg1[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	
	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			0,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	decl String:arg2[32];
	GetCmdArg(2, arg2, sizeof(arg2));
	
	new iState = StringToInt(arg2);
	
	decl String:sName[MAX_NAME_LENGTH];
	
	for (new i = 0; i < target_count; i++)
	{
		new target = target_list[i];
		GetClientName(target, sName, sizeof(sName));
		
		if (iState && g_bPlayerEliminated[target])
		{
			ClientForcePlay(target);
			
			CPrintToChatAll("%t %N: %t", "SF2 Prefix", client, "SF2 Player Forced In Game", sName);
			LogAction(client, target, "%N forced %N into the game.", client, target);
		}
		else if (!iState && !g_bPlayerEliminated[target])
		{
			ClientForceOutOfPlay(target);
			
			CPrintToChatAll("%t %N: %t", "SF2 Prefix", client, "SF2 Player Forced Out Of Game", sName);
			LogAction(client, target, "%N took %N out of the game.", client, target);
		}
	}
	
	return Plugin_Handled;
}

public Action:Hook_CommandBuild(client, const String:command[], argc)
{
	if (!g_bEnabled) return Plugin_Continue;
	if (!IsClientInPvP(client)) return Plugin_Handled;
	
	return Plugin_Continue;
}

public Action:Timer_BossCountUpdate(Handle:timer)
{
	new iBossCount = SlenderGetCount();
	new iBossPreferredCount;
	
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		if (!g_strSlenderProfile[i][0] ||
			g_iSlenderCopyMaster[i] != -1 ||
			(g_iSlenderFlags[i] & SFF_FAKE))
		{
			continue;
		}
		
		iBossPreferredCount++;
	}
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) ||
		!IsPlayerAlive(i) ||
		g_bPlayerEliminated[i] ||
		g_bPlayerGhostMode[i] ||
		g_bPlayerDeathCam[i] ||
		g_bPlayerEscaped[i]) continue;
		
		// Check if we're near any bosses.
		new iClosest = -1;
		new Float:flBestDist = SF2_BOSS_PAGE_CALCULATION;
		
		for (new iBoss = 0; iBoss < MAX_BOSSES; iBoss++)
		{
			if (!g_strSlenderProfile[iBoss][0]) continue;
			if (SlenderArrayIndexToEntIndex(iBoss) == INVALID_ENT_REFERENCE) continue;
			if (g_iSlenderFlags[iBoss] & SFF_FAKE) continue;
			
			new Float:flDist = SlenderGetDistanceFromPlayer(iBoss, i);
			if (flDist < flBestDist)
			{
				iClosest = iBoss;
				flBestDist = flDist;
				break;
			}
		}
		
		if (iClosest != -1) continue;
		
		iClosest = -1;
		flBestDist = SF2_BOSS_PAGE_CALCULATION;
		
		for (new iClient = 1; iClient <= MaxClients; iClient++)
		{
			if (!IsValidClient(iClient) ||
			!IsPlayerAlive(iClient) ||
			g_bPlayerEliminated[iClient] ||
			g_bPlayerGhostMode[iClient] ||
			g_bPlayerDeathCam[iClient] ||
			g_bPlayerEscaped[iClient]) continue;
			
			new bool:bwub = false;
			for (new iBoss = 0; iBoss < MAX_BOSSES; iBoss++)
			{
				if (!g_strSlenderProfile[iBoss][0]) continue;
				if (g_iSlenderFlags[iBoss] & SFF_FAKE) continue;
				
				if (g_iSlenderTarget[iBoss] == iClient)
				{
					bwub = true;
					break;
				}
			}
			
			if (!bwub) continue;
			
			new Float:flDist = EntityDistanceFromEntity(i, iClient);
			if (flDist < flBestDist)
			{
				iClosest = iClient;
				flBestDist = flDist;
			}
		}
		
		if (!IsValidClient(iClosest))
		{
			// No one's close to this dude? DUDE! WE NEED ANOTHER BOSS!
			iBossPreferredCount++;
		}
	}
	
	new iDiff = iBossCount - iBossPreferredCount;
	if (iDiff)
	{	
		if (iDiff > 0)
		{
			new iCount = iDiff;
			// We need less bosses. Try and see if we can remove some.
			for (new i = 0; i < MAX_BOSSES; i++)
			{
				if (g_iSlenderCopyMaster[i] == -1) continue;
				if (PeopleCanSeeSlender(i, _, false)) continue;
				if (g_iSlenderFlags[i] & SFF_FAKE) continue;
				
				if (SlenderCanRemove(i))
				{
					RemoveSlender(i);
					RemoveProfile(i);
					iCount--;
				}
				
				if (iCount <= 0)
				{
					break;
				}
			}
		}
		else
		{
			new iCount = RoundToFloor(FloatAbs(float(iDiff)));
			// Add new bosses (copy of the first boss).
			for (new i = 0; i < MAX_BOSSES && iCount > 0; i++)
			{
				if (g_iSlenderID[i] == -1) continue;
				if (g_iSlenderCopyMaster[i] != -1) continue;
				if (!(g_iSlenderFlags[i] & SFF_COPIES)) continue;
				
				// Get the number of copies I already have and see if I can have more copies.
				new iCopyCount;
				for (new i2 = 0; i2 < MAX_BOSSES; i2++)
				{
					if (!g_strSlenderProfile[i2][0]) continue;
					if (g_iSlenderCopyMaster[i2] != i) continue;
					iCopyCount++;
				}
				
				if (iCopyCount >= GetProfileNum(g_strSlenderProfile[i], "copy_max", 10)) 
				{
					continue;
				}
				
				new iBossIndex = AddProfile(g_strSlenderProfile[i], _, i);
				if (iBossIndex != -1)
				{
				}
				else
				{
					LogError("Could not add copy for %d: No free slots!", i);
				}
				
				iCount--;
			}
		}
	}
	
	// Check if we can add some proxies.
	if (!g_bRoundGrace)
	{
		new Handle:hAvailableProxies = CreateArray();
		
		for (new i = 0; i < MAX_BOSSES; i++)
		{
			if (!g_strSlenderProfile[i][0]) continue;
			if (!(g_iSlenderFlags[i] & SFF_PROXIES)) continue;
			if (g_iSlenderCopyMaster[i] != -1) continue; // Copies cannot generate proxies.
			
			if (GetGameTime() < g_flSlenderTimeUntilNextProxy[i]) continue;
			
			new iMaxProxies = GetProfileNum(g_strSlenderProfile[i], "proxies_max");
			new iNumProxies;
			
			for (new iClient = 1; iClient <= MaxClients; iClient++)
			{
				if (!IsClientInGame(iClient) || !g_bPlayerEliminated[iClient]) continue;
				if (!g_bPlayerProxy[iClient]) continue;
				if (SlenderGetFromID(g_iPlayerProxyMaster[iClient]) != i) continue;
				
				iNumProxies++;
			}
			
			if (iNumProxies >= iMaxProxies) continue;
			
			new Float:flSpawnChanceMin = GetProfileFloat(g_strSlenderProfile[i], "proxies_spawn_chance_min");
			new Float:flSpawnChanceMax = GetProfileFloat(g_strSlenderProfile[i], "proxies_spawn_chance_max");
			new Float:flSpawnChanceThreshold = GetProfileFloat(g_strSlenderProfile[i], "proxies_spawn_chance_threshold") * g_flSlenderAnger[i];
			
			new Float:flChance = GetRandomFloat(flSpawnChanceMin, flSpawnChanceMax);
			if (flChance > flSpawnChanceThreshold) continue;
			
			new iAvailableProxies = iMaxProxies - iNumProxies;
			
			new iSpawnNumMin = GetProfileNum(g_strSlenderProfile[i], "proxies_spawn_num_min");
			new iSpawnNumMax = GetProfileNum(g_strSlenderProfile[i], "proxies_spawn_num_max");
			
			// Get a list of people we can TRANSFORM!!!
			ClearArray(hAvailableProxies);
			
			new iSpawnNum;
			
			for (new iClient = 1; iClient <= MaxClients; iClient++)
			{
				if (!IsClientInGame(iClient) || !g_bPlayerEliminated[iClient]) continue;
				if (g_bPlayerProxy[iClient]) continue;
				
				if (!g_bPlayerWantsTheP[iClient] || !g_bPlayerProxyAvailable[iClient] || g_bPlayerProxyAvailableInForce[iClient]) continue;
				
				if (!IsClientParticipating(iClient)) continue;
				
				PushArrayCell(hAvailableProxies, iClient);
				iSpawnNum++;
			}
			
			if (iSpawnNumMax <= iSpawnNum)
			{
				iSpawnNum = GetRandomInt(iSpawnNumMin, iSpawnNumMax);
			}
			
			if (iSpawnNum <= 0) continue;
			
			new Float:flSpawnCooldownMin = GetProfileFloat(g_strSlenderProfile[i], "proxies_spawn_cooldown_min");
			new Float:flSpawnCooldownMax = GetProfileFloat(g_strSlenderProfile[i], "proxies_spawn_cooldown_max");
			
			g_flSlenderTimeUntilNextProxy[i] = GetGameTime() + GetRandomFloat(flSpawnCooldownMin, flSpawnCooldownMax);
			
			SortADTArray(hAvailableProxies, Sort_Random, Sort_Integer);
			
			decl Float:flNewPos[3];
			for (new iNum = 0; iNum < iSpawnNum && iNum < iAvailableProxies; iNum++)
			{
				new iClient = GetArrayCell(hAvailableProxies, iNum);
				if (!SlenderCalculateNewPlace(i, flNewPos, true, true, iClient)) break;
				
				if (!GetConVarBool(g_cvPlayerProxyAsk))
				{
					ClientStartProxyForce(iClient, g_iSlenderID[i], flNewPos);
				}
				else
				{
					DisplayProxyAskMenu(iClient, g_iSlenderID[i], flNewPos);
				}
			}
		}
		
		CloseHandle(hAvailableProxies);
	}
	
	return Plugin_Continue;
}

ReloadRestrictedWeapons()
{
	if (g_hRestrictedWeaponsConfig != INVALID_HANDLE)
	{
		CloseHandle(g_hRestrictedWeaponsConfig);
		g_hRestrictedWeaponsConfig = INVALID_HANDLE;
	}
	
	decl String:buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, sizeof(buffer), FILE_RESTRICTEDWEAPONS);
	new Handle:kv = CreateKeyValues("root");
	if (!FileToKeyValues(kv, buffer))
	{
		CloseHandle(kv);
		LogError("Failed to load restricted weapons list! File not found!");
	}
	else
	{
		g_hRestrictedWeaponsConfig = kv;
		LogMessage("Loaded restricted weapons configuration file!");
	}
}

public Action:Timer_RoundMessages(Handle:timer)
{
	if (!g_bEnabled) return Plugin_Stop;

	if (timer != g_hRoundMessagesTimer) return Plugin_Stop;
	
	switch (g_iRoundMessagesNum)
	{
		case 0: CPrintToChatAll("{olive}==== {lightgreen}Slender Fortress (%s){olive} coded by {lightgreen}Kit o' Rifty{olive} ====", PLUGIN_VERSION);
		case 1: CPrintToChatAll("%t", "SF2 Ad Message 1");
		case 2: CPrintToChatAll("%t", "SF2 Ad Message 2");
	}
	
	g_iRoundMessagesNum++;
	if (g_iRoundMessagesNum > 2) g_iRoundMessagesNum = 0;
	
	return Plugin_Continue;
}

public Action:Timer_WelcomeMessage(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client <= 0) return;
	
	CPrintToChat(client, "%T", "SF2 Welcome Message", client);
}

public OnConVarChanged(Handle:cvar, const String:oldValue[], const String:newValue[])
{
	if (cvar == g_cvDifficulty)
	{
		switch (StringToInt(newValue))
		{
			case Difficulty_Easy: g_flRoundDifficultyModifier = DIFFICULTY_EASY;
			case Difficulty_Hard: g_flRoundDifficultyModifier = DIFFICULTY_HARD;
			case Difficulty_Insane: g_flRoundDifficultyModifier = DIFFICULTY_INSANE;
			default: g_flRoundDifficultyModifier = DIFFICULTY_NORMAL;
		}
	}
	else if (cvar == g_cvMaxPlayers)
	{
		for (new i = 0; i < SF2_MAX_PLAYER_GROUPS; i++)
		{
			CheckPlayerGroup(i);
		}
	}
	else if (cvar == g_cvPlayerShakeEnabled)
	{
		g_bPlayerShakeEnabled = bool:StringToInt(newValue);
	}
	else if (cvar == g_cvPlayerViewbobEnabled)
	{
		g_bPlayerViewbobEnabled = bool:StringToInt(newValue);
	}
	else if (cvar == g_cvPlayerViewbobHurtEnabled)
	{
		g_bPlayerViewbobHurtEnabled = bool:StringToInt(newValue);
	}
	else if (cvar == g_cvPlayerViewbobSprintEnabled)
	{
		g_bPlayerViewbobSprintEnabled = bool:StringToInt(newValue);
	}
	else if (cvar == g_cvGravity)
	{
		g_flGravity = StringToFloat(newValue);
	}
}

//	==========================================================
//	IN-GAME AND ENTITY HOOK FUNCTIONS
//	==========================================================

public OnEntityCreated(ent, const String:classname[])
{
	if (!g_bEnabled) return;
	
	if (!IsValidEntity(ent) || ent <= 0) return;
	
	if (StrEqual(classname, "spotlight_end", false))
	{
		SDKHook(ent, SDKHook_SpawnPost, Hook_FlashlightEndSpawnPost);
	}
	else if (StrEqual(classname, "beam", false))
	{
		SDKHook(ent, SDKHook_SetTransmit, Hook_FlashlightBeamSetTransmit);
	}
	else if (StrEqual(classname, "func_breakable", false) || StrEqual(classname, "func_breakable_surf", false))
	{
		SDKHook(ent, SDKHook_SpawnPost, Hook_BreakableSpawnPost);
	}
	else
	{
		for (new i = 0; i < sizeof(g_sPlayerProjectileClasses); i++)
		{
			if (StrEqual(classname, g_sPlayerProjectileClasses[i], false))
			{
				SDKHook(ent, SDKHook_SpawnPost, Hook_ClientProjectileSpawnPost);
				break;
			}
		}
	}
}

public OnEntityDestroyed(ent)
{
	if (!g_bEnabled) return;

	if (ent <= 0) return;
	
	if (IsValidEdict(ent))
	{
		decl String:sClassname[64];
		GetEdictClassname(ent, sClassname, sizeof(sClassname));
		if (StrEqual(sClassname, "light_dynamic", false))
		{
			AcceptEntityInput(ent, "TurnOff");
		}
	}
}

public Action:Hook_BlockUserMessage(UserMsg:msg_id, Handle:bf, const players[], playersNum, bool:reliable, bool:init) 
{
	if (!g_bEnabled) return Plugin_Continue;
	return Plugin_Handled;
}

public Action:Hook_NormalSound(clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags)
{
	if (!g_bEnabled) return Plugin_Continue;
	
	if (IsValidClient(entity))
	{
		if (g_bPlayerGhostMode[entity])
		{
			switch (channel)
			{
				case SNDCHAN_VOICE, SNDCHAN_WEAPON, SNDCHAN_ITEM, SNDCHAN_BODY: return Plugin_Handled;
			}
		}
		else if (g_bPlayerProxy[entity])
		{
			new iMaster = SlenderGetFromID(g_iPlayerProxyMaster[entity]);
			if (iMaster != -1)
			{
				switch (channel)
				{
					case SNDCHAN_VOICE:
					{
						if (!bool:GetProfileNum(g_strSlenderProfile[iMaster], "proxies_allownormalvoices", 1))
						{
							return Plugin_Handled;
						}
					}
				}
			}
		}
		else if (!g_bPlayerEliminated[entity])
		{
			switch (channel)
			{
				case SNDCHAN_VOICE:
				{
					for (new iBossIndex = 0; iBossIndex < MAX_BOSSES; iBossIndex++)
					{
						if (g_iSlenderID[iBossIndex] == -1) continue;
						
						if (SlenderCanHearPlayer(iBossIndex, entity, SoundType_Voice))
						{
							GetClientAbsOrigin(entity, g_flSlenderTargetSoundTempPos[iBossIndex]);
							g_iSlenderInterruptConditions[iBossIndex] |= COND_HEARDSUSPICIOUSSOUND;
							g_iSlenderInterruptConditions[iBossIndex] |= COND_HEARDVOICE;
						}
					}
				}
				case SNDCHAN_BODY:
				{
					if (!StrContains(sample, "player/footsteps", false) || StrContains(sample, "step", false) != -1)
					{
						if (GetConVarBool(g_cvPlayerViewbobSprintEnabled) && ClientSprintIsValid(entity))
						{
							// Viewpunch.
							new Float:flPunchVelStep[3];
							
							decl Float:flVelocity[3];
							GetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", flVelocity);
							new Float:flSpeed = GetVectorLength(flVelocity);
							
							flPunchVelStep[0] = flSpeed / 300.0;
							flPunchVelStep[1] = 0.0;
							flPunchVelStep[2] = 0.0;
							
							ClientViewPunch(entity, flPunchVelStep);
						}
						
						for (new iBossIndex = 0; iBossIndex < MAX_BOSSES; iBossIndex++)
						{
							if (g_iSlenderID[iBossIndex] == -1) continue;
							
							if (SlenderCanHearPlayer(iBossIndex, entity, SoundType_Footstep))
							{
								GetClientAbsOrigin(entity, g_flSlenderTargetSoundTempPos[iBossIndex]);
								g_iSlenderInterruptConditions[iBossIndex] |= COND_HEARDSUSPICIOUSSOUND;
								g_iSlenderInterruptConditions[iBossIndex] |= COND_HEARDFOOTSTEP;
								
								if (g_bPlayerSprint[entity] && !(GetEntProp(entity, Prop_Send, "m_bDucking") || GetEntProp(entity, Prop_Send, "m_bDucked")))
								{
									g_iSlenderInterruptConditions[iBossIndex] |= COND_HEARDFOOTSTEPLOUD;
								}
							}
						}
					}
				}
				case SNDCHAN_ITEM, SNDCHAN_WEAPON:
				{
					if (StrContains(sample, "impact", false) != -1 || StrContains(sample, "hit", false) != -1)
					{
						for (new iBossIndex = 0; iBossIndex < MAX_BOSSES; iBossIndex++)
						{
							if (g_iSlenderID[iBossIndex] == -1) continue;
							
							if (SlenderCanHearPlayer(iBossIndex, entity, SoundType_Weapon))
							{
								GetClientAbsOrigin(entity, g_flSlenderTargetSoundTempPos[iBossIndex]);
								g_iSlenderInterruptConditions[iBossIndex] |= COND_HEARDSUSPICIOUSSOUND;
								g_iSlenderInterruptConditions[iBossIndex] |= COND_HEARDWEAPON;
							}
						}
					}
				}
			}
		}
	}
	
	new bool:bModified = false;
	
	for (new i = 0; i < numClients; i++)
	{
		new iClient = clients[i];
		if (IsValidClient(iClient) && IsPlayerAlive(iClient) && !g_bPlayerGhostMode[iClient])
		{
			new bool:bCanHearSound = true;
			
			if (IsValidClient(entity) && entity != iClient)
			{
				if (!g_bPlayerEliminated[iClient])
				{
					if (g_bSpecialRound && g_iSpecialRound == SPECIALROUND_SINGLEPLAYER)
					{
						if (!g_bPlayerEliminated[entity] && !g_bPlayerEscaped[entity])
						{
							bCanHearSound = false;
						}
					}
				}
			}
			
			if (!bCanHearSound)
			{
				bModified = true;
				clients[i] = -1;
			}
		}
	}
	
	if (bModified) return Plugin_Changed;
	return Plugin_Continue;
}

public Hook_BreakableSpawnPost(breakable)
{
	if (!g_bEnabled) return;
	
	SDKUnhook(breakable, SDKHook_SpawnPost, Hook_BreakableSpawnPost);
	SDKHook(breakable, SDKHook_StartTouch, Hook_BreakableOnTouch);
	SDKHook(breakable, SDKHook_EndTouch, Hook_BreakableOnTouch);
	SDKHook(breakable, SDKHook_Touch, Hook_BreakableOnTouch);
}

public Action:Hook_BreakableOnTouch(breakable, other)
{
	if (!g_bEnabled) return Plugin_Continue;
	
	if (IsValidClient(other))
	{
		if (g_bPlayerGhostMode[other]) return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Hook_FlashlightEndSpawnPost(ent)
{
	if (!g_bEnabled) return;

	SDKHook(ent, SDKHook_SetTransmit, Hook_FlashlightEndSetTransmit);
	SDKUnhook(ent, SDKHook_SpawnPost, Hook_FlashlightEndSpawnPost);
}

public Action:Hook_FlashlightBeamSetTransmit(ent, other)
{
	if (!g_bEnabled) return Plugin_Continue;

	new iOwner = -1;
	new iSpotlight = -1;
	while ((iSpotlight = FindEntityByClassname(iSpotlight, "point_spotlight")) != -1)
	{
		if (GetEntPropEnt(ent, Prop_Data, "m_hOwnerEntity") == iSpotlight)
		{
			iOwner = iSpotlight;
			break;
		}
	}
	
	if (iOwner == -1) return Plugin_Continue;
	
	new iClient = -1;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i)) continue;
		
		if (EntRefToEntIndex(g_iPlayerFlashlightEntAng[i]) == iOwner)
		{
			iClient = i;
			break;
		}
	}
	
	if (iClient == -1) return Plugin_Continue;
	
	if (iClient == other)
	{
		if (!GetEntProp(iClient, Prop_Send, "m_nForceTauntCam") || !GetEntProp(iClient, Prop_Send, "m_iObserverMode"))
		{
			return Plugin_Handled;
		}
	}
	else
	{
		if (g_bSpecialRound && g_iSpecialRound == SPECIALROUND_SINGLEPLAYER)
		{
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

public Action:Hook_FlashlightEndSetTransmit(ent, other)
{
	if (!g_bEnabled) return Plugin_Continue;

	new iOwner = -1;
	new iSpotlight = -1;
	while ((iSpotlight = FindEntityByClassname(iSpotlight, "point_spotlight")) != -1)
	{
		if (GetEntPropEnt(ent, Prop_Data, "m_hOwnerEntity") == iSpotlight)
		{
			iOwner = iSpotlight;
			break;
		}
	}
	
	if (iOwner == -1) return Plugin_Continue;
	
	new iClient = -1;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i)) continue;
		
		if (EntRefToEntIndex(g_iPlayerFlashlightEntAng[i]) == iOwner)
		{
			iClient = i;
			break;
		}
	}
	
	if (iClient == -1) return Plugin_Continue;
	
	if (iClient == other)
	{
		if (!GetEntProp(iClient, Prop_Send, "m_nForceTauntCam") || !GetEntProp(iClient, Prop_Send, "m_iObserverMode"))
		{
			return Plugin_Handled;
		}
	}
	else
	{
		if (g_bSpecialRound && g_iSpecialRound == SPECIALROUND_SINGLEPLAYER)
		{
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

public MRESReturn:Hook_EntityShouldTransmit(this, Handle:hReturn, Handle:hParams)
{
	if (!g_bEnabled) return MRES_Ignored;
	
	if (IsValidClient(this))
	{
		if (!g_bPlayerEliminated[this])
		{
			DHookSetReturn(hReturn, FL_EDICT_ALWAYS); // Should always transmit, but our SetTransmit hook gets the final say.
			return MRES_Supercede;
		}
	}
	
	return MRES_Ignored;
}

public Hook_TriggerOnStartTouch(const String:output[], caller, activator, Float:delay)
{
	if (!g_bEnabled) return;

	if (!IsValidEntity(caller)) return;
	
	decl String:sName[64];
	GetEntPropString(caller, Prop_Data, "m_iName", sName, sizeof(sName));
	
	if (!StrContains(sName, "sf2_escape_trigger", false) ||
		!StrContains(sName, "slender_escape_trigger", false))
	{
		if (g_bRoundMustEscape && g_iPageMax > 0 && g_iPageCount == g_iPageMax)
		{
			if (IsValidClient(activator) && IsPlayerAlive(activator) && !g_bPlayerDeathCam[activator] && !g_bPlayerEliminated[activator] && !g_bPlayerEscaped[activator])
			{
				new ent = -1;
				while ((ent = FindEntityByClassname(ent, "info_target")) != -1)
				{
					GetEntPropString(ent, Prop_Data, "m_iName", sName, sizeof(sName));
					if (!StrContains(sName, "sf2_escape_spawnpoint", false) ||
						!StrContains(sName, "slender_escape_spawnpoint", false))
					{
						decl Float:flPos[3], Float:flAng[3];
						GetEntPropVector(ent, Prop_Data, "m_vecAbsOrigin", flPos);
						GetEntPropVector(ent, Prop_Data, "m_angAbsRotation", flAng);
						flAng[2] = 0.0;
						TeleportEntity(activator, flPos, flAng, Float:{ 0.0, 0.0, 0.0 });
						
						AcceptEntityInput(ent, "FireUser1", activator);
						
						ClientEscape(activator);
						break;
					}
				}
			}
		}
	}
	else if (!StrContains(sName, "sf2_pvp_trigger", false))
	{
		if (IsValidClient(activator) && IsPlayerAlive(activator))
		{
			g_bPlayerInPvPTrigger[activator] = true;
			ClientEnablePvP(activator);
		}
	}
}

public Hook_TriggerOnEndTouch(const String:sOutput[], caller, activator, Float:flDelay)
{
	if (!g_bEnabled) return;

	decl String:sName[64];
	GetEntPropString(caller, Prop_Data, "m_iName", sName, sizeof(sName));
	if (!StrContains(sName, "sf2_pvp_trigger", false))
	{
		if (IsValidClient(activator))
		{
			g_bPlayerInPvPTrigger[activator] = false;
			
			if (IsClientInPvP(activator))
			{
				g_iPlayerPvPTimerCount[activator] = GetConVarInt(g_cvPvPArenaLeaveTime);
				g_hPlayerPvPTimer[activator] = CreateTimer(1.0, Timer_ClientDisablePvP, GetClientUserId(activator), TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
			}
		}
	}
}

public Action:Hook_PageOnTakeDamage(page, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	if (!g_bEnabled) return Plugin_Continue;

	if (IsValidClient(attacker))
	{
		if (!g_bPlayerEliminated[attacker])
		{
			if (damagetype & 0x80)
			{
				SetPageCount(g_iPageCount + 1);
				g_iPlayerPageCount[attacker] += 1;
				EmitSoundToAll(PAGE_GRABSOUND, attacker, SNDCHAN_ITEM, SNDLEVEL_SCREAMING);
				
				// Gives points. Credit to the makers of VSH/FF2.
				new Handle:hEvent = CreateEvent("player_escort_score", true);
				SetEventInt(hEvent, "player", attacker);
				SetEventInt(hEvent, "points", 1);
				FireEvent(hEvent);
				
				AcceptEntityInput(page, "FireUser1");
				AcceptEntityInput(page, "Kill");
				
				//ClientAddStress(attacker, 0.1);
			}
		}
	}
	
	return Plugin_Continue;
}

//	==========================================================
//	GENERIC CLIENT HOOKS AND FUNCTIONS
//	==========================================================

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (!g_bEnabled) return Plugin_Continue;
	if (!IsValidClient(client)) return Plugin_Continue;
	
	ClientDisableFakeLagCompensation(client);
	
	// Check impulse (block spraying and built-in flashlight)
	switch (impulse)
	{
		case 100:
		{
			impulse = 0;
		}
		case 201:
		{
			if (g_bPlayerGhostMode[client])
			{
				impulse = 0;
			}
		}
	}
	
	for (new i = 0; i < MAX_BUTTONS; i++)
	{
		new button = (1 << i);
		
		if ((buttons & button))
		{
			if (!(g_iPlayerLastButtons[client] & button))
			{
				ClientOnButtonPress(client, button);
			}
		}
		/*
		else if ((g_iPlayerLastButtons[client] & button))
		{
			ClientOnButtonRelease(client, button);
		}
		*/
	}
	
	g_iPlayerLastButtons[client] = buttons;
	
	return Plugin_Continue;
}

public OnClientCookiesCached(client)
{
	if (!g_bEnabled) return;
	
	// Load our saved settings.
	new String:sCookie[64];
	GetClientCookie(client, g_hCookie, sCookie, sizeof(sCookie));
	
	if (!sCookie[0])
	{
		g_iPlayerQueuePoints[client] = 0;
		g_bPlayerShowHints[client] = true;
		g_iPlayerMuteMode[client] = MuteMode_Normal;
		//g_bPlayerFlashlightProjected[client] = false;
		g_bPlayerWantsTheP[client] = true;
	}
	else
	{
		new String:s2[12][32];
		ExplodeString(sCookie, " ; ", s2, 12, 32);
		
		g_iPlayerQueuePoints[client] = StringToInt(s2[0]);
		g_bPlayerShowHints[client] = bool:StringToInt(s2[1]);
		g_iPlayerMuteMode[client] = MuteMode:StringToInt(s2[2]);
		//g_bPlayerFlashlightProjected[client] = bool:StringToInt(s2[3]);
		g_bPlayerWantsTheP[client] = bool:StringToInt(s2[4]);
	}
}

public OnClientPutInServer(client)
{
	if (!g_bEnabled) return;

#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("START OnClientPutInServer(%d)", client);
#endif
	
	InitializeClient(client);
	ClientSetPlayerGroup(client, -1);
	ClientResetDeathCam(client);
	
	g_bPlayerEscaped[client] = false;
	g_bPlayerEliminated[client] = true;
	g_bPlayerChoseTeam[client] = false;
	g_bPlayerDidSpecialRound[client] = true;
	g_bPlayerDidBossRound[client] = true;
	g_bPlayerInPvPSpawning[client] = false;
	g_bPlayerFlashlightProjected[client] = false;
	g_iPlayerDebugFlags[client] = 0;
	
	SDKHook(client, SDKHook_PreThink, Hook_ClientPreThink);
	SDKHook(client, SDKHook_SetTransmit, Hook_ClientSetTransmit);
	SDKHook(client, SDKHook_OnTakeDamage, Hook_ClientOnTakeDamage);
	
	DHookEntity(g_hSDKWantsLagCompensationOnEntity, true, client); 
	DHookEntity(g_hSDKShouldTransmit, true, client);
	
	for (new i = 0; i < SF2_MAX_PLAYER_GROUPS; i++)
	{
		if (!IsPlayerGroupActive(i)) continue;
		
		SetPlayerGroupInvitedPlayer(i, client, false);
		SetPlayerGroupInvitedPlayerCount(i, client, 0);
		SetPlayerGroupInvitedPlayerTime(i, client, 0.0);
	}
	
	ClientStartProxyAvailableTimer(client);
	
	if (!IsFakeClient(client))
	{
		// See if the player is using the custom flashlight.
		QueryClientConVar(client, "mat_supportflashlight", QueryClientFlashlight);
	}
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("END OnClientPutInServer(%d)", client);
#endif
}

public QueryClientFlashlight(QueryCookie:cookie, client, ConVarQueryResult:result, const String:cvarName[], const String:cvarValue[])
{
	if (result != ConVarQuery_Okay) 
	{
		LogError("Warning: Player %N failed to query for ConVar mat_supportflashlight", client);
		return;
	}
	
	if (StringToInt(cvarValue))
	{
		g_bPlayerFlashlightProjected[client] = true;
		LogMessage("Player %N has mat_supportflashlight enabled, using client-side flashlight!", client);
	}
}

public OnClientDisconnect(client)
{
	if (!g_bEnabled) return;
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("START OnClientDisconnect(%d)", client);
#endif
	
	// Save and reset settings for the next client.
	ClientSaveCookies(client);
	ClientSetPlayerGroup(client, -1);
	g_iPlayerQueuePoints[client] = 0;
	g_bPlayerShowHints[client] = true;
	g_bPlayerWantsTheP[client] = true;
	
	ClientResetPvP(client);
	ClientResetFlashlight(client);
	ClientDeactivateUltravision(client);
	ClientDisableGhostMode(client);
	ClientResetGlow(client);
	ClientStopProxyForce(client);
	
	if (!g_bRoundWarmup)
	{
		if (g_bRoundGrace)
		{
			if (g_bPlayerPlaying[client] && !g_bPlayerEliminated[client])
			{
				ForceInNextPlayersInQueue(1, true);
			}
		}
		else
		{
			if (!g_bRoundEnded) CreateTimer(0.2, Timer_CheckRoundState, _, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	
	g_bPlayerEscaped[client] = false;
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("END OnClientDisconnect(%d)", client);
#endif
}

public OnClientDisconnect_Post(client)
{
    g_iPlayerLastButtons[client] = 0;
}

public Action:TF2Footprints_ShouldAppear(client, &bool:bAppear)
{
	if (!g_bEnabled) return Plugin_Continue;

	if (g_bPlayerGhostMode[client])
	{
		bAppear = false;
		return Plugin_Changed;
	}
	else if (!g_bPlayerEliminated[client])
	{
		if (g_bSpecialRound && g_iSpecialRound == SPECIALROUND_SINGLEPLAYER)
		{
			bAppear = false;
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}

public TF2_OnWaitingForPlayersStart()
{
	g_bRoundWaitingForPlayers = true;
}

public TF2_OnWaitingForPlayersEnd()
{
	g_bRoundWaitingForPlayers = false;
}

#define SF2_PLAYER_HUD_BLINK_SYMBOL "B"
#define SF2_PLAYER_HUD_FLASHLIGHT_SYMBOL "ϟ"
#define SF2_PLAYER_HUD_BAR_SYMBOL "|"
#define SF2_PLAYER_HUD_BAR_MISSING_SYMBOL ""
#define SF2_PLAYER_HUD_INFINITY_SYMBOL "∞"
#define SF2_PLAYER_HUD_SPRINT_SYMBOL "»"

public Action:Timer_HUDUpdate(Handle:timer)
{
	if (!g_bEnabled) return Plugin_Continue;
	if (g_bRoundWarmup || g_bRoundEnded) return Plugin_Continue;
	
	decl String:buffer[256];
	
	static iHudColorHealthy[3] = { 150, 255, 150 };
	static iHudColorCritical[3] = { 255, 10, 10 };
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i)) continue;
		
		if (IsPlayerAlive(i) && !g_bPlayerDeathCam[i])
		{
			if (!g_bPlayerEliminated[i])
			{
				if (g_bPlayerEscaped[i]) continue;
				
				new iMaxBars = 12;
				new iBars = RoundToCeil(float(iMaxBars) * g_flPlayerBlinkMeter[i]);
				if (iBars > iMaxBars) iBars = iMaxBars;
				
				Format(buffer, sizeof(buffer), "%s  ", SF2_PLAYER_HUD_BLINK_SYMBOL);
				
				if (g_bRoundInfiniteBlink)
				{
					StrCat(buffer, sizeof(buffer), SF2_PLAYER_HUD_INFINITY_SYMBOL);
				}
				else
				{
					for (new i2 = 0; i2 < iMaxBars; i2++) 
					{
						if (i2 < iBars)
						{
							StrCat(buffer, sizeof(buffer), SF2_PLAYER_HUD_BAR_SYMBOL);
						}
						else
						{
							StrCat(buffer, sizeof(buffer), SF2_PLAYER_HUD_BAR_MISSING_SYMBOL);
						}
					}
				}
				
				if (!g_bSpecialRound || g_iSpecialRound != SPECIALROUND_LIGHTSOUT)
				{
					iBars = RoundToCeil(float(iMaxBars) * g_flPlayerFlashlightMeter[i]);
					if (iBars > iMaxBars) iBars = iMaxBars;
					
					decl String:sBuffer2[64];
					Format(sBuffer2, sizeof(sBuffer2), "\n%s  ", SF2_PLAYER_HUD_FLASHLIGHT_SYMBOL);
					StrCat(buffer, sizeof(buffer), sBuffer2);
					
					if (g_bRoundInfiniteFlashlight)
					{
						StrCat(buffer, sizeof(buffer), SF2_PLAYER_HUD_INFINITY_SYMBOL);
					}
					else
					{
						for (new i2 = 0; i2 < iMaxBars; i2++) 
						{
							if (i2 < iBars)
							{
								StrCat(buffer, sizeof(buffer), SF2_PLAYER_HUD_BAR_SYMBOL);
							}
							else
							{
								StrCat(buffer, sizeof(buffer), SF2_PLAYER_HUD_BAR_MISSING_SYMBOL);
							}
						}
					}
				}
				
				iBars = RoundToCeil(float(iMaxBars) * (float(g_iPlayerSprintPoints[i]) / 100.0));
				if (iBars > iMaxBars) iBars = iMaxBars;
				
				decl String:sBuffer2[64];
				Format(sBuffer2, sizeof(sBuffer2), "\n%s  ", SF2_PLAYER_HUD_SPRINT_SYMBOL);
				StrCat(buffer, sizeof(buffer), sBuffer2);
				
				for (new i2 = 0; i2 < iMaxBars; i2++) 
				{
					if (i2 < iBars)
					{
						StrCat(buffer, sizeof(buffer), SF2_PLAYER_HUD_BAR_SYMBOL);
					}
					else
					{
						StrCat(buffer, sizeof(buffer), SF2_PLAYER_HUD_BAR_MISSING_SYMBOL);
					}
				}
				
				
				new Float:flHealthRatio = float(GetEntProp(i, Prop_Send, "m_iHealth")) / float(SDKCall(g_hSDKGetMaxHealth, i));
				
				new iColor[3];
				for (new i2 = 0; i2 < 3; i2++)
				{
					iColor[i2] = RoundFloat(float(iHudColorHealthy[i2]) + (float(iHudColorCritical[i2] - iHudColorHealthy[i2]) * (1.0 - flHealthRatio)));
				}
				
				SetHudTextParams(0.035, 0.83,
					0.3,
					iColor[0],
					iColor[1],
					iColor[2],
					40,
					_,
					1.0,
					0.07,
					0.5);
				ShowSyncHudText(i, g_hHudSync2, buffer);
			}
			else
			{
				if (g_bPlayerProxy[i])
				{
					new iMaxBars = 12;
					new iBars = RoundToCeil(float(iMaxBars) * (float(g_iPlayerProxyControl[i]) / 100.0));
					if (iBars > iMaxBars) iBars = iMaxBars;
					
					strcopy(buffer, sizeof(buffer), "CONTROL\n");
					
					for (new i2 = 0; i2 < iBars; i2++)
					{
						StrCat(buffer, sizeof(buffer), SF2_PLAYER_HUD_BAR_SYMBOL);
					}
					
					SetHudTextParams(-1.0, 0.83,
						0.3,
						SF2_HUD_TEXT_COLOR_R,
						SF2_HUD_TEXT_COLOR_G,
						SF2_HUD_TEXT_COLOR_B,
						40,
						_,
						1.0,
						0.07,
						0.5);
					ShowSyncHudText(i, g_hHudSync2, buffer);
				}
			}
		}
		
		ClientUpdateListeningFlags(i);
	}
	
	return Plugin_Continue;
}

stock bool:IsClientParticipating(client)
{
	if (!IsValidClient(client)) return false;
	
	new iTeam = GetClientTeam(client);
	
	// Not taking any chances!
	if (g_bPlayerLagCompensation[client]) iTeam = g_iPlayerLagCompensationTeam[client];
	
	switch (iTeam)
	{
		case TFTeam_Unassigned, TFTeam_Spectator: return false;
	}
	
	return true;
}

Handle:GetQueueList()
{
	new Handle:hArray = CreateArray(3);
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientParticipating(i)) continue;
		if (IsPlayerGroupActive(ClientGetPlayerGroup(i))) continue;
		
		new index = PushArrayCell(hArray, i);
		SetArrayCell(hArray, index, g_iPlayerQueuePoints[i], 1);
		SetArrayCell(hArray, index, false, 2);
	}
	
	for (new i = 0; i < SF2_MAX_PLAYER_GROUPS; i++)
	{
		if (!IsPlayerGroupActive(i)) continue;
		new index = PushArrayCell(hArray, i);
		SetArrayCell(hArray, index, GetPlayerGroupQueuePoints(i), 1);
		SetArrayCell(hArray, index, true, 2);
	}
	
	if (GetArraySize(hArray)) SortADTArrayCustom(hArray, SortQueueList);
	return hArray;
}

stock ClientForcePlay(client, bool:bEnablePlay=true)
{
	if (!g_bPlayerEliminated[client]) return;
	
	if (bEnablePlay) g_bPlayerPlaying[client] = true;
	g_bPlayerEliminated[client] = false;
	g_hPlayerSwitchBlueTimer[client] = INVALID_HANDLE;
	ClientDisableGhostMode(client);
	ClientDisablePvP(client);
	
	if (g_bSpecialRound) g_bPlayerDidSpecialRound[client] = true;
	if (g_bBossRound) g_bPlayerDidBossRound[client] = true;
	
	ChangeClientTeamNoSuicide(client, _:TFTeam_Red);
}

stock ClientForceOutOfPlay(client, bool:bDisablePlay=true)
{
	if (g_bPlayerEliminated[client]) return;
	
	if (bDisablePlay) g_bPlayerPlaying[client] = false;
	g_bPlayerEliminated[client] = true;
	ChangeClientTeamNoSuicide(client, _:TFTeam_Blue);
}

stock ForceInNextPlayersInQueue(iAmount, bool:bShowMessage=false)
{
	// Grab the next person in line, or the next group in line if space allows.
	new iAmountLeft = iAmount;
	new Handle:hPlayers = CreateArray();
	new Handle:hArray = GetQueueList();
	
	for (new i = 0, iSize = GetArraySize(hArray); i < iSize && iAmountLeft > 0; i++)
	{
		if (!GetArrayCell(hArray, i, 2))
		{
			new iClient = GetArrayCell(hArray, i);
			if (g_bPlayerPlaying[iClient] || !g_bPlayerEliminated[iClient]) continue;
			
			PushArrayCell(hPlayers, iClient);
			iAmountLeft--;
		}
		else
		{
			new iGroupIndex = GetArrayCell(hArray, i);
			if (!IsPlayerGroupActive(iGroupIndex)) continue;
			
			new iMemberCount = GetPlayerGroupMemberCount(iGroupIndex);
			if (iMemberCount <= iAmountLeft)
			{
				for (new iClient = 1; iClient <= MaxClients; iClient++)
				{
					if (!IsValidClient(iClient)) continue;
					if (ClientGetPlayerGroup(iClient) == iGroupIndex)
					{
						PushArrayCell(hPlayers, iClient);
					}
				}
				
				SetPlayerGroupPlaying(iGroupIndex, true);
				
				iAmountLeft -= iMemberCount;
			}
		}
	}
	
	CloseHandle(hArray);
	
	for (new i = 0, iSize = GetArraySize(hPlayers); i < iSize; i++)
	{
		new iClient = GetArrayCell(hPlayers, i);
		ClientForcePlay(iClient);
		
		if (bShowMessage) CPrintToChat(iClient, "%T", "SF2 Force Play", iClient);
	}
	
	CloseHandle(hPlayers);
}

public SortQueueList(index1, index2, Handle:array, Handle:hndl)
{
	new iQueuePoints1 = GetArrayCell(array, index1, 1);
	new iQueuePoints2 = GetArrayCell(array, index2, 1);
	
	if (iQueuePoints1 > iQueuePoints2) return -1;
	else if (iQueuePoints1 == iQueuePoints2) return 0;
	return 1;
}

//	==========================================================
//	GENERIC PAGE/BOSS HOOKS AND FUNCTIONS
//	==========================================================

public Action:Hook_SlenderOnTakeDamage(slender, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	if (!g_bEnabled) return Plugin_Continue;

	new iBossIndex = SlenderEntIndexToArrayIndex(slender);
	if (iBossIndex == -1) return Plugin_Continue;
	
	if (g_iSlenderType[iBossIndex] == 2)
	{
		if (GetProfileNum(g_strSlenderProfile[iBossIndex], "stun_enabled"))
		{
			if (damagetype & DMG_ACID) damage *= 2.0; // Critical hits can help ALOT.
			
			g_iSlenderHealthUntilStun[iBossIndex] -= RoundToFloor(damage);
		}
	}
	
	damage = 0.0;
	return Plugin_Changed;
}

public Hook_SlenderOnTakeDamagePost(slender, attacker, inflictor, Float:damage, damagetype, weapon, const Float:damageForce[3], const Float:damagePosition[3])
{
	if (!g_bEnabled) return;

	new iBossIndex = SlenderEntIndexToArrayIndex(slender);
	if (iBossIndex == -1) return;
	
	if (g_iSlenderType[iBossIndex] == 2)
	{
		if (damagetype & DMG_ACID)
		{
			decl Float:flMyEyePos[3];
			SlenderGetEyePosition(iBossIndex, flMyEyePos);
			
			TE_SetupTFParticleEffect(g_iParticleCriticalHit, flMyEyePos, flMyEyePos);
			TE_SendToAll();
			
			EmitSoundToAll(CRIT_SOUND, slender, SNDCHAN_AUTO, SNDLEVEL_SCREAMING);
		}
	}
}

public Action:Hook_SlenderSetTransmit(slender, other)
{
	if (!g_bEnabled) return Plugin_Continue;

	new iBossIndex = SlenderEntIndexToArrayIndex(slender);
	if (iBossIndex == -1) return Plugin_Continue;
	
	if (g_iSlenderType[iBossIndex] != 1)
	{
		decl Float:myPos[3], Float:hisPos[3];
		SlenderGetAbsOrigin(iBossIndex, myPos);
		AddVectors(myPos, g_flSlenderEyePosOffset[iBossIndex], myPos);
		
		new iBestPlayer = -1;
		new Float:flBestDistance = 16384.0;
		new Float:flTempDistance;
		
		for (new i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || !IsPlayerAlive(i) || g_bPlayerGhostMode[i] || g_bPlayerDeathCam[i]) continue;
			if (!IsPointVisibleToPlayer(i, myPos, false, false)) continue;
			
			GetClientAbsOrigin(i, hisPos);
			
			flTempDistance = GetVectorDistance(myPos, hisPos);
			if (flTempDistance < flBestDistance)
			{
				iBestPlayer = i;
				flBestDistance = flTempDistance;
			}
		}
		
		if (iBestPlayer > 0)
		{
			SlenderGetAbsOrigin(iBossIndex, myPos);
			GetClientAbsOrigin(iBestPlayer, hisPos);
			
			if (!SlenderOnlyLooksIfNotSeen(iBossIndex) || !IsPointVisibleToAPlayer(myPos, false, SlenderUsesBlink(iBossIndex)))
			{
				if (g_flSlenderTurnRate[iBossIndex] > 0.0)
				{
					decl Float:flMyEyeAng[3], Float:ang[3], Float:flAngOffset[3];
					GetEntPropVector(slender, Prop_Data, "m_angAbsRotation", flMyEyeAng);
					GetProfileVector(g_strSlenderProfile[iBossIndex], "eye_ang_offset", flAngOffset);
					SubtractVectors(flMyEyeAng, flAngOffset, flMyEyeAng);
					SubtractVectors(hisPos, myPos, ang);
					GetVectorAngles(ang, ang);
					ang[0] = 0.0;
					ang[1] = ApproachAngle(ang[1], flMyEyeAng[1], g_flSlenderTurnRate[iBossIndex]);
					ang[2] = 0.0;
					
					// Take care of angle offsets.
					AddVectors(ang, flAngOffset, ang);
					for (new i = 0; i < 3; i++) ang[i] = AngleNormalize(ang[i]);
					
					TeleportEntity(slender, NULL_VECTOR, ang, NULL_VECTOR);
				}
			}
		}
	}
	
	if (!IsPlayerAlive(other) || g_bPlayerDeathCam[other]) return Plugin_Handled;
	return Plugin_Continue;
}

public Action:Hook_SlenderObjectSetTransmit(ent, other)
{
	if (!g_bEnabled) return Plugin_Continue;
	
	if (!IsPlayerAlive(other) || g_bPlayerDeathCam[other])
	{
		if (!IsValidEdict(GetEntPropEnt(other, Prop_Send, "m_hObserverTarget"))) return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

//	So this is how the thought process of the bosses should go.
//	1. Search for enemy; either by sight or by sound.
//		- Any noticeable sounds should be investigated.
//		- Too many sounds will put me in alert mode.
//	2. Alert of an enemy; I saw something or I heard something unusual
//		- Go to the position where I last heard the sound.
//		- Keep on searching until I give up. Then drop back to idle mode.
//	3. Found an enemy! Give chase!
//		- Keep on chasing until enemy is killed or I give up.
//			- Keep a path in memory as long as I still have him in my sights.
//			- If I lose sight or I'm unable to traverse safely, find paths around obstacles and follow memorized path.
//			- If I reach the end of my path and I still don't see him and I still want to pursue him, keep on going in the direction I'm going.

stock bool:IsTargetValidForSlender(iTarget, bool:bIncludeEliminated=false)
{
	if (!iTarget || !IsValidEntity(iTarget)) return false;
	
	if (IsValidClient(iTarget))
	{
		if (!IsClientInGame(iTarget) || 
			!IsPlayerAlive(iTarget) || 
			g_bPlayerDeathCam[iTarget] || 
			(!bIncludeEliminated && g_bPlayerEliminated[iTarget]) ||
			g_bPlayerGhostMode[iTarget] || 
			g_bPlayerEscaped[iTarget]) return false;
	}
	
	return true;
}

public Action:Timer_SlenderChaseBossThink(Handle:timer, any:entref)
{
	if (!g_bEnabled) return Plugin_Stop;

	new slender = EntRefToEntIndex(entref);
	if (!slender || slender == INVALID_ENT_REFERENCE) return Plugin_Stop;
	
	new iBossIndex = SlenderEntIndexToArrayIndex(slender);
	if (iBossIndex == -1) return Plugin_Stop;
	
	if (timer != g_hSlenderEntityThink[iBossIndex]) return Plugin_Stop;
	
	if (g_iSlenderFlags[iBossIndex] & SFF_MARKEDASFAKE) return Plugin_Stop;
	
	decl Float:flSlenderVelocity[3], Float:flMyPos[3], Float:flMyEyeAng[3];
	new Float:flBuffer[3];
	
	decl String:sSlenderProfile[SF2_MAX_PROFILE_NAME_LENGTH];
	strcopy(sSlenderProfile, sizeof(sSlenderProfile), g_strSlenderProfile[iBossIndex]);
	
	GetEntPropVector(slender, Prop_Data, "m_vecAbsVelocity", flSlenderVelocity);
	GetEntPropVector(slender, Prop_Data, "m_vecAbsOrigin", flMyPos);
	GetEntPropVector(slender, Prop_Data, "m_angAbsRotation", flMyEyeAng);
	GetProfileVector(sSlenderProfile, "eye_ang_offset", flBuffer, Float:{ 0.0, 0.0, 0.0 });
	AddVectors(flMyEyeAng, flBuffer, flMyEyeAng);
	for (new i = 0; i < 3; i++) flMyEyeAng[i] = AngleNormalize(flMyEyeAng[i]);
	
	new Float:flVelocityRatio;
	new Float:flVelocityRatioWalk;
	new Float:flOriginalSpeed = g_flSlenderSpeed[iBossIndex];
	new Float:flOriginalWalkSpeed = g_flSlenderWalkSpeed[iBossIndex];
	new Float:flMaxSpeed = GetProfileFloat(sSlenderProfile, "speed_max");
	new Float:flMaxWalkSpeed = GetProfileFloat(sSlenderProfile, "walkspeed_max");
	
	new Float:flSpeed = flOriginalSpeed * g_flSlenderAnger[iBossIndex] * g_flRoundDifficultyModifier;
	if (flSpeed < flOriginalSpeed) flSpeed = flOriginalSpeed;
	if (flSpeed > flMaxSpeed) flSpeed = flMaxSpeed;
	
	new Float:flWalkSpeed = flOriginalWalkSpeed * g_flSlenderAnger[iBossIndex] * g_flRoundDifficultyModifier;
	if (flWalkSpeed < flOriginalWalkSpeed) flWalkSpeed = flOriginalWalkSpeed;
	if (flWalkSpeed > flMaxWalkSpeed) flWalkSpeed = flMaxWalkSpeed;
	
	if (PeopleCanSeeSlender(iBossIndex, _, false))
	{
		if (SlenderHasAttribute(iBossIndex, "reduced speed on look"))
		{
			flSpeed *= SlenderGetAttributeValue(iBossIndex, "reduced speed on look");
		}
		
		if (SlenderHasAttribute(iBossIndex, "reduced walk speed on look"))
		{
			flWalkSpeed *= SlenderGetAttributeValue(iBossIndex, "reduced walk speed on look");
		}
	}
	
	g_flSlenderCalculatedWalkSpeed[iBossIndex] = flWalkSpeed;
	g_flSlenderCalculatedSpeed[iBossIndex] = flSpeed;
	
	if (flOriginalSpeed <= 0.0) flVelocityRatio = 0.0;
	else flVelocityRatio = GetVectorLength(flSlenderVelocity) / flOriginalSpeed;
	
	if (flOriginalWalkSpeed <= 0.0) flVelocityRatioWalk = 0.0;
	else flVelocityRatioWalk = GetVectorLength(flSlenderVelocity) / flOriginalWalkSpeed;
	
	new iOldState = g_iSlenderState[iBossIndex];
	new iOldTarget = EntRefToEntIndex(g_iSlenderTarget[iBossIndex]);
	
	new iBestNewTarget = INVALID_ENT_REFERENCE;
	new Float:flBestNewTargetDist = g_flSlenderSearchRange[iBossIndex];
	new iState = iOldState;
	
	new bool:bPlayerInFOV[MAXPLAYERS + 1];
	new bool:bPlayerNear[MAXPLAYERS + 1];
	new Float:flPlayerDists[MAXPLAYERS + 1];
	new bool:bPlayerVisible[MAXPLAYERS + 1];
	
	new bool:bAttackEliminated = bool:(g_iSlenderFlags[iBossIndex] & SFF_ATTACKWAITERS);
	new bool:bStunEnabled = bool:GetProfileNum(sSlenderProfile, "stun_enabled");
	
	decl Float:flSlenderMins[3], Float:flSlenderMaxs[3];
	GetEntPropVector(slender, Prop_Send, "m_vecMins", flSlenderMins);
	GetEntPropVector(slender, Prop_Send, "m_vecMaxs", flSlenderMaxs);
	
	decl Float:flTraceMins[3], Float:flTraceMaxs[3];
	flTraceMins[0] = flSlenderMins[0];
	flTraceMins[1] = flSlenderMins[1];
	flTraceMins[2] = 0.0;
	flTraceMaxs[0] = flSlenderMaxs[0];
	flTraceMaxs[1] = flSlenderMaxs[1];
	flTraceMaxs[2] = 0.0;
	
	// Gather data about the players around me and get the best new target, in case my old target is invalidated.
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsTargetValidForSlender(i, bAttackEliminated)) continue;
		
		decl Float:flTraceStartPos[3], Float:flTraceEndPos[3];
		SlenderGetEyePosition(iBossIndex, flTraceStartPos);
		GetClientEyePosition(i, flTraceEndPos);
		
		new Handle:hTrace = TR_TraceHullFilterEx(flTraceStartPos,
			flTraceEndPos,
			flTraceMins,
			flTraceMaxs,
			MASK_NPCSOLID,
			TraceRayBossVisibility,
			slender);
		
		new bool:bIsVisible = !TR_DidHit(hTrace);
		new iTraceHitEntity = TR_GetEntityIndex(hTrace);
		CloseHandle(hTrace);
		
		if (!bIsVisible && iTraceHitEntity == i) bIsVisible = true;
		
		bPlayerVisible[i] = bIsVisible;
		
		// Near radius check.
		if (bIsVisible &&
			GetVectorDistance(flTraceStartPos, flTraceEndPos) <= g_flSlenderWakeRange[iBossIndex])
		{
			bPlayerNear[i] = true;
		}
		
		// FOV check.
		SubtractVectors(flTraceEndPos, flTraceStartPos, flBuffer);
		GetVectorAngles(flBuffer, flBuffer);
		
		if (FloatAbs(AngleDiff(flMyEyeAng[1], flBuffer[1])) <= (g_flSlenderFOV[iBossIndex] * 0.5))
		{
			bPlayerInFOV[i] = true;
		}
		
		new Float:flDist;
		new Float:flPriorityValue = g_iPageMax > 0 ? (float(g_iPlayerPageCount[i]) / float(g_iPageMax)) : 0.0;
		
		if (TF2_GetPlayerClass(i) == TFClass_Medic) flPriorityValue += 0.5;
		
		flDist = GetVectorDistance(flTraceStartPos, flTraceEndPos);
		flPlayerDists[i] = flDist;
		
		if ((bPlayerNear[i] && iState != STATE_CHASE && iState != STATE_ALERT) || (bIsVisible && bPlayerInFOV[i]))
		{
			decl Float:flTargetPos[3];
			GetClientAbsOrigin(i, flTargetPos);
			
			// Subtract distance to increase priority.
			flDist -= (flDist * flPriorityValue);
			
			if (flDist < flBestNewTargetDist)
			{
				iBestNewTarget = i;
				flBestNewTargetDist = flDist;
			}
			
			g_flSlenderLastFoundPlayer[iBossIndex][i] = GetGameTime();
			g_flSlenderLastFoundPlayerPos[iBossIndex][i][0] = flTargetPos[0];
			g_flSlenderLastFoundPlayerPos[iBossIndex][i][1] = flTargetPos[1];
			g_flSlenderLastFoundPlayerPos[iBossIndex][i][2] = flTargetPos[2];
		}
	}
	
	new bool:bInFlashlight = false;
	
	// Check to see if someone is facing at us with flashlight on. Only if I'm facing them too. BLINDNESS!
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsTargetValidForSlender(i, bAttackEliminated)) continue;
	
		if (!g_bPlayerFlashlight[i] || !bPlayerInFOV[i]) continue;
		
		decl Float:flTraceStartPos[3], Float:flTraceEndPos[3];
		GetClientEyePosition(i, flTraceStartPos);
		SlenderGetEyePosition(iBossIndex, flTraceEndPos);
		
		if (GetVectorDistance(flTraceStartPos, flTraceEndPos) <= SF2_FLASHLIGHT_LENGTH)
		{
			decl Float:flEyeAng[3], Float:flRequiredAng[3];
			GetClientEyeAngles(i, flEyeAng);
			SubtractVectors(flTraceEndPos, flTraceStartPos, flRequiredAng);
			GetVectorAngles(flRequiredAng, flRequiredAng);
			
			if ((FloatAbs(AngleDiff(flEyeAng[0], flRequiredAng[0])) + FloatAbs(AngleDiff(flEyeAng[1], flRequiredAng[1]))) <= 45.0)
			{
				new Handle:hTrace = TR_TraceRayFilterEx(flTraceStartPos,
					flTraceEndPos,
					MASK_PLAYERSOLID,
					RayType_EndPoint,
					TraceRayBossVisibility,
					slender);
					
				new bool:bDidHit = TR_DidHit(hTrace);
				CloseHandle(hTrace);
				
				if (!bDidHit)
				{
					bInFlashlight = true;
					break;
				}
			}
		}
	}
	
	// Damage us if we're in a flashlight.
	if (bInFlashlight)
	{
		if (bStunEnabled)
		{
			if (g_iSlenderHealthUntilStun[iBossIndex] > 0)
			{
				g_iSlenderHealthUntilStun[iBossIndex] -= GetProfileNum(sSlenderProfile, "stun_damage_flashlight");
			}
		}
	}
	
	// Process the target that we should have.
	new iTarget = iOldTarget;
	
	if (IsValidEdict(iBestNewTarget))
	{
		iTarget = iBestNewTarget;
		g_iSlenderTarget[iBossIndex] = EntIndexToEntRef(iBestNewTarget);
	}
	
	if (iTarget != INVALID_ENT_REFERENCE)
	{
		if (!IsTargetValidForSlender(iTarget, bAttackEliminated))
		{
			// Clear our target; he's not valid anymore.
			iTarget = INVALID_ENT_REFERENCE;
			g_iSlenderTarget[iBossIndex] = INVALID_ENT_REFERENCE;
		}
	}
	
	new iInterruptConditions = g_iSlenderInterruptConditions[iBossIndex];
	new bool:bQueueForNewPath = false;
	
	// Process which state we should be in.
	switch (iState)
	{
		case STATE_IDLE, STATE_WANDER:
		{
			if (iState == STATE_WANDER)
			{
				if (GetArraySize(g_hSlenderPath[iBossIndex]) <= 0)
				{
					iState = STATE_IDLE;
				}
			}
			else
			{
				if (GetGameTime() >= g_flSlenderNextWanderPos[iBossIndex] && GetRandomFloat(0.0, 1.0) <= 0.25)
				{
					iState = STATE_WANDER;
				}
			}
			
			if (IsValidClient(iTarget))
			{
				// I saw someone over here. Automatically put me into alert mode.
				iState = STATE_ALERT;
			}
			else if (iInterruptConditions & COND_HEARDSUSPICIOUSSOUND)
			{
				// Sound counts:
				// +1 will be added if it hears a footstep.
				// +2 will be added if the footstep is someone sprinting.
				// +5 will be added if the sound is from a player's weapon hitting an object.
				// +10 will be added if a voice command is heard.
				//
				// Sound counts will be reset after the boss hears a sound after a certain amount of time.
				// The purpose of sound counts is to induce boss focusing on sounds suspicious entities are making.
				
				new iCount = 0;
				if (iInterruptConditions & COND_HEARDFOOTSTEP) iCount += 1;
				if (iInterruptConditions & COND_HEARDFOOTSTEPLOUD) iCount += 2;
				if (iInterruptConditions & COND_HEARDWEAPON) iCount += 5;
				if (iInterruptConditions & COND_HEARDVOICE) iCount += 10;
				
				new bool:bDiscardMasterPos = bool:(GetGameTime() >= g_flSlenderTargetSoundDiscardMasterPosTime[iBossIndex]);
				
				if (GetVectorDistance(g_flSlenderTargetSoundTempPos[iBossIndex], g_flSlenderTargetSoundMasterPos[iBossIndex]) <= GetProfileFloat(sSlenderProfile, "search_sound_pos_dist_tolerance", 512.0) ||
					bDiscardMasterPos)
				{
					if (bDiscardMasterPos) g_iSlenderTargetSoundCount[iBossIndex] = 0;
				
					g_flSlenderTargetSoundDiscardMasterPosTime[iBossIndex] = GetGameTime() + GetProfileFloat(sSlenderProfile, "search_sound_pos_discard_time", 2.0);
					g_flSlenderTargetSoundMasterPos[iBossIndex][0] = g_flSlenderTargetSoundTempPos[iBossIndex][0];
					g_flSlenderTargetSoundMasterPos[iBossIndex][1] = g_flSlenderTargetSoundTempPos[iBossIndex][1];
					g_flSlenderTargetSoundMasterPos[iBossIndex][2] = g_flSlenderTargetSoundTempPos[iBossIndex][2];
					g_iSlenderTargetSoundCount[iBossIndex] += iCount;
				}
				
				if (g_iSlenderTargetSoundCount[iBossIndex] >= GetProfileNum(sSlenderProfile, "search_sound_count_until_alert", 4))
				{
					// Someone's making some noise over there! Time to investigate.
					g_bSlenderInvestigatingSound[iBossIndex] = true; // This is just so that our sound position would be the goal position.
					iState = STATE_ALERT;
				}
			}
		}
		case STATE_ALERT:
		{
			if (GetArraySize(g_hSlenderPath[iBossIndex]) <= 0)
			{
				// Fully navigated through our path.
				iState = STATE_IDLE;
			}
			else if (GetGameTime() >= g_flSlenderTimeUntilIdle[iBossIndex])
			{
				iState = STATE_IDLE;
			}
			else if (IsValidClient(iBestNewTarget))
			{
				if (GetGameTime() >= g_flSlenderTimeUntilChase[iBossIndex] || bPlayerNear[iBestNewTarget])
				{
					decl Float:flTraceStartPos[3], Float:flTraceEndPos[3];
					SlenderGetEyePosition(iBossIndex, flTraceStartPos);
					
					if (IsValidClient(iBestNewTarget)) GetClientEyePosition(iBestNewTarget, flTraceEndPos);
					else
					{
						decl Float:flTargetMins[3], Float:flTargetMaxs[3];
						GetEntPropVector(iBestNewTarget, Prop_Send, "m_vecMins", flTargetMins);
						GetEntPropVector(iBestNewTarget, Prop_Send, "m_vecMaxs", flTargetMaxs);
						GetEntPropVector(iBestNewTarget, Prop_Data, "m_vecAbsOrigin", flTraceEndPos);
						for (new i = 0; i < 3; i++) flTraceEndPos[i] += ((flTargetMins[i] + flTargetMaxs[i]) / 2.0);
					}
					
					new Handle:hTrace = TR_TraceHullFilterEx(flTraceStartPos,
						flTraceEndPos,
						flTraceMins,
						flTraceMaxs,
						MASK_NPCSOLID,
						TraceRayBossVisibility,
						slender);
						
					new bool:bIsVisible = !TR_DidHit(hTrace);
					new iTraceHitEntity = TR_GetEntityIndex(hTrace);
					CloseHandle(hTrace);
					
					if (!bIsVisible && iTraceHitEntity == iBestNewTarget) bIsVisible = true;
					
					if ((bPlayerNear[iBestNewTarget] || bPlayerInFOV[iBestNewTarget]) && bPlayerVisible[iBestNewTarget])
					{
						// AHAHAHAH! I GOT YOU NOW!
						iState = STATE_CHASE;
					}
				}
			}
			else
			{
				if (iInterruptConditions & COND_HEARDSUSPICIOUSSOUND)
				{
					new bool:bDiscardMasterPos = bool:(GetGameTime() >= g_flSlenderTargetSoundDiscardMasterPosTime[iBossIndex]);
					
					if (GetVectorDistance(g_flSlenderTargetSoundTempPos[iBossIndex], g_flSlenderTargetSoundMasterPos[iBossIndex]) <= GetProfileFloat(sSlenderProfile, "search_sound_pos_dist_tolerance", 512.0) ||
						bDiscardMasterPos)
					{
						g_flSlenderTargetSoundDiscardMasterPosTime[iBossIndex] = GetGameTime() + GetProfileFloat(sSlenderProfile, "search_sound_pos_discard_time", 2.0);
						g_flSlenderTargetSoundMasterPos[iBossIndex][0] = g_flSlenderTargetSoundTempPos[iBossIndex][0];
						g_flSlenderTargetSoundMasterPos[iBossIndex][1] = g_flSlenderTargetSoundTempPos[iBossIndex][1];
						g_flSlenderTargetSoundMasterPos[iBossIndex][2] = g_flSlenderTargetSoundTempPos[iBossIndex][2];
						
						// We have to manually set the goal position here because the goal position will not be changed due to no change in state.
						g_flSlenderGoalPos[iBossIndex][0] = g_flSlenderTargetSoundMasterPos[iBossIndex][0];
						g_flSlenderGoalPos[iBossIndex][1] = g_flSlenderTargetSoundMasterPos[iBossIndex][1];
						g_flSlenderGoalPos[iBossIndex][2] = g_flSlenderTargetSoundMasterPos[iBossIndex][2];
						
						g_bSlenderInvestigatingSound[iBossIndex] = true;
						
						bQueueForNewPath = true;
					}
				}
			}
		}
		case STATE_CHASE, STATE_ATTACK, STATE_STUN:
		{
			if (iState == STATE_CHASE)
			{
				if (IsValidEdict(iTarget))
				{
					decl Float:flTraceStartPos[3], Float:flTraceEndPos[3];
					SlenderGetEyePosition(iBossIndex, flTraceStartPos);
					
					if (IsValidClient(iTarget))
					{
						GetClientEyePosition(iTarget, flTraceEndPos);
					}
					else
					{
						decl Float:flTargetMins[3], Float:flTargetMaxs[3];
						GetEntPropVector(iTarget, Prop_Send, "m_vecMins", flTargetMins);
						GetEntPropVector(iTarget, Prop_Send, "m_vecMaxs", flTargetMaxs);
						GetEntPropVector(iTarget, Prop_Data, "m_vecAbsOrigin", flTraceEndPos);
						for (new i = 0; i < 3; i++) flTraceEndPos[i] += ((flTargetMins[i] + flTargetMaxs[i]) / 2.0);
					}
					
					new bool:bIsDeathPosVisible = false;
					
					if (g_bSlenderChaseDeathPosition[iBossIndex])
					{
						new Handle:hTrace = TR_TraceRayFilterEx(flTraceStartPos,
							g_flSlenderChaseDeathPosition[iBossIndex],
							MASK_NPCSOLID,
							RayType_EndPoint,
							TraceRayBossVisibility,
							slender);
						bIsDeathPosVisible = !TR_DidHit(hTrace);
						CloseHandle(hTrace);
					}
					
					if (!bPlayerVisible[iTarget])
					{
						if (GetArraySize(g_hSlenderPath[iBossIndex]) == 0)
						{
							iState = STATE_IDLE;
						}
						else if (GetGameTime() >= g_flSlenderTimeUntilAlert[iBossIndex])
						{
							iState = STATE_ALERT;
						}
						else if (bIsDeathPosVisible)
						{
							iState = STATE_IDLE;
						}
						else if (iInterruptConditions & COND_CHASETARGETINVALIDATED)
						{
							if (!g_bSlenderChaseDeathPosition[iBossIndex])
							{
								g_bSlenderChaseDeathPosition[iBossIndex] = true;
							}
						}
					}
					else
					{
						g_bSlenderChaseDeathPosition[iBossIndex] = false;	// We're not chasing a dead player after all! Reset.
					
						new Float:flAttackRange = GetProfileFloat(sSlenderProfile, "attack_range", flAttackRange);
						new Float:flAttackBeginRange = GetProfileFloat(sSlenderProfile, "attack_begin_range", flAttackRange);
						
						GetClientAbsOrigin(iTarget, g_flSlenderGoalPos[iBossIndex]);
						if (GetVectorDistance(g_flSlenderGoalPos[iBossIndex], flMyPos) <= flAttackBeginRange)
						{
							// ENOUGH TALK! HAVE AT YOU!
							iState = STATE_ATTACK;
						}
						else if (GetGameTime() >= g_flSlenderNextPathTime[iBossIndex])
						{
							g_flSlenderNextPathTime[iBossIndex] = GetGameTime() + 0.33;
							bQueueForNewPath = true;
						}
					}
				}
				else
				{
					// Even if the target isn't valid anymore, see if I still have some ways to go on my current path,
					// because I shouldn't actually know that the target has died until I see it.
					if (GetArraySize(g_hSlenderPath[iBossIndex]) == 0)
					{
						iState = STATE_IDLE;
					}
				}
			}
			else if (iState == STATE_ATTACK)
			{
				if (!g_bSlenderAttacking[iBossIndex])
				{
					if (IsValidClient(iTarget))
					{
						g_bSlenderChaseDeathPosition[iBossIndex] = false;
					
						// Chase him again!
						iState = STATE_CHASE;
					}
					else
					{
						// Target isn't valid anymore. We killed him, Mac!
						iState = STATE_IDLE;
					}
				}
			}
			else if (iState == STATE_STUN)
			{
				if (GetGameTime() >= g_flSlenderTimeUntilRecover[iBossIndex])
				{
					g_iSlenderHealthUntilStun[iBossIndex] = GetProfileNum(sSlenderProfile, "stun_health", 85);
					
					if (IsValidClient(iTarget))
					{
						// Chase him again!
						iState = STATE_CHASE;
					}
					else
					{
						// WHAT DA FUUUUUUUUUUUQ. TARGET ISN'T VALID. AUSDHASUIHD
						iState = STATE_IDLE;
					}
				}
			}
		}
	}
	
	new bool:bDoChasePersistencyInit = false;
	
	if (iState != STATE_STUN)
	{
		if (bStunEnabled)
		{
			if (g_iSlenderHealthUntilStun[iBossIndex] <= 0)
			{
				if (iState != STATE_CHASE && iState != STATE_ATTACK)
				{
					// Sometimes players can stun the boss while it's not in chase mode. If that happens, we
					// need to set the persistency value to the chase initial value.
					bDoChasePersistencyInit = true;
				}
				
				iState = STATE_STUN;
			}
		}
	}
	
	// Finally, set our new state.
	g_iSlenderState[iBossIndex] = iState;
	
	decl String:sAnimation[64];
	new iModel = EntRefToEntIndex(g_iSlenderModel[iBossIndex]);
	
	new Float:flPlaybackRateWalk = g_flSlenderWalkAnimationPlaybackRate[iBossIndex];
	new Float:flPlaybackRateRun = g_flSlenderRunAnimationPlaybackRate[iBossIndex];
	new Float:flPlaybackRateIdle = g_flSlenderIdleAnimationPlaybackRate[iBossIndex];
	
	if (iOldState != iState)
	{
		switch (iState)
		{
			case STATE_IDLE, STATE_WANDER:
			{
				g_iSlenderTarget[iBossIndex] = INVALID_ENT_REFERENCE;
				g_flSlenderTimeUntilIdle[iBossIndex] = -1.0;
				g_flSlenderTimeUntilAlert[iBossIndex] = -1.0;
				g_flSlenderTimeUntilChase[iBossIndex] = -1.0;
				g_bSlenderChaseDeathPosition[iBossIndex] = false;
				
				if (iOldState != STATE_IDLE && iOldState != STATE_WANDER)
				{
					g_iSlenderTargetSoundCount[iBossIndex] = 0;
					g_bSlenderInvestigatingSound[iBossIndex] = false;
					g_flSlenderTargetSoundDiscardMasterPosTime[iBossIndex] = -1.0;
					
					g_flSlenderTimeUntilKill[iBossIndex] = GetGameTime() + GetProfileFloat(g_strSlenderProfile[iBossIndex], "idle_lifetime", 10.0);
				}
				
				if (iState == STATE_WANDER)
				{
					// Force new wander position.
					g_flSlenderNextWanderPos[iBossIndex] = -1.0;
				}
				
				// Animation handling.
				if (iModel && iModel != INVALID_ENT_REFERENCE)
				{
					if (iState == STATE_WANDER && (g_iSlenderFlags[iBossIndex] & SFF_WANDERMOVE))
					{
						if (GetProfileString(g_strSlenderProfile[iBossIndex], "animation_walk", sAnimation, sizeof(sAnimation)))
						{
							SetAnimation(iModel, sAnimation, _, flVelocityRatio * flPlaybackRateWalk);
						}
					}
					else
					{
						if (GetProfileString(g_strSlenderProfile[iBossIndex], "animation_idle", sAnimation, sizeof(sAnimation)))
						{
							SetAnimation(iModel, sAnimation, _, flPlaybackRateIdle);
						}
					}
				}
			}
			
			case STATE_ALERT:
			{
				g_bSlenderChaseDeathPosition[iBossIndex] = false;
			
				// Set our goal position.
				if (g_bSlenderInvestigatingSound[iBossIndex])
				{
					g_flSlenderGoalPos[iBossIndex][0] = g_flSlenderTargetSoundMasterPos[iBossIndex][0];
					g_flSlenderGoalPos[iBossIndex][1] = g_flSlenderTargetSoundMasterPos[iBossIndex][1];
					g_flSlenderGoalPos[iBossIndex][2] = g_flSlenderTargetSoundMasterPos[iBossIndex][2];
				}
				else if (IsValidClient(iTarget))
				{
					g_flSlenderGoalPos[iBossIndex][0] = g_flSlenderLastFoundPlayerPos[iBossIndex][iTarget][0];
					g_flSlenderGoalPos[iBossIndex][1] = g_flSlenderLastFoundPlayerPos[iBossIndex][iTarget][1];
					g_flSlenderGoalPos[iBossIndex][2] = g_flSlenderLastFoundPlayerPos[iBossIndex][iTarget][2];
				}
				
				g_flSlenderTimeUntilIdle[iBossIndex] = GetGameTime() + GetProfileFloat(g_strSlenderProfile[iBossIndex], "search_alert_duration", 5.0);
				g_flSlenderTimeUntilAlert[iBossIndex] = -1.0;
				g_flSlenderTimeUntilChase[iBossIndex] = GetGameTime() + GetProfileFloat(g_strSlenderProfile[iBossIndex], "search_alert_gracetime", 0.5);
				
				bQueueForNewPath = true;
				
				// Animation handling.
				if (iModel && iModel != INVALID_ENT_REFERENCE)
				{
					if (GetProfileString(g_strSlenderProfile[iBossIndex], "animation_walk", sAnimation, sizeof(sAnimation)))
					{
						SetAnimation(iModel, sAnimation, _, flVelocityRatio * flPlaybackRateWalk);
					}
				}
			}
			case STATE_CHASE, STATE_ATTACK, STATE_STUN:
			{
				g_bSlenderInvestigatingSound[iBossIndex] = false;
				g_iSlenderTargetSoundCount[iBossIndex] = 0;
				
				if (iOldState != STATE_ATTACK && iOldState != STATE_CHASE && iOldState != STATE_STUN)
				{
					g_flSlenderTimeUntilIdle[iBossIndex] = -1.0;
					g_flSlenderTimeUntilAlert[iBossIndex] = GetGameTime() + GetProfileFloat(g_strSlenderProfile[iBossIndex], "search_chase_duration", 10.0);
					g_flSlenderTimeUntilChase[iBossIndex] = -1.0;
					
					new Float:flPersistencyTime = GetProfileFloat(g_strSlenderProfile[iBossIndex], "search_chase_persistency_time_init", 5.0);
					if (flPersistencyTime >= 0.0)
					{
						g_flSlenderTimeUntilNoPersistence[iBossIndex] = GetGameTime() + flPersistencyTime;
					}
				}
				
				if (iState == STATE_ATTACK)
				{
					g_bSlenderAttacking[iBossIndex] = true;
					g_hSlenderAttackTimer[iBossIndex] = CreateTimer(GetProfileFloat(g_strSlenderProfile[iBossIndex], "attack_delay"), Timer_SlenderChaseBossAttack, EntIndexToEntRef(slender), TIMER_FLAG_NO_MAPCHANGE);
					
					new Float:flPersistencyTime = GetProfileFloat(g_strSlenderProfile[iBossIndex], "search_chase_persistency_time_init_attack", -1.0);
					if (flPersistencyTime >= 0.0)
					{
						g_flSlenderTimeUntilNoPersistence[iBossIndex] = GetGameTime() + flPersistencyTime;
					}
					
					flPersistencyTime = GetProfileFloat(g_strSlenderProfile[iBossIndex], "search_chase_persistency_time_add_attack", 2.0);
					if (flPersistencyTime >= 0.0)
					{
						if (g_flSlenderTimeUntilNoPersistence[iBossIndex] < GetGameTime()) g_flSlenderTimeUntilNoPersistence[iBossIndex] = GetGameTime();
						g_flSlenderTimeUntilNoPersistence[iBossIndex] += flPersistencyTime;
					}
					
					SlenderPerformVoice(iBossIndex, "sound_attackenemy");
				}
				else if (iState == STATE_STUN)
				{
					if (g_bSlenderAttacking[iBossIndex])
					{
						// Cancel attacking.
						g_bSlenderAttacking[iBossIndex] = false;
						g_hSlenderAttackTimer[iBossIndex] = INVALID_HANDLE;
					}
					
					if (!bDoChasePersistencyInit)
					{
						new Float:flPersistencyTime = GetProfileFloat(g_strSlenderProfile[iBossIndex], "search_chase_persistency_time_init_stun", -1.0);
						if (flPersistencyTime >= 0.0)
						{
							g_flSlenderTimeUntilNoPersistence[iBossIndex] = GetGameTime() + flPersistencyTime;
						}
						
						flPersistencyTime = GetProfileFloat(g_strSlenderProfile[iBossIndex], "search_chase_persistency_time_add_stun", 2.0);
						if (flPersistencyTime >= 0.0)
						{
							if (g_flSlenderTimeUntilNoPersistence[iBossIndex] < GetGameTime()) g_flSlenderTimeUntilNoPersistence[iBossIndex] = GetGameTime();
							g_flSlenderTimeUntilNoPersistence[iBossIndex] += flPersistencyTime;
						}
					}
					else
					{
						new Float:flPersistencyTime = GetProfileFloat(g_strSlenderProfile[iBossIndex], "search_chase_persistency_time_init", 5.0);
						if (flPersistencyTime >= 0.0)
						{
							g_flSlenderTimeUntilNoPersistence[iBossIndex] = GetGameTime() + flPersistencyTime;
						}
					}
					
					g_flSlenderTimeUntilRecover[iBossIndex] = GetGameTime() + GetProfileFloat(g_strSlenderProfile[iBossIndex], "stun_duration", 1.0);
					
					// Sound handling. Ignore time check.
					SlenderPerformVoice(iBossIndex, "sound_stun");
				}
				else
				{
					if (iOldState != STATE_ATTACK)
					{
						// Sound handling.
						SlenderPerformVoice(iBossIndex, "sound_chaseenemyinitial");
					}
				}
				
				// Animation handling.
				if (iModel && iModel != INVALID_ENT_REFERENCE)
				{
					if (iState == STATE_CHASE)
					{
						if (GetProfileString(g_strSlenderProfile[iBossIndex], "animation_run", sAnimation, sizeof(sAnimation)))
						{
							SetAnimation(iModel, sAnimation, _, flVelocityRatio * flPlaybackRateRun);
						}
					}
					else if (iState == STATE_ATTACK)
					{
						if (GetProfileString(g_strSlenderProfile[iBossIndex], "animation_attack", sAnimation, sizeof(sAnimation)))
						{
							SetAnimation(iModel, sAnimation, _, GetProfileFloat(g_strSlenderProfile[iBossIndex], "animation_attack_playbackrate", 1.0));
						}
					}
					else if (iState == STATE_STUN)
					{
						if (GetProfileString(g_strSlenderProfile[iBossIndex], "animation_stun", sAnimation, sizeof(sAnimation)))
						{
							SetAnimation(iModel, sAnimation, _, GetProfileFloat(g_strSlenderProfile[iBossIndex], "animation_stun_playbackrate", 1.0));
						}
					}
				}
			}
		}
		
		// Call our forward.
		Call_StartForward(fOnBossChangeState);
		Call_PushCell(iBossIndex);
		Call_PushCell(iOldState);
		Call_PushCell(iState);
		Call_Finish();
	}
	
	switch (iState)
	{
		case STATE_IDLE:
		{
			// Animation playback speed handling.
			if (iModel && iModel != INVALID_ENT_REFERENCE)
			{
				SetVariantFloat(flPlaybackRateIdle);
				AcceptEntityInput(iModel, "SetPlaybackRate");
			}
		}
		case STATE_WANDER, STATE_ALERT, STATE_CHASE, STATE_ATTACK:
		{
			// These deal with movement, therefore we need to set our 
			// destination first. That is, if we don't have one. (nav mesh only)
			
			if (iState == STATE_WANDER)
			{
				if (GetGameTime() >= g_flSlenderNextWanderPos[iBossIndex])
				{
					new Float:flMin = GetProfileFloat(sSlenderProfile, "search_wander_time_min", 4.0);
					new Float:flMax = GetProfileFloat(sSlenderProfile, "search_wander_time_max", 6.5);
					g_flSlenderNextWanderPos[iBossIndex] = GetGameTime() + GetRandomFloat(flMin, flMax);
					
					if (g_iSlenderFlags[iBossIndex] & SFF_WANDERMOVE)
					{
						// We're allowed to move in wander mode. Get a new wandering position and create a path to follow.
						// If the position can't be reached, then just get to the closest area that we can get.
						new Float:flWanderRangeMin = GetProfileFloat(sSlenderProfile, "search_wander_range_min", 400.0);
						new Float:flWanderRangeMax = GetProfileFloat(sSlenderProfile, "search_wander_range_max", 1024.0);
						new Float:flWanderRange = GetRandomFloat(flWanderRangeMin, flWanderRangeMax);
						
						decl Float:flWanderPos[3];
						flWanderPos[0] = 0.0;
						flWanderPos[1] = GetRandomFloat(0.0, 360.0);
						flWanderPos[2] = 0.0;
						
						GetAngleVectors(flWanderPos, flWanderPos, NULL_VECTOR, NULL_VECTOR);
						NormalizeVector(flWanderPos, flWanderPos);
						ScaleVector(flWanderPos, flWanderRange);
						AddVectors(flWanderPos, flMyPos, flWanderPos);
						
						g_flSlenderGoalPos[iBossIndex][0] = flWanderPos[0];
						g_flSlenderGoalPos[iBossIndex][1] = flWanderPos[1];
						g_flSlenderGoalPos[iBossIndex][2] = flWanderPos[2];
						
						bQueueForNewPath = true;
						g_flSlenderNextPathTime[iBossIndex] = -1.0; // We're not going to wander around too much, so no need for a time constraint.
					}
				}
			}
			else if (iState == STATE_ALERT)
			{
				if (IsValidClient(iTarget))
				{
					if ((bPlayerInFOV[iTarget] || bPlayerNear[iTarget]) && bPlayerVisible[iTarget])
					{
						// Constantly update my path if I see him.
						if (GetGameTime() >= g_flSlenderNextPathTime[iBossIndex])
						{
							GetEntPropVector(iTarget, Prop_Data, "m_vecAbsOrigin", g_flSlenderGoalPos[iBossIndex]);
							bQueueForNewPath = true;
							g_flSlenderNextPathTime[iBossIndex] = GetGameTime() + 0.33;
						}
					}
				}
			}
			else if (iState == STATE_CHASE || iState == STATE_ATTACK)
			{
				if (iTarget != INVALID_ENT_REFERENCE)
				{
					if (iOldTarget != iTarget)
					{
						// Brand new target! We need a path, and we need to reset our persistency, if needed.
						new Float:flPersistencyTime = GetProfileFloat(g_strSlenderProfile[iBossIndex], "search_chase_persistency_time_init_newtarget", -1.0);
						if (flPersistencyTime >= 0.0)
						{
							g_flSlenderTimeUntilNoPersistence[iBossIndex] = GetGameTime() + flPersistencyTime;
						}
						
						flPersistencyTime = GetProfileFloat(g_strSlenderProfile[iBossIndex], "search_chase_persistency_time_add_newtarget", 2.0);
						if (flPersistencyTime >= 0.0)
						{
							if (g_flSlenderTimeUntilNoPersistence[iBossIndex] < GetGameTime()) g_flSlenderTimeUntilNoPersistence[iBossIndex] = GetGameTime();
							g_flSlenderTimeUntilNoPersistence[iBossIndex] += flPersistencyTime;
						}
					
						GetEntPropVector(iTarget, Prop_Data, "m_vecAbsOrigin", g_flSlenderGoalPos[iBossIndex]);
						bQueueForNewPath = true; // Brand new target! We need a new path!
					}
					else if ((bPlayerInFOV[iTarget] && bPlayerVisible[iTarget]) || GetGameTime() < g_flSlenderTimeUntilNoPersistence[iBossIndex])
					{
						// Constantly update my path if I see him or if I'm still being persistent.
						if (GetGameTime() >= g_flSlenderNextPathTime[iBossIndex])
						{
							GetEntPropVector(iTarget, Prop_Data, "m_vecAbsOrigin", g_flSlenderGoalPos[iBossIndex]);
							bQueueForNewPath = true;
							g_flSlenderNextPathTime[iBossIndex] = GetGameTime() + 0.33;
						}
					}
				}
			}
			
			if (NavMesh_Exists())
			{
				// So by now we should have calculated our master goal position.
				// Now we use that to create a path.
				
				if (bQueueForNewPath)
				{
					ClearArray(g_hSlenderPath[iBossIndex]);
					
					new iCurrentAreaIndex = NavMesh_GetNearestArea(flMyPos);
					if (iCurrentAreaIndex != -1)
					{
						new iGoalAreaIndex = NavMesh_GetNearestArea(g_flSlenderGoalPos[iBossIndex]);
						if (iGoalAreaIndex != -1)
						{
							decl Float:flCenter[3], Float:flCenterPortal[3], Float:flClosestPoint[3];
							new iClosestAreaIndex = 0;
							
							new bool:bPathSuccess = NavMesh_BuildPath(iCurrentAreaIndex,
								iGoalAreaIndex,
								g_flSlenderGoalPos[iBossIndex],
								SlenderChaseBossShortestPathCost,
								RoundToFloor(GetProfileFloat(g_strSlenderProfile[iBossIndex], "stepsize", 18.0)),
								iClosestAreaIndex);
								
							new iTempAreaIndex = iClosestAreaIndex;
							new iTempParentAreaIndex = NavMeshArea_GetParent(iTempAreaIndex);
							new iNavDirection;
							new Float:flHalfWidth;
							
							if (bPathSuccess)
							{
								// Path successful? Insert the goal position into our list.
								new iIndex = PushArrayCell(g_hSlenderPath[iBossIndex], g_flSlenderGoalPos[iBossIndex][0]);
								SetArrayCell(g_hSlenderPath[iBossIndex], iIndex, g_flSlenderGoalPos[iBossIndex][1], 1);
								SetArrayCell(g_hSlenderPath[iBossIndex], iIndex, g_flSlenderGoalPos[iBossIndex][2], 2);
							}
							
							while (iTempParentAreaIndex != -1)
							{
								// Build a path of waypoints along the nav mesh for our AI to follow.
								// Path order is first come, first served, so when we got our waypoint list,
								// we have to reverse it so that the starting waypoint would be in front.
								
								NavMeshArea_GetCenter(iTempParentAreaIndex, flCenter);
								iNavDirection = NavMeshArea_ComputeDirection(iTempAreaIndex, flCenter);
								NavMeshArea_ComputePortal(iTempAreaIndex, iTempParentAreaIndex, iNavDirection, flCenterPortal, flHalfWidth);
								NavMeshArea_ComputeClosestPointInPortal(iTempAreaIndex, iTempParentAreaIndex, iNavDirection, flCenterPortal, flClosestPoint);
								
								flClosestPoint[2] = NavMeshArea_GetZ(iTempAreaIndex, flClosestPoint);
								
								new iIndex = PushArrayCell(g_hSlenderPath[iBossIndex], flClosestPoint[0]);
								SetArrayCell(g_hSlenderPath[iBossIndex], iIndex, flClosestPoint[1], 1);
								SetArrayCell(g_hSlenderPath[iBossIndex], iIndex, flClosestPoint[2], 2);
								
								iTempAreaIndex = iTempParentAreaIndex;
								iTempParentAreaIndex = NavMeshArea_GetParent(iTempAreaIndex);
							}
							
							// Set our goal position to the start node (hopefully there's something in the array).
							if (GetArraySize(g_hSlenderPath[iBossIndex]) > 0)
							{
								new iPosIndex = GetArraySize(g_hSlenderPath[iBossIndex]) - 1;
								
								g_flSlenderGoalPos[iBossIndex][0] = Float:GetArrayCell(g_hSlenderPath[iBossIndex], iPosIndex, 0);
								g_flSlenderGoalPos[iBossIndex][1] = Float:GetArrayCell(g_hSlenderPath[iBossIndex], iPosIndex, 1);
								g_flSlenderGoalPos[iBossIndex][2] = Float:GetArrayCell(g_hSlenderPath[iBossIndex], iPosIndex, 2);
							}
						}
						else
						{
							PrintToServer("SF2: Failed to create new path for boss %d: destination is not on nav mesh!", iBossIndex);
						}
					}
					else
					{
						PrintToServer("SF2: Failed to create new path for boss %d: boss is not on nav mesh!", iBossIndex);
					}
				}
			}
			else
			{
				// The nav mesh doesn't exist? Well, that sucks.
				ClearArray(g_hSlenderPath[iBossIndex]);
			}
			
			if (iState == STATE_CHASE || iState == STATE_ATTACK)
			{
				if (IsValidClient(iTarget))
				{
					SendDebugMessageToPlayer(iTarget, DEBUG_BOSS_CHASE, 1, "g_flSlenderTimeUntilAlert[%d]: %f\ng_flSlenderTimeUntilNoPersistence[%d]: %f", iBossIndex, g_flSlenderTimeUntilAlert[iBossIndex] - GetGameTime(), iBossIndex, g_flSlenderTimeUntilNoPersistence[iBossIndex] - GetGameTime());
				
					if (bPlayerInFOV[iTarget] && bPlayerVisible[iTarget])
					{
						new Float:flDistRatio = flPlayerDists[iTarget] / g_flSlenderSearchRange[iBossIndex];
						
						new Float:flChaseDurationTimeAddMin = GetProfileFloat(g_strSlenderProfile[iBossIndex], "search_chase_duration_add_visible_min", 0.025);
						new Float:flChaseDurationTimeAddMax = GetProfileFloat(g_strSlenderProfile[iBossIndex], "search_chase_duration_add_visible_max", 0.2);
						
						new Float:flChaseDurationAdd = flChaseDurationTimeAddMax - ((flChaseDurationTimeAddMax - flChaseDurationTimeAddMin) * flDistRatio);
						
						if (flChaseDurationAdd > 0.0)
						{
							g_flSlenderTimeUntilAlert[iBossIndex] += flChaseDurationAdd;
							if (g_flSlenderTimeUntilAlert[iBossIndex] > (GetGameTime() + GetProfileFloat(g_strSlenderProfile[iBossIndex], "search_chase_duration")))
							{
								g_flSlenderTimeUntilAlert[iBossIndex] = GetGameTime() + GetProfileFloat(g_strSlenderProfile[iBossIndex], "search_chase_duration");
							}
						}
						
						new Float:flPersistencyTimeAddMin = GetProfileFloat(g_strSlenderProfile[iBossIndex], "search_chase_persistency_time_add_visible_min", 0.05);
						new Float:flPersistencyTimeAddMax = GetProfileFloat(g_strSlenderProfile[iBossIndex], "search_chase_persistency_time_add_visible_max", 0.15);
						
						new Float:flPersistencyTimeAdd = flPersistencyTimeAddMax - ((flPersistencyTimeAddMax - flPersistencyTimeAddMin) * flDistRatio);
						
						if (flPersistencyTimeAdd > 0.0)
						{
							if (g_flSlenderTimeUntilNoPersistence[iBossIndex] < GetGameTime()) g_flSlenderTimeUntilNoPersistence[iBossIndex] = GetGameTime();
						
							g_flSlenderTimeUntilNoPersistence[iBossIndex] += flPersistencyTimeAdd;
							if (g_flSlenderTimeUntilNoPersistence[iBossIndex] > (GetGameTime() + GetProfileFloat(g_strSlenderProfile[iBossIndex], "search_chase_duration")))
							{
								g_flSlenderTimeUntilNoPersistence[iBossIndex] = GetGameTime() + GetProfileFloat(g_strSlenderProfile[iBossIndex], "search_chase_duration");
							}
						}
					}
				}
			}
			
			// Process through our path waypoints.
			if (GetArraySize(g_hSlenderPath[iBossIndex]) > 0)
			{
				decl Float:flHitNormal[3];
				decl Float:flNodePos[3];
				
				new Float:flNodeToleranceDist = g_flSlenderPathNodeTolerance[iBossIndex];
				new bool:bGotNewPoint = false;
				
				for (new iNodeIndex = 0, iNodeCount = GetArraySize(g_hSlenderPath[iBossIndex]); iNodeIndex < iNodeCount; iNodeIndex++)
				{
					flNodePos[0] = Float:GetArrayCell(g_hSlenderPath[iBossIndex], iNodeIndex, 0);
					flNodePos[1] = Float:GetArrayCell(g_hSlenderPath[iBossIndex], iNodeIndex, 1);
					flNodePos[2] = Float:GetArrayCell(g_hSlenderPath[iBossIndex], iNodeIndex, 2);
					
					new Handle:hTrace = TR_TraceHullFilterEx(flMyPos,
						flNodePos, 
						flSlenderMins, 
						flSlenderMaxs, 
						MASK_NPCSOLID, 
						TraceRayDontHitPlayersOrEntity, 
						slender);
						
					new bool:bDidHit = TR_DidHit(hTrace);
					TR_GetPlaneNormal(hTrace, flHitNormal);
					CloseHandle(hTrace);
					GetVectorAngles(flHitNormal, flHitNormal);
					for (new i = 0; i < 3; i++) flHitNormal[i] = AngleNormalize(flHitNormal[i]);
					
					// First check if we can see the point.
					if (!bDidHit || ((flHitNormal[0] >= 0.0 && flHitNormal[0] > 45.0) || (flHitNormal[0] < 0.0 && flHitNormal[0] < -45.0)))
					{
						new bool:bNearNode = false;
						
						// See if we're already near enough.
						new Float:flDist = GetVectorDistance(flNodePos, flMyPos);
						if (flDist < flNodeToleranceDist) bNearNode = true;
						
						if (!bNearNode)
						{
							new bool:bOutside = false;
						
							// Then, predict if we're going to pass over the point on the next think.
							decl Float:flTestPos[3];
							NormalizeVector(flSlenderVelocity, flTestPos);
							ScaleVector(flTestPos, GetVectorLength(flSlenderVelocity) * BOSS_THINKRATE);
							AddVectors(flMyPos, flTestPos, flTestPos);
							
							decl Float:flP[3], Float:flS[3];
							SubtractVectors(flNodePos, flMyPos, flP);
							SubtractVectors(flTestPos, flMyPos, flS);
							
							new Float:flSP = GetVectorDotProduct(flP, flS);
							if (flSP <= 0.0) bOutside = true;
							
							new Float:flPP = GetVectorDotProduct(flS, flS);
							
							if (!bOutside)
							{
								if (flPP <= flSP) bOutside = true;
							}
							
							if (!bOutside)
							{
								decl Float:flD[3];
								ScaleVector(flS, (flSP / flPP));
								SubtractVectors(flP, flS, flD);
							
								flDist = GetVectorLength(flD);
								if (flDist < flNodeToleranceDist)
								{
									bNearNode = true;
								}
							}
						}
						
						if (bNearNode)
						{
							// Shave off this node and set our goal position to the next one.
						
							ResizeArray(g_hSlenderPath[iBossIndex], iNodeIndex);
							
							if (GetArraySize(g_hSlenderPath[iBossIndex]) > 0)
							{
								new iPosIndex = GetArraySize(g_hSlenderPath[iBossIndex]) - 1;
								
								g_flSlenderGoalPos[iBossIndex][0] = Float:GetArrayCell(g_hSlenderPath[iBossIndex], iPosIndex, 0);
								g_flSlenderGoalPos[iBossIndex][1] = Float:GetArrayCell(g_hSlenderPath[iBossIndex], iPosIndex, 1);
								g_flSlenderGoalPos[iBossIndex][2] = Float:GetArrayCell(g_hSlenderPath[iBossIndex], iPosIndex, 2);
							}
							
							bGotNewPoint = true;
							break;
						}
					}
				}
				
				if (!bGotNewPoint)
				{
					// Try to see if we can look ahead.
					
					decl Float:flMyEyePos[3];
					SlenderGetEyePosition(iBossIndex, flMyEyePos);
					
					new Float:flNodeLookAheadDist = g_flSlenderPathNodeLookAhead[iBossIndex];
					if (flNodeLookAheadDist > 0.0)
					{
						new iNodeCount = GetArraySize(g_hSlenderPath[iBossIndex]);
						if (iNodeCount)
						{
							decl Float:flInitDir[3];
							flInitDir[0] = Float:GetArrayCell(g_hSlenderPath[iBossIndex], iNodeCount - 1, 0);
							flInitDir[1] = Float:GetArrayCell(g_hSlenderPath[iBossIndex], iNodeCount - 1, 1);
							flInitDir[2] = Float:GetArrayCell(g_hSlenderPath[iBossIndex], iNodeCount - 1, 2);
							
							SubtractVectors(flInitDir, flMyPos, flInitDir);
							NormalizeVector(flInitDir, flInitDir);
							
							decl Float:flPrevDir[3];
							flPrevDir[0] = flInitDir[0];
							flPrevDir[1] = flInitDir[1];
							flPrevDir[2] = flInitDir[2];
							
							NormalizeVector(flPrevDir, flPrevDir);
							
							decl Float:flPrevNodePos[3];
							
							new iStartPointIndex = iNodeCount - 1;
							new Float:flRangeSoFar = 0.0;
							
							new iLookAheadPointIndex;
							for (iLookAheadPointIndex = iStartPointIndex; iLookAheadPointIndex >= 0; iLookAheadPointIndex--)
							{
								flNodePos[0] = Float:GetArrayCell(g_hSlenderPath[iBossIndex], iLookAheadPointIndex, 0);
								flNodePos[1] = Float:GetArrayCell(g_hSlenderPath[iBossIndex], iLookAheadPointIndex, 1);
								flNodePos[2] = Float:GetArrayCell(g_hSlenderPath[iBossIndex], iLookAheadPointIndex, 2);
							
								decl Float:flDir[3];
								if (iLookAheadPointIndex == iStartPointIndex)
								{
									SubtractVectors(flNodePos, flMyPos, flDir);
									NormalizeVector(flDir, flDir);
								}
								else
								{
									flPrevNodePos[0] = Float:GetArrayCell(g_hSlenderPath[iBossIndex], iLookAheadPointIndex + 1, 0);
									flPrevNodePos[1] = Float:GetArrayCell(g_hSlenderPath[iBossIndex], iLookAheadPointIndex + 1, 1);
									flPrevNodePos[2] = Float:GetArrayCell(g_hSlenderPath[iBossIndex], iLookAheadPointIndex + 1, 2);
								
									SubtractVectors(flNodePos, flPrevNodePos, flDir);
									NormalizeVector(flDir, flDir);
								}
								
								if (GetVectorDotProduct(flDir, flInitDir) < 0.0)
								{
									break;
								}
								
								if (GetVectorDotProduct(flDir, flPrevDir) < 0.5)
								{
									break;
								}
								
								flPrevDir[0] = flDir[0];
								flPrevDir[1] = flDir[1];
								flPrevDir[2] = flDir[2];
								
								decl Float:flProbe[3];
								flProbe[0] = flNodePos[0];
								flProbe[1] = flNodePos[1];
								flProbe[2] = flNodePos[2] + HalfHumanHeight;
								
								if (!IsWalkableTraceLineClear(flMyEyePos, flProbe, WALK_THRU_BREAKABLES))
								{
									break;
								}
								
								if (iLookAheadPointIndex == iStartPointIndex)
								{
									flRangeSoFar += GetVectorDistance(flMyPos, flNodePos);
								}
								else
								{
									flRangeSoFar += GetVectorDistance(flNodePos, flPrevNodePos);
								}
								
								if (flRangeSoFar >= flNodeLookAheadDist)
								{
									break;
								}
							}
							
							// Shave off all unnecessary nodes and keep the one that is within
							// our viewsight.
							
							ResizeArray(g_hSlenderPath[iBossIndex], iLookAheadPointIndex + 1);
							
							if (GetArraySize(g_hSlenderPath[iBossIndex]) > 0)
							{
								new iPosIndex = GetArraySize(g_hSlenderPath[iBossIndex]) - 1;
								
								g_flSlenderGoalPos[iBossIndex][0] = Float:GetArrayCell(g_hSlenderPath[iBossIndex], iPosIndex, 0);
								g_flSlenderGoalPos[iBossIndex][1] = Float:GetArrayCell(g_hSlenderPath[iBossIndex], iPosIndex, 1);
								g_flSlenderGoalPos[iBossIndex][2] = Float:GetArrayCell(g_hSlenderPath[iBossIndex], iPosIndex, 2);
							}
							
							bGotNewPoint = true;
						}
					}
				}
			}
			
			if (iState != STATE_ATTACK && iState != STATE_STUN)
			{
				// Animation playback speed handling.
				if (iModel && iModel != INVALID_ENT_REFERENCE)
				{
					if (iState == STATE_WANDER && !(g_iSlenderFlags[iBossIndex] & SFF_WANDERMOVE))
					{
						SetVariantFloat(flPlaybackRateIdle);
						AcceptEntityInput(iModel, "SetPlaybackRate");
					}
					else
					{
						SetVariantFloat(iState == STATE_CHASE ? (flVelocityRatio * flPlaybackRateRun) : (flVelocityRatioWalk * flPlaybackRateWalk));
						AcceptEntityInput(iModel, "SetPlaybackRate");
					}
				}
			}
		}
	}
	
	//SlenderChaseBossProcessMovement(iBossIndex);
	
	// Sound handling.
	if (GetGameTime() >= g_flSlenderNextVoiceSound[iBossIndex])
	{
		if (iState == STATE_IDLE || iState == STATE_WANDER)
		{
			SlenderPerformVoice(iBossIndex, "sound_idle");
		}
		else if (iState == STATE_ALERT)
		{
			SlenderPerformVoice(iBossIndex, "sound_alertofenemy");
		}
		else if (iState == STATE_CHASE || iState == STATE_ATTACK)
		{
			SlenderPerformVoice(iBossIndex, "sound_chasingenemy");
		}
	}
	
	// Reset our interrupt conditions.
	g_iSlenderInterruptConditions[iBossIndex] = 0;
	
	return Plugin_Continue;
}

SlenderChaseBossProcessMovement(iBossIndex)
{
	new iBoss = EntRefToEntIndex(g_iSlender[iBossIndex]);
	new iState = g_iSlenderState[iBossIndex];
	
	// Constantly set the monster_generic's NPC state to idle to prevent
	// velocity confliction.
	
	SetEntProp(iBoss, Prop_Data, "m_NPCState", 0);
	
	new Float:flWalkSpeed = g_flSlenderCalculatedWalkSpeed[iBossIndex];
	new Float:flSpeed = g_flSlenderCalculatedSpeed[iBossIndex];
	
	new Float:flMyPos[3], Float:flMyEyeAng[3], Float:flMyVelocity[3];
	
	decl String:sSlenderProfile[SF2_MAX_PROFILE_NAME_LENGTH];
	strcopy(sSlenderProfile, sizeof(sSlenderProfile), g_strSlenderProfile[iBossIndex]);
	
	GetEntPropVector(iBoss, Prop_Data, "m_vecAbsOrigin", flMyPos);
	GetEntPropVector(iBoss, Prop_Data, "m_angAbsRotation", flMyEyeAng);
	GetEntPropVector(iBoss, Prop_Data, "m_vecAbsVelocity", flMyVelocity);
	
	decl Float:flBossMins[3], Float:flBossMaxs[3];
	GetEntPropVector(iBoss, Prop_Send, "m_vecMins", flBossMins);
	GetEntPropVector(iBoss, Prop_Send, "m_vecMaxs", flBossMaxs);
	
	decl Float:flTraceMins[3], Float:flTraceMaxs[3];
	flTraceMins[0] = flBossMins[0];
	flTraceMins[1] = flBossMins[1];
	flTraceMins[2] = 0.0;
	flTraceMaxs[0] = flBossMaxs[0];
	flTraceMaxs[1] = flBossMaxs[1];
	flTraceMaxs[2] = 0.0;
	
	// By now we should have our preferable goal position. Initiate
	// reflex adjustments.
	
	g_bSlenderFeelerReflexAdjustment[iBossIndex] = false;
	
	{
		decl Float:flMoveDir[3];
		NormalizeVector(flMyVelocity, flMoveDir);
		flMoveDir[2] = 0.0;
		
		decl Float:flLat[3];
		flLat[0] = -flMoveDir[1];
		flLat[1] = flMoveDir[0];
		flLat[2] = 0.0;
	
		new Float:flFeelerOffset = 25.0;
		new Float:flFeelerLengthRun = 50.0;
		new Float:flFeelerLengthWalk = 30.0;
		new Float:flFeelerHeight = StepHeight + 0.1;
		
		new Float:flFeelerLength = iState == STATE_CHASE ? flFeelerLengthRun : flFeelerLengthWalk;
		
		// Get the ground height and normal.
		new Handle:hTrace = TR_TraceRayFilterEx(flMyPos, Float:{ 0.0, 0.0, 90.0 }, MASK_NPCSOLID, RayType_Infinite, TraceFilterWalkableEntities);
		decl Float:flTraceEndPos[3];
		decl Float:flTraceNormal[3];
		TR_GetEndPosition(flTraceEndPos, hTrace);
		TR_GetPlaneNormal(hTrace, flTraceNormal);
		new bool:bTraceHit = TR_DidHit(hTrace);
		CloseHandle(hTrace);
		
		if (bTraceHit)
		{
			new Float:flGroundHeight = GetVectorDistance(flMyPos, flTraceEndPos);
			GetVectorCrossProduct(flLat, flTraceNormal, flMoveDir);
			GetVectorCrossProduct(flMoveDir, flTraceNormal, flLat);
			
			decl Float:flFeet[3];
			flFeet[0] = flMyPos[0];
			flFeet[1] = flMyPos[1];
			flFeet[2] = flMyPos[2] + flFeelerHeight;
			
			decl Float:flTo[3];
			decl Float:flFrom[3];
			for (new i = 0; i < 3; i++)
			{
				flFrom[i] = flFeet[i] + (flFeelerOffset * flLat[i]);
				flTo[i] = flFrom[i] + (flFeelerLength * flMoveDir[i]);
			}
			
			new bool:bLeftClear = IsWalkableTraceLineClear(flFrom, flTo, WALK_THRU_DOORS | WALK_THRU_BREAKABLES);
			
			for (new i = 0; i < 3; i++)
			{
				flFrom[i] = flFeet[i] - (flFeelerOffset * flLat[i]);
				flTo[i] = flFrom[i] + (flFeelerLength * flMoveDir[i]);
			}
			
			new bool:bRightClear = IsWalkableTraceLineClear(flFrom, flTo, WALK_THRU_DOORS | WALK_THRU_BREAKABLES);
			
			new Float:flAvoidRange = 300.0;
			
			if (!bRightClear)
			{
				if (bLeftClear)
				{
					g_bSlenderFeelerReflexAdjustment[iBossIndex] = true;
					
					for (new i = 0; i < 3; i++)
					{
						g_flSlenderFeelerReflexAdjustmentPos[iBossIndex][i] = g_flSlenderGoalPos[iBossIndex][i] + (flAvoidRange * flLat[i]);
					}
				}
			}
			else if (!bLeftClear)
			{
				g_bSlenderFeelerReflexAdjustment[iBossIndex] = true;
				
				for (new i = 0; i < 3; i++)
				{
					g_flSlenderFeelerReflexAdjustmentPos[iBossIndex][i] = g_flSlenderGoalPos[iBossIndex][i] - (flAvoidRange * flLat[i]);
				}
			}
		}
	}
	
	new Float:flGoalPosition[3];
	if (g_bSlenderFeelerReflexAdjustment[iBossIndex])
	{
		for (new i = 0; i < 3; i++)
		{
			flGoalPosition[i] = g_flSlenderFeelerReflexAdjustmentPos[iBossIndex][i];
		}
	}
	else
	{
		for (new i = 0; i < 3; i++)
		{
			flGoalPosition[i] = g_flSlenderGoalPos[iBossIndex][i];
		}
	}
	
	// Process our desired velocity.
	new Float:flDesiredVelocity[3];
	switch (iState)
	{
		case STATE_WANDER:
		{
			if (g_iSlenderFlags[iBossIndex] & SFF_WANDERMOVE)
			{
				SubtractVectors(flGoalPosition, flMyPos, flDesiredVelocity);
				flDesiredVelocity[2] = 0.0;
				NormalizeVector(flDesiredVelocity, flDesiredVelocity);
				ScaleVector(flDesiredVelocity, flWalkSpeed);
			}
		}
		case STATE_ALERT:
		{
			SubtractVectors(flGoalPosition, flMyPos, flDesiredVelocity);
			flDesiredVelocity[2] = 0.0;
			NormalizeVector(flDesiredVelocity, flDesiredVelocity);
			ScaleVector(flDesiredVelocity, flWalkSpeed);
		}
		case STATE_CHASE:
		{
			SubtractVectors(flGoalPosition, flMyPos, flDesiredVelocity);
			flDesiredVelocity[2] = 0.0;
			NormalizeVector(flDesiredVelocity, flDesiredVelocity);
			ScaleVector(flDesiredVelocity, flSpeed);
		}
	}
	
	// Check if we're on the ground.
	new bool:bSlenderOnGround = bool:(GetEntityFlags(iBoss) & FL_ONGROUND);
	
	decl Float:flTraceEndPos[3];
	new Handle:hTrace;
	
	// Determine speed behavior.
	if (bSlenderOnGround)
	{
		// Don't change the speed behavior.
	}
	else
	{
		flDesiredVelocity[2] = 0.0;
		NormalizeVector(flDesiredVelocity, flDesiredVelocity);
		ScaleVector(flDesiredVelocity, g_flSlenderAirSpeed[iBossIndex]);
	}
	
	new bool:bSlenderTeleportedOnStep = false;
	new Float:flSlenderStepSize = g_flSlenderStepSize[iBossIndex];
	
	// Check our stepsize in case we need to elevate ourselves a step.
	if (bSlenderOnGround && GetVectorLength(flDesiredVelocity) > 0.0)
	{
		if (flSlenderStepSize > 0.0)
		{
			decl Float:flTraceDirection[3], Float:flObstaclePos[3], Float:flObstacleNormal[3];
			NormalizeVector(flDesiredVelocity, flTraceDirection);
			AddVectors(flMyPos, flTraceDirection, flTraceEndPos);
			
			// Tracehull in front of us to check if there's a very small obstacle blocking our way.
			hTrace = TR_TraceHullFilterEx(flMyPos, 
				flTraceEndPos,
				flBossMins,
				flBossMaxs,
				MASK_NPCSOLID,
				TraceRayDontHitEntity,
				iBoss);
				
			new bool:bSlenderHitObstacle = TR_DidHit(hTrace);
			TR_GetEndPosition(flObstaclePos, hTrace);
			TR_GetPlaneNormal(hTrace, flObstacleNormal);
			CloseHandle(hTrace);
			
			if (bSlenderHitObstacle &&
				FloatAbs(flObstacleNormal[2]) == 0.0)
			{
				decl Float:flTraceStartPos[3];
				flTraceStartPos[0] = flObstaclePos[0];
				flTraceStartPos[1] = flObstaclePos[1];
				
				decl Float:flTraceFreePos[3];
				
				new Float:flTraceCheckZ = 0.0;
				
				// This does a crapload of traces along the wall. Very nasty and expensive to do...
				while (flTraceCheckZ <= flSlenderStepSize)
				{
					flTraceCheckZ += 1.0;
					flTraceStartPos[2] = flObstaclePos[2] + flTraceCheckZ;
					
					AddVectors(flTraceStartPos, flTraceDirection, flTraceEndPos);
					
					hTrace = TR_TraceHullFilterEx(flTraceStartPos, 
						flTraceEndPos,
						flTraceMins,
						flTraceMaxs,
						MASK_NPCSOLID,
						TraceRayDontHitEntity,
						iBoss);
						
					bSlenderHitObstacle = TR_DidHit(hTrace);
					TR_GetEndPosition(flTraceFreePos, hTrace);
					CloseHandle(hTrace);
					
					if (!bSlenderHitObstacle)
					{
						// Potential space to step on? See if we can fit!
						if (!IsSpaceOccupiedNPC(flTraceFreePos,
							flBossMins,
							flBossMaxs,
							iBoss))
						{
							// Yes we can! Break the loop and teleport to this pos.
							bSlenderTeleportedOnStep = true;
							TeleportEntity(iBoss, flTraceFreePos, NULL_VECTOR, NULL_VECTOR);
							break;
						}
					}
				}
			}
			/*
			else if (!bSlenderHitObstacle)
			{
				decl Float:flTraceStartPos[3];
				flTraceStartPos[0] = flObstaclePos[0];
				flTraceStartPos[1] = flObstaclePos[1];
				
				decl Float:flTraceFreePos[3];
				
				new Float:flTraceCheckZ = 0.0;
				
				// This does a crapload of traces along the wall. Very nasty and expensive to do...
				while (flTraceCheckZ <= flSlenderStepSize)
				{
					flTraceCheckZ += 1.0;
					flTraceStartPos[2] = flObstaclePos[2] - flTraceCheckZ;
					
					AddVectors(flTraceStartPos, flTraceDirection, flTraceEndPos);
					
					hTrace = TR_TraceHullFilterEx(flTraceStartPos, 
						flTraceEndPos,
						flTraceMins,
						flTraceMaxs,
						MASK_NPCSOLID,
						TraceRayDontHitEntity,
						iBoss);
						
					bSlenderHitObstacle = TR_DidHit(hTrace);
					TR_GetEndPosition(flTraceFreePos, hTrace);
					CloseHandle(hTrace);
					
					if (bSlenderHitObstacle)
					{
						// Potential space to step on? See if we can fit!
						if (!IsSpaceOccupiedNPC(flTraceFreePos,
							flBossMins,
							flBossMaxs,
							iBoss))
						{
							// Yes we can! Break the loop and teleport to this pos.
							bSlenderTeleportedOnStep = true;
							TeleportEntity(iBoss, flTraceFreePos, NULL_VECTOR, NULL_VECTOR);
							break;
						}
					}
				}
			}
			*/
		}
	}
	
	// Apply acceleration vectors.
	new Float:flMoveVelocity[3];
	new Float:flFrameTime = GetTickInterval();
	decl Float:flAcceleration[3];
	SubtractVectors(flDesiredVelocity, flMyVelocity, flAcceleration);
	NormalizeVector(flAcceleration, flAcceleration);
	ScaleVector(flAcceleration, g_flSlenderAcceleration[iBossIndex] * flFrameTime);
	
	AddVectors(flMyVelocity, flAcceleration, flMoveVelocity);
	
	new Float:flSlenderJumpSpeed = g_flSlenderJumpSpeed[iBossIndex];
	new bool:bSlenderShouldJump = false;
	
	decl Float:angJumpReach[3]; 
	
	// Check if we need to jump over a wall or something.
	if (!bSlenderShouldJump && bSlenderOnGround && !bSlenderTeleportedOnStep && flSlenderJumpSpeed > 0.0 && GetVectorLength(flDesiredVelocity) > 0.0 &&
		GetGameTime() >= g_flSlenderNextJump[iBossIndex])
	{
		new Float:flSlenderMaxJumpHeight = Pow(flSlenderJumpSpeed, 2.0) / (2.0 * g_flGravity);
		new Float:flZDiff = (flMyPos[2] - flGoalPosition[2]);
		
		if (flZDiff > flSlenderStepSize && flZDiff <= flSlenderMaxJumpHeight)
		{
			// Our path has a jump thingy to it. Calculate the jump height needed to reach it and how far away we should start
			// checking on when to jump.
			
			decl Float:vecDir[3], Float:vecDesiredDir[3];
			NormalizeVector(flMyVelocity, vecDir);
			SubtractVectors(flGoalPosition, flMyPos, vecDesiredDir);
			NormalizeVector(vecDesiredDir, vecDesiredDir);
			
			if (GetVectorDotProduct(vecDir, vecDesiredDir) >= 0.5)
			{
				// Assuming we are actually capable of making the jump, find out WHEN we have to jump,
				// based on 2D distance between our position and the target point, and our current horizontal 
				// velocity.
				
				decl Float:vecMyPos2D[3], Float:vecGoalPos2D[3];
				vecMyPos2D[0] = flMyPos[0];
				vecMyPos2D[1] = flMyPos[1];
				vecMyPos2D[2] = 0.0;
				vecGoalPos2D[0] = flGoalPosition[0];
				vecGoalPos2D[1] = flGoalPosition[1];
				vecGoalPos2D[2] = 0.0;
				
				new Float:fl2DDist = GetVectorDistance(vecMyPos2D, vecGoalPos2D);
				
				new Float:flNotImaginary = Pow(flSlenderJumpSpeed, 4.0) - g_flGravity * (g_flGravity * Pow(fl2DDist, 2.0) + 2.0 * flZDiff * Pow(flSlenderJumpSpeed, 2.0));
				if (flNotImaginary >= 0.0)
				{
					// We can reach it.
					new Float:flNotInfinite = g_flGravity * fl2DDist;
					if (flNotInfinite > 0.0)
					{
						SubtractVectors(vecGoalPos2D, vecMyPos2D, angJumpReach);
						GetVectorAngles(angJumpReach, angJumpReach);
						angJumpReach[0] = RadToDeg(ArcTangent((Pow(flSlenderJumpSpeed, 2.0) + Pow(flNotImaginary, 0.5)) / flNotInfinite));
						bSlenderShouldJump = true;
					}
				}
			}
		}
	}
	
	if (bSlenderOnGround && bSlenderShouldJump)
	{
		g_flSlenderNextJump[iBossIndex] = GetGameTime() + GetProfileFloat(sSlenderProfile, "jump_cooldown", 2.0);
		
		decl Float:vecJump[3];
		GetAngleVectors(angJumpReach, vecJump, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(vecJump, vecJump);
		ScaleVector(vecJump, flSlenderJumpSpeed);
		AddVectors(flMoveVelocity, vecJump, flMoveVelocity);
	}
	else 
	{
		// We are in no position to defy gravity.
		flMoveVelocity[2] = flMyVelocity[2];
	}
	
	decl Float:flMoveAng[3];
	new bool:bChangeAngles = false;
	
	// Process angles.
	if (iState != STATE_ATTACK && iState != STATE_STUN)
	{
		if (SlenderHasAttribute(iBossIndex, "always look at target"))
		{
			new iTarget = EntRefToEntIndex(g_iSlenderTarget[iBossIndex]);
			
			if (iTarget && iTarget != INVALID_ENT_REFERENCE)
			{
				decl Float:flTargetPos[3];
				GetEntPropVector(iTarget, Prop_Data, "m_vecAbsOrigin", flTargetPos);
				SubtractVectors(flTargetPos, flMyPos, flMoveAng);
				GetVectorAngles(flMoveAng, flMoveAng);
			}
			else
			{
				SubtractVectors(flGoalPosition, flMyPos, flMoveAng);
				GetVectorAngles(flMoveAng, flMoveAng);
			}
		}
		else
		{
			SubtractVectors(flGoalPosition, flMyPos, flMoveAng);
			GetVectorAngles(flMoveAng, flMoveAng);
		}
		
		new Float:flTurnRate = g_flSlenderTurnRate[iBossIndex];
		if (iState == STATE_CHASE) flTurnRate *= 2.0;
		
		flMoveAng[0] = 0.0;
		flMoveAng[2] = 0.0;
		flMoveAng[1] = ApproachAngle(flMoveAng[1], flMyEyeAng[1], flTurnRate * flFrameTime);
		
		bChangeAngles = true;
	}
	
	TeleportEntity(iBoss, NULL_VECTOR, bChangeAngles ? flMoveAng : NULL_VECTOR, flMoveVelocity);
}

// Shortest-path cost function for NavMesh_BuildPath.
public SlenderChaseBossShortestPathCost(iAreaIndex, iFromAreaIndex, iLadderIndex, any:iStepSize)
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

public Action:Timer_SlenderBlinkBossThink(Handle:timer, any:entref)
{
	new slender = EntRefToEntIndex(entref);
	if (!slender || slender == INVALID_ENT_REFERENCE) return Plugin_Stop;
	
	new iBossIndex = SlenderEntIndexToArrayIndex(slender);
	if (iBossIndex == -1) return Plugin_Stop;
	
	if (timer != g_hSlenderEntityThink[iBossIndex]) return Plugin_Stop;
	
	if (g_iSlenderType[iBossIndex] == 1)
	{
		new bool:bMove = false;
		
		if ((GetGameTime() - g_flSlenderLastKill[iBossIndex]) >= GetProfileFloat(g_strSlenderProfile[iBossIndex], "kill_cooldown"))
		{
			if (PeopleCanSeeSlender(iBossIndex, false, false) && !PeopleCanSeeSlender(iBossIndex, true, SlenderUsesBlink(iBossIndex)))
			{
				new iBestPlayer = -1;
				new Handle:hArray = CreateArray();
				
				for (new i = 1; i <= MaxClients; i++)
				{
					if (!IsClientInGame(i) || !IsPlayerAlive(i) || g_bPlayerDeathCam[i] || g_bPlayerEliminated[i] || g_bPlayerEscaped[i] || !PlayerCanSeeSlender(i, iBossIndex, false, false)) continue;
					PushArrayCell(hArray, i);
				}
				
				if (GetArraySize(hArray))
				{
					decl Float:flSlenderPos[3];
					SlenderGetAbsOrigin(iBossIndex, flSlenderPos);
					
					decl Float:flTempPos[3];
					new iTempPlayer = -1;
					new Float:flTempDist = 16384.0;
					for (new i = 0; i < GetArraySize(hArray); i++)
					{
						new iClient = GetArrayCell(hArray, i);
						GetClientAbsOrigin(iClient, flTempPos);
						if (GetVectorDistance(flTempPos, flSlenderPos) < flTempDist)
						{
							iTempPlayer = iClient;
							flTempDist = GetVectorDistance(flTempPos, flSlenderPos);
						}
					}
					
					iBestPlayer = iTempPlayer;
				}
				
				CloseHandle(hArray);
				
				decl Float:buffer[3];
				if (iBestPlayer != -1 && SlenderCalculateApproachToPlayer(iBossIndex, iBestPlayer, buffer))
				{
					bMove = true;
					
					decl Float:flAng[3], Float:flBuffer[3];
					decl Float:flSlenderPos[3], Float:flPos[3];
					GetEntPropVector(slender, Prop_Data, "m_vecAbsOrigin", flSlenderPos);
					GetClientAbsOrigin(iBestPlayer, flPos);
					SubtractVectors(flPos, buffer, flAng);
					GetVectorAngles(flAng, flAng);
					
					// Take care of angle offsets.
					GetProfileVector(g_strSlenderProfile[iBossIndex], "eye_ang_offset", flBuffer);
					AddVectors(flAng, flBuffer, flAng);
					for (new i = 0; i < 3; i++) flAng[i] = AngleNormalize(flAng[i]);
					
					flAng[0] = 0.0;
					
					// Take care of position offsets.
					GetProfileVector(g_strSlenderProfile[iBossIndex], "pos_offset", flBuffer);
					AddVectors(buffer, flBuffer, buffer);
					
					TeleportEntity(slender, buffer, flAng, NULL_VECTOR);
					
					new Float:flMaxRange = GetProfileFloat(g_strSlenderProfile[iBossIndex], "teleport_range_max");
					new Float:flDist = GetVectorDistance(buffer, flPos);
					
					decl String:sBuffer[PLATFORM_MAX_PATH];
					
					if (flDist < (flMaxRange * 0.33)) 
					{
						GetProfileString(g_strSlenderProfile[iBossIndex], "model_closedist", sBuffer, sizeof(sBuffer));
					}
					else if (flDist < (flMaxRange * 0.66)) 
					{
						GetProfileString(g_strSlenderProfile[iBossIndex], "model_averagedist", sBuffer, sizeof(sBuffer));
					}
					else 
					{
						GetProfileString(g_strSlenderProfile[iBossIndex], "model", sBuffer, sizeof(sBuffer));
					}
					
					// Fallback if error.
					if (!sBuffer[0]) GetProfileString(g_strSlenderProfile[iBossIndex], "model", sBuffer, sizeof(sBuffer));
					
					SetEntProp(slender, Prop_Send, "m_nModelIndex", PrecacheModel(sBuffer));
					
					if (flDist <= GetProfileFloat(g_strSlenderProfile[iBossIndex], "kill_radius"))
					{
						if (g_iSlenderFlags[iBossIndex] & SFF_FAKE)
						{
							SlenderMarkAsFake(iBossIndex);
							return Plugin_Stop;
						}
						else
						{
							g_flSlenderLastKill[iBossIndex] = GetGameTime();
							ClientStartDeathCam(iBestPlayer, iBossIndex, buffer); // Lmao. You're dead.
						}
					}
				}
			}
		}
		
		if (bMove)
		{
			decl String:sBuffer[PLATFORM_MAX_PATH];
			GetRandomStringFromProfile(g_strSlenderProfile[iBossIndex], "sound_move_single", sBuffer, sizeof(sBuffer));
			if (sBuffer[0]) EmitSoundToAll(sBuffer, slender, SNDCHAN_AUTO, SNDLEVEL_SCREAMING);
			
			GetRandomStringFromProfile(g_strSlenderProfile[iBossIndex], "sound_move", sBuffer, sizeof(sBuffer), 1);
			if (sBuffer[0]) EmitSoundToAll(sBuffer, slender, SNDCHAN_AUTO, SNDLEVEL_SCREAMING);
		}
		else
		{
			decl String:sBuffer[PLATFORM_MAX_PATH];
			GetRandomStringFromProfile(g_strSlenderProfile[iBossIndex], "sound_move", sBuffer, sizeof(sBuffer), 1);
			if (sBuffer[0]) StopSound(slender, SNDCHAN_AUTO, g_strSlenderProfile[iBossIndex]);
		}
	}
	
	return Plugin_Continue;
}



/*
public Action:Timer_SlenderTrueMasterThink(Handle:timer, any:iBossIndex)
{
	if (iBossIndex < 0 || iBossIndex >= MAX_BOSSES) return Plugin_Stop;
	if (g_iSlenderID[iBossIndex] == -1) return Plugin_Stop;
	
	if (timer != g_hSlenderThink[iBossIndex]) return;
	
	if (!(g_iSlenderFlags[iBossIndex] & SFF_NOTELEPORT))
	{
	}
}

public Action:Timer_SlenderChaseBossTeleport(Handle:timer, any:iBossID)
{
	new iBossIndex = SlenderGetFromID(iBossID);
	if (iBossIndex == -1) return Plugin_Stop;
	
	if (timer != g_hSlenderThink[iBossIndex]) return Plugin_Stop;
	
	new iBossFlags = g_iSlenderFlags[iBossIndex];
	if (iBossFlags & SFF_MARKEDASFAKE ||
		iBossFlags & SFF_FAKE ||
		iBossFlags & SFF_NOTELEPORT) return Plugin_Stop;
	
	new iBoss = EntRefToEntIndex(g_iSlender[iBossIndex]);
	
	// We can only teleport if we are inactive.
	new iState = g_iSlenderState[iBossIndex];
	if (iBoss && iBoss != INVALID_ENT_REFERENCE && iState != STATE_IDLE && iState != STATE_WANDER) return Plugin_Continue;
	
	new Float:flCurTime = GetGameTime();
	
	if (iBoss && iBoss != INVALID_ENT_REFERENCE)
	{
		if (flCurTime < g_flSlenderNextTeleportTime[iBossIndex] ||
			flCurTime < g_flSlenderTimeUntilKill[iBossIndex]) return Plugin_Continue;
	}
	
	// Don't teleport until we have gone out of (potential) sight.
	// Instead, make the boss queue a path towards the best player, so that the boss can actually be able to
	// do something instead of just standing around.
	
	new bool:bPotentiallyVisibleToPlayers = PeopleCanSeeSlender(iBossIndex, _, false);
	
	new iMasterIndex = SlenderGetFromID(g_iSlenderCopyMaster[iBossIndex]);
	if (iMasterIndex == -1) iMasterIndex = iBossIndex;
	
	// Get a list of players that can potentially be targeted to.
	new Handle:hPlayers = CreateArray();
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) ||
			!IsPlayerAlive(i) ||
			g_bPlayerEliminated[i] ||
			g_bPlayerEscaped[i]) continue;
		
		// Encounter times are entirely based on the copy master.
		if (flCurTime >= (g_flPlayerLastChaseBossEncounterTime[i][iMasterIndex] + g_flPlayerNextChaseBossEncounterTimeAdd[i][iMasterIndex]))
		{
			PushArrayCell(hPlayers, i);
		}
	}
	
	if (GetArraySize(hPlayers))
	{
		// Pick the player with the most stress.
		new iBestPlayer = -1;
		new Float:flBestPlayerStress = -1.0;
		
		for (new i = 0, iSize = GetArraySize(hPlayers); i < iSize; i++)
		{
			new iClient = GetArrayCell(hPlayers, i);
			new Float:flClientStress = g_flPlayerStress[iClient];
			
			if (flClientStress > flBestPlayerStress)
			{
				iBestPlayer = iClient;
				flBestPlayerStress = flClientStress;
			}
		}
		
		if (iBestPlayer != -1)
		{
			PrintToChatAll("iBestPlayer: %d", iBestPlayer);
		
			new Float:flPageProgress = 0.0;
			if (g_iPageMax) flPageProgress = float(g_iPageCount) / float(g_iPageMax);
		
			new Float:flTeleportMinDist = GetProfileFloat(g_strSlenderProfile[iMasterIndex], "teleport_range_min", 1024.0);
			new Float:flTeleportMaxDist = GetProfileFloat(g_strSlenderProfile[iMasterIndex], "teleport_range_max", 3000.0);
			
			// Change the minimum distance dynamically based on game progression.
			flTeleportMinDist += ((flTeleportMaxDist - flTeleportMinDist) * (1.0 - flPageProgress));
			
			decl Float:flActiveAreaCenterPos[3];
			GetClientAbsOrigin(iBestPlayer, flActiveAreaCenterPos);
			
			decl Float:flTeleportPos[3];
			if (SlenderChaseBossCalculateNewPlace(iMasterIndex, flActiveAreaCenterPos, flTeleportMinDist, flTeleportMaxDist, SlenderChaseBossPlaceFunctor, flTeleportPos))
			{
				PrintToChatAll("new place!", iBestPlayer);
			
				new Float:flTeleportCooldownMin = GetProfileFloat(g_strSlenderProfile[iMasterIndex], "teleport_cooldown_min", 10.0);
				new Float:flTeleportCooldownMax = GetProfileFloat(g_strSlenderProfile[iMasterIndex], "teleport_cooldown_max", 23.0);
				g_flSlenderNextTeleportTime[iBossIndex] = flCurTime + GetRandomFloat(flTeleportCooldownMin, flTeleportCooldownMax);
				
				if (!bPotentiallyVisibleToPlayers)
				{
					PrintToChatAll("not visible!", iBestPlayer);
				
					new Float:flEncounterTimeCooldownMin = GetProfileFloat(g_strSlenderProfile[iMasterIndex], "encounter_time_cooldown_min", 20.0);
					new Float:flEncounterTimeCooldownMax = GetProfileFloat(g_strSlenderProfile[iMasterIndex], "encounter_time_cooldown_max", 35.0);
					
					SpawnSlender(iBossIndex, flTeleportPos);
					
					g_flPlayerLastChaseBossEncounterTime[iBestPlayer][iMasterIndex] = flCurTime;
					g_flPlayerNextChaseBossEncounterTimeAdd[iBestPlayer][iMasterIndex] = GetRandomFloat(flEncounterTimeCooldownMin, flEncounterTimeCooldownMax);
				}
				else
				{
					// Force the boss to target the best player, no matter where he's at.
					// This will force the boss to queue for a new path towards its target.
					
					g_iSlenderTarget[iBossIndex] = EntIndexToEntRef(iBestPlayer);
				}
			}
		}
	}
	
	CloseHandle(hPlayers);
	
	return Plugin_Continue;
}
*/

SlenderOnClientStressUpdate(client)
{
	new Float:flStress = g_flPlayerStress[client];
	
	for (new iBossIndex = 0; iBossIndex < MAX_BOSSES; iBossIndex++)
	{	
		if (g_iSlenderID[iBossIndex] == -1) continue;
		
		new iBossFlags = g_iSlenderFlags[iBossIndex];
		if (iBossFlags & SFF_MARKEDASFAKE ||
			iBossFlags & SFF_NOTELEPORT)
		{
			continue;
		}
		
		new iTeleportTarget = EntRefToEntIndex(g_iSlenderTeleportTarget[iBossIndex]);
		if (iTeleportTarget && iTeleportTarget != INVALID_ENT_REFERENCE)
		{
			if (g_bPlayerEliminated[iTeleportTarget] ||
				g_bPlayerEscaped[iTeleportTarget] ||
				flStress >= g_flSlenderTeleportMaxTargetStress[iBossIndex] ||
				GetGameTime() >= g_flSlenderTeleportMaxTargetTime[iBossIndex])
			{
				// Queue for a new target and mark the old target in the rest period.
				new Float:flRestPeriod = GetProfileFloat(g_strSlenderProfile[iBossIndex], "teleport_target_rest_period", 15.0);
				flRestPeriod = (flRestPeriod * GetRandomFloat(0.92, 1.08)) / (g_flSlenderAnger[iBossIndex] * g_flRoundDifficultyModifier);
				
				g_iSlenderTeleportTarget[iBossIndex] = INVALID_ENT_REFERENCE;
				g_flSlenderTeleportPlayersRestTime[iBossIndex][iTeleportTarget] = GetGameTime() + flRestPeriod;
				g_flSlenderTeleportMaxTargetStress[iBossIndex] = 9999.0;
				g_flSlenderTeleportMaxTargetTime[iBossIndex] = -1.0;
				g_flSlenderTeleportTargetTime[iBossIndex] = -1.0;
				
				SendDebugMessageToPlayers(DEBUG_BOSS_TELEPORTATION, 0, "Teleport for boss %d: lost target, putting at rest period", iBossIndex);
			}
		}
		else if (!g_bRoundGrace)
		{
			new iPreferredTeleportTarget = INVALID_ENT_REFERENCE;
			new Float:flPreferredTeleportTargetStress = 99999.0;
			
			for (new i = 1; i <= MaxClients; i++)
			{
				if (!IsClientInGame(i) ||
					!IsPlayerAlive(i) ||
					g_bPlayerEliminated[i] ||
					g_bPlayerGhostMode[i] ||
					g_bPlayerEscaped[i])
				{
					continue;
				}
				
				if (g_flPlayerStress[i] < flPreferredTeleportTargetStress)
				{
					if (g_flSlenderTeleportPlayersRestTime[iBossIndex][i] <= GetGameTime())
					{
						iPreferredTeleportTarget = i;
						flPreferredTeleportTargetStress = g_flPlayerStress[i];
					}
				}
			}
			
			if (iPreferredTeleportTarget && iPreferredTeleportTarget != INVALID_ENT_REFERENCE)
			{
				// Set our preferred target to the new guy.
				new Float:flTargetDuration = GetProfileFloat(g_strSlenderProfile[iBossIndex], "teleport_target_persistency_period", 13.0);
				new Float:flDeviation = GetRandomFloat(0.92, 1.08);
				flTargetDuration = Pow(flDeviation * flTargetDuration, ((g_flRoundDifficultyModifier * (g_flSlenderAnger[iBossIndex] - 1.0)) / 2.0)) + ((flDeviation * flTargetDuration) - 1.0);
				
				new Float:flTargetStressMin = GetProfileFloat(g_strSlenderProfile[iBossIndex], "teleport_target_stress_min", 0.2);
				new Float:flTargetStressMax = GetProfileFloat(g_strSlenderProfile[iBossIndex], "teleport_target_stress_max", 0.9);
				
				new Float:flTargetStress = flTargetStressMax - ((flTargetStressMax - flTargetStressMin) / (g_flRoundDifficultyModifier * g_flSlenderAnger[iBossIndex]));
				
				g_iSlenderTeleportTarget[iBossIndex] = EntIndexToEntRef(iPreferredTeleportTarget);
				g_flSlenderTeleportPlayersRestTime[iBossIndex][iPreferredTeleportTarget] = -1.0;
				g_flSlenderTeleportMaxTargetTime[iBossIndex] = GetGameTime() + flTargetDuration;
				g_flSlenderTeleportTargetTime[iBossIndex] = GetGameTime();
				g_flSlenderTeleportMaxTargetStress[iBossIndex] = flTargetStress;
				
				iTeleportTarget = iPreferredTeleportTarget;
				
				SendDebugMessageToPlayers(DEBUG_BOSS_TELEPORTATION, 0, "Teleport for boss %d: got new target %N", iBossIndex, iPreferredTeleportTarget);
			}
		}
	}
}

stock SendDebugMessageToPlayer(client, iDebugFlags, iType, const String:sMessage[], any:...)
{
	if (!IsClientInGame(client) || IsFakeClient(client)) return;

	decl String:sMsg[1024];
	VFormat(sMsg, sizeof(sMsg), sMessage, 5);
	
	if (g_iPlayerDebugFlags[client] & iDebugFlags)
	{
		switch (iType)
		{
			case 0: CPrintToChat(client, sMsg);
			case 1: PrintCenterText(client, sMsg);
			case 2: PrintHintText(client, sMsg);
		}
	}
}

stock SendDebugMessageToPlayers(iDebugFlags, iType, const String:sMessage[], any:...)
{
	decl String:sMsg[1024];
	VFormat(sMsg, sizeof(sMsg), sMessage, 4);

	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i)) return;
		
		if (g_iPlayerDebugFlags[i] & iDebugFlags)
		{
			switch (iType)
			{
				case 0: CPrintToChat(i, sMsg);
				case 1: PrintCenterText(i, sMsg);
				case 2: PrintHintText(i, sMsg);
			}
		}
	}
}

public Action:Timer_SlenderTeleportThink(Handle:timer, any:iBossIndex)
{
	if (iBossIndex == -1) return Plugin_Stop;
	if (timer != g_hSlenderThink[iBossIndex]) return Plugin_Stop;
	
	if (g_iSlenderFlags[iBossIndex] & SFF_NOTELEPORT) return Plugin_Continue;
	
	// Check to see if anyone's looking at me before doing anything.
	if (PeopleCanSeeSlender(iBossIndex, _, false))
	{
		return Plugin_Continue;
	}
	
	if (g_iSlenderTeleportType[iBossIndex] == 2)
	{
		// Check to see if it's a good time to teleport away.
		new iState = g_iSlenderState[iBossIndex];
		if (iState == STATE_IDLE || iState == STATE_WANDER)
		{
			if (GetGameTime() < g_flSlenderTimeUntilKill[iBossIndex])
			{
				return Plugin_Continue;
			}
		}
	}
	
	if (!g_bRoundGrace)
	{
		if (GetGameTime() >= g_flSlenderNextTeleportTime[iBossIndex])
		{
			new Float:flTeleportTime = GetRandomFloat(GetProfileFloat(g_strSlenderProfile[iBossIndex], "teleport_time_min", 5.0), GetProfileFloat(g_strSlenderProfile[iBossIndex], "teleport_time_max", 9.0));
			g_flSlenderNextTeleportTime[iBossIndex] = GetGameTime() + flTeleportTime;
			
			new iTeleportTarget = EntRefToEntIndex(g_iSlenderTeleportTarget[iBossIndex]);
			
			if (!iTeleportTarget || iTeleportTarget == INVALID_ENT_REFERENCE)
			{
				// We don't have any good targets. Remove myself for now.
				if (SlenderCanRemove(iBossIndex)) RemoveSlender(iBossIndex);
				SendDebugMessageToPlayers(DEBUG_BOSS_TELEPORTATION, 0, "Teleport for boss %d: no good target, removing...", iBossIndex);
			}
			else
			{
				// As time passes on, we have to get more aggressive in order to successfully peak the target's
				// stress level in the allotted duration we're given. Otherwise we'll be forced to place him
				// in a rest period.
				
				// Teleport progressively closer as time passes in attempt to increase the target's stress level.
				// Maximum minimum range is capped by the boss's anger level.
				
				new Float:flTeleportTargetTimeLeft = g_flSlenderTeleportMaxTargetTime[iBossIndex] - GetGameTime();
				new Float:flTeleportTargetTimeInitial = g_flSlenderTeleportMaxTargetTime[iBossIndex] - g_flSlenderTeleportTargetTime[iBossIndex];
				
				new Float:flTeleportMinRange = g_flSlenderTeleportMaxRange[iBossIndex] - (1.0 - (flTeleportTargetTimeLeft / flTeleportTargetTimeInitial)) * (g_flSlenderTeleportMaxRange[iBossIndex] - g_flSlenderTeleportMinRange[iBossIndex]);
				
				if (g_flSlenderAnger[iBossIndex] <= 1.0)
				{
					flTeleportMinRange += (g_flSlenderTeleportMinRange[iBossIndex] - g_flSlenderTeleportMaxRange[iBossIndex]) * Pow(g_flSlenderAnger[iBossIndex] - 1.0, 2.0 / g_flRoundDifficultyModifier);
				}
				
				if (flTeleportMinRange < g_flSlenderTeleportMinRange[iBossIndex]) flTeleportMinRange = g_flSlenderTeleportMinRange[iBossIndex];
				if (flTeleportMinRange > g_flSlenderTeleportMaxRange[iBossIndex]) flTeleportMinRange = g_flSlenderTeleportMaxRange[iBossIndex];
				
				new iTeleportAreaIndex = -1;
				
				// Search surrounding nav areas around target.
				if (NavMesh_Exists())
				{
					decl Float:flTargetPos[3];
					GetClientAbsOrigin(iTeleportTarget, flTargetPos);
					
					new iTargetAreaIndex = NavMesh_GetNearestArea(flTargetPos);
					if (iTargetAreaIndex != -1)
					{
						new bool:bShouldBeBehindObstruction = false;
						if (g_iSlenderTeleportType[iBossIndex] == 2)
						{
							bShouldBeBehindObstruction = true;
						}
					
						// Search outwards until travel distance is at maximum range.
						new Handle:hAreaArray = CreateArray(2);
						new Handle:hAreas = NavMesh_CollectSurroundingAreas(iTargetAreaIndex, g_flSlenderTeleportMaxRange[iBossIndex]);
						if (hAreas != INVALID_HANDLE)
						{
							new iPoppedAreas;
						
							while (!IsStackEmpty(hAreas))
							{
								new iAreaIndex = -1;
								PopStackCell(hAreas, iAreaIndex);
								new iIndex = PushArrayCell(hAreaArray, iAreaIndex);
								SetArrayCell(hAreaArray, iIndex, float(NavMeshArea_GetCostSoFar(iAreaIndex)), 1);
								iPoppedAreas++;
							}
							
							SendDebugMessageToPlayers(DEBUG_BOSS_TELEPORTATION, 0, "Teleport for boss %d: collected %d areas", iBossIndex, iPoppedAreas);
							
							CloseHandle(hAreas);
						}
						
						new Handle:hAreaArrayClose = CreateArray();
						new Handle:hAreaArrayAverage = CreateArray();
						new Handle:hAreaArrayFar = CreateArray();
						
						for (new i = 1; i <= 3; i++)
						{
							new Float:flRangeSectionMin = flTeleportMinRange + (g_flSlenderTeleportMaxRange[iBossIndex] - flTeleportMinRange) * (float(i - 1) / 3.0);
							new Float:flRangeSectionMax = flTeleportMinRange + (g_flSlenderTeleportMaxRange[iBossIndex] - flTeleportMinRange) * (float(i) / 3.0);
							
							for (new i2 = 0, iSize = GetArraySize(hAreaArray); i2 < iSize; i2++)
							{
								new iAreaIndex = GetArrayCell(hAreaArray, i2);
								
								decl Float:flAreaCenter[3];
								NavMeshArea_GetCenter(iAreaIndex, flAreaCenter);
								
								// Check visibility.
								if (IsPointVisibleToAPlayer(flAreaCenter, !bShouldBeBehindObstruction, false)) continue;
								
								AddVectors(flAreaCenter, g_flSlenderEyePosOffset[iBossIndex], flAreaCenter);
								
								if (IsPointVisibleToAPlayer(flAreaCenter, !bShouldBeBehindObstruction, false)) continue;
								
								SubtractVectors(flAreaCenter, g_flSlenderEyePosOffset[iBossIndex], flAreaCenter);
								
								new iBoss = EntRefToEntIndex(g_iSlender[iBossIndex]);
								
								// Check space.
								if (IsSpaceOccupiedNPC(flAreaCenter,
									g_flSlenderDetectMins[iBossIndex],
									g_flSlenderDetectMaxs[iBossIndex],
									iBoss))
								{
									continue;
								}
								
								new bool:bTooNear = false;
								
								// Check minimum range.
								for (new iClient = 1; iClient <= MaxClients; iClient++)
								{
									if (!IsClientInGame(iClient) ||
										!IsPlayerAlive(iClient) ||
										g_bPlayerEliminated[iClient] ||
										g_bPlayerEscaped[iClient])
									{
										continue;
									}
									
									decl Float:flTempPos[3];
									GetClientAbsOrigin(iClient, flTempPos);
									
									if (GetVectorDistance(flAreaCenter, flTempPos) <= g_flSlenderTeleportMinRange[iBossIndex])
									{
										bTooNear = true;
										break;
									}
								}
								
								if (bTooNear) continue;	// This area is not compatible.
								
								// Check travel distance.
								new Float:flDist = Float:GetArrayCell(hAreaArray, i2, 1);
								if (flDist > flRangeSectionMin && flDist < flRangeSectionMax)
								{
									switch (i)
									{
										case 1: PushArrayCell(hAreaArrayClose, iAreaIndex);
										case 2: PushArrayCell(hAreaArrayAverage, iAreaIndex);
										case 3: PushArrayCell(hAreaArrayFar, iAreaIndex);
									}
								}
							}
						}
						
						CloseHandle(hAreaArray);
						
						SendDebugMessageToPlayers(DEBUG_BOSS_TELEPORTATION, 0, "Teleport for boss %d: collected %d close areas, %d average areas, %d far areas", iBossIndex, GetArraySize(hAreaArrayClose),
							GetArraySize(hAreaArrayAverage),
							GetArraySize(hAreaArrayFar));
						
						new iBestAreaIndex = -1;
						
						if (GetArraySize(hAreaArrayClose))
						{
							iBestAreaIndex = GetArrayCell(hAreaArrayClose, GetRandomInt(0, GetArraySize(hAreaArrayClose) - 1));
						}
						else if (GetArraySize(hAreaArrayAverage))
						{
							iBestAreaIndex = GetArrayCell(hAreaArrayAverage, GetRandomInt(0, GetArraySize(hAreaArrayAverage) - 1));
						}
						else if (GetArraySize(hAreaArrayFar))
						{
							iBestAreaIndex = GetArrayCell(hAreaArrayFar, GetRandomInt(0, GetArraySize(hAreaArrayFar) - 1));
						}
						
						CloseHandle(hAreaArrayClose);
						CloseHandle(hAreaArrayAverage);
						CloseHandle(hAreaArrayFar);
						
						if (iBestAreaIndex != -1)
						{
							iTeleportAreaIndex = iBestAreaIndex;
						}
					}
				}
				
				if (iTeleportAreaIndex == -1)
				{
					// We don't have any good areas. Remove myself for now.
					if (SlenderCanRemove(iBossIndex)) RemoveSlender(iBossIndex);
				}
				else
				{
					// Use the center for now.
					decl Float:flTeleportPos[3];
					NavMeshArea_GetCenter(iTeleportAreaIndex, flTeleportPos);
					SpawnSlender(iBossIndex, flTeleportPos);
					
					if (g_iSlenderFlags[iBossIndex] & SFF_HASJUMPSCARE)
					{
						new bool:bDidJumpScare = false;
						
						for (new i = 1; i <= MaxClients; i++)
						{
							if (!IsClientInGame(i) || !IsPlayerAlive(i) || g_bPlayerEliminated[i] || g_bPlayerGhostMode[i]) continue;
							
							if (PlayerCanSeeSlender(i, iBossIndex, false))
							{
								if ((SlenderGetDistanceFromPlayer(iBossIndex, i) <= GetProfileFloat(g_strSlenderProfile[iBossIndex], "jumpscare_distance") &&
									GetGameTime() >= g_flSlenderNextJumpScare[iBossIndex]) ||
									PlayerCanSeeSlender(i, iBossIndex))
								{
									g_iPlayerJumpScareMaster[i] = iBossIndex;
									g_flPlayerJumpScareLifeTime[i] = GetGameTime() + GetProfileFloat(g_strSlenderProfile[iBossIndex], "jumpscare_duration");
									
									decl String:sBuffer[PLATFORM_MAX_PATH];
									GetRandomStringFromProfile(g_strSlenderProfile[iBossIndex], "sound_jumpscare", sBuffer, sizeof(sBuffer), 1);
									EmitSoundToClient(i, sBuffer, _, MUSIC_CHAN);
									
									bDidJumpScare = true;
								}
							}
						}
						
						if (bDidJumpScare)
						{
							g_flSlenderNextJumpScare[iBossIndex] = GetGameTime() + GetProfileFloat(g_strSlenderProfile[iBossIndex], "jumpscare_cooldown");
						}
					}
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public Action:Timer_SlenderChaseBossAttack(Handle:timer, any:entref)
{
	if (!g_bEnabled) return;

	new slender = EntRefToEntIndex(entref);
	if (!slender || slender == INVALID_ENT_REFERENCE) return;
	
	new iBossIndex = SlenderEntIndexToArrayIndex(slender);
	if (iBossIndex == -1) return;
	
	if (timer != g_hSlenderAttackTimer[iBossIndex]) return;
	
	if (g_iSlenderFlags[iBossIndex] & SFF_FAKE)
	{
		SlenderMarkAsFake(iBossIndex);
		return;
	}
	
	new bool:bAttackEliminated = bool:(g_iSlenderFlags[iBossIndex] & SFF_ATTACKWAITERS);
	
	new Float:flDamage = GetProfileFloat(g_strSlenderProfile[iBossIndex], "attack_damage");
	new iDamageType = GetProfileNum(g_strSlenderProfile[iBossIndex], "attack_damagetype");
	
	// Damage all players within range.
	decl Float:flMyEyePos[3], Float:flMyEyeAngOffset[3], Float:flMyEyeAng[3];
	SlenderGetEyePosition(iBossIndex, flMyEyePos);
	GetEntPropVector(slender, Prop_Data, "m_angAbsRotation", flMyEyeAng);
	GetProfileVector(g_strSlenderProfile[iBossIndex], "eye_ang_offset", flMyEyeAngOffset);
	AddVectors(flMyEyeAngOffset, flMyEyeAng, flMyEyeAng);
	for (new i = 0; i < 3; i++) flMyEyeAng[i] = AngleNormalize(flMyEyeAng[i]);
	
	decl Float:flViewPunch[3];
	GetProfileVector(g_strSlenderProfile[iBossIndex], "attack_punchvel", flViewPunch);
	
	decl Float:flTargetDist;
	decl Handle:hTrace;
	
	new Float:flAttackRange = GetProfileFloat(g_strSlenderProfile[iBossIndex], "attack_range");
	new Float:flAttackFOV = GetProfileFloat(g_strSlenderProfile[iBossIndex], "attack_fov", g_flSlenderFOV[iBossIndex] * 0.5);
	
	new bool:bHit = false;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || g_bPlayerGhostMode[i]) continue;
		
		if (!bAttackEliminated && g_bPlayerEliminated[i]) continue;
		
		decl Float:flTargetPos[3];
		GetClientEyePosition(i, flTargetPos);
		
		hTrace = TR_TraceRayFilterEx(flMyEyePos,
			flTargetPos,
			MASK_NPCSOLID,
			RayType_EndPoint,
			TraceRayDontHitEntity,
			slender);
		
		new bool:bTraceDidHit = TR_DidHit(hTrace);
		new iTraceHitEntity = TR_GetEntityIndex(hTrace);
		CloseHandle(hTrace);
		
		if (bTraceDidHit && iTraceHitEntity != i)
		{
			decl Float:flTargetMins[3], Float:flTargetMaxs[3];
			GetEntPropVector(i, Prop_Send, "m_vecMins", flTargetMins);
			GetEntPropVector(i, Prop_Send, "m_vecMaxs", flTargetMaxs);
			GetClientAbsOrigin(i, flTargetPos);
			for (new i2 = 0; i2 < 3; i2++) flTargetPos[i2] += ((flTargetMins[i2] + flTargetMaxs[i2]) / 2.0);
			
			hTrace = TR_TraceRayFilterEx(flMyEyePos,
				flTargetPos,
				MASK_NPCSOLID,
				RayType_EndPoint,
				TraceRayDontHitEntity,
				slender);
				
			bTraceDidHit = TR_DidHit(hTrace);
			iTraceHitEntity = TR_GetEntityIndex(hTrace);
			CloseHandle(hTrace);
		}
		
		if (!bTraceDidHit || iTraceHitEntity == i)
		{
			flTargetDist = GetVectorDistance(flTargetPos, flMyEyePos);
		
			if (flTargetDist <= flAttackRange)
			{
				decl Float:flDirection[3];
				SubtractVectors(flTargetPos, flMyEyePos, flDirection);
				GetVectorAngles(flDirection, flDirection);
				
				if (FloatAbs(AngleDiff(flDirection[1], flMyEyeAng[1])) <= flAttackFOV)
				{
					bHit = true;
					
					Call_StartForward(fOnClientDamagedByBoss);
					Call_PushCell(i);
					Call_PushCell(iBossIndex);
					Call_PushCell(slender);
					Call_PushFloat(flDamage);
					Call_PushCell(iDamageType);
					Call_Finish();
					
					SDKHooks_TakeDamage(i, slender, slender, flDamage, iDamageType);
					ClientViewPunch(i, flViewPunch);
					
					if (SlenderHasAttribute(iBossIndex, "bleed player on hit"))
					{
						new Float:flDuration = SlenderGetAttributeValue(iBossIndex, "bleed player on hit");
						if (flDuration > 0.0)
						{
							TF2_MakeBleed(i, i, flDuration);
						}
					}
					
					// Add stress
					new Float:flStressScalar = flDamage / 125.0;
					if (flStressScalar > 1.0) flStressScalar = 1.0;
					ClientAddStress(i, 0.33 * flStressScalar);
				}
			}
		}
	}
	
	decl String:sSoundPath[PLATFORM_MAX_PATH];
	
	if (bHit)
	{
		GetRandomStringFromProfile(g_strSlenderProfile[iBossIndex], "sound_hitenemy", sSoundPath, sizeof(sSoundPath));
		if (sSoundPath[0]) EmitSoundToAll(sSoundPath, slender, SNDCHAN_AUTO, SNDLEVEL_SCREAMING);
	}
	else
	{
		GetRandomStringFromProfile(g_strSlenderProfile[iBossIndex], "sound_missenemy", sSoundPath, sizeof(sSoundPath));
		if (sSoundPath[0]) EmitSoundToAll(sSoundPath, slender, SNDCHAN_AUTO, SNDLEVEL_SCREAMING);
	}
	
	g_hSlenderAttackTimer[iBossIndex] = CreateTimer(GetProfileFloat(g_strSlenderProfile[iBossIndex], "attack_endafter"), Timer_SlenderChaseBossAttackEnd, entref, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_SlenderChaseBossAttackEnd(Handle:timer, any:entref)
{
	if (!g_bEnabled) return;

	new slender = EntRefToEntIndex(entref);
	if (!slender || slender == INVALID_ENT_REFERENCE) return;
	
	new iBossIndex = SlenderEntIndexToArrayIndex(slender);
	if (iBossIndex == -1) return;
	
	if (timer != g_hSlenderAttackTimer[iBossIndex]) return;
	
	g_bSlenderAttacking[iBossIndex] = false;
	g_hSlenderAttackTimer[iBossIndex] = INVALID_HANDLE;
}

SlenderPerformVoice(iBossIndex, const String:sSectionName[], iIndex=-1)
{
	if (iBossIndex == -1) return;

	new slender = EntRefToEntIndex(g_iSlender[iBossIndex]);
	if (!slender || slender == INVALID_ENT_REFERENCE) return;

	decl String:sPath[PLATFORM_MAX_PATH];
	GetRandomStringFromProfile(g_strSlenderProfile[iBossIndex], sSectionName, sPath, sizeof(sPath), iIndex);
	if (sPath[0])
	{
		decl String:sBuffer[512];
		strcopy(sBuffer, sizeof(sBuffer), sSectionName);
		StrCat(sBuffer, sizeof(sBuffer), "_cooldown_min");
		new Float:flCooldownMin = GetProfileFloat(g_strSlenderProfile[iBossIndex], sBuffer, 1.5);
		strcopy(sBuffer, sizeof(sBuffer), sSectionName);
		StrCat(sBuffer, sizeof(sBuffer), "_cooldown_max");
		new Float:flCooldownMax = GetProfileFloat(g_strSlenderProfile[iBossIndex], sBuffer, 1.5);
		new Float:flCooldown = GetRandomFloat(flCooldownMin, flCooldownMax);
		strcopy(sBuffer, sizeof(sBuffer), sSectionName);
		StrCat(sBuffer, sizeof(sBuffer), "_volume");
		new Float:flVolume = GetProfileFloat(g_strSlenderProfile[iBossIndex], sBuffer, 1.0);
		strcopy(sBuffer, sizeof(sBuffer), sSectionName);
		StrCat(sBuffer, sizeof(sBuffer), "_channel");
		new iChannel = GetProfileNum(g_strSlenderProfile[iBossIndex], sBuffer, SNDCHAN_AUTO);
		strcopy(sBuffer, sizeof(sBuffer), sSectionName);
		StrCat(sBuffer, sizeof(sBuffer), "_level");
		new iLevel = GetProfileNum(g_strSlenderProfile[iBossIndex], sBuffer, SNDLEVEL_SCREAMING);
		
		g_flSlenderNextVoiceSound[iBossIndex] = GetGameTime() + flCooldown;
		EmitSoundToAll(sPath, slender, iChannel, iLevel, _, flVolume);
	}
}

stock Handle:GetPageMusicRanges()
{
	ClearArray(g_hPageMusicRanges);
	
	decl String:sName[64];
	
	new ent = -1;
	while ((ent = FindEntityByClassname(ent, "ambient_generic")) != -1)
	{
		GetEntPropString(ent, Prop_Data, "m_iName", sName, sizeof(sName));
		
		if (sName[0] && !StrContains(sName, "sf2_page_music_", false))
		{
			ReplaceString(sName, sizeof(sName), "sf2_page_music_", "", false);
			
			new String:sPageRanges[2][32];
			ExplodeString(sName, "-", sPageRanges, 2, 32);
			
			new iIndex = PushArrayCell(g_hPageMusicRanges, EntIndexToEntRef(ent));
			if (iIndex != -1)
			{
				new iMin = StringToInt(sPageRanges[0]);
				new iMax = StringToInt(sPageRanges[0]);
				
#if defined DEBUG
				LogMessage("Page range found: entity %d, iMin = %d, iMax = %d", ent, iMin, iMax);
#endif
				SetArrayCell(g_hPageMusicRanges, iIndex, iMin, 1);
				SetArrayCell(g_hPageMusicRanges, iIndex, iMax, 2);
			}
		}
	}
	
	LogMessage("Loaded page music ranges successfully!");
}

SetPageCount(iNum)
{
	if (iNum > g_iPageMax) iNum = g_iPageMax;
	
	new iOldPageCount = g_iPageCount;
	g_iPageCount = iNum;
	
	if (g_iPageCount != iOldPageCount)
	{
		CreateTimer(0.2, Timer_CheckRoundState, _, TIMER_FLAG_NO_MAPCHANGE);
		
		new iGameTextPage = GetTextEntity("sf2_page_message", false);
		if (iGameTextPage == -1) iGameTextPage = GetTextEntity("slender_page_message", false);
		
		new iGameTextEscape = GetTextEntity("sf2_escape_message", false);
		if (iGameTextEscape == -1) iGameTextEscape = GetTextEntity("slender_escape_message", false);
		
		new iClients[MAXPLAYERS + 1] = { -1, ... };
		new iClientsNum = 0;
		
		for (new i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i)) continue;
			if (!g_bPlayerEliminated[i] || g_bPlayerGhostMode[i])
			{
				if (g_iPageCount)
				{
					if (g_bRoundMustEscape && g_iPageCount == g_iPageMax)
					{
						// Escape initialized!
						decl String:sName[32];
						new ent = -1;
						while ((ent = FindEntityByClassname(ent, "info_target")) != -1)
						{
							GetEntPropString(ent, Prop_Data, "m_iName", sName, sizeof(sName));
							if (StrEqual(sName, "sf2_logic_escape", false) ||
								StrEqual(sName, "slender_logic_escape", false))
							{
								AcceptEntityInput(ent, "FireUser1");
								break;
							}
						}
						
						if (iGameTextEscape == -1)
						{
							ClientShowMainMessage(i, "%d/%d\n%T", g_iPageCount, g_iPageMax, "SF2 Default Escape Message", i);
						}
					}
					else 
					{
						if (iGameTextPage == -1)
						{
							ClientShowMainMessage(i, "%d/%d", g_iPageCount, g_iPageMax);
						}
					}
					
					iClients[iClientsNum] = i;
					iClientsNum++;
				}
			}
		}
		
		if (g_bRoundMustEscape && g_iPageCount == g_iPageMax)
		{
			if (iClientsNum)
			{
				if (iGameTextEscape != -1)
				{
					decl String:sMessage[512];
					GetEntPropString(iGameTextEscape, Prop_Data, "m_iszMessage", sMessage, sizeof(sMessage));
					ShowHudTextUsingTextEntity(iClients, iClientsNum, iGameTextEscape, g_hHudSync, sMessage);
				}
			}
		}
		else
		{
			if (iClientsNum)
			{
				if (iGameTextPage != -1)
				{
					decl String:sMessage[512];
					GetEntPropString(iGameTextPage, Prop_Data, "m_iszMessage", sMessage, sizeof(sMessage));
					ShowHudTextUsingTextEntity(iClients, iClientsNum, iGameTextPage, g_hHudSync, sMessage, g_iPageCount, g_iPageMax);
				}
			}
		}
		
		if (g_iPageCount > iOldPageCount)
		{
			if (g_hRoundGraceTimer != INVALID_HANDLE) TriggerTimer(g_hRoundGraceTimer);
			
			g_iRoundTime += g_iRoundTimeGainFromPage;
			if (g_iRoundTime > g_iRoundTimeLimit) g_iRoundTime = g_iRoundTimeLimit;
			
			// Increase anger on selected bosses.
			for (new i = 0; i < MAX_BOSSES; i++)
			{
				if (!g_strSlenderProfile[i][0]) continue;
			
				new Float:flPageDiff = GetProfileFloat(g_strSlenderProfile[i], "anger_page_time_diff");
				if (flPageDiff >= 0.0)
				{
					new iDiff = g_iPageCount - iOldPageCount;
					if ((GetGameTime() - g_flPageFoundLastTime) < flPageDiff)
					{
						g_flSlenderAnger[i] += (GetProfileFloat(g_strSlenderProfile[i], "anger_page_add") * float(iDiff));
					}
				}
			}
			
			if (g_iPageCount == g_iPageMax)
			{
				// Initialize the escape timer.
				if (g_iRoundEscapeTimeLimit > 0)
				{
					g_iRoundTime = g_iRoundEscapeTimeLimit;
					g_hRoundTimer = CreateTimer(1.0, Timer_RoundTimeEscape, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
				}
				else
				{
					g_hRoundTimer = INVALID_HANDLE;
				}
			}
			
			g_flPageFoundLastTime = GetGameTime();
		}
		
		// Notify logic entities.
		decl String:sTargetName[64];
		decl String:sFindTargetName[64];
		Format(sFindTargetName, sizeof(sFindTargetName), "sf2_onpagecount_%d", g_iPageCount);
		
		new ent = -1;
		while ((ent = FindEntityByClassname(ent, "logic_relay")) != -1)
		{
			GetEntPropString(ent, Prop_Data, "m_iName", sTargetName, sizeof(sTargetName));
			if (sTargetName[0] && StrEqual(sTargetName, sFindTargetName, false))
			{
				AcceptEntityInput(ent, "Trigger");
				break;
			}
		}
	}
}

GetTextEntity(const String:sTargetName[], bool:bCaseSensitive=true)
{
	// Try to see if we can use a custom message instead of the default.
	decl String:targetName[64];
	new ent = -1;
	while ((ent = FindEntityByClassname(ent, "game_text")) != -1)
	{
		GetEntPropString(ent, Prop_Data, "m_iName", targetName, sizeof(targetName));
		if (targetName[0])
		{
			if (StrEqual(targetName, sTargetName, bCaseSensitive))
			{
				return ent;
			}
		}
	}
	
	return -1;
}

ShowHudTextUsingTextEntity(const iClients[], iClientsNum, iGameText, Handle:hHudSync, const String:sMessage[], ...)
{
	if (!sMessage[0]) return;
	if (!IsValidEntity(iGameText)) return;
	
	decl String:sTrueMessage[512];
	VFormat(sTrueMessage, sizeof(sTrueMessage), sMessage, 6);
	
	new Float:flX = GetEntPropFloat(iGameText, Prop_Data, "m_textParms.x");
	new Float:flY = GetEntPropFloat(iGameText, Prop_Data, "m_textParms.y");
	new iEffect = GetEntProp(iGameText, Prop_Data, "m_textParms.effect");
	new Float:flFadeInTime = GetEntPropFloat(iGameText, Prop_Data, "m_textParms.fadeinTime");
	new Float:flFadeOutTime = GetEntPropFloat(iGameText, Prop_Data, "m_textParms.fadeoutTime");
	new Float:flHoldTime = GetEntPropFloat(iGameText, Prop_Data, "m_textParms.holdTime");
	new Float:flFxTime = GetEntPropFloat(iGameText, Prop_Data, "m_textParms.fxTime");
	
	new Color1[4], Color2[4];
	/*
	Color1[0] = GetEntProp(iGameText, Prop_Data, "m_textParms.r1");
	Color1[1] = GetEntProp(iGameText, Prop_Data, "m_textParms.g1");
	Color1[2] = GetEntProp(iGameText, Prop_Data, "m_textParms.b1");
	Color1[3] = GetEntProp(iGameText, Prop_Data, "m_textParms.a1");
	Color2[0] = GetEntProp(iGameText, Prop_Data, "m_textParms.r2");
	Color2[1] = GetEntProp(iGameText, Prop_Data, "m_textParms.g2");
	Color2[2] = GetEntProp(iGameText, Prop_Data, "m_textParms.b2");
	Color2[3] = GetEntProp(iGameText, Prop_Data, "m_textParms.a2");
	*/
	for (new i = 0; i < 4; i++)
	{
		Color1[i] = 255;
		Color2[i] = 255;
	}
	
	
	SetHudTextParamsEx(flX, flY, flHoldTime, Color1, Color2, iEffect, flFxTime, flFadeInTime, flFadeOutTime);
	
	for (new i = 0; i < iClientsNum; i++)
	{
		new iClient = iClients[i];
		if (!IsValidClient(iClient) || IsFakeClient(iClient)) continue;
		
		ShowSyncHudText(iClient, hHudSync, sTrueMessage);
	}
}

//	==========================================================
//	EVENT HOOKS
//	==========================================================

public Event_RoundStart(Handle:event, const String:name[], bool:dB)
{
	if (!g_bEnabled) return;
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("EVENT START: Event_RoundStart");
#endif
	
	InitializeNewGame();
	
	if (g_bRoundWaitingForPlayers)
	{
	}
	else if (g_bRoundWarmup)
	{
		ServerCommand("mp_restartgame 15");
		PrintCenterTextAll("Round restarting in 15 seconds");
	}
	else
	{
		CreateTimer(2.0, Timer_RoundStart, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("EVENT END: Event_RoundStart");
#endif
}

public Event_RoundEnd(Handle:event, const String:name[], bool:dB)
{
	if (!g_bEnabled) return;
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("EVENT START: Event_RoundEnd");
#endif
	
	g_bRoundEnded = true;
	g_hRoundGraceTimer = INVALID_HANDLE;
	g_hRoundTimer = INVALID_HANDLE;
	
	// Remove all bosses.
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		RemoveSlender(i);
	}
	
	decl String:sTargetName[64];
	new Float:flPos[3], Float:flAng[3];
	new iEscapePoint = -1;
	new ent = -1;
	while ((ent = FindEntityByClassname(ent, "info_target")) != -1)
	{
		GetEntPropString(ent, Prop_Data, "m_iName", sTargetName, sizeof(sTargetName));
		if (!StrContains(sTargetName, "sf2_escape_spawnpoint", false) || 
			!StrContains(sTargetName, "slender_escape_spawnpoint", false))
		{
			iEscapePoint = ent;
			GetEntPropVector(ent, Prop_Data, "m_vecAbsOrigin", flPos);
			GetEntPropVector(ent, Prop_Data, "m_angAbsRotation", flAng);
			break;
		}
	}
	
	// Give away queue points.
	
	new iDefaultAmount = 5;
	new iAmount = iDefaultAmount;
	new iAmount2 = iAmount;
	new Action:iAction = Plugin_Continue;
	
	for (new i = 0; i < SF2_MAX_PLAYER_GROUPS; i++)
	{
		if (!IsPlayerGroupActive(i)) continue;
		
		if (IsPlayerGroupPlaying(i))
		{
			SetPlayerGroupQueuePoints(i, 0);
		}
		else
		{
			iAmount = iDefaultAmount;
			iAmount2 = iAmount;
			iAction = Plugin_Continue;
			
			Call_StartForward(fOnGroupGiveQueuePoints);
			Call_PushCell(i);
			Call_PushCellRef(iAmount2);
			Call_Finish(iAction);
			
			if (iAction == Plugin_Changed) iAmount = iAmount2;
			
			SetPlayerGroupQueuePoints(i, GetPlayerGroupQueuePoints(i) + iAmount);
		
			for (new iClient = 1; iClient <= MaxClients; iClient++)
			{
				if (!IsValidClient(iClient)) continue;
				if (ClientGetPlayerGroup(iClient) == i)
				{
					CPrintToChat(iClient, "%T", "SF2 Give Group Queue Points", iClient, iAmount);
				}
			}
		}
	}
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i)) continue;
		
		if (!g_bRoundMustEscape)
		{
			if (!g_bPlayerEliminated[i])
			{
				if (iEscapePoint != -1)
				{
					TeleportEntity(i, flPos, flAng, NULL_VECTOR);
				}
			}
		}
		
		if (g_bPlayerPlaying[i]) 
		{
			ClientSetQueuePoints(i, 0);
		}
		else
		{
			if (!IsClientParticipating(i))
			{
				CPrintToChat(i, "%T", "SF2 No Queue Points To Spectator", i);
			}
			else
			{
				iAmount = iDefaultAmount;
				iAmount2 = iAmount;
				iAction = Plugin_Continue;
				
				Call_StartForward(fOnClientGiveQueuePoints);
				Call_PushCell(i);
				Call_PushCellRef(iAmount2);
				Call_Finish(iAction);
				
				if (iAction == Plugin_Changed) iAmount = iAmount2;
				
				ClientSetQueuePoints(i, g_iPlayerQueuePoints[i] + iAmount);
				CPrintToChat(i, "%T", "SF2 Give Queue Points", i, iAmount);
			}
		}
		
		if (g_bPlayerGhostMode[i])
		{
			ClientDisableGhostMode(i);
			TF2_RespawnPlayer(i);
		}
		else if (g_bPlayerProxy[i])
		{
			TF2_RespawnPlayer(i);
		}
		
		if (!g_bPlayerEliminated[i])
		{
			TF2_RegeneratePlayer(i); // Give them back all their weapons so they can beat the crap out of the other team.
		}
		
		ClientUpdateListeningFlags(i);
	}
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("EVENT END: Event_RoundEnd");
#endif
	
}

public Action:Event_PlayerTeamPre(Handle:event, const String:name[], bool:dB)
{
	if (!g_bEnabled) return Plugin_Continue;

#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 1) DebugMessage("EVENT START: Event_PlayerTeamPre");
#endif
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client > 0)
	{
		if (GetEventInt(event, "team") > 1 || GetEventInt(event, "oldteam") > 1) SetEventBroadcast(event, true);
	}
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 1) DebugMessage("EVENT END: Event_PlayerTeamPre");
#endif
	
	return Plugin_Continue;
}

public Event_PlayerTeam(Handle:event, const String:name[], bool:dB)
{
	if (!g_bEnabled) return;
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("EVENT START: Event_PlayerTeam");
#endif
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client > 0)
	{
		new iNewTeam = GetEventInt(event, "team");
		if (iNewTeam <= _:TFTeam_Spectator)
		{
			if (g_bRoundGrace)
			{
				if (g_bPlayerPlaying[client] && !g_bPlayerEliminated[client])
				{
					ForceInNextPlayersInQueue(1, true);
				}
			}
			
			// You're not playing anymore.
			if (g_bPlayerPlaying[client])
			{
				ClientSetQueuePoints(client, 0);
			}
			
			g_bPlayerPlaying[client] = false;
			g_bPlayerEliminated[client] = true;
			g_bPlayerEscaped[client] = false;
			ClientDisableGhostMode(client);
			TF2_RespawnPlayer(client);
			
			// Special round.
			if (g_bSpecialRound) g_bPlayerDidSpecialRound[client] = true;
			
			// Boss round.
			if (g_bBossRound) g_bPlayerDidBossRound[client] = true;
		}
		else
		{
			if (!g_bPlayerChoseTeam[client])
			{
				g_bPlayerChoseTeam[client] = true;
				
				if (g_bPlayerFlashlightProjected[client])
				{
					EmitSoundToClient(client, PJSOUND);
					CPrintToChat(client, "{olive}Your flashlight mode has been set to {lightgreen}Projected{olive}.");
				}
				else
				{
					CPrintToChat(client, "{olive}Your flashlight mode has been set to {lightgreen}Normal{olive}.");
				}
				
				CreateTimer(5.0, Timer_WelcomeMessage, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
	
	// Check groups.
	if (!g_bRoundEnded)
	{
		for (new i = 0; i < SF2_MAX_PLAYER_GROUPS; i++)
		{
			if (!IsPlayerGroupActive(i)) continue;
			CheckPlayerGroup(i);
		}
	}
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("EVENT END: Event_PlayerTeam");
#endif

}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dB)
{
	if (!g_bEnabled) return;
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("EVENT START: Event_PlayerSpawn");
#endif
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client > 0)
	{
		InitializeClient(client);
		
		if (!IsClientParticipating(client))
		{
			ClientDisableGhostMode(client);
		}
		
		if (IsPlayerAlive(client))
		{
			SetVariantString("");
			AcceptEntityInput(client, "SetCustomModel");
			
			ClientResetDeathCam(client);
			
			g_hPlayerOverlayCheck[client] = CreateTimer(0.1, Timer_PlayerOverlayCheck, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
			TriggerTimer(g_hPlayerOverlayCheck[client], true);
			
			if (g_bPlayerGhostMode[client])
			{
				ClientEnableGhostMode(client);
			}
			
			if ((g_bRoundWarmup || 
				g_bPlayerEliminated[client] || 
				g_bPlayerEscaped[client]) && 
				!g_bPlayerGhostMode[client] &&
				!g_bPlayerProxy[client])
			{
				SetEntProp(client, Prop_Send, "m_iHideHUD", 0);
			}
			else
			{
				SetEntProp(client, Prop_Send, "m_iHideHUD", HIDEHUD_CROSSHAIR | HIDEHUD_HEALTH);
			}
			
			if (!g_bPlayerEliminated[client])
			{
				if (GetClientTeam(client) != _:TFTeam_Red)
				{
					ChangeClientTeamNoSuicide(client, _:TFTeam_Red);
				}
				else 
				{
					ClientCreateProxyGlow(client, "head");
					
					g_hPlayerCampingTimer[client] = CreateTimer(5.0, Timer_ClientCheckCamp, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
					g_hPlayerBlinkTimer[client] = CreateTimer(GetClientBlinkRate(client), Timer_BlinkTimer, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
					CreateTimer(0.1, Timer_CheckEscapedPlayer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
				}
			}
			else
			{
				ClientRemoveProxyGlow(client);
				
				if (GetClientTeam(client) != _:TFTeam_Blue)
				{
					ChangeClientTeamNoSuicide(client, _:TFTeam_Blue);
				}
			}
			
			CreateTimer(0.1, Timer_ClientPostWeapons, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
			CreateTimer(0.12, Timer_TeleportPlayerToPvP, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
			
			// Remove any conditions that linger due to mediguns.
			TF2_RemoveCondition(client, TFCond_MegaHeal); // Quick-Fix
			TF2_RemoveCondition(client, TFCond_UberBulletResist); // Vaccinator
			TF2_RemoveCondition(client, TFCond_UberBlastResist);
			TF2_RemoveCondition(client, TFCond_UberFireResist);
			TF2_RemoveCondition(client, TFCond_SmallBulletResist);
			TF2_RemoveCondition(client, TFCond_SmallBlastResist);
			TF2_RemoveCondition(client, TFCond_SmallFireResist);
		}
	}
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("EVENT END: Event_PlayerSpawn");
#endif
}

public Event_PostInventoryApplication(Handle:event, const String:name[], bool:dB)
{
	if (!g_bEnabled) return;
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 1) DebugMessage("EVENT START: Event_PostInventoryApplication");
#endif
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client > 0)
	{
		CreateTimer(0.1, Timer_ClientPostWeapons, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 1) DebugMessage("EVENT END: Event_PostInventoryApplication");
#endif
}

public Action:Event_TrueBroadcast(Handle:event, const String:name[], bool:dB)
{
	if (!g_bEnabled) return Plugin_Continue;
	if (g_bRoundWarmup) return Plugin_Continue;
	
	SetEventBroadcast(event, true);
	return Plugin_Continue;
}

public Action:Event_PlayerDeathPre(Handle:event, const String:name[], bool:dB)
{
	if (!g_bEnabled) return Plugin_Continue;
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 1) DebugMessage("EVENT START: Event_PlayerDeathPre");
#endif
	
	if (!g_bRoundWarmup)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		if (client > 0)
		{
			if (!g_bRoundEnded)
			{
				if (g_bRoundGrace || g_bPlayerEliminated[client] || g_bPlayerGhostMode[client])
				{
					SetEventBroadcast(event, true);
				}
			}
		}
	}
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 1) DebugMessage("EVENT END: Event_PlayerDeathPre");
#endif
	
	return Plugin_Continue;
}

public Event_PlayerHurt(Handle:event, const String:name[], bool:dB)
{
	if (!g_bEnabled) return;
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 1) DebugMessage("EVENT START: Event_PlayerHurt");
#endif
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client > 0)
	{
		ClientDisableFakeLagCompensation(client);
		
		new iMaster = SlenderGetFromID(g_iPlayerProxyMaster[client]);
		
		// Play any sounds, if any.
		if (g_bPlayerProxy[client] && iMaster != -1)
		{
			decl String:sBuffer[PLATFORM_MAX_PATH];
			if (GetRandomStringFromProfile(g_strSlenderProfile[iMaster], "sound_proxy_hurt", sBuffer, sizeof(sBuffer)) && sBuffer[0])
			{
				new iChannel = GetProfileNum(g_strSlenderProfile[iMaster], "sound_proxy_hurt_channel", SNDCHAN_AUTO);
				new iLevel = GetProfileNum(g_strSlenderProfile[iMaster], "sound_proxy_hurt_level", SNDLEVEL_NORMAL);
				new iFlags = GetProfileNum(g_strSlenderProfile[iMaster], "sound_proxy_hurt_flags", SND_NOFLAGS);
				new Float:flVolume = GetProfileFloat(g_strSlenderProfile[iMaster], "sound_proxy_hurt_volume", SNDVOL_NORMAL);
				new iPitch = GetProfileNum(g_strSlenderProfile[iMaster], "sound_proxy_hurt_pitch", SNDPITCH_NORMAL);
				
				EmitSoundToAll(sBuffer, client, iChannel, iLevel, iFlags, flVolume, iPitch);
			}
		}
		
		new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
		if (attacker > 0)
		{
			if (g_bPlayerProxy[attacker])
			{
				g_iPlayerProxyControl[attacker] = 100;
			}
		}
	}
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 1) DebugMessage("EVENT END: Event_PlayerHurt");
#endif
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dB)
{
	if (!g_bEnabled) return;
	
#if defined DEBUG
	DebugMessage("EVENT START: Event_PlayerDeath");
#endif
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client > 0)
	{
		if (!(GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER))
		{
			ClientDisableFakeLagCompensation(client);
			
			ClientResetStatic(client);
			ClientResetSlenderStats(client);
			ClientResetFlashlight(client);
			ClientResetUltravision(client);
			ClientResetCampingStats(client);
			ClientResetBlink(client);
			ClientResetOverlay(client);
			ClientResetJumpScare(client);
			ClientResetGlow(client);
			ClientResetProxyGlow(client);
			ClientMusicReset(client);
			ClientChaseMusicReset(client);
			ClientChaseMusicSeeReset(client);
			ClientAlertMusicReset(client);
			ClientResetDeathCam(client);
			ClientResetPvP(client);
			ClientResetSprint(client);
			ClientResetBreathing(client);
			
			ClientUpdateMusicSystem(client);
			
			if (g_bRoundWarmup)
			{
				CreateTimer(0.3, Timer_RespawnPlayer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
			}
			else
			{
				if (!g_bPlayerEliminated[client] && (g_bRoundGrace || g_bPlayerEscaped[client])) 
				{
					CreateTimer(0.3, Timer_RespawnPlayer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
				}
				else
				{
					if (g_bPlayerEliminated[client] && !g_bPlayerGhostMode[client] && g_bPlayerInPvPSpawning[client])
					{
						CreateTimer(0.3, Timer_RespawnPlayer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
					}
					
					g_bPlayerEliminated[client] = true;
					g_bPlayerEscaped[client] = false;
					
					CreateTimer(0.2, Timer_CheckRoundState, _, TIMER_FLAG_NO_MAPCHANGE);
					g_hPlayerSwitchBlueTimer[client] = CreateTimer(0.5, Timer_PlayerSwitchToBlue, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
					
					for (new i = 0; i < MAX_BOSSES; i++)
					{
						if (g_iSlenderID[i] == -1) continue;
						
						if (EntRefToEntIndex(g_iSlenderTarget[i]) == client)
						{
							g_iSlenderInterruptConditions[i] |= COND_CHASETARGETINVALIDATED;
							GetClientAbsOrigin(client, g_flSlenderChaseDeathPosition[i]);
						}
					}
				}
			}
			
			new iMaster = SlenderGetFromID(g_iPlayerProxyMaster[client]);
			
			// Play any sounds, if any.
			if (g_bPlayerProxy[client] && iMaster != -1)
			{
				decl String:sBuffer[PLATFORM_MAX_PATH];
				if (GetRandomStringFromProfile(g_strSlenderProfile[iMaster], "sound_proxy_death", sBuffer, sizeof(sBuffer)) && sBuffer[0])
				{
					new iChannel = GetProfileNum(g_strSlenderProfile[iMaster], "sound_proxy_death_channel", SNDCHAN_AUTO);
					new iLevel = GetProfileNum(g_strSlenderProfile[iMaster], "sound_proxy_death_level", SNDLEVEL_NORMAL);
					new iFlags = GetProfileNum(g_strSlenderProfile[iMaster], "sound_proxy_death_flags", SND_NOFLAGS);
					new Float:flVolume = GetProfileFloat(g_strSlenderProfile[iMaster], "sound_proxy_death_volume", SNDVOL_NORMAL);
					new iPitch = GetProfileNum(g_strSlenderProfile[iMaster], "sound_proxy_death_pitch", SNDPITCH_NORMAL);
					
					EmitSoundToAll(sBuffer, client, iChannel, iLevel, iFlags, flVolume, iPitch);
				}
			}
			
			ClientResetProxy(client, false);
			ClientUpdateListeningFlags(client);
			
			// Half-Zatoichi nerf code.
			new iKatanaHealthGain = GetConVarInt(g_cvHalfZatoichiHealthGain);
			if (iKatanaHealthGain >= 0)
			{
				new iAttacker = GetClientOfUserId(GetEventInt(event, "attacker"));
				if (iAttacker > 0)
				{
					if (!IsClientInPvP(iAttacker) && (!g_bPlayerEliminated[iAttacker] || g_bPlayerProxy[iAttacker]))
					{
						decl String:sWeapon[64];
						GetEventString(event, "weapon", sWeapon, sizeof(sWeapon));
						
						if (StrEqual(sWeapon, "demokatana"))
						{
							new iAttackerPreHealth = GetEntProp(iAttacker, Prop_Send, "m_iHealth");
							new Handle:hPack = CreateDataPack();
							WritePackCell(hPack, GetClientUserId(iAttacker));
							WritePackCell(hPack, iAttackerPreHealth + iKatanaHealthGain);
							
							CreateTimer(0.0, Timer_SetPlayerHealth, hPack, TIMER_FLAG_NO_MAPCHANGE);
						}
					}
				}
			}
		}
	}
	
#if defined DEBUG
	DebugMessage("EVENT END: Event_PlayerDeath");
#endif
}

public Action:Timer_SetPlayerHealth(Handle:timer, any:data)
{
	new Handle:hPack = Handle:data;
	ResetPack(hPack);
	new iAttacker = GetClientOfUserId(ReadPackCell(hPack));
	new iHealth = ReadPackCell(hPack);
	CloseHandle(hPack);
	
	if (iAttacker <= 0) return;
	
	SetEntProp(iAttacker, Prop_Data, "m_iHealth", iHealth);
	SetEntProp(iAttacker, Prop_Send, "m_iHealth", iHealth);
}

public Action:Timer_PlayerSwitchToBlue(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client <= 0) return;
	
	if (timer != g_hPlayerSwitchBlueTimer[client]) return;
	
	ChangeClientTeam(client, _:TFTeam_Blue);
}

public Action:Timer_RoundStart(Handle:timer)
{
	if (g_iPageMax > 0)
	{
		new Handle:hArrayClients = CreateArray();
		new iClients[MAXPLAYERS + 1];
		new iClientsNum = 0;
		
		new iGameText = GetTextEntity("sf2_intro_message", false);
		if (iGameText == -1)
		{
			iGameText = GetTextEntity("slender_intro_message", false);
		}
		
		for (new i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i) || g_bPlayerEliminated[i]) continue;
			
			if (iGameText == -1)
			{
				if (g_iPageMax > 1)
				{
					ClientShowMainMessage(i, "%T", "SF2 Default Intro Message Plural", i, g_iPageMax);
				}
				else
				{
					ClientShowMainMessage(i, "%T", "SF2 Default Intro Message Singular", i, g_iPageMax);
				}
			}
			
			PushArrayCell(hArrayClients, GetClientUserId(i));
			iClients[iClientsNum] = i;
			iClientsNum++;
		}
		
		// Show difficulty menu.
		if (iClientsNum)
		{
			// Automatically set it to Normal.
			SetConVarInt(g_cvDifficulty, Difficulty_Normal);
			
			g_hVoteTimer = CreateTimer(1.0, Timer_VoteDifficulty, hArrayClients, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
			TriggerTimer(g_hVoteTimer, true);
			
			if (iGameText != -1)
			{
				decl String:sMessage[512];
				GetEntPropString(iGameText, Prop_Data, "m_iszMessage", sMessage, sizeof(sMessage));
				
				ShowHudTextUsingTextEntity(iClients, iClientsNum, iGameText, g_hHudSync, sMessage);
			}
		}
	}
}

public Action:Timer_CheckRoundState(Handle:timer)
{
	CheckRoundState();
}

public Action:Timer_TeleportPlayerToPvP(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client <= 0) return;

	if (!g_bPlayerEliminated[client] && !g_bPlayerEscaped[client]) return;
	
	if (g_bPlayerGhostMode[client]) return;
	
	if (g_bPlayerProxy[client]) return; // Proxy mode not allowed.
	
	if (!g_bPlayerInPvPSpawning[client]) return;
	
	if (!IsClientParticipating(client)) return;
	
	new Handle:hArray = CreateArray();
	
	new ent = -1;
	while ((ent = FindEntityByClassname(ent, "info_target")) != -1)
	{
		decl String:sName[32];
		GetEntPropString(ent, Prop_Data, "m_iName", sName, sizeof(sName));
		if (!StrContains(sName, "sf2_pvp_spawnpoint", false))
		{
			PushArrayCell(hArray, ent);
		}
	}
	
	decl Float:flMins[3], Float:flMaxs[3];
	GetEntPropVector(client, Prop_Send, "m_vecMins", flMins);
	GetEntPropVector(client, Prop_Send, "m_vecMaxs", flMaxs);
	
	new Handle:hArrayHull = CloneArray(hArray);
	for (new i = 0; i < GetArraySize(hArray); i++)
	{
		new iEnt = GetArrayCell(hArray, i);
		
		decl Float:flMyPos[3];
		GetEntPropVector(iEnt, Prop_Data, "m_vecAbsOrigin", flMyPos);
		
		if (IsSpaceOccupiedPlayer(flMyPos, flMins, flMaxs, client))
		{
			new iIndex = FindValueInArray(hArrayHull, iEnt);
			if (iIndex != -1)
			{
				RemoveFromArray(hArrayHull, iIndex);
			}
		}
	}
	
	new iNum;
	if ((iNum = GetArraySize(hArrayHull)) > 0)
	{
		ent = GetArrayCell(hArrayHull, GetRandomInt(0, iNum - 1));
	}
	else if ((iNum = GetArraySize(hArray)) > 0)
	{
		ent = GetArrayCell(hArray, GetRandomInt(0, iNum - 1));
	}
	
	if (iNum > 0)
	{
		decl Float:flPos[3], Float:flAng[3];
		GetEntPropVector(ent, Prop_Data, "m_vecAbsOrigin", flPos);
		GetEntPropVector(ent, Prop_Data, "m_angAbsRotation", flAng);
		TeleportEntity(client, flPos, flAng, Float:{ 0.0, 0.0, 0.0 });
		
		EmitAmbientSound(PVP_SPAWN_SOUND, flPos, _, SNDLEVEL_NORMAL, _, 1.0);
	}
	
	CloseHandle(hArray);
	CloseHandle(hArrayHull);
}

public Action:Timer_RoundGrace(Handle:timer)
{
	if (timer != g_hRoundGraceTimer) return;
	
	g_bRoundGrace = false;
	g_hRoundGraceTimer = INVALID_HANDLE;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientParticipating(i)) g_bPlayerEliminated[i] = true;
	}
	
	// Initialize the main round timer.
	if (g_iRoundTimeLimit > 0)
	{
		g_iRoundTime = g_iRoundTimeLimit;
		g_hRoundTimer = CreateTimer(1.0, Timer_RoundTime, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		g_hRoundTimer = INVALID_HANDLE;
	}
	
	CPrintToChatAll("{olive}%t", "SF2 Grace Period End");
}

public Action:Timer_RoundTime(Handle:timer)
{
	if (timer != g_hRoundTimer) return Plugin_Stop;
	
	if (g_iRoundTime <= 0)
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || !IsPlayerAlive(i) || g_bPlayerEliminated[i] || g_bPlayerGhostMode[i]) continue;
			
			decl Float:flBuffer[3];
			GetClientAbsOrigin(i, flBuffer);
			SDKHooks_TakeDamage(i, 0, 0, 9001.0, 0x80 | DMG_PREVENT_PHYSICS_FORCE, _, Float:{ 0.0, 0.0, 0.0 });
		}
		
		return Plugin_Stop;
	}
	
	g_iRoundTime--;
	
	new hours, minutes, seconds;
	FloatToTimeHMS(float(g_iRoundTime), hours, minutes, seconds);
	
	SetHudTextParams(-1.0, 0.1, 
		1.0,
		SF2_HUD_TEXT_COLOR_R, SF2_HUD_TEXT_COLOR_G, SF2_HUD_TEXT_COLOR_B, SF2_HUD_TEXT_COLOR_A,
		_,
		_,
		1.5, 1.5);
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || (g_bPlayerEliminated[i] && !g_bPlayerGhostMode[i])) continue;
		ShowSyncHudText(i, g_hRoundTimerSync, "%d/%d\n%d:%02d", g_iPageCount, g_iPageMax, minutes, seconds);
	}
	
	return Plugin_Continue;
}

public Action:Timer_RoundTimeEscape(Handle:timer)
{
	if (timer != g_hRoundTimer) return Plugin_Stop;
	
	if (g_iRoundTime <= 0)
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || !IsPlayerAlive(i) || g_bPlayerEliminated[i] || g_bPlayerGhostMode[i] || g_bPlayerEscaped[i]) continue;
			
			decl Float:flBuffer[3];
			GetClientAbsOrigin(i, flBuffer);
			ClientStartDeathCam(i, 0, flBuffer);
		}
		
		return Plugin_Stop;
	}
	
	new hours, minutes, seconds;
	FloatToTimeHMS(float(g_iRoundTime), hours, minutes, seconds);
	
	SetHudTextParams(-1.0, 0.1, 
		1.0,
		SF2_HUD_TEXT_COLOR_R, 
		SF2_HUD_TEXT_COLOR_G, 
		SF2_HUD_TEXT_COLOR_B, 
		SF2_HUD_TEXT_COLOR_A,
		_,
		_,
		1.5, 1.5);
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || (g_bPlayerEliminated[i] && !g_bPlayerGhostMode[i])) continue;
		ShowSyncHudText(i, g_hRoundTimerSync, "%T\n%d:%02d", "SF2 Default Escape Message", i, minutes, seconds);
	}
	
	g_iRoundTime--;
	
	return Plugin_Continue;
}

public Action:Timer_VoteDifficulty(Handle:timer, any:data)
{
	new Handle:hArrayClients = Handle:data;
	
	if (timer != g_hVoteTimer || g_bRoundEnded) 
	{
		CloseHandle(hArrayClients);
		return Plugin_Stop;
	}
	
	if (IsVoteInProgress()) return Plugin_Continue;
	
	new iClients[MAXPLAYERS + 1] = { -1, ... };
	new iClientsNum;
	for (new i = 0, iSize = GetArraySize(hArrayClients); i < iSize; i++)
	{
		new iClient = GetClientOfUserId(GetArrayCell(hArrayClients, i));
		if (iClient <= 0) continue;
		
		iClients[iClientsNum] = iClient;
		iClientsNum++;
	}
	
	CloseHandle(hArrayClients);
	
	VoteMenu(g_hMenuVoteDifficulty, iClients, iClientsNum, 15);
	
	return Plugin_Stop;
}

InitializeNewGame()
{
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("START InitializeNewGame()");
#endif

	SetPageCount(0);
	g_iPageMax = 0;
	g_flPageFoundLastTime = GetGameTime();
	g_iRoundCount++;
	g_bRoundEnded = false;
	g_bRoundWarmup = true;
	g_bRoundGrace = true;
	g_bRoundMustEscape = false;
	g_hRoundGraceTimer = CreateTimer(GetConVarFloat(g_cvGraceTime), Timer_RoundGrace, _, TIMER_FLAG_NO_MAPCHANGE);
	g_bRoundInfiniteFlashlight = false;
	g_bRoundInfiniteBlink = false;
	g_hRoundTimer = INVALID_HANDLE;
	g_iRoundTimeLimit = GetConVarInt(g_cvTimeLimit);
	g_iRoundEscapeTimeLimit = GetConVarInt(g_cvTimeLimitEscape);
	g_iRoundTimeGainFromPage = GetConVarInt(g_cvTimeGainFromPageGrab);
	g_hVoteTimer = INVALID_HANDLE;
	
	// Reset the boss profiles.
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		RemoveProfile(i);
	}
	
	if (g_iRoundCount <= 1)
	{
		SetConVarString(g_cvProfileOverride, "");
	}
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("InitializeNewGame(): Determine warmup round state");
#endif
	
	if (GetConVarBool(g_cvWarmupRound) && g_iRoundCount < 4)
	{
		g_bRoundWarmup = true;
	}
	else
	{
		g_bRoundWarmup = false;
	}
	
	if (g_bRoundWarmup)
	{
		g_hRoundGraceTimer = INVALID_HANDLE;
		return;
	}
	
	decl String:buffer[64];
	new iCount;
	
	// Determine special round state.

#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("InitializeNewGame(): Special round check");
#endif
	
	g_bSpecialRoundNew = false;
	
	if (!g_bSpecialRound)
	{
		g_iSpecialRoundCount++;
		
		if (GetConVarInt(g_cvSpecialRoundInterval) > 0)
		{
			iCount = g_iSpecialRoundCount;
			while (iCount > 0) iCount -= GetConVarInt(g_cvSpecialRoundInterval);
			if (iCount == 0) 
			{
				g_bSpecialRound = true;
				g_bSpecialRoundNew = true;
			}
		}
	}
	else
	{
		if (GetConVarInt(g_cvSpecialRoundBehavior) == 0)
		{
			g_bSpecialRound = false;
		}
		else
		{
			new iSpecialCount;
			for (new i = 1; i <= MaxClients; i++)
			{
				if (!IsClientInGame(i)) continue;
				
				if (!g_bPlayerDidSpecialRound[i] && IsClientParticipating(i))
				{
					iSpecialCount++;
				}
			}
			
			if (!iSpecialCount) 
			{
				g_bSpecialRound = false;
			}
			else
			{
				g_bSpecialRoundNew = false;
			}
		}
	}
	
	// Do special round force override and reset it.
	if (GetConVarInt(g_cvSpecialRoundForce) >= 0)
	{
		g_bSpecialRound = GetConVarBool(g_cvSpecialRoundForce);
		SetConVarInt(g_cvSpecialRoundForce, -1);
		
		if (g_bSpecialRound)
		{
			g_bSpecialRoundNew = true;
		}
	}
	
	// Was a new special round initialized?
	if (g_bSpecialRound)
	{
		if (g_bSpecialRoundNew)
		{
			g_iSpecialRoundCount = 0; // Reset round count
			
			SpecialRoundCycleStart();
			
			// Reset all players' values.
			for (new i = 1; i <= MaxClients; i++)
			{
				if (!IsClientParticipating(i))
				{
					g_bPlayerDidSpecialRound[i] = true;
					continue;
				}
				
				g_bPlayerDidSpecialRound[i] = false;
			}
		}
		else
		{
			SpecialRoundStart();
		
			CreateTimer(3.0, Timer_DisplaySpecialRound, _, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	else
	{
		SpecialRoundReset();
	}
	
	// Initialize pages and entities.
	GetPageMusicRanges();
	
	if (GetArraySize(g_hPageMusicRanges) > 0)
	{
		for (new i = 0; i < GetArraySize(g_hPageMusicRanges); i++)
		{
			new ent = EntRefToEntIndex(GetArrayCell(g_hPageMusicRanges, i));
			if (!ent || ent == INVALID_ENT_REFERENCE) continue;
			
			decl String:sPath[PLATFORM_MAX_PATH];
			GetEntPropString(ent, Prop_Data, "m_iszSound", sPath, sizeof(sPath));
			if (sPath[0])
			{
				PrecacheSound(sPath);
			}
		}
	}
	
	// Reset page reference.
	g_bPageRef = false;
	strcopy(g_strPageRefModel, sizeof(g_strPageRefModel), "");
	g_flPageRefModelScale = 1.0;
	
	new Handle:hArray = CreateArray(2);
	new Handle:hPageTrie = CreateTrie();
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("InitializeNewGame(): Parsing through map entities");
#endif
	
	decl String:targetName[64];
	new ent = -1;
	while ((ent = FindEntityByClassname(ent, "info_target")) != -1)
	{
		GetEntPropString(ent, Prop_Data, "m_iName", targetName, sizeof(targetName));
		if (targetName[0])
		{
			if (!StrContains(targetName, "sf2_maxpages_", false) ||
				!StrContains(targetName, "slender_logic_numpages_", false))
			{
				ReplaceString(targetName, sizeof(targetName), "sf2_maxpages_", "", false);
				ReplaceString(targetName, sizeof(targetName), "slender_logic_numpages_", "", false);
				g_iPageMax = StringToInt(targetName);
			}
			else if (!StrContains(targetName, "sf2_page_spawnpoint", false) ||
				!StrContains(targetName, "slender_page_spawn", false))
			{
				if (!StrContains(targetName, "sf2_page_spawnpoint_", false))
				{
					ReplaceString(targetName, sizeof(targetName), "sf2_page_spawnpoint_", "", false);
					if (targetName[0])
					{
						new Handle:hButtStallion = INVALID_HANDLE;
						if (!GetTrieValue(hPageTrie, targetName, hButtStallion))
						{
							hButtStallion = CreateArray();
							SetTrieValue(hPageTrie, targetName, hButtStallion);
						}
						
						new iIndex = FindValueInArray(hArray, hButtStallion);
						if (iIndex == -1)
						{
							iIndex = PushArrayCell(hArray, hButtStallion);
						}
						
						PushArrayCell(hButtStallion, ent);
						SetArrayCell(hArray, iIndex, true, 1);
					}
					else
					{
						new iIndex = PushArrayCell(hArray, ent);
						SetArrayCell(hArray, iIndex, false, 1);
					}
				}
				else
				{
					new iIndex = PushArrayCell(hArray, ent);
					SetArrayCell(hArray, iIndex, false, 1);
				}
			}
			else if (!StrContains(targetName, "sf2_logic_escape", false) ||
				!StrContains(targetName, "slender_logic_escape", false))
			{
				g_bRoundMustEscape = true;
			}
			else if (!StrContains(targetName, "sf2_infiniteflashlight", false) ||
				!StrContains(targetName, "slender_logic_infiniteflashlight", false))
			{
				g_bRoundInfiniteFlashlight = true;
			}
			else if (!StrContains(targetName, "sf2_infiniteblink", false) ||
				!StrContains(targetName, "slender_logic_infiniteblink", false))
			{
				g_bRoundInfiniteBlink = true;
			}
			else if (!StrContains(targetName, "sf2_time_limit_", false) ||
				!StrContains(targetName, "slender_time_limit_", false))
			{
				ReplaceString(targetName, sizeof(targetName), "sf2_time_limit_", "", false);
				ReplaceString(targetName, sizeof(targetName), "slender_time_limit_", "", false);
				g_iRoundTimeLimit = StringToInt(targetName);
				
				LogMessage("Found sf2_time_limit entity, set time limit to %d", g_iRoundTimeLimit);
			}
			//g_iRoundTimeGainFromPage
			else if (!StrContains(targetName, "sf2_escape_time_limit_", false) ||
				!StrContains(targetName, "slender_escape_time_limit_", false))
			{
				ReplaceString(targetName, sizeof(targetName), "sf2_escape_time_limit_", "", false);
				ReplaceString(targetName, sizeof(targetName), "slender_escape_time_limit_", "", false);
				g_iRoundEscapeTimeLimit = StringToInt(targetName);
				
				LogMessage("Found sf2_escape_time_limit entity, set escape time limit to %d", g_iRoundEscapeTimeLimit);
			}
			else if (!StrContains(targetName, "sf2_time_gain_from_page_", false) ||
				!StrContains(targetName, "slender_time_gain_from_page_", false))
			{
				ReplaceString(targetName, sizeof(targetName), "sf2_time_gain_from_page_", "", false);
				ReplaceString(targetName, sizeof(targetName), "slender_time_gain_from_page_", "", false);
				g_iRoundTimeGainFromPage = StringToInt(targetName);
				
				LogMessage("Found sf2_time_gain_from_page entity, set time gain to %d", g_iRoundTimeGainFromPage);
			}
			else if (g_iRoundCount == 1 && 
				(!StrContains(targetName, "sf2_maxplayers_", false) || !StrContains(targetName, "slender_logic_maxplayers_", false)))
			{
				ReplaceString(targetName, sizeof(targetName), "sf2_maxplayers_", "", false);
				ReplaceString(targetName, sizeof(targetName), "slender_logic_maxplayers_", "", false);
				SetConVarInt(g_cvMaxPlayers, StringToInt(targetName));
				
				LogMessage("Found sf2_maxplayers entity, set maxplayers to %d", StringToInt(targetName));
			}
			else if (!StrContains(targetName, "sf2_boss_override_", false) ||
				!StrContains(targetName, "slender_boss_override_", false))
			{
				ReplaceString(targetName, sizeof(targetName), "sf2_boss_override_", "", false);
				ReplaceString(targetName, sizeof(targetName), "slender_boss_override_", "", false);
				SetConVarString(g_cvProfileOverride, targetName);
				
				LogMessage("Found sf2_boss_override entity, set override to %s", targetName);
			}
		}
	}
	
	// Get a reference entity, if any.
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("InitializeNewGame(): Finding page reference entity");
#endif
	
	ent = -1;
	while ((ent = FindEntityByClassname(ent, "prop_dynamic")) != -1)
	{
		if (g_bPageRef) break;
	
		GetEntPropString(ent, Prop_Data, "m_iName", targetName, sizeof(targetName));
		if (targetName[0])
		{
			if (StrEqual(targetName, "sf2_page_model", false) || 
				StrEqual(targetName, "slender_page_ref", false))
			{
				g_bPageRef = true;
				GetEntPropString(ent, Prop_Data, "m_ModelName", g_strPageRefModel, sizeof(g_strPageRefModel));
				g_flPageRefModelScale = 1.0;
			}
		}
	}
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("InitializeNewGame(): Spawning pages");
#endif
	
	new iPageCount = GetArraySize(hArray);
	if (iPageCount)
	{
		SortADTArray(hArray, Sort_Random, Sort_Integer);
		
		decl Float:vecPos[3], Float:vecAng[3], Float:vecDir[3];
		decl page;
		ent = -1;
		
		for (new i = 0; i < iPageCount && (i + 1) <= g_iPageMax; i++)
		{
			if (bool:GetArrayCell(hArray, i, 1))
			{
				new Handle:hButtStallion = Handle:GetArrayCell(hArray, i);
				ent = GetArrayCell(hButtStallion, GetRandomInt(0, GetArraySize(hButtStallion) - 1));
			}
			else
			{
				ent = GetArrayCell(hArray, i);
			}
			
			GetEntPropVector(ent, Prop_Data, "m_vecAbsOrigin", vecPos);
			GetEntPropVector(ent, Prop_Data, "m_angAbsRotation", vecAng);
			GetAngleVectors(vecAng, vecDir, NULL_VECTOR, NULL_VECTOR);
			NormalizeVector(vecDir, vecDir);
			ScaleVector(vecDir, 1.0);
			
			page = CreateEntityByName("prop_dynamic_override");
			if (page != -1)
			{
				TeleportEntity(page, vecPos, vecAng, NULL_VECTOR);
				DispatchKeyValue(page, "targetname", "sf2_page");
				
				if (g_bPageRef)
				{
					SetEntityModel(page, g_strPageRefModel);
				}
				else
				{
					SetEntityModel(page, PAGE_MODEL);
				}
				
				DispatchKeyValue(page, "solid", "2");
				DispatchSpawn(page);
				ActivateEntity(page);
				SetVariantInt(i);
				AcceptEntityInput(page, "Skin");
				AcceptEntityInput(page, "EnableCollision");
				
				if (g_bPageRef)
				{
					SetEntPropFloat(page, Prop_Send, "m_flModelScale", g_flPageRefModelScale);
				}
				else
				{
					SetEntPropFloat(page, Prop_Send, "m_flModelScale", PAGE_MODELSCALE);
				}
				
				SDKHook(page, SDKHook_OnTakeDamage, Hook_PageOnTakeDamage);
				SDKHook(page, SDKHook_SetTransmit, Hook_SlenderObjectSetTransmit);
			}
		}
		
		// Safely remove all handles.
		for (new i = 0, iSize = GetArraySize(hArray); i < iSize; i++)
		{
			if (bool:GetArrayCell(hArray, i, 1))
			{
				CloseHandle(Handle:GetArrayCell(hArray, i));
			}
		}
	
		Call_StartForward(fOnPagesSpawned);
		Call_Finish();
	}
	
	CloseHandle(hPageTrie);
	CloseHandle(hArray);
	
	// Get valid boss list.
	
	hArray = CreateArray(64);
	KvRewind(g_hConfig);
	KvGotoFirstSubKey(g_hConfig);
	do
	{
		KvGetSectionName(g_hConfig, buffer, sizeof(buffer));
		PushArrayString(hArray, buffer);
	}
	while (KvGotoNextKey(g_hConfig));
	
	// Determine boss round state.
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("InitializeNewGame(): New boss round check");
#endif
	
	new bool:bBossOld = g_bBossRound;
	
	if (!g_bBossRound)
	{
		g_iBossRoundCount++;
		
		if (GetConVarInt(g_cvSpecialRoundInterval) > 0)
		{
			iCount = g_iBossRoundCount;
			while (iCount > 0) iCount -= GetConVarInt(g_cvBossRoundInterval);
			if (iCount == 0) 
			{
				g_bBossRound = true;
			}
		}
	}
	else
	{
		if (GetConVarInt(g_cvBossRoundBehavior) == 0)
		{
			g_bBossRound = false;
		}
		else
		{
			new iBossCount;
			for (new i = 1; i <= MaxClients; i++)
			{
				if (!IsClientInGame(i)) continue;
				
				if (!g_bPlayerDidBossRound[i] && IsClientParticipating(i))
				{
					iBossCount++;
				}
			}
			
			if (!iBossCount)
			{
				g_bBossRound = false;
			}
		}
	}
	
	// Do boss round force override and reset it.
	if (GetConVarInt(g_cvBossRoundForce) >= 0)
	{
		g_bBossRound = GetConVarBool(g_cvBossRoundForce);
		SetConVarInt(g_cvBossRoundForce, -1);
	}
	
	if (GetArraySize(hArray) < 2)
	{
		g_bBossRound = false; // Not enough bosses.
	}
	
	// Was a new boss round initialized?
	if (bBossOld != g_bBossRound || GetConVarInt(g_cvBossRoundBehavior) == 0)
	{
		if (g_bBossRound)
		{
			// Reset round count;
			g_iBossRoundCount = 0;
			
			// Reset all players' values.
			for (new i = 1; i <= MaxClients; i++)
			{
				if (!IsClientParticipating(i))
				{
					g_bPlayerDidBossRound[i] = true;
					continue;
				}
				
				g_bPlayerDidBossRound[i] = false;
			}
			
			// Get a new boss.
			GetArrayString(hArray, GetRandomInt(1, GetArraySize(hArray) - 1), g_strBossRoundProfile, sizeof(g_strBossRoundProfile));
		}
		else
		{
			strcopy(g_strBossRoundProfile, sizeof(g_strBossRoundProfile), "");
		}
	}
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("InitializeNewGame(): Selecting boss profile");
#endif
	
	// Select which profile to use.
	decl String:sProfileOverride[SF2_MAX_PROFILE_NAME_LENGTH], String:sProfile[SF2_MAX_PROFILE_NAME_LENGTH];
	GetConVarString(g_cvProfileOverride, sProfileOverride, sizeof(sProfileOverride));
	
	if (sProfileOverride[0] && FindStringInArray(hArray, sProfileOverride) != -1)
	{
		// Pick the overridden boss.
		strcopy(sProfile, sizeof(sProfile), sProfileOverride);
		SetConVarString(g_cvProfileOverride, "");
	}
	else if (g_bBossRound && g_strBossRoundProfile[0] && FindStringInArray(hArray, g_strBossRoundProfile) != -1)
	{
		// Pick the special boss.
		strcopy(sProfile, sizeof(sProfile), g_strBossRoundProfile);
	}
	else
	{
		GetConVarString(g_cvBossMain, sProfileOverride, sizeof(sProfileOverride));
		if (sProfileOverride[0] && FindStringInArray(hArray, sProfileOverride) != -1)
		{
			strcopy(sProfile, sizeof(sProfile), sProfileOverride);
		}
		else
		{
			// Pick the first boss.
			GetArrayString(hArray, 0, sProfile, sizeof(sProfile));
		}
	}
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("InitializeNewGame(): Getting boss profile companions");
#endif
	
	// We don't need this anymore. Close it now.
	CloseHandle(hArray);
	
	SelectProfile(0, sProfile);
	
	KvRewind(g_hConfig);
	KvJumpToKey(g_hConfig, sProfile);
	
	if (KvJumpToKey(g_hConfig, "companions"))
	{
		for (new i = 1; i <= MAX_BOSSES; i++)
		{
			IntToString(i, buffer, sizeof(buffer));
			KvGetString(g_hConfig, buffer, sProfile, sizeof(sProfile));
			if (!sProfile[0]) break;
			
			SelectProfile(i, sProfile);
		}
	}
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("InitializeNewGame(): Refreshing groups and players");
#endif
	
	// Refresh groups.
	for (new i = 0; i < SF2_MAX_PLAYER_GROUPS; i++)
	{
		SetPlayerGroupPlaying(i, false);
		CheckPlayerGroup(i);
	}
	
	// Refresh players.
	for (new i = 1; i <= MaxClients; i++)
	{
		ClientDisableGhostMode(i);
		g_bPlayerPlaying[i] = false;
		g_bPlayerEliminated[i] = true;
		g_bPlayerEscaped[i] = false;
	}
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("InitializeNewGame(): Going through player and group queue list");
#endif
	
	ForceInNextPlayersInQueue(GetConVarInt(g_cvMaxPlayers));
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("InitializeNewGame(): Respawning players");
#endif
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientParticipating(i)) TF2_RespawnPlayer(i);
	}
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("END InitializeNewGame()");
#endif
}

public Action:Timer_DisplaySpecialRound(Handle:timer)
{
	decl String:sDescHud[64];
	SpecialRoundGetDescriptionHud(g_iSpecialRound, sDescHud, sizeof(sDescHud));
	
	decl String:sIconHud[64];
	SpecialRoundGetIconHud(g_iSpecialRound, sIconHud, sizeof(sIconHud));
	
	decl String:sDescChat[64];
	SpecialRoundGetDescriptionChat(g_iSpecialRound, sDescChat, sizeof(sDescChat));
	
	GameTextTFMessage(sDescHud, sIconHud);
	CPrintToChatAll("%t", "SF2 Special Round Announce Chat", sDescChat); // For those who are using minimized HUD...
}

CheckRoundState()
{
	if (g_bRoundWarmup || g_bRoundEnded) return;
	
	new iTotalCount;
	new iAliveCount;
	new iEscapedCount;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i)) continue;
		iTotalCount++;
		if (!g_bPlayerEliminated[i] && !g_bPlayerDeathCam[i]) 
		{
			iAliveCount++;
			if (g_bPlayerEscaped[i]) iEscapedCount++;
		}
	}
	
	if (!iAliveCount)
	{
		ForceTeamWin(_:TFTeam_Blue);
	}
	else
	{
		if (g_iPageMax && g_iPageCount == g_iPageMax)
		{
			if (!g_bRoundMustEscape) ForceTeamWin(_:TFTeam_Red);
			else
			{
				if (iEscapedCount == iAliveCount) ForceTeamWin(_:TFTeam_Red);
			}
		}
	}
}

//	==========================================================
//	API
//	==========================================================

public Native_IsRunning(Handle:plugin, numParams)
{
	return g_bEnabled;
}

public Native_GetCurrentDifficulty(Handle:plugin, numParams)
{
	return GetConVarInt(g_cvDifficulty);
}

public Native_GetDifficultyModifier(Handle:plugin, numParams)
{
	new iDifficulty = GetNativeCell(1);
	if (iDifficulty < Difficulty_Easy || iDifficulty >= Difficulty_Max)
	{
		LogError("Difficulty parameter can only be from %d to %d!", Difficulty_Easy, Difficulty_Max - 1);
		return _:1.0;
	}
	
	switch (iDifficulty)
	{
		case Difficulty_Easy: return _:DIFFICULTY_EASY;
		case Difficulty_Hard: return _:DIFFICULTY_HARD;
		case Difficulty_Insane: return _:DIFFICULTY_INSANE;
	}
	
	return _:DIFFICULTY_NORMAL;
}

public Native_IsClientEliminated(Handle:plugin, numParams)
{
	return g_bPlayerEliminated[GetNativeCell(1)];
}

public Native_IsClientInGhostMode(Handle:plugin, numParams)
{
	return g_bPlayerGhostMode[GetNativeCell(1)];
}

public Native_IsClientInPvP(Handle:plugin, numParams)
{
	return IsClientInPvP(GetNativeCell(1));
}

public Native_IsClientProxy(Handle:plugin, numParams)
{
	return g_bPlayerProxy[GetNativeCell(1)];
}

public Native_GetClientBlinkCount(Handle:plugin, numParams)
{
	return g_iPlayerBlinkCount[GetNativeCell(1)];
}

public Native_GetClientProxyMaster(Handle:plugin, numParams)
{
	return SlenderGetFromID(g_iPlayerProxyMaster[GetNativeCell(1)]);
}

public Native_GetClientProxyControlAmount(Handle:plugin, numParams)
{
	return g_iPlayerProxyControl[GetNativeCell(1)];
}

public Native_GetClientProxyControlRate(Handle:plugin, numParams)
{
	return _:g_flPlayerProxyControlRate[GetNativeCell(1)];
}

public Native_SetClientProxyMaster(Handle:plugin, numParams)
{
	g_iPlayerProxyMaster[GetNativeCell(1)] = g_iSlenderID[GetNativeCell(2)];
}

public Native_SetClientProxyControlAmount(Handle:plugin, numParams)
{
	g_iPlayerProxyControl[GetNativeCell(1)] = GetNativeCell(2);
}

public Native_SetClientProxyControlRate(Handle:plugin, numParams)
{
	g_flPlayerProxyControlRate[GetNativeCell(1)] = Float:GetNativeCell(2);
}

public Native_IsClientLookingAtBoss(Handle:plugin, numParams)
{
	return g_bPlayerSeesSlender[GetNativeCell(1)][GetNativeCell(2)];
}

public Native_GetMaxBosses(Handle:plugin, numParams)
{
	return MAX_BOSSES;
}

public Native_EntIndexToBossIndex(Handle:plugin, numParams)
{
	new iEntIndex = GetNativeCell(1);
	if (!IsValidEntity(iEntIndex)) return -1;
	
	new iEntRef = EntIndexToEntRef(iEntIndex);
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		if (g_iSlender[i] == iEntRef) return i;
	}
	
	return -1;
}

public Native_BossIndexToEntIndex(Handle:plugin, numParams)
{
	return EntRefToEntIndex(g_iSlender[GetNativeCell(1)]);
}

public Native_BossIDToBossIndex(Handle:plugin, numParams)
{
	new iBossID = GetNativeCell(1);
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		if (g_iSlenderID[i] == iBossID) return i;
	}
	
	return -1;
}

public Native_BossIndexToBossID(Handle:plugin, numParams)
{
	return g_iSlenderID[GetNativeCell(1)]
}

public Native_GetBossName(Handle:plugin, numParams)
{
	SetNativeString(2, g_strSlenderProfile[GetNativeCell(1)], GetNativeCell(3));
}

public Native_GetBossModelEntity(Handle:plugin, numParams)
{
	return EntRefToEntIndex(g_iSlenderModel[GetNativeCell(1)]);
}

public Native_GetBossTarget(Handle:plugin, numParams)
{
	return EntRefToEntIndex(g_iSlenderTarget[GetNativeCell(1)]);
}

public Native_GetBossMaster(Handle:plugin, numParams)
{
	return g_iSlenderCopyMaster[GetNativeCell(1)];
}

public Native_GetBossState(Handle:plugin, numParams)
{
	return g_iSlenderState[GetNativeCell(1)];
}

public Native_IsBossProfileValid(Handle:plugin, numParams)
{
	decl String:sProfile[SF2_MAX_PROFILE_NAME_LENGTH];
	GetNativeString(1, sProfile, SF2_MAX_PROFILE_NAME_LENGTH);
	
	if (!sProfile[0]) return false;
	if (g_hConfig == INVALID_HANDLE) return false;
	
	KvRewind(g_hConfig);
	if (!KvJumpToKey(g_hConfig, sProfile)) return false;
	
	return true;
}

public Native_GetBossProfileNum(Handle:plugin, numParams)
{
	decl String:sProfile[SF2_MAX_PROFILE_NAME_LENGTH];
	GetNativeString(1, sProfile, SF2_MAX_PROFILE_NAME_LENGTH);
	
	decl String:sKeyValue[256];
	GetNativeString(2, sKeyValue, sizeof(sKeyValue));
	
	return GetProfileNum(sProfile, sKeyValue, GetNativeCell(3));
}

public Native_GetBossProfileFloat(Handle:plugin, numParams)
{
	decl String:sProfile[SF2_MAX_PROFILE_NAME_LENGTH];
	GetNativeString(1, sProfile, SF2_MAX_PROFILE_NAME_LENGTH);

	decl String:sKeyValue[256];
	GetNativeString(2, sKeyValue, sizeof(sKeyValue));
	
	return _:GetProfileFloat(sProfile, sKeyValue, Float:GetNativeCell(3));
}

public Native_GetBossProfileString(Handle:plugin, numParams)
{
	decl String:sProfile[SF2_MAX_PROFILE_NAME_LENGTH];
	GetNativeString(1, sProfile, SF2_MAX_PROFILE_NAME_LENGTH);

	decl String:sKeyValue[256];
	GetNativeString(2, sKeyValue, sizeof(sKeyValue));
	
	new iResultLen = GetNativeCell(4);
	decl String:sResult[iResultLen];
	
	decl String:sDefaultValue[512];
	GetNativeString(5, sDefaultValue, sizeof(sDefaultValue));
	
	new bool:bSuccess = GetProfileString(sProfile, sKeyValue, sResult, iResultLen, sDefaultValue);
	
	SetNativeString(3, sResult, iResultLen);
	return bSuccess;
}

public Native_GetBossProfileVector(Handle:plugin, numParams)
{
	decl String:sProfile[SF2_MAX_PROFILE_NAME_LENGTH];
	GetNativeString(1, sProfile, SF2_MAX_PROFILE_NAME_LENGTH);

	decl String:sKeyValue[256];
	GetNativeString(2, sKeyValue, sizeof(sKeyValue));
	
	decl Float:flResult[3];
	decl Float:flDefaultValue[3];
	GetNativeArray(4, flDefaultValue, 3);
	
	new bool:bSuccess = GetProfileVector(sProfile, sKeyValue, flResult, flDefaultValue);
	
	SetNativeArray(3, flResult, 3);
	return bSuccess;
}

public Native_GetRandomStringFromBossProfile(Handle:plugin, numParams)
{
	decl String:sProfile[SF2_MAX_PROFILE_NAME_LENGTH];
	GetNativeString(1, sProfile, SF2_MAX_PROFILE_NAME_LENGTH);

	decl String:sKeyValue[256];
	GetNativeString(2, sKeyValue, sizeof(sKeyValue));
	
	new iBufferLen = GetNativeCell(4);
	decl String:sBuffer[iBufferLen];
	
	new iIndex = GetNativeCell(5);
	
	new bool:bSuccess = GetRandomStringFromProfile(sProfile, sKeyValue, sBuffer, iBufferLen, iIndex);
	SetNativeString(3, sBuffer, iBufferLen);
	return bSuccess;
}

//	==========================================================
//	DEBUGGING
//	==========================================================

#if defined DEBUG
stock DebugMessage(const String:sMessage[], ...)
{
	decl String:sDebugMessage[1024], String:sTemp[1024];
	VFormat(sTemp, sizeof(sTemp), sMessage, 2);
	Format(sDebugMessage, sizeof(sDebugMessage), "SF2: %s", sTemp);
	PrintToServer(sDebugMessage);
}
#endif
