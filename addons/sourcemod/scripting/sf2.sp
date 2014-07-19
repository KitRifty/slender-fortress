#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <steamtools>
#include <tf2items>
#include <dhooks>
#include <navmesh>

#include <tf2>
#include <tf2_stocks>
#include <morecolors>
#include <sf2>

#undef REQUIRE_PLUGIN
#include <adminmenu>
#tryinclude <store/store-tf2footprints>
#define REQUIRE_PLUGIN

//#define DEBUG

#define PLUGIN_VERSION "0.2.3f"

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

#define MUSIC_CHAN SNDCHAN_AUTO

#define MUSIC_GOTPAGES1_SOUND "slender/newambience_1.wav"
#define MUSIC_GOTPAGES2_SOUND "slender/newambience_2.wav"
#define MUSIC_GOTPAGES3_SOUND "slender/newambience_3.wav"
#define MUSIC_GOTPAGES4_SOUND "slender/newambience_4.wav"
#define MUSIC_PAGE_VOLUME 1.0

#define SF2_INTRO_DEFAULT_MUSIC "slender/intro.mp3"

#define SF2_HUD_TEXT_COLOR_R 127
#define SF2_HUD_TEXT_COLOR_G 167
#define SF2_HUD_TEXT_COLOR_B 141
#define SF2_HUD_TEXT_COLOR_A 255

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

new String:g_strSlenderProfile[MAX_BOSSES][SF2_MAX_PROFILE_NAME_LENGTH];
new g_iSlenderFlags[MAX_BOSSES];
new g_iSlender[MAX_BOSSES] = { INVALID_ENT_REFERENCE, ... };
new g_iSlenderModel[MAX_BOSSES] = { INVALID_ENT_REFERENCE, ... };
new g_iSlenderPoseEnt[MAX_BOSSES] = { INVALID_ENT_REFERENCE, ... };
new g_iSlenderCopyMaster[MAX_BOSSES] = { -1, ... };
new Float:g_flSlenderEyePosOffset[MAX_BOSSES][3];
new Float:g_flSlenderEyeAngOffset[MAX_BOSSES][3];
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

new Float:g_flSlenderProxyTeleportMinRange[MAX_BOSSES];
new Float:g_flSlenderProxyTeleportMaxRange[MAX_BOSSES];

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

static Handle:g_hPlayerIntroMusicTimer[MAXPLAYERS + 1] = { INVALID_HANDLE, ... };

// Seeing Mr. Slendy data.
new bool:g_bPlayerSeesSlender[MAXPLAYERS + 1][MAX_BOSSES];
new Float:g_flPlayerSeesSlenderLastTime[MAXPLAYERS + 1][MAX_BOSSES];

new Float:g_flPlayerSightSoundNextTime[MAXPLAYERS + 1][MAX_BOSSES];

new Float:g_flPlayerScareLastTime[MAXPLAYERS + 1][MAX_BOSSES];
new Float:g_flPlayerScareNextTime[MAXPLAYERS + 1][MAX_BOSSES];
new Float:g_flPlayerStaticAmount[MAXPLAYERS + 1];

new Float:g_flPlayerLastChaseBossEncounterTime[MAXPLAYERS + 1][MAX_BOSSES];

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

enum PlayerPreferences
{
	bool:PlayerPreference_PvPAutoSpawn,
	MuteMode:PlayerPreference_MuteMode,
	bool:PlayerPreference_ShowHints,
	bool:PlayerPreference_EnableProxySelection,
	bool:PlayerPreference_ProjectedFlashlight
};

new bool:g_bPlayerHints[MAXPLAYERS + 1][PlayerHint_MaxNum];
new g_iPlayerPreferences[MAXPLAYERS + 1][PlayerPreferences];

// Player data. Holy crap this is a lot of data.
new g_iPlayerLastButtons[MAXPLAYERS + 1];
new bool:g_bPlayerChoseTeam[MAXPLAYERS + 1];
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

new Handle:g_hPlayerSwitchBlueTimer[MAXPLAYERS + 1];

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
new Handle:g_hPlayerProxyControlTimer[MAXPLAYERS + 1];
new Float:g_flPlayerProxyControlRate[MAXPLAYERS + 1];
new Handle:g_flPlayerProxyVoiceTimer[MAXPLAYERS + 1];
new g_iPlayerProxyAskMaster[MAXPLAYERS + 1] = { -1, ... };
new Float:g_iPlayerProxyAskPosition[MAXPLAYERS + 1][3];

new g_iPlayerDesiredFOV[MAXPLAYERS + 1];

new Handle:g_hPlayerPostWeaponsTimer[MAXPLAYERS + 1] = { INVALID_HANDLE, ... };

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

new String:g_strPlayer20DollarsMusic[MAXPLAYERS + 1][PLATFORM_MAX_PATH];
new Float:g_flPlayer20DollarsMusicVolumes[MAXPLAYERS + 1][MAX_BOSSES];
new Handle:g_hPlayer20DollarsMusicTimer[MAXPLAYERS + 1][MAX_BOSSES];
new g_iPlayer20DollarsMusicMaster[MAXPLAYERS + 1] = { -1, ... };


new SF2RoundState:g_iRoundState = SF2RoundState_Invalid;
new bool:g_bRoundGrace = false;
new Float:g_flRoundDifficultyModifier = DIFFICULTY_NORMAL;
new bool:g_bRoundInfiniteFlashlight = false;
new bool:g_bRoundInfiniteBlink = false;

new bool:g_bSpecialRound = false;
new g_iSpecialRoundType = 0;

static Handle:g_hRoundGraceTimer = INVALID_HANDLE;
static Handle:g_hRoundTimer = INVALID_HANDLE;
static Handle:g_hVoteTimer = INVALID_HANDLE;
static String:g_strRoundBossProfile[SF2_MAX_PROFILE_NAME_LENGTH];

static g_iRoundCount = 0;
static g_iRoundTime = 0;
static g_iRoundTimeLimit = 0;
static g_iRoundEscapeTimeLimit = 0;
static g_iRoundTimeGainFromPage = 0;
static bool:g_bRoundHasEscapeObjective = false;

static g_iRoundEscapePointEntity = INVALID_ENT_REFERENCE;

static g_iRoundIntroFadeColor[4] = { 255, ... };
static Float:g_flRoundIntroFadeHoldTime;
static Float:g_flRoundIntroFadeDuration;
static Handle:g_hRoundIntroTimer = INVALID_HANDLE;
static bool:g_bRoundIntroTextDefault = true;
static Handle:g_hRoundIntroTextTimer = INVALID_HANDLE;
static g_iRoundIntroText;
static String:g_strRoundIntroMusic[PLATFORM_MAX_PATH] = "";

static bool:g_bRoundWaitingForPlayers = false;

static bool:g_bNewBossRound = false;
static bool:g_bNewBossRoundNew = false;
static bool:g_bNewBossRoundContinuous = false;
static g_iNewBossRoundCount = 0;
static bool:g_bPlayerPlayedNewBossRound[MAXPLAYERS + 1] = { false, ... };
static String:g_strNewBossRoundProfile[64] = "";

static Handle:g_hRoundMessagesTimer = INVALID_HANDLE;
static g_iRoundMessagesNum = 0;

static Handle:g_hBossCountUpdateTimer = INVALID_HANDLE;
static Handle:g_hClientAverageUpdateTimer = INVALID_HANDLE;

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
new Handle:g_cvProfileOverride;
new Handle:g_cvPlayerBlinkRate;
new Handle:g_cvPlayerBlinkHoldTime;
new Handle:g_cvSpecialRoundBehavior;
new Handle:g_cvSpecialRoundForce;
new Handle:g_cvSpecialRoundOverride;
new Handle:g_cvSpecialRoundInterval;
new Handle:g_cvNewBossRoundBehavior;
new Handle:g_cvNewBossRoundInterval;
new Handle:g_cvNewBossRoundForce;
new Handle:g_cvPlayerVoiceDistance;
new Handle:g_cvPlayerVoiceWallScale;
new Handle:g_cvUltravisionEnabled;
new Handle:g_cvUltravisionRadiusRed;
new Handle:g_cvUltravisionRadiusBlue;
new Handle:g_cvUltravisionBrightness;
new Handle:g_cvIntroEnabled;
new Handle:g_cvIntroDefaultHoldTime;
new Handle:g_cvIntroDefaultFadeTime;
new Handle:g_cvTimeLimit;
new Handle:g_cvTimeLimitEscape;
new Handle:g_cvTimeGainFromPageGrab;
new Handle:g_cvWarmupRound;
new Handle:g_cvPlayerViewbobHurtEnabled;
new Handle:g_cvPlayerViewbobSprintEnabled;
new Handle:g_cvPlayerFakeLagCompensation;
new Handle:g_cvPlayerProxyWaitTime;
new Handle:g_cvPlayerProxyAsk;
new Handle:g_cvHalfZatoichiHealthGain;
new Handle:g_cvBlockSuicideDuringRound;

new Handle:g_cvGravity;
new Float:g_flGravity;

new bool:g_b20Dollars;

new bool:g_bPlayerShakeEnabled;
new bool:g_bPlayerViewbobEnabled;
new bool:g_bPlayerViewbobHurtEnabled;
new bool:g_bPlayerViewbobSprintEnabled;

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
#include "sf2/logging.sp"
#include "sf2/debug.sp"
#include "sf2/profiles.sp"
#include "sf2/effects.sp"
#include "sf2/pvp.sp"
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
	
	PvP_InitializeAPI();
	
	SpecialRoundInitializeAPI();
	
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
	g_cvIntroEnabled = CreateConVar("sf2_intro_enabled", "1");
	g_cvIntroDefaultHoldTime = CreateConVar("sf2_intro_default_hold_time", "9.0");
	g_cvIntroDefaultFadeTime = CreateConVar("sf2_intro_default_fade_time", "1.0");
	
	g_cvBlockSuicideDuringRound = CreateConVar("sf2_block_suicide_during_round", "0");
	
	g_cvAllChat = CreateConVar("sf2_alltalk", "0");
	HookConVarChange(g_cvAllChat, OnConVarChanged);
	
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
	HookConVarChange(g_cv20Dollars, OnConVarChanged);
	
	g_cvMaxPlayers = CreateConVar("sf2_maxplayers", "5", "The maximum amount of players than can be in one round.");
	HookConVarChange(g_cvMaxPlayers, OnConVarChanged);
	
	g_cvCampingEnabled = CreateConVar("sf2_anticamping_enabled", "1", "Enable/Disable anti-camping system for RED.");
	g_cvCampingMaxStrikes = CreateConVar("sf2_anticamping_maxstrikes", "4", "How many 5-second intervals players are allowed to stay in one spot before he/she is forced to suicide.");
	g_cvCampingStrikesWarn = CreateConVar("sf2_anticamping_strikeswarn", "2", "The amount of strikes left where the player will be warned of camping.");
	g_cvCampingMinDistance = CreateConVar("sf2_anticamping_mindistance", "128.0", "Every 5 seconds the player has to be at least this far away from his last position 5 seconds ago or else he'll get a strike.");
	g_cvCampingNoStrikeSanity = CreateConVar("sf2_anticamping_no_strike_sanity", "0.1", "The camping system will NOT give any strikes under any circumstances if the players's Sanity is missing at least this much of his maximum Sanity (max is 1.0).");
	g_cvCampingNoStrikeBossDistance = CreateConVar("sf2_anticamping_no_strike_boss_distance", "512.0", "The camping system will NOT give any strikes under any circumstances if the player is this close to a boss (ignoring LOS).");
	g_cvBossMain = CreateConVar("sf2_boss_main", "slenderman", "The name of the main boss (its profile name, not its display name)");
	g_cvProfileOverride = CreateConVar("sf2_boss_profile_override", "", "Overrides which boss will be chosen next. Only applies to the first boss being chosen.");
	g_cvDifficulty = CreateConVar("sf2_difficulty", "1", "Difficulty of the game. 1 = Normal, 2 = Hard, 3 = Insane.", _, true, 1.0, true, 3.0);
	HookConVarChange(g_cvDifficulty, OnConVarChanged);
	
	g_cvSpecialRoundBehavior = CreateConVar("sf2_specialround_mode", "0", "0 = Special Round resets on next round, 1 = Special Round keeps going until all players have played (not counting spectators, recently joined players, and those who reset their queue points during the round)");
	g_cvSpecialRoundForce = CreateConVar("sf2_specialround_forceenable", "-1", "Sets whether a Special Round will occur on the next round or not.");
	g_cvSpecialRoundOverride = CreateConVar("sf2_specialround_forcetype", "-1", "Sets the type of Special Round that will be chosen on the next Special Round. Set to -1 to let the game choose.");
	g_cvSpecialRoundInterval = CreateConVar("sf2_specialround_interval", "5", "If this many rounds are completed, the next round will be a Special Round.");
	
	g_cvNewBossRoundBehavior = CreateConVar("sf2_newbossround_mode", "0", "0 = boss selection will return to normal after the boss round, 1 = the new boss will continue being the boss until all players in the server have played against it (not counting spectators, recently joined players, and those who reset their queue points during the round).");
	g_cvNewBossRoundInterval = CreateConVar("sf2_newbossround_interval", "3", "If this many around are completed, the next round's boss will be randomly chosen.");
	g_cvNewBossRoundForce = CreateConVar("sf2_newbossround_forceenable", "-1", "Sets whether a new boss will be chosen on the next round or not. Set to -1 to let the game choose.");
	
	g_cvTimeLimit = CreateConVar("sf2_timelimit_default", "300", "The time limit of the round. Maps can change the time limit.");
	g_cvTimeLimitEscape = CreateConVar("sf2_timelimit_escape_default", "90", "The time limit to escape. Maps can change the time limit.");
	g_cvTimeGainFromPageGrab = CreateConVar("sf2_time_gain_page_grab", "12", "The time gained from grabbing a page. Maps can change the time gain amount.");
	
	g_cvWarmupRound = CreateConVar("sf2_warmupround", "1");
	
	g_cvPlayerProxyWaitTime = CreateConVar("sf2_player_proxy_waittime", "35", "How long (in seconds) after a player was chosen to be a Proxy must the system wait before choosing him again.");
	g_cvPlayerProxyAsk = CreateConVar("sf2_player_proxy_ask", "0", "Set to 1 if the player can choose before becoming a Proxy, set to 0 to force.");
	
	g_cvHalfZatoichiHealthGain = CreateConVar("sf2_halfzatoichi_healthgain", "20", "How much health should be gained from killing a player with the Half-Zatoichi? Set to -1 for default behavior.");
	
	g_hHudSync = CreateHudSynchronizer();
	g_hHudSync2 = CreateHudSynchronizer();
	g_hRoundTimerSync = CreateHudSynchronizer();
	g_hCookie = RegClientCookie("slender_cookie", "", CookieAccess_Private);
	
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
	RegConsoleCmd("+sprint", Command_SprintOn);
	RegConsoleCmd("-sprint", Command_SprintOff);
	
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
	
	// Hook onto existing console commands.
	AddCommandListener(Hook_CommandBuild, "build");
	AddCommandListener(Hook_CommandSuicideAttempt, "kill");
	AddCommandListener(Hook_CommandSuicideAttempt, "explode");
	AddCommandListener(Hook_CommandSuicideAttempt, "joinclass");
	AddCommandListener(Hook_CommandSuicideAttempt, "join_class");
	AddCommandListener(Hook_CommandSuicideAttempt, "jointeam");
	AddCommandListener(Hook_CommandSuicideAttempt, "spectate");
	AddCommandListener(Hook_CommandVoiceMenu, "voicemenu");
	AddCommandListener(Hook_CommandSay, "say");
	
	// Hook events.
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("teamplay_round_win", Event_RoundEnd);
	HookEvent("player_team", Event_DontBroadcastToClients, EventHookMode_Pre);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("post_inventory_application", Event_PostInventoryApplication);
	HookEvent("item_found", Event_DontBroadcastToClients, EventHookMode_Pre);
	HookEvent("teamplay_teambalanced_player", Event_DontBroadcastToClients, EventHookMode_Pre);
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
	
	AddTempEntHook("Fire Bullets", Hook_TEFireBullets);
	
	SetupMenus();
	
	SetupAdminMenu();
	
	SetupClassDefaultWeapons();
	
	SetupPlayerGroups();
	
	PvP_Initialize();
	
#if defined DEBUG
	InitializeDebug();
#endif
}

public OnAllPluginsLoaded()
{
	SetupHooks();
}

public OnPluginEnd()
{
	StopPlugin();
}

static SetupMenus()
{
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
	
	g_hMenuCredits = CreateMenu(Menu_Credits);
	
	Format(buffer, sizeof(buffer), "%tCredits\n \n", "SF2 Prefix");
	StrCat(buffer, sizeof(buffer), "Coder: Kit o' Rifty\n");
	StrCat(buffer, sizeof(buffer), "Version: ");
	StrCat(buffer, sizeof(buffer), PLUGIN_VERSION);
	StrCat(buffer, sizeof(buffer), "\n \n");
	StrCat(buffer, sizeof(buffer), "Mark J. Hadley (AgentParsec) - Creating Slender and the default music ambience\n");
	StrCat(buffer, sizeof(buffer), "Mark Steen - Composing the intro music");
	StrCat(buffer, sizeof(buffer), "Mammoth Mogul - for being a GREAT test subject\n");
	StrCat(buffer, sizeof(buffer), "Egosins - getting the first server to run this mod\n");
	StrCat(buffer, sizeof(buffer), "Somberguy - suggestions and support\n");
	StrCat(buffer, sizeof(buffer), "Voonyl/Tristtess - materials, maps, importing current Slender Man model, and more!\n");
	StrCat(buffer, sizeof(buffer), "Narry Gewman - imported first Slender Man model\n");
	StrCat(buffer, sizeof(buffer), "Simply Delicious - for the awesome camera overlay!\n");
	StrCat(buffer, sizeof(buffer), "Jason278 - Page models");
	StrCat(buffer, sizeof(buffer), "\n \n");
	
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
	
	PvP_SetupMenus();
}

static SetupHooks()
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
	
	new iOffset = GameConfGetOffset(hConfig, "CTFPlayer::WantsLagCompensationOnEntity"); 
	g_hSDKWantsLagCompensationOnEntity = DHookCreate(iOffset, HookType_Entity, ReturnType_Bool, ThisPointer_CBaseEntity, Hook_ClientWantsLagCompensationOnEntity); 
	if (g_hSDKWantsLagCompensationOnEntity == INVALID_HANDLE)
	{
		SetFailState("Failed to create hook CTFPlayer::WantsLagCompensationOnEntity offset from SF2 gamedata!");
	}
	
	DHookAddParam(g_hSDKWantsLagCompensationOnEntity, HookParamType_CBaseEntity);
	DHookAddParam(g_hSDKWantsLagCompensationOnEntity, HookParamType_ObjectPtr);
	DHookAddParam(g_hSDKWantsLagCompensationOnEntity, HookParamType_Unknown);
	
	iOffset = GameConfGetOffset(hConfig, "CBaseEntity::ShouldTransmit");
	g_hSDKShouldTransmit = DHookCreate(iOffset, HookType_Entity, ReturnType_Int, ThisPointer_CBaseEntity, Hook_EntityShouldTransmit);
	if (g_hSDKShouldTransmit == INVALID_HANDLE)
	{
		SetFailState("Failed to create hook CBaseEntity::ShouldTransmit offset from SF2 gamedata!");
	}
	
	DHookAddParam(g_hSDKShouldTransmit, HookParamType_ObjectPtr);
	
	CloseHandle(hConfig);
}

SetupClassDefaultWeapons()
{
	// Scout
	g_hSDKWeaponScattergun = PrepareItemHandle("tf_weapon_scattergun", 13, 0, 0, "");
	g_hSDKWeaponPistolScout = PrepareItemHandle("tf_weapon_pistol", 23, 0, 0, "");
	g_hSDKWeaponBat = PrepareItemHandle("tf_weapon_bat", 0, 0, 0, "");
	
	// Sniper
	g_hSDKWeaponSniperRifle = PrepareItemHandle("tf_weapon_sniperrifle", 14, 0, 0, "");
	g_hSDKWeaponSMG = PrepareItemHandle("tf_weapon_smg", 16, 0, 0, "");
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

public OnMapStart()
{
	PvP_OnMapStart();
}

public OnConfigsExecuted()
{
	if (!GetConVarBool(g_cvEnabled))
	{
		StopPlugin();
	}
	else
	{
		if (GetConVarBool(g_cvSlenderMapsOnly))
		{
			decl String:sMap[256];
			GetCurrentMap(sMap, sizeof(sMap));
			
			if (!StrContains(sMap, "slender_", false) || !StrContains(sMap, "sf2_", false))
			{
				StartPlugin();
			}
			else
			{
				LogMessage("%s is not a Slender Fortress map. Plugin disabled!", sMap);
				StopPlugin();
			}
		}
		else
		{
			StartPlugin();
		}
	}
}

static StartPlugin()
{
	if (g_bEnabled) return;
	
	g_bEnabled = true;
	
	InitializeLogging();
	
#if defined DEBUG
	InitializeDebugLogging();
#endif
	
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
	
	g_b20Dollars = GetConVarBool(g_cv20Dollars);
	
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
	
	// Reset special round.
	SpecialRoundReset();
	
	// Reset boss rounds.
	g_bNewBossRound = false;
	g_bNewBossRoundNew = false;
	g_bNewBossRoundContinuous = false;
	g_iNewBossRoundCount = 1;
	strcopy(g_strNewBossRoundProfile, sizeof(g_strNewBossRoundProfile), "");
	
	// Reset global round vars.
	g_iRoundCount = 0;
	g_iRoundState = SF2RoundState_Invalid;
	g_hRoundMessagesTimer = CreateTimer(200.0, Timer_RoundMessages, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	g_iRoundMessagesNum = 0;
	g_iSpecialRoundCount = 0;
	
	g_hClientAverageUpdateTimer = CreateTimer(0.2, Timer_ClientAverageUpdate, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	g_hBossCountUpdateTimer = CreateTimer(2.0, Timer_BossCountUpdate, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	SetRoundState(SF2RoundState_Waiting);
	
	// Late load compensation.
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i)) continue;
		OnClientPutInServer(i);
	}
}

static PrecacheStuff()
{
	// Initialize particles.
	g_iParticleCriticalHit = PrecacheParticleSystem(CRIT_PARTICLENAME);
	
	PrecacheSound2(CRIT_SOUND);
	
	// simple_bot;
	PrecacheModel("models/humans/group01/female_01.mdl", true);
	
	PrecacheModel(PAGE_MODEL, true);
	PrecacheModel(GHOST_MODEL, true);
	
	PrecacheSound2(FLASHLIGHT_CLICKSOUND);
	PrecacheSound2(FLASHLIGHT_BREAKSOUND);
	PrecacheSound2(FLASHLIGHT_NOSOUND);
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
	PrecacheSound2(SF2_INTRO_DEFAULT_MUSIC);
	
	PrecacheMaterial2(BLACK_OVERLAY);
	
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
	
	// pvp
	PvP_Precache();
}

static StopPlugin()
{
	if (!g_bEnabled) return;
	
	g_bEnabled = false;
	
	// Reset CVars.
	new Handle:hCvar = FindConVar("mp_friendlyfire");
	if (hCvar != INVALID_HANDLE) SetConVarBool(hCvar, false);
	
	hCvar = FindConVar("mp_flashlight");
	if (hCvar != INVALID_HANDLE) SetConVarBool(hCvar, false);
	
	hCvar = FindConVar("mat_supportflashlight");
	if (hCvar != INVALID_HANDLE) SetConVarBool(hCvar, false);
	
	for (new i = 1; i <= MaxClients; i++)
	{
		ClientResetFlashlight(i);
		ClientDeactivateUltravision(i);
	}
}

public OnMapEnd()
{
	StopPlugin();
}

public TF2_OnConditionAdded(client, TFCond:cond)
{
	if (cond == TFCond_Taunting)
	{
		if (IsClientInGhostMode(client))
		{
			// Stop ghosties from taunting.
			TF2_RemoveCondition(client, TFCond_Taunting);
		}
	}
}

public OnGameFrame()
{
	// Process through boss movement.
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		if (SlenderGetID(i) == -1) continue;
		
		new iBoss = EntRefToEntIndex(g_iSlender[i]);
		
		if (!iBoss || iBoss == INVALID_ENT_REFERENCE) continue;
		if (g_iSlenderFlags[i] & SFF_MARKEDASFAKE) continue;
		
		new iType = g_iSlenderType[i];
		
		switch (iType)
		{
			case 0:
			{
				decl Float:myPos[3], Float:hisPos[3];
				SlenderGetAbsOrigin(i, myPos);
				AddVectors(myPos, g_flSlenderEyePosOffset[i], myPos);
				
				new iBestPlayer = -1;
				new Float:flBestDistance = 16384.0;
				new Float:flTempDistance;
				
				for (new iClient = 1; iClient <= MaxClients; iClient++)
				{
					if (!IsClientInGame(iClient) || !IsPlayerAlive(iClient) || IsClientInGhostMode(iClient) || IsClientInDeathCam(iClient)) continue;
					if (!IsPointVisibleToPlayer(iClient, myPos, false, false)) continue;
					
					GetClientAbsOrigin(iClient, hisPos);
					
					flTempDistance = GetVectorDistance(myPos, hisPos);
					if (flTempDistance < flBestDistance)
					{
						iBestPlayer = iClient;
						flBestDistance = flTempDistance;
					}
				}
				
				if (iBestPlayer > 0)
				{
					SlenderGetAbsOrigin(i, myPos);
					GetClientAbsOrigin(iBestPlayer, hisPos);
					
					if (!SlenderOnlyLooksIfNotSeen(i) || !IsPointVisibleToAPlayer(myPos, false, SlenderUsesBlink(i)))
					{
						new Float:flTurnRate = g_flSlenderTurnRate[i];
					
						if (flTurnRate > 0.0)
						{
							decl Float:flMyEyeAng[3], Float:ang[3];
							GetEntPropVector(iBoss, Prop_Data, "m_angAbsRotation", flMyEyeAng);
							AddVectors(flMyEyeAng, g_flSlenderEyeAngOffset[i], flMyEyeAng);
							SubtractVectors(hisPos, myPos, ang);
							GetVectorAngles(ang, ang);
							ang[0] = 0.0;
							ang[1] += (AngleDiff(ang[1], flMyEyeAng[1]) >= 0.0 ? 1.0 : -1.0) * flTurnRate * GetTickInterval();
							ang[2] = 0.0;
							
							// Take care of angle offsets.
							AddVectors(ang, g_flSlenderEyePosOffset[i], ang);
							for (new i2 = 0; i2 < 3; i2++) ang[i2] = AngleNormalize(ang[i2]);
							
							TeleportEntity(iBoss, NULL_VECTOR, ang, NULL_VECTOR);
						}
					}
				}
			}
			case 2:
			{
				SlenderChaseBossProcessMovement(i);
			}
		}
	}
	
	PvP_OnGameFrame();
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
			(g_iSpecialRoundType == SPECIALROUND_INSANEDIFFICULTY || g_iSpecialRoundType == SPECIALROUND_DOUBLEMAXPLAYERS))
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
		if (IsRoundEnding() ||
			IsRoundInWarmup() ||
			!g_bPlayerEliminated[param1] ||
			!IsClientParticipating(param1) ||
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
					if (IsClientInGhostMode(param1)) CPrintToChat(param1, "{red}%T", "SF2 Ghost Mode Enabled Already", param1);
					else
					{
						TF2_RespawnPlayer(param1);
						ClientSetGhostModeState(param1, true);
						
						CPrintToChat(param1, "{olive}%T", "SF2 Ghost Mode Enabled", param1);
					}
				}
				case 1:
				{
					if (!IsClientInGhostMode(param1)) CPrintToChat(param1, "{red}%T", "SF2 Ghost Mode Disabled Already", param1);
					else
					{
						ClientSetGhostModeState(param1, false);
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

public Panel_SettingsHints(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 1:
			{
				g_iPlayerPreferences[param1][PlayerPreference_ShowHints] = true;
				ClientSaveCookies(param1);
				CPrintToChat(param1, "%T", "SF2 Enabled Hints", param1);
			}
			case 2:
			{
				g_iPlayerPreferences[param1][PlayerPreference_ShowHints] = false;
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
				g_iPlayerPreferences[param1][PlayerPreference_EnableProxySelection] = true;
				ClientSaveCookies(param1);
				CPrintToChat(param1, "%T", "SF2 Enabled Proxy", param1);
			}
			case 2:
			{
				g_iPlayerPreferences[param1][PlayerPreference_EnableProxySelection] = false;
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
				g_iPlayerPreferences[param1][PlayerPreference_MuteMode] = MuteMode_Normal;
				ClientUpdateListeningFlags(param1);
				ClientSaveCookies(param1);
				CPrintToChat(param1, "{lightgreen}Mute mode set to normal.");
			}
			case 2:
			{
				g_iPlayerPreferences[param1][PlayerPreference_MuteMode] = MuteMode_DontHearOtherTeam;
				ClientUpdateListeningFlags(param1);
				ClientSaveCookies(param1);
				CPrintToChat(param1, "{lightgreen}Muted opposing team.");
			}
			case 3:
			{
				g_iPlayerPreferences[param1][PlayerPreference_MuteMode] = MuteMode_DontHearOtherTeamIfNotProxy;
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
					if (g_bSpecialRound) 
					{
						g_bPlayerDidSpecialRound[param1] = true;
					}
					
					// new boss round
					if (g_bNewBossRound) 
					{
						// If the player resets the queue points ignore them when checking for players that haven't played the new boss yet, if applicable.
						g_bPlayerPlayedNewBossRound[param1] = true;
					}
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
	
	if (!IsRoundInWarmup() && !IsRoundInIntro() && !IsRoundEnding() && !g_bPlayerEscaped[client])
	{
		if (GetGameTime() >= ClientGetFlashlightNextInputTime(client))
		{
			ClientHandleFlashlight(client);
		}
	}
	
	return Plugin_Handled;
}

public Action:Command_SprintOn(client, args)
{
	if (!g_bEnabled) return Plugin_Continue;
	
	if (IsPlayerAlive(client) && !g_bPlayerEliminated[client])
	{
		ClientHandleSprint(client, true);
	}
	
	return Plugin_Handled;
}

public Action:Command_SprintOff(client, args)
{
	if (!g_bEnabled) return Plugin_Continue;
	
	if (IsPlayerAlive(client) && !g_bPlayerEliminated[client])
	{
		ClientHandleSprint(client, false);
	}
	
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
	
	if (!IsRoundEnding())
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

public Action:Hook_CommandSuicideAttempt(client, const String:command[], argc)
{
	if (!g_bEnabled) return Plugin_Continue;
	if (IsClientInGhostMode(client)) return Plugin_Handled;
	
	if (IsRoundInIntro() && !g_bPlayerEliminated[client]) return Plugin_Handled;
	
	if (!g_bRoundGrace && !g_bPlayerEliminated[client] && GetConVarBool(g_cvBlockSuicideDuringRound)) return Plugin_Handled;
	
	return Plugin_Continue;
}

public Action:Hook_CommandBlockInGhostMode(client, const String:command[], argc)
{
	if (!g_bEnabled) return Plugin_Continue;
	if (IsClientInGhostMode(client)) return Plugin_Handled;
	if (IsRoundInIntro() && !g_bPlayerEliminated[client]) return Plugin_Handled;
	
	return Plugin_Continue;
}

public Action:Hook_CommandVoiceMenu(client, const String:command[], argc)
{
	if (!g_bEnabled) return Plugin_Continue;
	if (IsClientInGhostMode(client))
	{
		ClientGhostModeNextTarget(client);
		return Plugin_Handled;
	}
	
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
	
	if (IsRoundEnding() || IsRoundInWarmup())
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
	
	if (IsRoundEnding() || IsRoundInWarmup())
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
			SetClientPlayState(target, true);
			
			CPrintToChatAll("%t %N: %t", "SF2 Prefix", client, "SF2 Player Forced In Game", sName);
			LogAction(client, target, "%N forced %N into the game.", client, target);
		}
		else if (!iState && !g_bPlayerEliminated[target])
		{
			SetClientPlayState(target, false);
			
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
	if (timer != g_hBossCountUpdateTimer) return Plugin_Stop;
	
	if (!g_bEnabled) return Plugin_Stop;

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
			IsClientInGhostMode(i) ||
			IsClientInDeathCam(i) ||
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
				IsClientInGhostMode(iClient) ||
				IsClientInDeathCam(iClient) ||
				g_bPlayerEscaped[iClient]) 
			{
				continue;
			}
			
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
				if (SlenderGetID(i) == -1) continue;
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
		if (NavMesh_Exists())
		{
			new Handle:hProxyCandidates = CreateArray();
			
			for (new iBossIndex = 0; iBossIndex < MAX_BOSSES; iBossIndex++)
			{
				if (!g_strSlenderProfile[iBossIndex][0]) continue;
				if (!(g_iSlenderFlags[iBossIndex] & SFF_PROXIES)) continue;
				
				if (g_iSlenderCopyMaster[iBossIndex] != -1) continue; // Copies cannot generate proxies.
				
				if (GetGameTime() < g_flSlenderTimeUntilNextProxy[iBossIndex]) continue; // Proxy spawning hasn't cooled down yet.
				
				new iTeleportTarget = EntRefToEntIndex(g_iSlenderTeleportTarget[iBossIndex]);
				if (!iTeleportTarget || iTeleportTarget == INVALID_ENT_REFERENCE) continue; // No teleport target.
				
				new iMaxProxies = GetProfileNum(g_strSlenderProfile[iBossIndex], "proxies_max");
				new iNumActiveProxies = 0;
				
				for (new iClient = 1; iClient <= MaxClients; iClient++)
				{
					if (!IsClientInGame(iClient) || !g_bPlayerEliminated[iClient]) continue;
					if (!g_bPlayerProxy[iClient]) continue;
					
					if (SlenderGetFromID(g_iPlayerProxyMaster[iClient]) == iBossIndex)
					{
						iNumActiveProxies++;
					}
				}
				
				if (iNumActiveProxies >= iMaxProxies) 
				{
#if defined DEBUG
					SendDebugMessageToPlayers(DEBUG_BOSS_PROXIES, 0, "[PROXIES] Boss %d has too many active proxies!", iBossIndex);
#endif
					continue;
				}
				
				new Float:flSpawnChanceMin = GetProfileFloat(g_strSlenderProfile[iBossIndex], "proxies_spawn_chance_min");
				new Float:flSpawnChanceMax = GetProfileFloat(g_strSlenderProfile[iBossIndex], "proxies_spawn_chance_max");
				new Float:flSpawnChanceThreshold = GetProfileFloat(g_strSlenderProfile[iBossIndex], "proxies_spawn_chance_threshold") * g_flSlenderAnger[iBossIndex];
				
				new Float:flChance = GetRandomFloat(flSpawnChanceMin, flSpawnChanceMax);
				if (flChance > flSpawnChanceThreshold) 
				{
#if defined DEBUG
					SendDebugMessageToPlayers(DEBUG_BOSS_PROXIES, 0, "[PROXIES] Boss %d's chances weren't in his favor!", iBossIndex);
#endif
					continue;
				}
				
				new iAvailableProxies = iMaxProxies - iNumActiveProxies;
				
				new iSpawnNumMin = GetProfileNum(g_strSlenderProfile[iBossIndex], "proxies_spawn_num_min");
				new iSpawnNumMax = GetProfileNum(g_strSlenderProfile[iBossIndex], "proxies_spawn_num_max");
				
				new iSpawnNum = 0;
				
				// Get a list of people we can transform into a good Proxy.
				ClearArray(hProxyCandidates);
				
				for (new iClient = 1; iClient <= MaxClients; iClient++)
				{
					if (!IsClientInGame(iClient) || !g_bPlayerEliminated[iClient]) continue;
					if (g_bPlayerProxy[iClient]) continue;
					
					if (!g_iPlayerPreferences[iClient][PlayerPreference_EnableProxySelection])
					{
#if defined DEBUG
						SendDebugMessageToPlayer(iClient, DEBUG_BOSS_PROXIES, 0, "[PROXIES] You were rejected for being a proxy for boss %d because of your preferences.", iBossIndex);
#endif
						continue;
					}
					
					if (!g_bPlayerProxyAvailable[iClient])
					{
#if defined DEBUG
						SendDebugMessageToPlayer(iClient, DEBUG_BOSS_PROXIES, 0, "[PROXIES] You were rejected for being a proxy for boss %d because of your cooldown.", iBossIndex);
#endif
						continue;
					}
					
					if (g_bPlayerProxyAvailableInForce[iClient])
					{
#if defined DEBUG
						SendDebugMessageToPlayer(iClient, DEBUG_BOSS_PROXIES, 0, "[PROXIES] You were rejected for being a proxy for boss %d because you're already being forced into a Proxy.", iBossIndex);
#endif
						continue;
					}
					
					if (!IsClientParticipating(iClient))
					{
#if defined DEBUG
						SendDebugMessageToPlayer(iClient, DEBUG_BOSS_PROXIES, 0, "[PROXIES] You were rejected for being a proxy for boss %d because you're not participating.", iBossIndex);
#endif
						continue;
					}
					
					PushArrayCell(hProxyCandidates, iClient);
					iSpawnNum++;
				}
				
				if (iSpawnNum >= iSpawnNumMax)
				{
					iSpawnNum = GetRandomInt(iSpawnNumMin, iSpawnNumMax);
				}
				else if (iSpawnNum >= iSpawnNumMin)
				{
					iSpawnNum = GetRandomInt(iSpawnNumMin, iSpawnNum);
				}
				
				if (iSpawnNum <= 0) 
				{
#if defined DEBUG
					SendDebugMessageToPlayers(DEBUG_BOSS_PROXIES, 0, "[PROXIES] Boss %d had a set spawn number of 0!", iBossIndex);
#endif
					continue;
				}
				
				decl Float:flTargetPos[3];
				GetClientAbsOrigin(iTeleportTarget, flTargetPos);
				
				new iTargetAreaIndex = NavMesh_GetNearestArea(flTargetPos);
				if (iTargetAreaIndex == -1) 
				{
#if defined DEBUG
					SendDebugMessageToPlayers(DEBUG_BOSS_PROXIES, 0, "[PROXIES] Boss %d's teleport target is not on the navmesh!", iBossIndex);
#endif
					continue; // target is not on the nav mesh.
				}
				
				// Search outwards until travel distance is at maximum range.
				new Handle:hAreaArray = CreateArray(2);
				new Handle:hAreas = CreateStack();
				NavMesh_CollectSurroundingAreas(hAreas, iTargetAreaIndex, g_flSlenderProxyTeleportMaxRange[iBossIndex]);
				
				new Float:flTeleportMinRange = CalculateTeleportMinRange(iBossIndex, g_flSlenderProxyTeleportMinRange[iBossIndex], g_flSlenderProxyTeleportMaxRange[iBossIndex]);
				
				{
					new iAreaIndex = -1;
					new iPoppedAreas = 0;
					
					while (!IsStackEmpty(hAreas))
					{
						PopStackCell(hAreas, iAreaIndex);
						new iCostSoFar = NavMeshArea_GetCostSoFar(iAreaIndex);
						
						if (float(iCostSoFar) >= flTeleportMinRange)
						{
							new iIndex = PushArrayCell(hAreaArray, iAreaIndex);
							SetArrayCell(hAreaArray, iIndex, float(iCostSoFar), 1);
							iPoppedAreas++;
						}
					}
					
					CloseHandle(hAreas);
					
					if (iPoppedAreas == 0)
					{
						// no areas to use!
						CloseHandle(hAreaArray);

#if defined DEBUG
						SendDebugMessageToPlayers(DEBUG_BOSS_PROXIES, 0, "[PROXIES] Boss %d could not find any sufficient surrounding areas!", iBossIndex);
#endif
						
						continue;
					}
#if defined DEBUG
					else
					{
						SendDebugMessageToPlayers(DEBUG_BOSS_PROXIES, 0, "[PROXIES] Boss %d found %d surrounding areas", iBossIndex, iPoppedAreas);
					}
#endif
				}
				
				new Handle:hAreaArrayClose = CreateArray();
				new Handle:hAreaArrayAverage = CreateArray();
				new Handle:hAreaArrayFar = CreateArray();
				
				for (new iRangeSection = 1; iRangeSection <= 3; iRangeSection++)
				{
					new Float:flRangeSectionMin = flTeleportMinRange + (g_flSlenderProxyTeleportMaxRange[iBossIndex] - flTeleportMinRange) * (float(iRangeSection - 1) / 3.0);
					new Float:flRangeSectionMax = flTeleportMinRange + (g_flSlenderProxyTeleportMaxRange[iBossIndex] - flTeleportMinRange) * (float(iRangeSection) / 3.0);
					
					for (new i = 0, iSize = GetArraySize(hAreaArray); i < iSize; i++)
					{
						new iAreaIndex = GetArrayCell(hAreaArray, i);
						
						decl Float:flAreaCenter[3];
						NavMeshArea_GetCenter(iAreaIndex, flAreaCenter);
						
						decl Float:flTestPos[3];
						decl Float:flEyeOffset[3];
						flEyeOffset[0] = 0.0;
						flEyeOffset[1] = 0.0;
						flEyeOffset[2] = HalfHumanHeight * 2.0;
						
						// Check visibility first.
						if (IsPointVisibleToAPlayer(flAreaCenter, false, false)) 
						{
#if defined DEBUG
							SendDebugMessageToPlayers(DEBUG_BOSS_PROXIES, 0, "[PROXIES] Boss %d rejected visible area index %d! (1)", iBossIndex, iAreaIndex);
#endif
							continue;
						}
						
						AddVectors(flAreaCenter, flEyeOffset, flTestPos);
						
						if (IsPointVisibleToAPlayer(flTestPos, false, false)) 
						{
#if defined DEBUG
							SendDebugMessageToPlayers(DEBUG_BOSS_PROXIES, 0, "[PROXIES] Boss %d rejected visible area index %d! (2)", iBossIndex, iAreaIndex);
#endif
						
							continue;
						}
						
						new iBoss = EntRefToEntIndex(g_iSlender[iBossIndex]);
						
						// Check space. First raise to HalfHumanHeight * 2, then trace downwards to get ground level.
						{
							decl Float:flTraceStartPos[3];
							flTraceStartPos[0] = flAreaCenter[0];
							flTraceStartPos[1] = flAreaCenter[1];
							flTraceStartPos[2] = flAreaCenter[2] + (HalfHumanHeight * 2.0);
							
							decl Float:flTraceMins[3];
							flTraceMins[0] = -20.0;
							flTraceMins[1] = -20.0;
							flTraceMins[2] = 0.0;
							
							decl Float:flTraceMaxs[3];
							flTraceMaxs[0] = 20.0;
							flTraceMaxs[1] = 20.0;
							flTraceMaxs[2] = 0.0;
							
							new Handle:hTrace = TR_TraceHullFilterEx(flTraceStartPos,
								flAreaCenter,
								flTraceMins,
								flTraceMaxs,
								MASK_NPCSOLID,
								TraceRayDontHitEntity,
								iBoss);
							
							decl Float:flTraceHitPos[3];
							TR_GetEndPosition(flTraceHitPos, hTrace);
							flTraceHitPos[2] += 1.0;
							CloseHandle(hTrace);
							
							static Float:flTraceSpaceMin[3] = { -20.0, -20.0, 0.0 };
							static Float:flTraceSpaceMax[3] = { 20.0, 20.0, 72.0 };
							
							flTraceSpaceMax[2] = HalfHumanHeight * 2.0;
							
							if (IsSpaceOccupiedPlayer(flTraceHitPos,
								flTraceSpaceMin,
								flTraceSpaceMax,
								iBoss == INVALID_ENT_REFERENCE ? -1 : iBoss))
							{
#if defined DEBUG
								SendDebugMessageToPlayers(DEBUG_BOSS_PROXIES, 0, "[PROXIES] Boss %d rejected too small area index %d! (2)", iBossIndex, iAreaIndex);
#endif
							
								continue;
							}
						}
						
						new bool:bTooNear = false;
						
						// Check minimum range.
						for (new iClient = 1; iClient <= MaxClients; iClient++)
						{
							if (!IsClientInGame(iClient) ||
								!IsPlayerAlive(iClient) ||
								g_bPlayerEliminated[iClient] ||
								g_bPlayerEscaped[iClient] ||
								g_bPlayerProxy[iClient] ||
								IsClientInGhostMode(iClient))
							{
								continue;
							}
							
							decl Float:flTempPos[3];
							GetClientAbsOrigin(iClient, flTempPos);
							
							if (GetVectorDistance(flAreaCenter, flTempPos) <= flTeleportMinRange)
							{
								bTooNear = true;
								break;
							}
						}
						
						if (bTooNear) 
						{
#if defined DEBUG
							SendDebugMessageToPlayers(DEBUG_BOSS_PROXIES, 0, "[PROXIES] Boss %d rejected near area index %d!", iBossIndex, iAreaIndex);
#endif
						
							continue;	// This area is too close to a player.
						}
						
						// Check travel distance.
						new Float:flDist = Float:GetArrayCell(hAreaArray, i, 1);
						if (flDist > flRangeSectionMin && flDist < flRangeSectionMax)
						{
							switch (iRangeSection)
							{
								case 1: PushArrayCell(hAreaArrayClose, iAreaIndex);
								case 2: PushArrayCell(hAreaArrayAverage, iAreaIndex);
								case 3: PushArrayCell(hAreaArrayFar, iAreaIndex);
							}
						}
					}
				}
				
				CloseHandle(hAreaArray);
				
				// Set the cooldown time!
				new Float:flSpawnCooldownMin = GetProfileFloat(g_strSlenderProfile[iBossIndex], "proxies_spawn_cooldown_min");
				new Float:flSpawnCooldownMax = GetProfileFloat(g_strSlenderProfile[iBossIndex], "proxies_spawn_cooldown_max");
				
				g_flSlenderTimeUntilNextProxy[iBossIndex] = GetGameTime() + GetRandomFloat(flSpawnCooldownMin, flSpawnCooldownMax);
				
				// Randomize the array.
				SortADTArray(hProxyCandidates, Sort_Random, Sort_Integer);
				
				decl Float:flDestinationPos[3];
				
				for (new iNum = 0; iNum < iSpawnNum && iNum < iAvailableProxies; iNum++)
				{
					new iClient = GetArrayCell(hProxyCandidates, iNum);
					new iBestAreaIndex = -1;
					
					if (GetArraySize(hAreaArrayClose) > 0)
					{
						iBestAreaIndex = GetArrayCell(hAreaArrayClose, GetRandomInt(0, GetArraySize(hAreaArrayClose) - 1));
					}
					else if (GetArraySize(hAreaArrayAverage) > 0)
					{
						iBestAreaIndex = GetArrayCell(hAreaArrayAverage, GetRandomInt(0, GetArraySize(hAreaArrayAverage) - 1));
					}
					else if (GetArraySize(hAreaArrayFar) > 0)
					{
						iBestAreaIndex = GetArrayCell(hAreaArrayFar, GetRandomInt(0, GetArraySize(hAreaArrayFar) - 1));
					}
					
					if (iBestAreaIndex == -1) 
					{
#if defined DEBUG
						SendDebugMessageToPlayers(DEBUG_BOSS_PROXIES, 0, "[PROXIES] Boss %d could not find any areas to place proxies (spawned %d)!", iBossIndex, iNum);
#endif
						break;
					}
					
					NavMeshArea_GetCenter(iBestAreaIndex, flDestinationPos);
					
					if (!GetConVarBool(g_cvPlayerProxyAsk))
					{
						ClientStartProxyForce(iClient, SlenderGetID(iBossIndex), flDestinationPos);
					}
					else
					{
						DisplayProxyAskMenu(iClient, SlenderGetID(iBossIndex), flDestinationPos);
					}
				}
				
				CloseHandle(hAreaArrayClose);
				CloseHandle(hAreaArrayAverage);
				CloseHandle(hAreaArrayFar);
				
#if defined DEBUG
				SendDebugMessageToPlayers(DEBUG_BOSS_PROXIES, 0, "[PROXIES] Boss %d finished proxy process!", iBossIndex);
#endif
			}
			
			CloseHandle(hProxyCandidates);
		}
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
		LogSF2Message("Reloaded restricted weapons configuration file successfully");
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
	else if (cvar == g_cv20Dollars)
	{
		g_b20Dollars = bool:StringToInt(newValue);
	}
	else if (cvar == g_cvAllChat)
	{
		if (g_bEnabled)
		{
			for (new i = 1; i <= MaxClients; i++)
			{
				ClientUpdateListeningFlags(i);
			}
		}
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
	
	PvP_OnEntityCreated(ent, classname);
}

public OnEntityDestroyed(ent)
{
	if (!g_bEnabled) return;

	if (!IsValidEntity(ent) || ent <= 0) return;
	
	decl String:sClassname[64];
	GetEntityClassname(ent, sClassname, sizeof(sClassname));
	
	if (StrEqual(sClassname, "light_dynamic", false))
	{
		AcceptEntityInput(ent, "TurnOff");
		
		new iEnd = INVALID_ENT_REFERENCE;
		while ((iEnd = FindEntityByClassname(iEnd, "spotlight_end")) != -1)
		{
			if (GetEntPropEnt(iEnd, Prop_Data, "m_hOwnerEntity") == ent)
			{
				AcceptEntityInput(iEnd, "Kill");
				break;
			}
		}
	}
	
	PvP_OnEntityDestroyed(ent, sClassname);
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
		if (IsClientInGhostMode(entity))
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
					if (IsRoundInIntro()) return Plugin_Handled;
				
					for (new iBossIndex = 0; iBossIndex < MAX_BOSSES; iBossIndex++)
					{
						if (SlenderGetID(iBossIndex) == -1) continue;
						
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
						if (GetConVarBool(g_cvPlayerViewbobSprintEnabled) && IsClientReallySprinting(entity))
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
							if (SlenderGetID(iBossIndex) == -1) continue;
							
							if (SlenderCanHearPlayer(iBossIndex, entity, SoundType_Footstep))
							{
								GetClientAbsOrigin(entity, g_flSlenderTargetSoundTempPos[iBossIndex]);
								g_iSlenderInterruptConditions[iBossIndex] |= COND_HEARDSUSPICIOUSSOUND;
								g_iSlenderInterruptConditions[iBossIndex] |= COND_HEARDFOOTSTEP;
								
								if (IsClientSprinting(entity) && !(GetEntProp(entity, Prop_Send, "m_bDucking") || GetEntProp(entity, Prop_Send, "m_bDucked")))
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
							if (SlenderGetID(iBossIndex) == -1) continue;
							
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
		if (IsValidClient(iClient) && IsPlayerAlive(iClient) && !IsClientInGhostMode(iClient))
		{
			new bool:bCanHearSound = true;
			
			if (IsValidClient(entity) && entity != iClient)
			{
				if (!g_bPlayerEliminated[iClient])
				{
					if (g_bSpecialRound && g_iSpecialRoundType == SPECIALROUND_SINGLEPLAYER)
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
	else
	{
		new iBossIndex = SlenderEntIndexToArrayIndex(this);
		if (iBossIndex != -1)
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
	
	if (StrContains(sName, "sf2_escape_trigger", false) == 0)
	{
		if (IsRoundInEscapeObjective())
		{
			if (IsValidClient(activator) && IsPlayerAlive(activator) && !IsClientInDeathCam(activator) && !g_bPlayerEliminated[activator] && !g_bPlayerEscaped[activator])
			{
				ClientEscape(activator);
				TeleportClientToEscapePoint(activator);
			}
		}
	}
	
	PvP_OnTriggerStartTouch(caller, activator);
}

public Hook_TriggerOnEndTouch(const String:sOutput[], caller, activator, Float:flDelay)
{
	if (!g_bEnabled) return;
	
	PvP_OnTriggerEndTouch(caller, activator);
}

public Action:Hook_PageOnTakeDamage(page, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	if (!g_bEnabled) return Plugin_Continue;

	if (IsValidClient(attacker))
	{
		if (!g_bPlayerEliminated[attacker])
		{
			if (damagetype & 0x80) // 0x80 == melee damage
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
			if (IsClientInGhostMode(client))
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
		else if ((g_iPlayerLastButtons[client] & button))
		{
			ClientOnButtonRelease(client, button);
		}
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
		
		g_iPlayerPreferences[client][PlayerPreference_ShowHints] = true;
		g_iPlayerPreferences[client][PlayerPreference_MuteMode] = MuteMode_Normal;
		g_iPlayerPreferences[client][PlayerPreference_EnableProxySelection] = true;
	}
	else
	{
		new String:s2[12][32];
		ExplodeString(sCookie, " ; ", s2, 12, 32);
		
		g_iPlayerQueuePoints[client] = StringToInt(s2[0]);
		
		g_iPlayerPreferences[client][PlayerPreference_ShowHints] = bool:StringToInt(s2[1]);
		g_iPlayerPreferences[client][PlayerPreference_MuteMode] = MuteMode:StringToInt(s2[2]);
		g_iPlayerPreferences[client][PlayerPreference_EnableProxySelection] = bool:StringToInt(s2[4]);
	}
}

public OnClientPutInServer(client)
{
	if (!g_bEnabled) return;
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("START OnClientPutInServer(%d)", client);
#endif
	
	ClientSetPlayerGroup(client, -1);
	
	g_bPlayerEscaped[client] = false;
	g_bPlayerEliminated[client] = true;
	g_bPlayerChoseTeam[client] = false;
	g_bPlayerDidSpecialRound[client] = true;
	g_bPlayerPlayedNewBossRound[client] = true;
	
	g_iPlayerPreferences[client][PlayerPreference_PvPAutoSpawn] = false;
	g_iPlayerPreferences[client][PlayerPreference_ProjectedFlashlight] = false;
	
	g_iPlayerPageCount[client] = 0;
	g_iPlayerDesiredFOV[client] = 90;
	
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
	
	ClientDisableFakeLagCompensation(client);
	
	ClientResetStatic(client);
	ClientResetSlenderStats(client);
	ClientResetCampingStats(client);
	ClientResetOverlay(client);
	ClientResetJumpScare(client);
	ClientUpdateListeningFlags(client);
	ClientUpdateMusicSystem(client);
	ClientChaseMusicReset(client);
	ClientChaseMusicSeeReset(client);
	ClientAlertMusicReset(client);
	Client20DollarsMusicReset(client);
	ClientMusicReset(client);
	ClientResetProxy(client);
	ClientResetHints(client);
	ClientResetScare(client);
	
	ClientResetDeathCam(client);
	ClientResetFlashlight(client);
	ClientDeactivateUltravision(client);
	ClientResetSprint(client);
	ClientResetBreathing(client);
	ClientResetBlink(client);
	ClientResetInteractiveGlow(client);
	ClientDisableConstantGlow(client);
	
	ClientSetScareBoostEndTime(client, -1.0);
	
	ClientStartProxyAvailableTimer(client);
	
	if (!IsFakeClient(client))
	{
		// See if the player is using the custom flashlight.
		QueryClientConVar(client, "mat_supportflashlight", OnClientGetProjectedFlashlightSetting);
		
		// Get desired FOV.
		QueryClientConVar(client, "fov_desired", OnClientGetDesiredFOV);
	}
	
	PvP_OnClientPutInServer(client);
	
#if defined DEBUG
	g_iPlayerDebugFlags[client] = 0;

	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("END OnClientPutInServer(%d)", client);
#endif
}

public OnClientGetProjectedFlashlightSetting(QueryCookie:cookie, client, ConVarQueryResult:result, const String:cvarName[], const String:cvarValue[])
{
	if (result != ConVarQuery_Okay) 
	{
		LogError("Warning: Player %N failed to query for ConVar mat_supportflashlight", client);
		return;
	}
	
	if (StringToInt(cvarValue))
	{
		decl String:sAuth[64];
		GetClientAuthString(client, sAuth, sizeof(sAuth));
		
		g_iPlayerPreferences[client][PlayerPreference_ProjectedFlashlight] = true;
		LogSF2Message("Player %N (%s) has mat_supportflashlight enabled, projected flashlight will be used", client, sAuth);
	}
}

public OnClientGetDesiredFOV(QueryCookie:cookie, client, ConVarQueryResult:result, const String:cvarName[], const String:cvarValue[])
{
	if (!IsValidClient(client)) return;
	
	g_iPlayerDesiredFOV[client] = StringToInt(cvarValue);
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
	
	g_iPlayerPreferences[client][PlayerPreference_ShowHints] = true;
	g_iPlayerPreferences[client][PlayerPreference_MuteMode] = MuteMode_Normal;
	g_iPlayerPreferences[client][PlayerPreference_EnableProxySelection] = true;
	g_iPlayerPreferences[client][PlayerPreference_ProjectedFlashlight] = false;
	
	ClientResetFlashlight(client);
	ClientDeactivateUltravision(client);
	
	ClientSetGhostModeState(client, false);
	
	ClientResetInteractiveGlow(client);
	ClientStopProxyForce(client);
	ClientResetOverlay(client);
	
	if (!IsRoundInWarmup())
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
			if (g_bPlayerPlaying[client] && !g_bPlayerEliminated[client])
			{
				ClientSetQueuePoints(client, 0);
			}
		
			if (!IsRoundEnding()) CreateTimer(0.2, Timer_CheckRoundWinConditions, _, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	
	g_bPlayerEscaped[client] = false;
	
	PvP_OnClientDisconnect(client);
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("END OnClientDisconnect(%d)", client);
#endif
}

public OnClientDisconnect_Post(client)
{
    g_iPlayerLastButtons[client] = 0;
}

public TF2_OnWaitingForPlayersStart()
{
	g_bRoundWaitingForPlayers = true;
}

public TF2_OnWaitingForPlayersEnd()
{
	g_bRoundWaitingForPlayers = false;
}

SF2RoundState:GetRoundState()
{
	return g_iRoundState;
}

static GetRoundIntroParameters()
{
	g_iRoundIntroFadeColor[0] = 0;
	g_iRoundIntroFadeColor[1] = 0;
	g_iRoundIntroFadeColor[2] = 0;
	g_iRoundIntroFadeColor[3] = 255;
	
	g_flRoundIntroFadeHoldTime = GetConVarFloat(g_cvIntroDefaultHoldTime);
	g_flRoundIntroFadeDuration = GetConVarFloat(g_cvIntroDefaultFadeTime);
	
	new ent = -1;
	while ((ent = FindEntityByClassname(ent, "env_fade")) != -1)
	{
		decl String:sName[32];
		GetEntPropString(ent, Prop_Data, "m_iName", sName, sizeof(sName));
		if (StrEqual(sName, "sf2_intro_fade", false))
		{
			new iColorOffset = FindSendPropOffs("CBaseEntity", "m_clrRender");
			if (iColorOffset != -1)
			{
				g_iRoundIntroFadeColor[0] = GetEntData(ent, iColorOffset, 1);
				g_iRoundIntroFadeColor[1] = GetEntData(ent, iColorOffset + 1, 1);
				g_iRoundIntroFadeColor[2] = GetEntData(ent, iColorOffset + 2, 1);
				g_iRoundIntroFadeColor[3] = GetEntData(ent, iColorOffset + 3, 1);
			}
			
			g_flRoundIntroFadeHoldTime = GetEntPropFloat(ent, Prop_Data, "m_HoldTime");
			g_flRoundIntroFadeDuration = GetEntPropFloat(ent, Prop_Data, "m_Duration");
			
			break;
		}
	}
	
	// Get the intro music.
	strcopy(g_strRoundIntroMusic, sizeof(g_strRoundIntroMusic), SF2_INTRO_DEFAULT_MUSIC);
	
	ent = -1;
	while ((ent = FindEntityByClassname(ent, "ambient_generic")) != -1)
	{
		decl String:sName[64];
		GetEntPropString(ent, Prop_Data, "m_iName", sName, sizeof(sName));
		
		if (StrEqual(sName, "sf2_intro_music", false))
		{
			decl String:sSongPath[PLATFORM_MAX_PATH];
			GetEntPropString(ent, Prop_Data, "m_iszSound", sSongPath, sizeof(sSongPath));
			
			if (strlen(sSongPath) == 0)
			{
				LogError("Found sf2_intro_music entity, but it has no sound path specified! Default intro music will be used instead.");
			}
			else
			{
				strcopy(g_strRoundIntroMusic, sizeof(g_strRoundIntroMusic), sSongPath);
			}
			
			break;
		}
	}
}

static GetRoundEscapeParameters()
{
	g_iRoundEscapePointEntity = INVALID_ENT_REFERENCE;
	
	decl String:sName[64];
	new ent = -1;
	while ((ent = FindEntityByClassname(ent, "info_target")) != -1)
	{
		GetEntPropString(ent, Prop_Data, "m_iName", sName, sizeof(sName));
		if (!StrContains(sName, "sf2_escape_spawnpoint", false))
		{
			g_iRoundEscapePointEntity = EntIndexToEntRef(ent);
			break;
		}
	}
}

SetRoundState(SF2RoundState:iRoundState)
{
	if (g_iRoundState == iRoundState) return;
	
	PrintToServer("SetRoundState(%d)", iRoundState);
	
	new SF2RoundState:iOldRoundState = GetRoundState();
	g_iRoundState = iRoundState;
	
	// Cleanup from old roundstate if needed.
	switch (iOldRoundState)
	{
		case SF2RoundState_Waiting:
		{
		}
		case SF2RoundState_Intro:
		{
			g_hRoundIntroTimer = INVALID_HANDLE;
		}
		case SF2RoundState_Active:
		{
			g_bRoundGrace = false;
			g_hRoundGraceTimer = INVALID_HANDLE;
			g_hRoundTimer = INVALID_HANDLE;
		}
		case SF2RoundState_Escape:
		{
			g_hRoundTimer = INVALID_HANDLE;
		}
		case SF2RoundState_Outro:
		{
		}
	}
	
	switch (g_iRoundState)
	{
		case SF2RoundState_Waiting:
		{
		}
		case SF2RoundState_Intro:
		{
			g_hRoundIntroTimer = INVALID_HANDLE;
			g_iRoundIntroText = 0;
			g_bRoundIntroTextDefault = false;
			g_hRoundIntroTextTimer = CreateTimer(0.0, Timer_IntroTextSequence, _, TIMER_FLAG_NO_MAPCHANGE);
			TriggerTimer(g_hRoundIntroTextTimer);
			
			// Gather data on the intro parameters set by the map.
			new Float:flHoldTime = g_flRoundIntroFadeHoldTime;
			g_hRoundIntroTimer = CreateTimer(flHoldTime, Timer_ActivateRoundFromIntro, _, TIMER_FLAG_NO_MAPCHANGE);
			
			// Trigger any intro logic entities, if any.
			new ent = -1;
			while ((ent = FindEntityByClassname(ent, "logic_relay")) != -1)
			{
				decl String:sName[64];
				GetEntPropString(ent, Prop_Data, "m_iName", sName, sizeof(sName));
				if (StrEqual(sName, "sf2_intro_relay", false))
				{
					AcceptEntityInput(ent, "Trigger");
					break;
				}
			}
		}
		case SF2RoundState_Active:
		{
			// Start the grace period timer.
			g_bRoundGrace = true;
			g_hRoundGraceTimer = CreateTimer(GetConVarFloat(g_cvGraceTime), Timer_RoundGrace, _, TIMER_FLAG_NO_MAPCHANGE);
			
			CreateTimer(2.0, Timer_RoundStart, _, TIMER_FLAG_NO_MAPCHANGE);
			
			// Enable movement on players.
			for (new i = 1; i <= MaxClients; i++)
			{
				if (!IsClientInGame(i) || g_bPlayerEliminated[i]) continue;
				SetEntityFlags(i, GetEntityFlags(i) & ~FL_FROZEN);
			}
			
			// Fade in.
			new Float:flFadeTime = g_flRoundIntroFadeDuration;
			new iFadeFlags = SF_FADE_IN | FFADE_PURGE;
			
			for (new i = 1; i <= MaxClients; i++)
			{
				if (!IsClientInGame(i) || g_bPlayerEliminated[i]) continue;
				UTIL_ScreenFade(i, FixedUnsigned16(flFadeTime, 1 << 12), 0, iFadeFlags, g_iRoundIntroFadeColor[0], g_iRoundIntroFadeColor[1], g_iRoundIntroFadeColor[2], g_iRoundIntroFadeColor[3]);
			}
		}
		case SF2RoundState_Escape:
		{
			// Initialize the escape timer, if needed.
			if (g_iRoundEscapeTimeLimit > 0)
			{
				g_iRoundTime = g_iRoundEscapeTimeLimit;
				g_hRoundTimer = CreateTimer(1.0, Timer_RoundTimeEscape, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
			}
			else
			{
				g_hRoundTimer = INVALID_HANDLE;
			}
		
			decl String:sName[32];
			new ent = -1;
			while ((ent = FindEntityByClassname(ent, "info_target")) != -1)
			{
				GetEntPropString(ent, Prop_Data, "m_iName", sName, sizeof(sName));
				if (StrEqual(sName, "sf2_logic_escape", false))
				{
					AcceptEntityInput(ent, "FireUser1");
					break;
				}
			}
		}
		case SF2RoundState_Outro:
		{
			if (!g_bRoundHasEscapeObjective)
			{
				// Teleport winning players to the escape point.
				for (new i = 1; i <= MaxClients; i++)
				{
					if (!IsClientInGame(i)) continue;
					
					if (!g_bPlayerEliminated[i])
					{
						TeleportClientToEscapePoint(i);
					}
				}
			}
			
			for (new i = 1; i <= MaxClients; i++)
			{
				if (!IsClientInGame(i)) continue;
				
				if (IsClientInGhostMode(i))
				{
					// Take the player out of ghost mode.
					ClientSetGhostModeState(i, false);	
					TF2_RespawnPlayer(i);
				}
				else if (g_bPlayerProxy[i])
				{
					TF2_RespawnPlayer(i);
				}
				
				if (!g_bPlayerEliminated[i])
				{
					// Give them back all their weapons so they can beat the crap out of the other team.
					TF2_RegeneratePlayer(i);
				}
				
				ClientUpdateListeningFlags(i);
			}
		}
	}
}

bool:IsRoundInEscapeObjective()
{
	return bool:(GetRoundState() == SF2RoundState_Escape);
}

bool:IsRoundInWarmup()
{
	return bool:(GetRoundState() == SF2RoundState_Waiting);
}

bool:IsRoundInIntro()
{
	return bool:(GetRoundState() == SF2RoundState_Intro);
}

bool:IsRoundEnding()
{
	return bool:(GetRoundState() == SF2RoundState_Outro);
}

#define SF2_PLAYER_HUD_BLINK_SYMBOL "B"
#define SF2_PLAYER_HUD_FLASHLIGHT_SYMBOL "ϟ"
#define SF2_PLAYER_HUD_BAR_SYMBOL "|"
#define SF2_PLAYER_HUD_BAR_MISSING_SYMBOL ""
#define SF2_PLAYER_HUD_INFINITY_SYMBOL "∞"
#define SF2_PLAYER_HUD_SPRINT_SYMBOL "»"

public Action:Timer_ClientAverageUpdate(Handle:timer)
{
	if (timer != g_hClientAverageUpdateTimer) return Plugin_Stop;
	
	if (!g_bEnabled) return Plugin_Stop;
	
	if (IsRoundInWarmup() || IsRoundEnding()) return Plugin_Continue;
	
	// First, process through HUD stuff.
	decl String:buffer[256];
	
	static iHudColorHealthy[3] = { 150, 255, 150 };
	static iHudColorCritical[3] = { 255, 10, 10 };
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i)) continue;
		
		if (IsPlayerAlive(i) && !IsClientInDeathCam(i))
		{
			if (!g_bPlayerEliminated[i])
			{
				if (g_bPlayerEscaped[i]) continue;
				
				new iMaxBars = 12;
				new iBars = RoundToCeil(float(iMaxBars) * ClientGetBlinkMeter(i));
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
				
				if (!g_bSpecialRound || g_iSpecialRoundType != SPECIALROUND_LIGHTSOUT)
				{
					iBars = RoundToCeil(float(iMaxBars) * ClientGetFlashlightBatteryLife(i));
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
				
				iBars = RoundToCeil(float(iMaxBars) * (float(ClientGetSprintPoints(i)) / 100.0));
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
		ClientUpdateMusicSystem(i);
	}
	
	return Plugin_Continue;
}

stock bool:IsClientParticipating(client)
{
	if (!IsValidClient(client)) return false;
	
	if (bool:GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
	
	new iTeam = GetClientTeam(client);
	
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

SetClientPlayState(client, bool:bState, bool:bEnablePlay=true)
{
	if (bState)
	{
		if (!g_bPlayerEliminated[client]) return;
		
		g_bPlayerEliminated[client] = false;
		g_bPlayerPlaying[client] = bEnablePlay;
		g_hPlayerSwitchBlueTimer[client] = INVALID_HANDLE;
		
		ClientSetGhostModeState(client, false);
		
		PvP_SetPlayerPvPState(client, false, false, false);
		
		if (g_bSpecialRound) 
		{
			g_bPlayerDidSpecialRound[client] = true;
		}
		
		if (g_bNewBossRound) 
		{
			g_bPlayerPlayedNewBossRound[client] = true;
		}
		
		if (TF2_GetPlayerClass(client) == TFClassType:0)
		{
			// Player hasn't chosen a class for some reason. Choose one for him.
			TF2_SetPlayerClass(client, TFClassType:GetRandomInt(1, 9), true, true);
		}
		
		ChangeClientTeamNoSuicide(client, _:TFTeam_Red);
	}
	else
	{
		if (g_bPlayerEliminated[client]) return;
		
		g_bPlayerEliminated[client] = true;
		g_bPlayerPlaying[client] = false;
		
		ChangeClientTeamNoSuicide(client, _:TFTeam_Blue);
	}
}

TeleportClientToEscapePoint(client)
{
	if (!IsClientInGame(client)) return;
	
	new ent = EntRefToEntIndex(g_iRoundEscapePointEntity);
	if (ent && ent != -1)
	{
		decl Float:flPos[3], Float:flAng[3];
		GetEntPropVector(ent, Prop_Data, "m_vecAbsOrigin", flPos);
		GetEntPropVector(ent, Prop_Data, "m_angAbsRotation", flAng);
		
		TeleportEntity(client, flPos, flAng, Float:{ 0.0, 0.0, 0.0 });
		AcceptEntityInput(ent, "FireUser1", client);
	}
}

ForceInNextPlayersInQueue(iAmount, bool:bShowMessage=false)
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
			if (g_bPlayerPlaying[iClient] || !g_bPlayerEliminated[iClient] || !IsClientParticipating(iClient)) continue;
			
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
					if (!IsValidClient(iClient) || g_bPlayerPlaying[iClient] || !g_bPlayerEliminated[iClient] || !IsClientParticipating(iClient)) continue;
					if (ClientGetPlayerGroup(iClient) == iGroupIndex)
					{
						PushArrayCell(hPlayers, iClient);
						
						// Set queue points to 0.
						ClientSetQueuePoints(iClient, 0);
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
		SetClientPlayState(iClient, true);
		
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

public Action:Hook_SlenderModelSetTransmit(entity, other)
{
	if (!g_bEnabled) return Plugin_Continue;

	new iBossIndex = -1;
	
	new entref = EntIndexToEntRef(entity);
	
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		if (SlenderGetID(i) == -1) continue;
		if (g_iSlenderModel[i] != entref) continue;
		
		iBossIndex = i;
		break;
	}
	
	if (iBossIndex == -1) return Plugin_Continue;
	
	if (!IsPlayerAlive(other) || IsClientInDeathCam(other)) return Plugin_Handled;
	return Plugin_Continue;
}

public Action:Hook_SlenderObjectSetTransmit(ent, other)
{
	if (!g_bEnabled) return Plugin_Continue;
	
	if (!IsPlayerAlive(other) || IsClientInDeathCam(other))
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
			IsClientInDeathCam(iTarget) || 
			(!bIncludeEliminated && g_bPlayerEliminated[iTarget]) ||
			IsClientInGhostMode(iTarget) || 
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
	AddVectors(flMyEyeAng, g_flSlenderEyePosOffset[iBossIndex], flMyEyeAng);
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
	
	new Float:flAttackRange = GetProfileFloat(sSlenderProfile, "attack_range");
	new Float:flAttackFOV = GetProfileFloat(sSlenderProfile, "attack_fov", g_flSlenderFOV[iBossIndex] * 0.5);
	new Float:flAttackBeginRange = GetProfileFloat(sSlenderProfile, "attack_begin_range", flAttackRange);
	new Float:flAttackBeginFOV = GetProfileFloat(sSlenderProfile, "attack_begin_fov", 70.0);
	
	
	new iOldState = g_iSlenderState[iBossIndex];
	new iOldTarget = EntRefToEntIndex(g_iSlenderTarget[iBossIndex]);
	
	new iBestNewTarget = INVALID_ENT_REFERENCE;
	new Float:flSearchRange = g_flSlenderSearchRange[iBossIndex];
	new Float:flBestNewTargetDist = flSearchRange;
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
		
		if (TF2_GetPlayerClass(i) == TFClass_Medic) flPriorityValue += 0.72;
		
		flDist = GetVectorDistance(flTraceStartPos, flTraceEndPos);
		flPlayerDists[i] = flDist;
		
		if ((bPlayerNear[i] && iState != STATE_CHASE && iState != STATE_ALERT) || (bIsVisible && bPlayerInFOV[i]))
		{
			decl Float:flTargetPos[3];
			GetClientAbsOrigin(i, flTargetPos);
			
			if (flDist <= flSearchRange)
			{
				// Subtract distance to increase priority.
				flDist -= (flDist * flPriorityValue);
				
				if (flDist < flBestNewTargetDist)
				{
					iBestNewTarget = i;
					flBestNewTargetDist = flDist;
					g_iSlenderInterruptConditions[iBossIndex] |= COND_SAWENEMY;
				}
				
				g_flSlenderLastFoundPlayer[iBossIndex][i] = GetGameTime();
				g_flSlenderLastFoundPlayerPos[iBossIndex][i][0] = flTargetPos[0];
				g_flSlenderLastFoundPlayerPos[iBossIndex][i][1] = flTargetPos[1];
				g_flSlenderLastFoundPlayerPos[iBossIndex][i][2] = flTargetPos[2];
			}
		}
	}
	
	new bool:bInFlashlight = false;
	
	// Check to see if someone is facing at us with flashlight on. Only if I'm facing them too. BLINDNESS!
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsTargetValidForSlender(i, bAttackEliminated)) continue;
	
		if (!IsClientUsingFlashlight(i) || !bPlayerInFOV[i]) continue;
		
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
	
	/*
	if (IsValidEdict(iBestNewTarget))
	{
		iTarget = iBestNewTarget;
		g_iSlenderTarget[iBossIndex] = EntIndexToEntRef(iBestNewTarget);
	}
	*/
	
	if (iTarget && iTarget != INVALID_ENT_REFERENCE)
	{
		if (!IsTargetValidForSlender(iTarget, bAttackEliminated))
		{
			// Clear our target; he's not valid anymore.
			iOldTarget = iTarget;
			iTarget = INVALID_ENT_REFERENCE;
			g_iSlenderTarget[iBossIndex] = INVALID_ENT_REFERENCE;
		}
	}
	else
	{
		// Clear our target; he's not valid anymore.
		iOldTarget = iTarget;
		iTarget = INVALID_ENT_REFERENCE;
		g_iSlenderTarget[iBossIndex] = INVALID_ENT_REFERENCE;
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
			
			if (iInterruptConditions & COND_SAWENEMY)
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
						iTarget = iBestNewTarget;
						g_iSlenderTarget[iBossIndex] = EntIndexToEntRef(iBestNewTarget);
						iState = STATE_CHASE;
					}
				}
			}
			else
			{
				if (iInterruptConditions & COND_SAWENEMY)
				{
					if (IsValidClient(iBestNewTarget))
					{
						g_flSlenderGoalPos[iBossIndex][0] = g_flSlenderLastFoundPlayerPos[iBossIndex][iBestNewTarget][0];
						g_flSlenderGoalPos[iBossIndex][1] = g_flSlenderLastFoundPlayerPos[iBossIndex][iBestNewTarget][1];
						g_flSlenderGoalPos[iBossIndex][2] = g_flSlenderLastFoundPlayerPos[iBossIndex][iBestNewTarget][2];
						
						bQueueForNewPath = true;
					}
				}
				else if (iInterruptConditions & COND_HEARDSUSPICIOUSSOUND)
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
				
				new bool:bBlockingProp = false;
				
				if (g_iSlenderFlags[iBossIndex] & SFF_ATTACKPROPS)
				{
					new prop = -1;
					while ((prop = FindEntityByClassname(prop, "prop_physics")) != -1)
					{
						if (SlenderAttackValidateTarget(iBossIndex, prop, flAttackRange, flAttackFOV))
						{
							bBlockingProp = true;
							break;
						}
					}
					
					if (!bBlockingProp)
					{
						prop = -1;
						while ((prop = FindEntityByClassname(prop, "prop_dynamic")) != -1)
						{
							if (GetEntProp(prop, Prop_Data, "m_iHealth") > 0)
							{
								if (SlenderAttackValidateTarget(iBossIndex, prop, flAttackRange, flAttackFOV))
								{
									bBlockingProp = true;
									break;
								}
							}
						}
					}
				}
				
				if (bBlockingProp)
				{
					iState = STATE_ATTACK;
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
					
						decl Float:flAttackDirection[3];
						GetClientAbsOrigin(iTarget, g_flSlenderGoalPos[iBossIndex]);
						SubtractVectors(g_flSlenderGoalPos[iBossIndex], flMyPos, flAttackDirection);
						GetVectorAngles(flAttackDirection, flAttackDirection);
						
						if (GetVectorDistance(g_flSlenderGoalPos[iBossIndex], flMyPos) <= flAttackBeginRange &&
							(FloatAbs(AngleDiff(flAttackDirection[0], flMyEyeAng[0])) + FloatAbs(AngleDiff(flAttackDirection[1], flMyEyeAng[1]))) <= flAttackBeginFOV)
						{
							// ENOUGH TALK! HAVE AT YOU!
							iState = STATE_ATTACK;
						}
						else
						{
							new bool:bBlockingProp = false;
							
							if (g_iSlenderFlags[iBossIndex] & SFF_ATTACKPROPS)
							{
								new prop = -1;
								while ((prop = FindEntityByClassname(prop, "prop_physics")) != -1)
								{
									if (SlenderAttackValidateTarget(iBossIndex, prop, flAttackRange, flAttackFOV))
									{
										bBlockingProp = true;
										break;
									}
								}
								
								if (!bBlockingProp)
								{
									prop = -1;
									while ((prop = FindEntityByClassname(prop, "prop_dynamic")) != -1)
									{
										if (GetEntProp(prop, Prop_Data, "m_iHealth") > 0)
										{
											if (SlenderAttackValidateTarget(iBossIndex, prop, flAttackRange, flAttackFOV))
											{
												bBlockingProp = true;
												break;
											}
										}
									}
								}
							}
							
							if (bBlockingProp)
							{
								iState = STATE_ATTACK;
							}
							else if (GetGameTime() >= g_flSlenderNextPathTime[iBossIndex])
							{
								g_flSlenderNextPathTime[iBossIndex] = GetGameTime() + 0.33;
								bQueueForNewPath = true;
							}
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
						iState = STATE_ALERT;
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
						iState = STATE_ALERT;
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
				if (iInterruptConditions & COND_SAWENEMY)
				{
					if (IsValidEntity(iBestNewTarget))
					{
						if ((bPlayerInFOV[iBestNewTarget] || bPlayerNear[iBestNewTarget]) && bPlayerVisible[iBestNewTarget])
						{
							// Constantly update my path if I see him.
							if (GetGameTime() >= g_flSlenderNextPathTime[iBossIndex])
							{
								GetEntPropVector(iBestNewTarget, Prop_Data, "m_vecAbsOrigin", g_flSlenderGoalPos[iBossIndex]);
								bQueueForNewPath = true;
								g_flSlenderNextPathTime[iBossIndex] = GetGameTime() + 0.33;
							}
						}
					}
				}
			}
			else if (iState == STATE_CHASE || iState == STATE_ATTACK)
			{
				if (IsValidEntity(iBestNewTarget))
				{
					iOldTarget = iTarget;
					iTarget = iBestNewTarget;
					g_iSlenderTarget[iBossIndex] = EntIndexToEntRef(iBestNewTarget);
				}
				
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
#if defined DEBUG
					SendDebugMessageToPlayer(iTarget, DEBUG_BOSS_CHASE, 1, "g_flSlenderTimeUntilAlert[%d]: %f\ng_flSlenderTimeUntilNoPersistence[%d]: %f", iBossIndex, g_flSlenderTimeUntilAlert[iBossIndex] - GetGameTime(), iBossIndex, g_flSlenderTimeUntilNoPersistence[iBossIndex] - GetGameTime());
#endif
				
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
			//new Float:flGroundHeight = GetVectorDistance(flMyPos, flTraceEndPos);
			NormalizeVector(flTraceNormal, flTraceNormal);
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
		new Float:flZDiff = (flGoalPosition[2] - flMyPos[2]);
		
		if (flZDiff > flSlenderStepSize)
		{
			// Our path has a jump thingy to it. Calculate the jump height needed to reach it and how far away we should start
			// checking on when to jump.
			
			decl Float:vecDir[3], Float:vecDesiredDir[3];
			GetVectorAngles(flMyVelocity, vecDir);
			SubtractVectors(flGoalPosition, flMyPos, vecDesiredDir);
			GetVectorAngles(vecDesiredDir, vecDesiredDir);
			
			if ((FloatAbs(AngleDiff(vecDir[0], vecDesiredDir[0])) + FloatAbs(AngleDiff(vecDir[1], vecDesiredDir[1]))) >= 45.0)
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
				
				new Float:flNotImaginary = Pow(flSlenderJumpSpeed, 4.0) - (g_flGravity * (g_flGravity * Pow(fl2DDist, 2.0)) + (2.0 * flZDiff * Pow(flSlenderJumpSpeed, 2.0)));
				if (flNotImaginary >= 0.0)
				{
					// We can reach it.
					new Float:flNotInfinite = g_flGravity * fl2DDist;
					if (flNotInfinite > 0.0)
					{
						SubtractVectors(vecGoalPos2D, vecMyPos2D, angJumpReach);
						GetVectorAngles(angJumpReach, angJumpReach);
						angJumpReach[0] = -RadToDeg(ArcTangent((Pow(flSlenderJumpSpeed, 2.0) + SquareRoot(flNotImaginary)) / flNotInfinite));
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
					if (!IsClientInGame(i) || !IsPlayerAlive(i) || IsClientInDeathCam(i) || g_bPlayerEliminated[i] || g_bPlayerEscaped[i] || IsClientInGhostMode(i) || !PlayerCanSeeSlender(i, iBossIndex, false, false)) continue;
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
					AddVectors(flAng, g_flSlenderEyeAngOffset[iBossIndex], flAng);
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
							ClientStartDeathCam(iBestPlayer, iBossIndex, buffer);
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
			if (sBuffer[0]) EmitSoundToAll(sBuffer, slender, SNDCHAN_AUTO, SNDLEVEL_SCREAMING, SND_CHANGEVOL);
		}
		else
		{
			decl String:sBuffer[PLATFORM_MAX_PATH];
			GetRandomStringFromProfile(g_strSlenderProfile[iBossIndex], "sound_move", sBuffer, sizeof(sBuffer), 1);
			if (sBuffer[0]) StopSound(slender, SNDCHAN_AUTO, sBuffer);
		}
	}
	
	return Plugin_Continue;
}


SlenderOnClientStressUpdate(client)
{
	new Float:flStress = g_flPlayerStress[client];
	
	for (new iBossIndex = 0; iBossIndex < MAX_BOSSES; iBossIndex++)
	{	
		if (SlenderGetID(iBossIndex) == -1) continue;
		
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
				
#if defined DEBUG
				SendDebugMessageToPlayers(DEBUG_BOSS_TELEPORTATION, 0, "Teleport for boss %d: lost target, putting at rest period", iBossIndex);
#endif
			}
		}
		else if (!g_bRoundGrace)
		{
			new iPreferredTeleportTarget = INVALID_ENT_REFERENCE;
			
			new Float:flTargetStressMin = GetProfileFloat(g_strSlenderProfile[iBossIndex], "teleport_target_stress_min", 0.2);
			new Float:flTargetStressMax = GetProfileFloat(g_strSlenderProfile[iBossIndex], "teleport_target_stress_max", 0.9);
			
			new Float:flTargetStress = flTargetStressMax - ((flTargetStressMax - flTargetStressMin) / (g_flRoundDifficultyModifier * g_flSlenderAnger[iBossIndex]));
			
			new Float:flPreferredTeleportTargetStress = flTargetStress;
			
			for (new i = 1; i <= MaxClients; i++)
			{
				if (!IsClientInGame(i) ||
					!IsPlayerAlive(i) ||
					g_bPlayerEliminated[i] ||
					IsClientInGhostMode(i) ||
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
				
				g_iSlenderTeleportTarget[iBossIndex] = EntIndexToEntRef(iPreferredTeleportTarget);
				g_flSlenderTeleportPlayersRestTime[iBossIndex][iPreferredTeleportTarget] = -1.0;
				g_flSlenderTeleportMaxTargetTime[iBossIndex] = GetGameTime() + flTargetDuration;
				g_flSlenderTeleportTargetTime[iBossIndex] = GetGameTime();
				g_flSlenderTeleportMaxTargetStress[iBossIndex] = flTargetStress;
				
				iTeleportTarget = iPreferredTeleportTarget;
				
#if defined DEBUG
				SendDebugMessageToPlayers(DEBUG_BOSS_TELEPORTATION, 0, "Teleport for boss %d: got new target %N", iBossIndex, iPreferredTeleportTarget);
#endif
			}
		}
	}
}

// As time passes on, we have to get more aggressive in order to successfully peak the target's
// stress level in the allotted duration we're given. Otherwise we'll be forced to place him
// in a rest period.

// Teleport progressively closer as time passes in attempt to increase the target's stress level.
// Maximum minimum range is capped by the boss's anger level.

stock Float:CalculateTeleportMinRange(iBossIndex, Float:flInitialMinRange, Float:flTeleportMaxRange)
{
	new Float:flTeleportTargetTimeLeft = g_flSlenderTeleportMaxTargetTime[iBossIndex] - GetGameTime();
	new Float:flTeleportTargetTimeInitial = g_flSlenderTeleportMaxTargetTime[iBossIndex] - g_flSlenderTeleportTargetTime[iBossIndex];
	new Float:flTeleportMinRange = flTeleportMaxRange - (1.0 - (flTeleportTargetTimeLeft / flTeleportTargetTimeInitial)) * (flTeleportMaxRange - flInitialMinRange);
	
	if (g_flSlenderAnger[iBossIndex] <= 1.0)
	{
		flTeleportMinRange += (g_flSlenderTeleportMinRange[iBossIndex] - flTeleportMaxRange) * Pow(g_flSlenderAnger[iBossIndex] - 1.0, 2.0 / g_flRoundDifficultyModifier);
	}
	
	if (flTeleportMinRange < flInitialMinRange) flTeleportMinRange = flInitialMinRange;
	if (flTeleportMinRange > flTeleportMaxRange) flTeleportMinRange = flTeleportMaxRange;
	
	return flTeleportMinRange;
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
		new iBoss = EntRefToEntIndex(g_iSlender[iBossIndex]);
		if (iBoss && iBoss != INVALID_ENT_REFERENCE)
		{
			if (g_iSlenderType[iBossIndex] == 2)
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
				
#if defined DEBUG
				SendDebugMessageToPlayers(DEBUG_BOSS_TELEPORTATION, 0, "Teleport for boss %d: no good target, removing...", iBossIndex);
#endif
			}
			else
			{
				new Float:flTeleportMinRange = CalculateTeleportMinRange(iBossIndex, g_flSlenderTeleportMinRange[iBossIndex], g_flSlenderTeleportMaxRange[iBossIndex]);
				
				new iTeleportAreaIndex = -1;
				decl Float:flTeleportPos[3];
				
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
						new Handle:hAreas = CreateStack();
						NavMesh_CollectSurroundingAreas(hAreas, iTargetAreaIndex, g_flSlenderTeleportMaxRange[iBossIndex]);
						
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
							
#if defined DEBUG
							SendDebugMessageToPlayers(DEBUG_BOSS_TELEPORTATION, 0, "Teleport for boss %d: collected %d areas", iBossIndex, iPoppedAreas);
#endif
							
							CloseHandle(hAreas);
						}
						
						new Handle:hAreaArrayClose = CreateArray(4);
						new Handle:hAreaArrayAverage = CreateArray(4);
						new Handle:hAreaArrayFar = CreateArray(4);
						
						for (new i = 1; i <= 3; i++)
						{
							new Float:flRangeSectionMin = flTeleportMinRange + (g_flSlenderTeleportMaxRange[iBossIndex] - flTeleportMinRange) * (float(i - 1) / 3.0);
							new Float:flRangeSectionMax = flTeleportMinRange + (g_flSlenderTeleportMaxRange[iBossIndex] - flTeleportMinRange) * (float(i) / 3.0);
							
							for (new i2 = 0, iSize = GetArraySize(hAreaArray); i2 < iSize; i2++)
							{
								new iAreaIndex = GetArrayCell(hAreaArray, i2);
								
								decl Float:flAreaSpawnPoint[3];
								NavMeshArea_GetCenter(iAreaIndex, flAreaSpawnPoint);
								
								new iBoss = EntRefToEntIndex(g_iSlender[iBossIndex]);
								
								// Check space. First raise to HalfHumanHeight * 2, then trace downwards to get ground level.
								{
									decl Float:flTraceStartPos[3];
									flTraceStartPos[0] = flAreaSpawnPoint[0];
									flTraceStartPos[1] = flAreaSpawnPoint[1];
									flTraceStartPos[2] = flAreaSpawnPoint[2] + (HalfHumanHeight * 2.0);
									
									decl Float:flTraceMins[3];
									flTraceMins[0] = g_flSlenderDetectMins[iBossIndex][0];
									flTraceMins[1] = g_flSlenderDetectMins[iBossIndex][1];
									flTraceMins[2] = 0.0;
									
									decl Float:flTraceMaxs[3];
									flTraceMaxs[0] = g_flSlenderDetectMaxs[iBossIndex][0];
									flTraceMaxs[1] = g_flSlenderDetectMaxs[iBossIndex][1];
									flTraceMaxs[2] = 0.0;
									
									new Handle:hTrace = TR_TraceHullFilterEx(flTraceStartPos,
										flAreaSpawnPoint,
										flTraceMins,
										flTraceMaxs,
										MASK_NPCSOLID,
										TraceRayDontHitEntity,
										iBoss);
									
									decl Float:flTraceHitPos[3];
									TR_GetEndPosition(flTraceHitPos, hTrace);
									flTraceHitPos[2] += 1.0;
									CloseHandle(hTrace);
									
									if (IsSpaceOccupiedNPC(flTraceHitPos,
										g_flSlenderDetectMins[iBossIndex],
										g_flSlenderDetectMaxs[iBossIndex],
										iBoss))
									{
										continue;
									}
									
									flAreaSpawnPoint[0] = flTraceHitPos[0];
									flAreaSpawnPoint[1] = flTraceHitPos[1];
									flAreaSpawnPoint[2] = flTraceHitPos[2];
								}
								
								// Check visibility.
								if (IsPointVisibleToAPlayer(flAreaSpawnPoint, !bShouldBeBehindObstruction, false)) continue;
								
								AddVectors(flAreaSpawnPoint, g_flSlenderEyePosOffset[iBossIndex], flAreaSpawnPoint);
								
								if (IsPointVisibleToAPlayer(flAreaSpawnPoint, !bShouldBeBehindObstruction, false)) continue;
								
								SubtractVectors(flAreaSpawnPoint, g_flSlenderEyePosOffset[iBossIndex], flAreaSpawnPoint);
								
								new bool:bTooNear = false;
								
								// Check minimum range with players.
								for (new iClient = 1; iClient <= MaxClients; iClient++)
								{
									if (!IsClientInGame(iClient) ||
										!IsPlayerAlive(iClient) ||
										g_bPlayerEliminated[iClient] ||
										IsClientInGhostMode(iClient) || 
										g_bPlayerEscaped[iClient])
									{
										continue;
									}
									
									decl Float:flTempPos[3];
									GetClientAbsOrigin(iClient, flTempPos);
									
									if (GetVectorDistance(flAreaSpawnPoint, flTempPos) <= g_flSlenderTeleportMinRange[iBossIndex])
									{
										bTooNear = true;
										break;
									}
								}
								
								if (bTooNear) continue;	// This area is not compatible.
								
								// Check minimum range with boss copies (if supported).
								if (g_iSlenderFlags[iBossIndex] & SFF_COPIES)
								{
									new Float:flMinDistBetweenBosses = GetProfileFloat(g_strSlenderProfile[iBossIndex], "copy_teleport_dist_from_others", 800.0);
									
									for (new iBossCheck = 0; iBossCheck < MAX_BOSSES; iBossCheck++)
									{
										if (iBossCheck == iBossIndex ||
											SlenderGetID(iBossCheck) == -1 ||
											(g_iSlenderCopyMaster[iBossIndex] != iBossCheck && g_iSlenderCopyMaster[iBossIndex] != g_iSlenderCopyMaster[iBossCheck]))
										{
											continue;
										}
										
										new iBossEnt = EntRefToEntIndex(g_iSlender[iBossCheck]);
										if (!iBossEnt || iBossEnt == INVALID_ENT_REFERENCE) continue;
										
										decl Float:flTempPos[3];
										SlenderGetAbsOrigin(iBossCheck, flTempPos);
										
										if (GetVectorDistance(flAreaSpawnPoint, flTempPos) <= flMinDistBetweenBosses)
										{
											bTooNear = true;
											break;
										}
									}
								}
								
								if (bTooNear) continue;	// This area is not compatible.
								
								// Check travel distance and put in the appropriate arrays.
								new Float:flDist = Float:GetArrayCell(hAreaArray, i2, 1);
								if (flDist > flRangeSectionMin && flDist < flRangeSectionMax)
								{
									new iIndex = -1;
									new Handle:hTargetAreaArray = INVALID_HANDLE;
									
									switch (i)
									{
										case 1: 
										{
											iIndex = PushArrayCell(hAreaArrayClose, iAreaIndex);
											hTargetAreaArray = hAreaArrayClose;
										}
										case 2: 
										{
											iIndex = PushArrayCell(hAreaArrayAverage, iAreaIndex);
											hTargetAreaArray = hAreaArrayAverage;
										}
										case 3: 
										{
											iIndex = PushArrayCell(hAreaArrayFar, iAreaIndex);
											hTargetAreaArray = hAreaArrayFar;
										}
									}
									
									if (hTargetAreaArray != INVALID_HANDLE && iIndex != -1)
									{
										SetArrayCell(hTargetAreaArray, iIndex, flAreaSpawnPoint[0], 1);
										SetArrayCell(hTargetAreaArray, iIndex, flAreaSpawnPoint[1], 2);
										SetArrayCell(hTargetAreaArray, iIndex, flAreaSpawnPoint[2], 3);
									}
								}
							}
						}
						
						CloseHandle(hAreaArray);
						
#if defined DEBUG
						SendDebugMessageToPlayers(DEBUG_BOSS_TELEPORTATION, 0, "Teleport for boss %d: collected %d close areas, %d average areas, %d far areas", iBossIndex, GetArraySize(hAreaArrayClose),
							GetArraySize(hAreaArrayAverage),
							GetArraySize(hAreaArrayFar));
#endif
						
						new iArrayIndex = -1;
						
						if (GetArraySize(hAreaArrayClose))
						{
							iArrayIndex = GetRandomInt(0, GetArraySize(hAreaArrayClose) - 1);
							iTeleportAreaIndex = GetArrayCell(hAreaArrayClose, iArrayIndex);
							flTeleportPos[0] = Float:GetArrayCell(hAreaArrayClose, iArrayIndex, 1);
							flTeleportPos[1] = Float:GetArrayCell(hAreaArrayClose, iArrayIndex, 2);
							flTeleportPos[2] = Float:GetArrayCell(hAreaArrayClose, iArrayIndex, 3);
						}
						else if (GetArraySize(hAreaArrayAverage))
						{
							iArrayIndex = GetRandomInt(0, GetArraySize(hAreaArrayAverage) - 1);
							iTeleportAreaIndex = GetArrayCell(hAreaArrayAverage, iArrayIndex);
							flTeleportPos[0] = Float:GetArrayCell(hAreaArrayAverage, iArrayIndex, 1);
							flTeleportPos[1] = Float:GetArrayCell(hAreaArrayAverage, iArrayIndex, 2);
							flTeleportPos[2] = Float:GetArrayCell(hAreaArrayAverage, iArrayIndex, 3);
						}
						else if (GetArraySize(hAreaArrayFar))
						{
							iArrayIndex = GetRandomInt(0, GetArraySize(hAreaArrayFar) - 1);
							iTeleportAreaIndex = GetArrayCell(hAreaArrayFar, iArrayIndex);
							flTeleportPos[0] = Float:GetArrayCell(hAreaArrayFar, iArrayIndex, 1);
							flTeleportPos[1] = Float:GetArrayCell(hAreaArrayFar, iArrayIndex, 2);
							flTeleportPos[2] = Float:GetArrayCell(hAreaArrayFar, iArrayIndex, 3);
						}
						
						CloseHandle(hAreaArrayClose);
						CloseHandle(hAreaArrayAverage);
						CloseHandle(hAreaArrayFar);
					}
					else
					{
#if defined DEBUG
						SendDebugMessageToPlayers(DEBUG_BOSS_TELEPORTATION, 0, "Teleport for boss %d: failed because target is not on nav mesh!", iBossIndex);
#endif
					}
				}
				else
				{
#if defined DEBUG
					SendDebugMessageToPlayers(DEBUG_BOSS_TELEPORTATION, 0, "Teleport for boss %d: failed because of lack of nav mesh!", iBossIndex);
#endif
				}
				
				if (iTeleportAreaIndex == -1)
				{
					// We don't have any good areas. Remove myself for now.
					if (SlenderCanRemove(iBossIndex)) RemoveSlender(iBossIndex);
				}
				else
				{
					SpawnSlender(iBossIndex, flTeleportPos);
					
					if (g_iSlenderFlags[iBossIndex] & SFF_HASJUMPSCARE)
					{
						new bool:bDidJumpScare = false;
						
						for (new i = 1; i <= MaxClients; i++)
						{
							if (!IsClientInGame(i) || !IsPlayerAlive(i) || g_bPlayerEliminated[i] || IsClientInGhostMode(i)) continue;
							
							if (PlayerCanSeeSlender(i, iBossIndex, false))
							{
								if ((SlenderGetDistanceFromPlayer(iBossIndex, i) <= GetProfileFloat(g_strSlenderProfile[iBossIndex], "jumpscare_distance") &&
									GetGameTime() >= g_flSlenderNextJumpScare[iBossIndex]) ||
									PlayerCanSeeSlender(i, iBossIndex))
								{
									bDidJumpScare = true;
								
									new Float:flJumpScareDuration = GetProfileFloat(g_strSlenderProfile[iBossIndex], "jumpscare_duration");
									ClientDoJumpScare(i, iBossIndex, flJumpScareDuration);
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
		else
		{
#if defined DEBUG
			SendDebugMessageToPlayers(DEBUG_BOSS_TELEPORTATION, 0, "Teleport for boss %d: failed because of teleport time (curtime: %f, teletime: %f)", iBossIndex, GetGameTime(), g_flSlenderNextTeleportTime[iBossIndex]);
#endif
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
	new Float:flDamageVsProps = GetProfileFloat(g_strSlenderProfile[iBossIndex], "attack_damage_vs_props", flDamage);
	new iDamageType = GetProfileNum(g_strSlenderProfile[iBossIndex], "attack_damagetype");
	
	// Damage all players within range.
	decl Float:flMyEyePos[3], Float:flMyEyeAng[3];
	SlenderGetEyePosition(iBossIndex, flMyEyePos);
	GetEntPropVector(slender, Prop_Data, "m_angAbsRotation", flMyEyeAng);
	AddVectors(g_flSlenderEyePosOffset[iBossIndex], flMyEyeAng, flMyEyeAng);
	for (new i = 0; i < 3; i++) flMyEyeAng[i] = AngleNormalize(flMyEyeAng[i]);
	
	decl Float:flViewPunch[3];
	GetProfileVector(g_strSlenderProfile[iBossIndex], "attack_punchvel", flViewPunch);
	
	decl Float:flTargetDist;
	decl Handle:hTrace;
	
	new Float:flAttackRange = GetProfileFloat(g_strSlenderProfile[iBossIndex], "attack_range");
	new Float:flAttackFOV = GetProfileFloat(g_strSlenderProfile[iBossIndex], "attack_fov", g_flSlenderFOV[iBossIndex] * 0.5);
	new Float:flAttackDamageForce = GetProfileFloat(g_strSlenderProfile[iBossIndex], "attack_damageforce");
	
	new bool:bHit = false;
	
	{
		new prop = -1;
		while ((prop = FindEntityByClassname(prop, "prop_physics")) != -1)
		{
			if (SlenderAttackValidateTarget(iBossIndex, prop, flAttackRange, flAttackFOV))
			{
				bHit = true;
				SDKHooks_TakeDamage(prop, slender, slender, flDamageVsProps, iDamageType, _, _, flMyEyePos);
			}
		}
		
		prop = -1;
		while ((prop = FindEntityByClassname(prop, "prop_dynamic")) != -1)
		{
			if (GetEntProp(prop, Prop_Data, "m_iHealth") > 0)
			{
				if (SlenderAttackValidateTarget(iBossIndex, prop, flAttackRange, flAttackFOV))
				{
					bHit = true;
					SDKHooks_TakeDamage(prop, slender, slender, flDamageVsProps, iDamageType, _, _, flMyEyePos);
				}
			}
		}
	}
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || IsClientInGhostMode(i)) continue;
		
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
					GetAngleVectors(flDirection, flDirection, NULL_VECTOR, NULL_VECTOR);
					NormalizeVector(flDirection, flDirection);
					ScaleVector(flDirection, flAttackDamageForce);
					
					Call_StartForward(fOnClientDamagedByBoss);
					Call_PushCell(i);
					Call_PushCell(iBossIndex);
					Call_PushCell(slender);
					Call_PushFloat(flDamage);
					Call_PushCell(iDamageType);
					Call_Finish();
					
					SDKHooks_TakeDamage(i, slender, slender, flDamage, iDamageType, _, flDirection, flMyEyePos);
					ClientViewPunch(i, flViewPunch);
					
					if (SlenderHasAttribute(iBossIndex, "bleed player on hit"))
					{
						new Float:flDuration = SlenderGetAttributeValue(iBossIndex, "bleed player on hit");
						if (flDuration > 0.0)
						{
							TF2_MakeBleed(i, slender, flDuration);
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
		// Fling it.
		new phys = CreateEntityByName("env_physexplosion");
		if (phys != -1)
		{
			TeleportEntity(phys, flMyEyePos, NULL_VECTOR, NULL_VECTOR);
			DispatchKeyValue(phys, "spawnflags", "1");
			DispatchKeyValueFloat(phys, "radius", flAttackRange);
			DispatchKeyValueFloat(phys, "magnitude", flAttackDamageForce);
			DispatchSpawn(phys);
			ActivateEntity(phys);
			AcceptEntityInput(phys, "Explode");
			AcceptEntityInput(phys, "Kill");
		}
		
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

SlenderAttackValidateTarget(iBossIndex, iTarget, Float:flAttackRange, Float:flAttackFOV)
{
	new iBoss = EntRefToEntIndex(g_iSlender[iBossIndex]);
	
	decl Float:flMyEyePos[3], Float:flMyEyeAng[3];
	SlenderGetEyePosition(iBossIndex, flMyEyePos);
	GetEntPropVector(iBoss, Prop_Data, "m_angAbsRotation", flMyEyeAng);
	AddVectors(g_flSlenderEyePosOffset[iBossIndex], flMyEyeAng, flMyEyeAng);
	for (new i = 0; i < 3; i++) flMyEyeAng[i] = AngleNormalize(flMyEyeAng[i]);
	
	decl Float:flTargetPos[3], Float:flTargetMins[3], Float:flTargetMaxs[3];
	GetEntPropVector(iTarget, Prop_Data, "m_vecAbsOrigin", flTargetPos);
	GetEntPropVector(iTarget, Prop_Send, "m_vecMins", flTargetMins);
	GetEntPropVector(iTarget, Prop_Send, "m_vecMaxs", flTargetMaxs);
	
	for (new i = 0; i < 3; i++)
	{
		flTargetPos[i] += (flTargetMins[i] + flTargetMaxs[i]) / 2.0;
	}
	
	new Float:flTargetDist = GetVectorDistance(flTargetPos, flMyEyePos);
	if (flTargetDist <= flAttackRange)
	{
		decl Float:flDirection[3];
		SubtractVectors(g_flSlenderGoalPos[iBossIndex], flMyEyePos, flDirection);
		GetVectorAngles(flDirection, flDirection);
		
		if (FloatAbs(AngleDiff(flDirection[1], flMyEyeAng[1])) <= flAttackFOV)
		{
			new Handle:hTrace = TR_TraceRayFilterEx(flMyEyePos,
				flTargetPos,
				MASK_NPCSOLID,
				RayType_EndPoint,
				TraceRayDontHitEntity,
				iBoss);
				
			new bool:bTraceDidHit = TR_DidHit(hTrace);
			new iTraceHitEntity = TR_GetEntityIndex(hTrace);
			CloseHandle(hTrace);
			
			if (!bTraceDidHit || iTraceHitEntity == iTarget)
			{
				return true;
			}
		}
	}
	
	return false;
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

static GetPageMusicRanges()
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
				DebugMessage("Page range found: entity %d, iMin = %d, iMax = %d", ent, iMin, iMax);
#endif
				SetArrayCell(g_hPageMusicRanges, iIndex, iMin, 1);
				SetArrayCell(g_hPageMusicRanges, iIndex, iMax, 2);
			}
		}
	}
	
	LogSF2Message("Loaded page music ranges successfully!");
}

SetPageCount(iNum)
{
	if (iNum > g_iPageMax) iNum = g_iPageMax;
	
	new iOldPageCount = g_iPageCount;
	g_iPageCount = iNum;
	
	if (g_iPageCount != iOldPageCount)
	{
		if (g_iPageCount > iOldPageCount)
		{
			if (g_hRoundGraceTimer != INVALID_HANDLE) 
			{
				TriggerTimer(g_hRoundGraceTimer);
			}
			
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
	
		new iClients[MAXPLAYERS + 1] = { -1, ... };
		new iClientsNum = 0;
		
		for (new i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i)) continue;
			if (!g_bPlayerEliminated[i] || IsClientInGhostMode(i))
			{
				if (g_iPageCount)
				{
					iClients[iClientsNum] = i;
					iClientsNum++;
				}
			}
		}
		
		if (g_iPageCount > 0 && g_bRoundHasEscapeObjective && g_iPageCount == g_iPageMax)
		{
			// Escape initialized!
			SetRoundState(SF2RoundState_Escape);
			
			if (iClientsNum)
			{
				new iGameTextEscape = GetTextEntity("sf2_escape_message", false);
				if (iGameTextEscape != -1)
				{
					// Custom escape message.
					decl String:sMessage[512];
					GetEntPropString(iGameTextEscape, Prop_Data, "m_iszMessage", sMessage, sizeof(sMessage));
					ShowHudTextUsingTextEntity(iClients, iClientsNum, iGameTextEscape, g_hHudSync, sMessage);
				}
				else
				{
					// Default escape message.
					for (new i = 0; i < iClientsNum; i++)
					{
						new client = iClients[i];
						ClientShowMainMessage(client, "%d/%d\n%T", g_iPageCount, g_iPageMax, "SF2 Default Escape Message", i);
					}
				}
			}
		}
		else
		{
			if (iClientsNum)
			{
				new iGameTextPage = GetTextEntity("sf2_page_message", false);
				if (iGameTextPage != -1)
				{
					// Custom page message.
					decl String:sMessage[512];
					GetEntPropString(iGameTextPage, Prop_Data, "m_iszMessage", sMessage, sizeof(sMessage));
					ShowHudTextUsingTextEntity(iClients, iClientsNum, iGameTextPage, g_hHudSync, sMessage, g_iPageCount, g_iPageMax);
				}
				else
				{
					// Default page message.
					for (new i = 0; i < iClientsNum; i++)
					{
						new client = iClients[i];
						ClientShowMainMessage(client, "%d/%d", g_iPageCount, g_iPageMax);
					}
				}
			}
		}
		
		CreateTimer(0.2, Timer_CheckRoundWinConditions, _, TIMER_FLAG_NO_MAPCHANGE);
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
	
	new Color1[4] = { 255, 255, 255, 255 };
	new Color2[4] = { 255, 255, 255, 255 };
	
	new iParmsOffset = FindDataMapOffs(iGameText, "m_textParms");
	if (iParmsOffset != -1)
	{
		// hudtextparms_s m_textParms
		
		Color1[0] = GetEntData(iGameText, iParmsOffset + 12, 1);
		Color1[1] = GetEntData(iGameText, iParmsOffset + 13, 1);
		Color1[2] = GetEntData(iGameText, iParmsOffset + 14, 1);
		Color1[3] = GetEntData(iGameText, iParmsOffset + 15, 1);
		
		Color2[0] = GetEntData(iGameText, iParmsOffset + 16, 1);
		Color2[1] = GetEntData(iGameText, iParmsOffset + 17, 1);
		Color2[2] = GetEntData(iGameText, iParmsOffset + 18, 1);
		Color2[3] = GetEntData(iGameText, iParmsOffset + 19, 1);
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
	
	// Reset some global variables.
	g_iRoundCount++;
	g_hRoundTimer = INVALID_HANDLE;
	
	SetRoundState(SF2RoundState_Invalid);
	
	SetPageCount(0);
	g_iPageMax = 0;
	g_flPageFoundLastTime = GetGameTime();
	
	g_hVoteTimer = INVALID_HANDLE;
	
	// Remove all bosses from the game.
	for (new i = 0; i < MAX_BOSSES; i++)
	{
		RemoveProfile(i);
	}
	
	// Refresh groups.
	for (new i = 0; i < SF2_MAX_PLAYER_GROUPS; i++)
	{
		SetPlayerGroupPlaying(i, false);
		CheckPlayerGroup(i);
	}
	
	// Refresh players.
	for (new i = 1; i <= MaxClients; i++)
	{
		ClientSetGhostModeState(i, false);
		
		g_bPlayerPlaying[i] = false;
		g_bPlayerEliminated[i] = true;
		g_bPlayerEscaped[i] = false;
	}
	
	// Calculate the new round state.
	if (g_bRoundWaitingForPlayers)
	{
		SetRoundState(SF2RoundState_Waiting);
	}
	else if (GetConVarBool(g_cvWarmupRound) && g_iRoundCount < 4)
	{
		SetRoundState(SF2RoundState_Waiting);
		
		ServerCommand("mp_restartgame 15");
		PrintCenterTextAll("Round restarting in 15 seconds");
	}
	else
	{
		InitializeNewGame();
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
	
	SetRoundState(SF2RoundState_Outro);
	
	DistributeQueuePointsToPlayers();
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("EVENT END: Event_RoundEnd");
#endif
}

static DistributeQueuePointsToPlayers()
{
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
	}
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
			
			ClientSetGhostModeState(client, false);
			
			if (!bool:GetEntProp(client, Prop_Send, "m_bIsCoaching"))
			{
				// This is to prevent player spawn spam when someone is coaching. Who coaches in SF2, anyway?
				TF2_RespawnPlayer(client);
			}
			
			// Special round.
			if (g_bSpecialRound) g_bPlayerDidSpecialRound[client] = true;
			
			// Boss round.
			if (g_bNewBossRound) g_bPlayerPlayedNewBossRound[client] = true;
		}
		else
		{
			if (!g_bPlayerChoseTeam[client])
			{
				g_bPlayerChoseTeam[client] = true;
				
				if (g_iPlayerPreferences[client][PlayerPreference_ProjectedFlashlight])
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
	if (!IsRoundEnding())
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

/**
 *	Sets the player to the correct team if needed. Returns true if a change was necessary, false if no change occurred.
 */
static bool:HandlePlayerTeam(client, bool:bRespawn=true)
{
	if (!IsClientInGame(client) || !IsClientParticipating(client)) return false;
	
	if (!g_bPlayerEliminated[client])
	{
		if (GetClientTeam(client) != _:TFTeam_Red)
		{
			if (bRespawn)
				ChangeClientTeamNoSuicide(client, _:TFTeam_Red);
			else
				ChangeClientTeam(client, _:TFTeam_Red);
				
			return true;
		}
	}
	else
	{
		if (GetClientTeam(client) != _:TFTeam_Blue)
		{
			if (bRespawn)
				ChangeClientTeamNoSuicide(client, _:TFTeam_Blue);
			else
				ChangeClientTeam(client, _:TFTeam_Blue);
				
			return true;
		}
	}
	
	return false;
}

static HandlePlayerIntroState(client)
{
	if (!IsClientInGame(client) || !IsPlayerAlive(client) || !IsClientParticipating(client)) return;
	
	if (!IsRoundInIntro()) return;
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("START HandlePlayerIntroState(%d)", client);
#endif
	
	// Disable movement on player.
	SetEntityFlags(client, GetEntityFlags(client) | FL_FROZEN);
	
	new Float:flDelay = 0.0;
	if (!IsFakeClient(client))
	{
		flDelay = GetClientLatency(client, NetFlow_Outgoing);
	}
	
	CreateTimer(flDelay * 4.0, Timer_IntroBlackOut, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 2) DebugMessage("END HandlePlayerIntroState(%d)", client);
#endif
}

HandlePlayerHUD(client)
{
	if (IsRoundInWarmup() || IsClientInGhostMode(client))
	{
		SetEntProp(client, Prop_Send, "m_iHideHUD", 0);
	}
	else
	{
		if (!g_bPlayerEliminated[client])
		{
			if (!g_bPlayerEscaped[client])
			{
				// Player is in the game; disable normal HUD.
				SetEntProp(client, Prop_Send, "m_iHideHUD", HIDEHUD_CROSSHAIR | HIDEHUD_HEALTH);
			}
			else
			{
				// Player isn't in the game; enable normal HUD behavior.
				SetEntProp(client, Prop_Send, "m_iHideHUD", 0);
			}
		}
		else
		{
			if (g_bPlayerProxy[client])
			{
				// Player is in the game; disable normal HUD.
				SetEntProp(client, Prop_Send, "m_iHideHUD", HIDEHUD_CROSSHAIR | HIDEHUD_HEALTH);
			}
			else
			{
				// Player isn't in the game; enable normal HUD behavior.
				SetEntProp(client, Prop_Send, "m_iHideHUD", 0);
			}
		}
	}
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dB)
{
	if (!g_bEnabled) return;
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client <= 0) return;
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("EVENT START: Event_PlayerSpawn(%d)", client);
#endif
	
	if (!IsClientParticipating(client))
	{
		ClientSetGhostModeState(client, false);
	}
	
	g_hPlayerPostWeaponsTimer[client] = INVALID_HANDLE;
	
	if (IsPlayerAlive(client) && IsClientParticipating(client))
	{
		if (HandlePlayerTeam(client))
		{
#if defined DEBUG
		if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("client->HandlePlayerTeam()");
#endif
		}
		else
		{
			g_iPlayerPageCount[client] = 0;
			
			ClientDisableFakeLagCompensation(client);
			
			ClientResetStatic(client);
			ClientResetSlenderStats(client);
			ClientResetCampingStats(client);
			ClientResetOverlay(client);
			ClientResetJumpScare(client);
			ClientUpdateListeningFlags(client);
			ClientUpdateMusicSystem(client);
			ClientChaseMusicReset(client);
			ClientChaseMusicSeeReset(client);
			ClientAlertMusicReset(client);
			Client20DollarsMusicReset(client);
			ClientMusicReset(client);
			ClientResetProxy(client);
			ClientResetHints(client);
			ClientResetScare(client);
			
			ClientResetDeathCam(client);
			ClientResetFlashlight(client);
			ClientDeactivateUltravision(client);
			ClientResetSprint(client);
			ClientResetBreathing(client);
			ClientResetBlink(client);
			ClientResetInteractiveGlow(client);
			ClientDisableConstantGlow(client);
			
			ClientHandleGhostMode(client);
			
			if (!g_bPlayerEliminated[client])
			{
				ClientStartDrainingBlinkMeter(client);
				ClientSetScareBoostEndTime(client, -1.0);
				
				g_hPlayerCampingTimer[client] = CreateTimer(5.0, Timer_ClientCheckCamp, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
				
				HandlePlayerIntroState(client);
				
				// screen overlay timer
				g_hPlayerOverlayCheck[client] = CreateTimer(0.0, Timer_PlayerOverlayCheck, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
				TriggerTimer(g_hPlayerOverlayCheck[client], true);
				
				ClientEnableConstantGlow(client, "head");
				
				ClientActivateUltravision(client);
				
				if (g_bPlayerEscaped[client])
				{
					CreateTimer(0.1, Timer_TeleportPlayerToEscapePoint, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
				}
			}
			else
			{
				g_hPlayerOverlayCheck[client] = INVALID_HANDLE;
			}
			
			g_hPlayerPostWeaponsTimer[client] = CreateTimer(0.1, Timer_ClientPostWeapons, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
			
			HandlePlayerHUD(client);
		}
	}
	
	PvP_OnPlayerSpawn(client);
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("EVENT END: Event_PlayerSpawn(%d)", client);
#endif
}

public Action:Timer_IntroBlackOut(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client <= 0) return;
	
	if (!IsRoundInIntro()) return;
	
	if (!IsPlayerAlive(client) || g_bPlayerEliminated[client]) return;
	
	// Black out the player's screen.
	new iFadeFlags = FFADE_OUT | FFADE_STAYOUT | FFADE_PURGE;
	UTIL_ScreenFade(client, 0, FixedUnsigned16(90.0, 1 << 12), iFadeFlags, g_iRoundIntroFadeColor[0], g_iRoundIntroFadeColor[1], g_iRoundIntroFadeColor[2], g_iRoundIntroFadeColor[3]);
}

public Event_PostInventoryApplication(Handle:event, const String:name[], bool:dB)
{
	if (!g_bEnabled) return;
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("EVENT START: Event_PostInventoryApplication");
#endif
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client > 0)
	{
		g_hPlayerPostWeaponsTimer[client] = CreateTimer(0.1, Timer_ClientPostWeapons, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("EVENT END: Event_PostInventoryApplication");
#endif
}

public Action:Event_DontBroadcastToClients(Handle:event, const String:name[], bool:dB)
{
	if (!g_bEnabled) return Plugin_Continue;
	if (IsRoundInWarmup()) return Plugin_Continue;
	
	SetEventBroadcast(event, true);
	return Plugin_Continue;
}

public Action:Event_PlayerDeathPre(Handle:event, const String:name[], bool:dB)
{
	if (!g_bEnabled) return Plugin_Continue;
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 1) DebugMessage("EVENT START: Event_PlayerDeathPre");
#endif
	
	if (!IsRoundInWarmup())
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		if (client > 0)
		{
			if (!IsRoundEnding())
			{
				if (g_bRoundGrace || g_bPlayerEliminated[client] || IsClientInGhostMode(client))
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
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client <= 0) return;
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("EVENT START: Event_PlayerHurt");
#endif
	
	ClientDisableFakeLagCompensation(client);
	
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if (attacker > 0)
	{
		if (g_bPlayerProxy[attacker])
		{
			g_iPlayerProxyControl[attacker] = 100;
		}
	}
	
	// Play any sounds, if any.
	if (g_bPlayerProxy[client])
	{
		new iProxyMaster = SlenderGetFromID(g_iPlayerProxyMaster[client]);
		if (iProxyMaster != -1)
		{
			decl String:sBuffer[PLATFORM_MAX_PATH];
			if (GetRandomStringFromProfile(g_strSlenderProfile[iProxyMaster], "sound_proxy_hurt", sBuffer, sizeof(sBuffer)) && sBuffer[0])
			{
				new iChannel = GetProfileNum(g_strSlenderProfile[iProxyMaster], "sound_proxy_hurt_channel", SNDCHAN_AUTO);
				new iLevel = GetProfileNum(g_strSlenderProfile[iProxyMaster], "sound_proxy_hurt_level", SNDLEVEL_NORMAL);
				new iFlags = GetProfileNum(g_strSlenderProfile[iProxyMaster], "sound_proxy_hurt_flags", SND_NOFLAGS);
				new Float:flVolume = GetProfileFloat(g_strSlenderProfile[iProxyMaster], "sound_proxy_hurt_volume", SNDVOL_NORMAL);
				new iPitch = GetProfileNum(g_strSlenderProfile[iProxyMaster], "sound_proxy_hurt_pitch", SNDPITCH_NORMAL);
				
				EmitSoundToAll(sBuffer, client, iChannel, iLevel, iFlags, flVolume, iPitch);
			}
		}
	}
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("EVENT END: Event_PlayerHurt");
#endif
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dB)
{
	if (!g_bEnabled) return;
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client <= 0) return;
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("EVENT START: Event_PlayerDeath(%d)", client);
#endif
	
	new bool:bFake = bool:(GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER);
	
	if (!bFake)
	{
		ClientDisableFakeLagCompensation(client);
		
		ClientResetStatic(client);
		ClientResetSlenderStats(client);
		ClientResetCampingStats(client);
		ClientResetOverlay(client);
		ClientResetJumpScare(client);
		ClientResetInteractiveGlow(client);
		ClientDisableConstantGlow(client);
		ClientChaseMusicReset(client);
		ClientChaseMusicSeeReset(client);
		ClientAlertMusicReset(client);
		Client20DollarsMusicReset(client);
		ClientMusicReset(client);
		
		ClientResetFlashlight(client);
		ClientDeactivateUltravision(client);
		ClientResetSprint(client);
		ClientResetBreathing(client);
		ClientResetBlink(client);
		ClientResetDeathCam(client);
		
		ClientUpdateMusicSystem(client);
		
		PvP_SetPlayerPvPState(client, false, false, false);
		
		if (IsRoundInWarmup())
		{
			CreateTimer(0.3, Timer_RespawnPlayer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		}
		else
		{
			if (!g_bPlayerEliminated[client])
			{
				if (g_bRoundGrace || g_bPlayerEscaped[client])
				{
					CreateTimer(0.3, Timer_RespawnPlayer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
				}
				else
				{
					g_bPlayerEliminated[client] = true;
					g_bPlayerEscaped[client] = false;
					g_hPlayerSwitchBlueTimer[client] = CreateTimer(0.5, Timer_PlayerSwitchToBlue, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
				}
			}
			else
			{
			}
			
			CreateTimer(0.2, Timer_CheckRoundWinConditions, _, TIMER_FLAG_NO_MAPCHANGE);
			
			// Notify to other bosses that this player has died.
			for (new i = 0; i < MAX_BOSSES; i++)
			{
				if (SlenderGetID(i) == -1) continue;
				
				if (EntRefToEntIndex(g_iSlenderTarget[i]) == client)
				{
					g_iSlenderInterruptConditions[i] |= COND_CHASETARGETINVALIDATED;
					GetClientAbsOrigin(client, g_flSlenderChaseDeathPosition[i]);
				}
			}
		}
		
		if (g_bPlayerProxy[client])
		{
			// We're a proxy, so play some sounds.
		
			new iProxyMaster = SlenderGetFromID(g_iPlayerProxyMaster[client]);
			if (iProxyMaster != -1)
			{
				decl String:sBuffer[PLATFORM_MAX_PATH];
				if (GetRandomStringFromProfile(g_strSlenderProfile[iProxyMaster], "sound_proxy_death", sBuffer, sizeof(sBuffer)) && sBuffer[0])
				{
					new iChannel = GetProfileNum(g_strSlenderProfile[iProxyMaster], "sound_proxy_death_channel", SNDCHAN_AUTO);
					new iLevel = GetProfileNum(g_strSlenderProfile[iProxyMaster], "sound_proxy_death_level", SNDLEVEL_NORMAL);
					new iFlags = GetProfileNum(g_strSlenderProfile[iProxyMaster], "sound_proxy_death_flags", SND_NOFLAGS);
					new Float:flVolume = GetProfileFloat(g_strSlenderProfile[iProxyMaster], "sound_proxy_death_volume", SNDVOL_NORMAL);
					new iPitch = GetProfileNum(g_strSlenderProfile[iProxyMaster], "sound_proxy_death_pitch", SNDPITCH_NORMAL);
					
					EmitSoundToAll(sBuffer, client, iChannel, iLevel, iFlags, flVolume, iPitch);
				}
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
		
		g_hPlayerPostWeaponsTimer[client] = INVALID_HANDLE;
	}
	
	PvP_OnPlayerDeath(client, bFake);
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("EVENT END: Event_PlayerDeath(%d)", client);
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
		else
		{
			CloseHandle(hArrayClients);
		}
	}
}

public Action:Timer_CheckRoundWinConditions(Handle:timer)
{
	CheckRoundWinConditions();
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
		// Set round time.
		g_iRoundTime = g_iRoundTimeLimit;
		g_hRoundTimer = CreateTimer(1.0, Timer_RoundTime, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		// Infinite round time.
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
			if (!IsClientInGame(i) || !IsPlayerAlive(i) || g_bPlayerEliminated[i] || IsClientInGhostMode(i)) continue;
			
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
		if (!IsClientInGame(i) || IsFakeClient(i) || (g_bPlayerEliminated[i] && !IsClientInGhostMode(i))) continue;
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
			if (!IsClientInGame(i) || !IsPlayerAlive(i) || g_bPlayerEliminated[i] || IsClientInGhostMode(i) || g_bPlayerEscaped[i]) continue;
			
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
		if (!IsClientInGame(i) || IsFakeClient(i) || (g_bPlayerEliminated[i] && !IsClientInGhostMode(i))) continue;
		ShowSyncHudText(i, g_hRoundTimerSync, "%T\n%d:%02d", "SF2 Default Escape Message", i, minutes, seconds);
	}
	
	g_iRoundTime--;
	
	return Plugin_Continue;
}

public Action:Timer_VoteDifficulty(Handle:timer, any:data)
{
	new Handle:hArrayClients = Handle:data;
	
	if (timer != g_hVoteTimer || IsRoundEnding()) 
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

static InitializeMapEntities()
{
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("START InitializeMapEntities()");
#endif
	
	g_bRoundInfiniteFlashlight = false;
	g_bRoundInfiniteBlink = false;
	g_bRoundHasEscapeObjective = false;
	
	g_iRoundTimeLimit = GetConVarInt(g_cvTimeLimit);
	g_iRoundEscapeTimeLimit = GetConVarInt(g_cvTimeLimitEscape);
	g_iRoundTimeGainFromPage = GetConVarInt(g_cvTimeGainFromPageGrab);
	
	// Reset page reference.
	g_bPageRef = false;
	strcopy(g_strPageRefModel, sizeof(g_strPageRefModel), "");
	g_flPageRefModelScale = 1.0;
	
	new Handle:hArray = CreateArray(2);
	new Handle:hPageTrie = CreateTrie();
	
	decl String:targetName[64];
	new ent = -1;
	while ((ent = FindEntityByClassname(ent, "info_target")) != -1)
	{
		GetEntPropString(ent, Prop_Data, "m_iName", targetName, sizeof(targetName));
		if (targetName[0])
		{
			if (!StrContains(targetName, "sf2_maxpages_", false))
			{
				ReplaceString(targetName, sizeof(targetName), "sf2_maxpages_", "", false);
				g_iPageMax = StringToInt(targetName);
			}
			else if (!StrContains(targetName, "sf2_page_spawnpoint", false))
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
			else if (!StrContains(targetName, "sf2_logic_escape", false))
			{
				g_bRoundHasEscapeObjective = true;
			}
			else if (!StrContains(targetName, "sf2_infiniteflashlight", false))
			{
				g_bRoundInfiniteFlashlight = true;
			}
			else if (!StrContains(targetName, "sf2_infiniteblink", false))
			{
				g_bRoundInfiniteBlink = true;
			}
			else if (!StrContains(targetName, "sf2_time_limit_", false))
			{
				ReplaceString(targetName, sizeof(targetName), "sf2_time_limit_", "", false);
				g_iRoundTimeLimit = StringToInt(targetName);
				
				LogSF2Message("Found sf2_time_limit entity, set time limit to %d", g_iRoundTimeLimit);
			}
			else if (!StrContains(targetName, "sf2_escape_time_limit_", false))
			{
				ReplaceString(targetName, sizeof(targetName), "sf2_escape_time_limit_", "", false);
				g_iRoundEscapeTimeLimit = StringToInt(targetName);
				
				LogSF2Message("Found sf2_escape_time_limit entity, set escape time limit to %d", g_iRoundEscapeTimeLimit);
			}
			else if (!StrContains(targetName, "sf2_time_gain_from_page_", false))
			{
				ReplaceString(targetName, sizeof(targetName), "sf2_time_gain_from_page_", "", false);
				g_iRoundTimeGainFromPage = StringToInt(targetName);
				
				LogSF2Message("Found sf2_time_gain_from_page entity, set time gain to %d", g_iRoundTimeGainFromPage);
			}
			else if (g_iRoundCount == 1 && (!StrContains(targetName, "sf2_maxplayers_", false)))
			{
				ReplaceString(targetName, sizeof(targetName), "sf2_maxplayers_", "", false);
				SetConVarInt(g_cvMaxPlayers, StringToInt(targetName));
				
				LogSF2Message("Found sf2_maxplayers entity, set maxplayers to %d", StringToInt(targetName));
			}
			else if (!StrContains(targetName, "sf2_boss_override_", false))
			{
				ReplaceString(targetName, sizeof(targetName), "sf2_boss_override_", "", false);
				SetConVarString(g_cvProfileOverride, targetName);
				
				LogSF2Message("Found sf2_boss_override entity, set boss profile override to %s", targetName);
			}
		}
	}
	
	// Get a reference entity, if any.
	
	ent = -1;
	while ((ent = FindEntityByClassname(ent, "prop_dynamic")) != -1)
	{
		if (g_bPageRef) break;
	
		GetEntPropString(ent, Prop_Data, "m_iName", targetName, sizeof(targetName));
		if (targetName[0])
		{
			if (StrEqual(targetName, "sf2_page_model", false))
			{
				g_bPageRef = true;
				GetEntPropString(ent, Prop_Data, "m_ModelName", g_strPageRefModel, sizeof(g_strPageRefModel));
				g_flPageRefModelScale = 1.0;
			}
		}
	}
	
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
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("END InitializeMapEntities()");
#endif
}

static HandleNewBossRoundState()
{
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("START HandleNewBossRoundState()");
#endif
	
	new bool:bBossOld = g_bNewBossRound;
	new bool:bBossContinuousOld = g_bNewBossRoundContinuous;
	g_bNewBossRound = false;
	g_bNewBossRoundNew = false;
	g_bNewBossRoundContinuous = false;
	
	new bool:bForceNew = false;
	
	if (bBossOld)
	{
		if (bBossContinuousOld)
		{
			// Check if there are players who haven't played the boss round yet.
			for (new i = 1; i <= MaxClients; i++)
			{
				if (!IsClientInGame(i) || !IsClientParticipating(i))
				{
					g_bPlayerPlayedNewBossRound[i] = true;
					continue;
				}
				
				if (!g_bPlayerPlayedNewBossRound[i])
				{
					// Someone didn't get to play this yet. Continue the boss round.
					g_bNewBossRound = true;
					g_bNewBossRoundContinuous = true;
					break;
				}
			}
		}
	}
	
	new iRoundInterval = GetConVarInt(g_cvNewBossRoundInterval);
	
	if (iRoundInterval > 0 && g_iNewBossRoundCount >= iRoundInterval)
	{
		g_bNewBossRound = true;
		bForceNew = true;
	}
	
	// Do boss round force override and reset it.
	if (GetConVarInt(g_cvNewBossRoundForce) >= 0)
	{
		g_bNewBossRound = GetConVarBool(g_cvNewBossRoundForce);
		SetConVarInt(g_cvNewBossRoundForce, -1);
	}
	
	new Handle:hSelectableBossList = GetSelectableBossProfileList();
	
	// Check if we have enough bosses.
	if (g_bNewBossRound)
	{
		if (GetArraySize(hSelectableBossList) < 2)
		{
			g_bNewBossRound = false; // Not enough bosses.
		}
	}
	
	CloseHandle(hSelectableBossList);
	
	if (g_bNewBossRound)
	{
		if (bForceNew || !bBossOld || !bBossContinuousOld)
		{
			g_bNewBossRoundNew = true;
		}
		
		if (g_bNewBossRoundNew)
		{
			if (GetConVarInt(g_cvNewBossRoundBehavior) == 1)
			{
				g_bNewBossRoundContinuous = true;
			}
			else
			{
				// New "new boss round", but it's not continuous.
				g_bNewBossRoundContinuous = false;
			}
		}
	}
	else
	{
		g_bNewBossRoundContinuous = false;
	}
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("END HandleNewBossRoundState() -> g_bNewBossRound = %d (count = %d, new = %d, continuous = %d)", g_bNewBossRound, g_iNewBossRoundCount, g_bNewBossRoundNew, g_bNewBossRoundContinuous);
#endif
}

static SelectStartingBossesForRound()
{
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("START SelectStartingBossesForRound()");
#endif

	new Handle:hBossList = GetBossProfileList();
	new Handle:hSelectableBossList = GetSelectableBossProfileList();

	// Select which boss profile to use.
	decl String:sProfileOverride[SF2_MAX_PROFILE_NAME_LENGTH];
	GetConVarString(g_cvProfileOverride, sProfileOverride, sizeof(sProfileOverride));
	
	if (sProfileOverride[0] && FindStringInArray(hBossList, sProfileOverride) != -1)
	{
		// Pick the overridden boss.
		strcopy(g_strRoundBossProfile, sizeof(g_strRoundBossProfile), sProfileOverride);
		SetConVarString(g_cvProfileOverride, "");
	}
	else if (g_bNewBossRound)
	{
		if (g_bNewBossRoundNew)
		{
			GetArrayString(hSelectableBossList, GetRandomInt(0, GetArraySize(hSelectableBossList) - 1), g_strNewBossRoundProfile, sizeof(g_strNewBossRoundProfile));
		}
		
		strcopy(g_strRoundBossProfile, sizeof(g_strRoundBossProfile), g_strNewBossRoundProfile);
	}
	else
	{
		decl String:sProfile[SF2_MAX_PROFILE_NAME_LENGTH];
		GetConVarString(g_cvBossMain, sProfile, sizeof(sProfile));
		
		if (sProfile[0] && FindStringInArray(hBossList, sProfile) != -1)
		{
			strcopy(g_strRoundBossProfile, sizeof(g_strRoundBossProfile), sProfile);
		}
		else
		{
			// Pick the first boss in our array if the main boss doesn't exist.
			GetArrayString(hSelectableBossList, 0, g_strRoundBossProfile, sizeof(g_strRoundBossProfile));
		}
	}
	
	CloseHandle(hBossList);
	CloseHandle(hSelectableBossList);
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("END SelectStartingBossesForRound() -> boss: %s", g_strRoundBossProfile);
#endif
}

InitializeNewGame()
{
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("START InitializeNewGame()");
#endif
	
	GetRoundIntroParameters();
	GetRoundEscapeParameters();
	
	// Choose round state.
	if (GetConVarBool(g_cvIntroEnabled))
	{
		// Set the round state to the intro stage.
		SetRoundState(SF2RoundState_Intro);
	}
	else
	{
		SetRoundState(SF2RoundState_Active);
	}
	
	if (g_iRoundCount <= 1)
	{
		SetConVarString(g_cvProfileOverride, "");
	}
	
	g_bSpecialRoundNew = false;
	
	if (!g_bSpecialRound)
	{
		g_iSpecialRoundCount++;
		
		if (GetConVarInt(g_cvSpecialRoundInterval) > 0)
		{
			new iCount = g_iSpecialRoundCount;
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
			
			// Display the current special round going on to late players.
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
		decl String:sPath[PLATFORM_MAX_PATH];
	
		for (new i = 0; i < GetArraySize(g_hPageMusicRanges); i++)
		{
			new ent = EntRefToEntIndex(GetArrayCell(g_hPageMusicRanges, i));
			if (!ent || ent == INVALID_ENT_REFERENCE) continue;
			
			GetEntPropString(ent, Prop_Data, "m_iszSound", sPath, sizeof(sPath));
			if (sPath[0])
			{
				PrecacheSound(sPath);
			}
		}
	}
	
	InitializeMapEntities();
	
	// Determine boss round state.
	HandleNewBossRoundState();
	
	if (g_bNewBossRound)
	{
		if (g_bNewBossRoundNew)
		{
			// Reset round count;
			g_iNewBossRoundCount = 1;
			
			if (g_bNewBossRoundContinuous)
			{
				// It's the start of a continuous "new boss round".
			
				// Initialize all players' values.
				for (new i = 1; i <= MaxClients; i++)
				{
					if (!IsClientInGame(i))
					{
						g_bPlayerPlayedNewBossRound[i] = true;
						continue;
					}
				
					if (!IsClientParticipating(i))
					{
						g_bPlayerPlayedNewBossRound[i] = true;
						continue;
					}
					
					g_bPlayerPlayedNewBossRound[i] = false;
				}
			}
		}
	}
	else
	{
		g_iNewBossRoundCount++;
	}
	
	SelectStartingBossesForRound();
	
	ForceInNextPlayersInQueue(GetConVarInt(g_cvMaxPlayers));
	
	// Respawn all players, if needed.
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientParticipating(i))
		{
			if (!HandlePlayerTeam(i))
			{
				if (!g_bPlayerEliminated[i])
				{
					// Players currently in the "game" still have to be respawned.
					TF2_RespawnPlayer(i);
				}
			}
		}
	}
	
	if (GetRoundState() == SF2RoundState_Intro)
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i)) continue;
			
			if (!g_bPlayerEliminated[i])
			{
				if (!IsFakeClient(i))
				{
					// Currently in intro state, play intro music.
					g_hPlayerIntroMusicTimer[i] = CreateTimer(0.5, Timer_PlayIntroMusicToPlayer, GetClientUserId(i), TIMER_FLAG_NO_MAPCHANGE);
				}
				else
				{
					g_hPlayerIntroMusicTimer[i] = INVALID_HANDLE;
				}
			}
			else
			{
				g_hPlayerIntroMusicTimer[i] = INVALID_HANDLE;
			}
		}
	}
	else
	{
		// Spawn the boss!
		SelectProfile(0, g_strRoundBossProfile);
	}
	
#if defined DEBUG
	if (GetConVarInt(g_cvDebugDetail) > 0) DebugMessage("END InitializeNewGame()");
#endif
}

public Action:Timer_PlayIntroMusicToPlayer(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client <= 0) return;
	
	if (timer != g_hPlayerIntroMusicTimer[client]) return;
	
	g_hPlayerIntroMusicTimer[client] = INVALID_HANDLE;
	
	EmitSoundToClient(client, g_strRoundIntroMusic, _, MUSIC_CHAN, SNDLEVEL_NONE);
}

public Action:Timer_IntroTextSequence(Handle:timer)
{
	if (!g_bEnabled) return;
	if (g_hRoundIntroTextTimer != timer) return;
	
	new Float:flDuration = 0.0;
	
	if (g_iRoundIntroText != 0)
	{
		decl String:sTargetname[64];
		Format(sTargetname, sizeof(sTargetname), "sf2_intro_text_%d", g_iRoundIntroText);
		
		new iGameText = INVALID_ENT_REFERENCE;
		new bool:bFoundGameText = false;
		
		new iClients[MAXPLAYERS + 1];
		new iClientsNum;
		
		for (new i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || g_bPlayerEliminated[i]) continue;
			
			iClients[iClientsNum] = i;
			iClientsNum++;
		}
		
		if (!g_bRoundIntroTextDefault)
		{
			while ((iGameText = FindEntityByClassname(iGameText, "game_text")) != -1)
			{
				decl String:sName[64];
				GetEntPropString(iGameText, Prop_Data, "m_iName", sName, sizeof(sName));
				
				if (StrEqual(sName, sTargetname, false))
				{
					bFoundGameText = true;
					flDuration = GetEntPropFloat(iGameText, Prop_Data, "m_textParms.fadeinTime") + GetEntPropFloat(iGameText, Prop_Data, "m_textParms.fadeoutTime") + GetEntPropFloat(iGameText, Prop_Data, "m_textParms.holdTime");
					
					decl String:sMessage[512];
					GetEntPropString(iGameText, Prop_Data, "m_iszMessage", sMessage, sizeof(sMessage));
					ShowHudTextUsingTextEntity(iClients, iClientsNum, iGameText, g_hHudSync, sMessage);
					break;
				}
			}
		}
		else
		{
			if (g_iRoundIntroText == 2)
			{
				bFoundGameText = false;
				
				decl String:sMessage[64];
				GetCurrentMap(sMessage, sizeof(sMessage));
				
				for (new i = 0; i < iClientsNum; i++)
				{
					ClientShowMainMessage(iClients[i], sMessage, 1);
				}
			}
		}
		
		if (g_iRoundIntroText == 1 && !bFoundGameText)
		{
			// Use default intro sequence. Eugh.
			g_bRoundIntroTextDefault = true;
			flDuration = GetConVarFloat(g_cvIntroDefaultHoldTime) / 2.0;
			
			for (new i = 0; i < iClientsNum; i++)
			{
				EmitSoundToClient(iClients[i], SF2_INTRO_DEFAULT_MUSIC, _, MUSIC_CHAN, SNDLEVEL_NONE);
			}
		}
		else
		{
			if (!bFoundGameText) return; // done with sequence; don't check anymore.
		}
	}
	
	g_iRoundIntroText++;
	g_hRoundIntroTextTimer = CreateTimer(flDuration, Timer_IntroTextSequence, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_ActivateRoundFromIntro(Handle:timer)
{
	if (!g_bEnabled) return;
	if (g_hRoundIntroTimer != timer) return;
	
	// Obviously we don't want to spawn the boss when g_strRoundBossProfile isn't set yet.
	SetRoundState(SF2RoundState_Active);
	
	// Spawn the boss!
	SelectProfile(0, g_strRoundBossProfile);
}

CheckRoundWinConditions()
{
	if (IsRoundInWarmup() || IsRoundEnding()) return;
	
	new iTotalCount = 0;
	new iAliveCount = 0;
	new iEscapedCount = 0;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i)) continue;
		iTotalCount++;
		if (!g_bPlayerEliminated[i] && !IsClientInDeathCam(i)) 
		{
			iAliveCount++;
			if (g_bPlayerEscaped[i]) iEscapedCount++;
		}
	}
	
	if (iAliveCount == 0)
	{
		ForceTeamWin(_:TFTeam_Blue);
	}
	else
	{
		if (IsRoundInEscapeObjective())
		{
			if (iEscapedCount == iAliveCount)
			{
				ForceTeamWin(_:TFTeam_Red);
			}
		}
		else
		{
			if (g_iPageMax > 0 && g_iPageCount == g_iPageMax)
			{
				ForceTeamWin(_:TFTeam_Red);
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
	return IsClientInGhostMode(GetNativeCell(1));
}

public Native_IsClientProxy(Handle:plugin, numParams)
{
	return g_bPlayerProxy[GetNativeCell(1)];
}

public Native_GetClientBlinkCount(Handle:plugin, numParams)
{
	return ClientGetBlinkCount(GetNativeCell(1));
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
	g_iPlayerProxyMaster[GetNativeCell(1)] = SlenderGetID(GetNativeCell(2));
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
		if (SlenderGetID(i) == iBossID) return i;
	}
	
	return -1;
}

public Native_BossIndexToBossID(Handle:plugin, numParams)
{
	return SlenderGetID(GetNativeCell(1));
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