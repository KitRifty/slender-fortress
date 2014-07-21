#if defined _sf2_profiles_included
 #endinput
#endif
#define _sf2_profiles_included

#define FILE_PROFILES "configs/sf2/profiles.cfg"

static Handle:g_hBossProfileList = INVALID_HANDLE;
static Handle:g_hSelectableBossProfileList = INVALID_HANDLE;

InitializeProfiles()
{
}

public ProfilesOnMapEnd()
{
	if (g_hBossProfileList != INVALID_HANDLE)
	{
		CloseHandle(g_hBossProfileList);
		g_hBossProfileList = INVALID_HANDLE;
	}
	
	if (g_hSelectableBossProfileList != INVALID_HANDLE)
	{
		CloseHandle(g_hSelectableBossProfileList);
		g_hSelectableBossProfileList = INVALID_HANDLE;
	}
}

ReloadProfiles()
{
	if (g_hConfig != INVALID_HANDLE)
	{
		CloseHandle(g_hConfig);
		g_hConfig = INVALID_HANDLE;
	}
	
	// Clear and reload the lists.
	if (g_hBossProfileList == INVALID_HANDLE)
	{
		g_hBossProfileList = CreateArray(SF2_MAX_PROFILE_NAME_LENGTH);
	}
	
	if (g_hSelectableBossProfileList == INVALID_HANDLE)
	{
		g_hSelectableBossProfileList = CreateArray(SF2_MAX_PROFILE_NAME_LENGTH);
	}
	
	decl String:buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, sizeof(buffer), FILE_PROFILES);
	new Handle:kv = CreateKeyValues("root");
	if (!FileToKeyValues(kv, buffer))
	{
		CloseHandle(kv);
		LogSF2Message("Boss profiles config file not found! No boss profiles will be loaded.");
	}
	else
	{
		LogSF2Message("Loading boss profiles from config file...");
	
		KvRewind(kv);
		if (KvGotoFirstSubKey(kv))
		{
			g_hConfig = kv;
			
			decl String:sProfile[SF2_MAX_PROFILE_NAME_LENGTH];
			decl String:sProfileLoadFailReason[512];
			
			new iLoadedCount = 0;
			
			do
			{
				KvGetSectionName(g_hConfig, sProfile, sizeof(sProfile));
				if (LoadProfile(sProfile, sProfileLoadFailReason, sizeof(sProfileLoadFailReason)))
				{
					iLoadedCount++;
					LogSF2Message("%s...", sProfile);
				}
				else
				{
					LogSF2Message("%s...FAILED (reason: %s)", sProfile, sProfileLoadFailReason);
				}
			}
			while (KvGotoNextKey(g_hConfig));
			
			LogSF2Message("Loaded %d boss profile(s) from config file!", iLoadedCount);
		}
		else
		{
			CloseHandle(kv);
			
			LogSF2Message("No boss profiles detected in config file! No boss profiles will be loaded.");
		}
	}
}

/**
 *	Loads a profile in the current KeyValues position in g_hConfig.
 */
static bool:LoadProfile(const String:sProfile[], String:sLoadFailReasonBuffer[], iLoadFailReasonBufferLen)
{
	// Add to the boss list.
	PushArrayString(GetBossProfileList(), sProfile);
	
	if (bool:KvGetNum(g_hConfig, "enable_random_selection", 1))
	{
		// Add to the selectable boss list.
		PushArrayString(GetSelectableBossProfileList(), sProfile);
	}
	
	if (KvGotoFirstSubKey(g_hConfig))
	{
		decl String:s2[64], String:s3[64], String:s4[PLATFORM_MAX_PATH], String:s5[PLATFORM_MAX_PATH];
		
		do
		{
			KvGetSectionName(g_hConfig, s2, sizeof(s2));
			
			if (!StrContains(s2, "sound_"))
			{
				for (new i = 1;; i++)
				{
					IntToString(i, s3, sizeof(s3));
					KvGetString(g_hConfig, s3, s4, sizeof(s4));
					if (!s4[0]) break;
					
					PrecacheSound2(s4);
				}
			}
			else if (StrEqual(s2, "download"))
			{
				for (new i = 1;; i++)
				{
					IntToString(i, s3, sizeof(s3));
					KvGetString(g_hConfig, s3, s4, sizeof(s4));
					if (!s4[0]) break;
					
					AddFileToDownloadsTable(s4);
				}
			}
			else if (StrEqual(s2, "mod_precache"))
			{
				for (new i = 1;; i++)
				{
					IntToString(i, s3, sizeof(s3));
					KvGetString(g_hConfig, s3, s4, sizeof(s4));
					if (!s4[0]) break;
					
					PrecacheModel(s4, true);
				}
			}
			else if (StrEqual(s2, "mat_download"))
			{	
				for (new i = 1;; i++)
				{
					IntToString(i, s3, sizeof(s3));
					KvGetString(g_hConfig, s3, s4, sizeof(s4));
					if (!s4[0]) break;
					
					Format(s5, sizeof(s5), "%s.vtf", s4);
					AddFileToDownloadsTable(s5);
					Format(s5, sizeof(s5), "%s.vmt", s4);
					AddFileToDownloadsTable(s5);
				}
			}
			else if (StrEqual(s2, "mod_download"))
			{
				static const String:extensions[][] = { ".mdl", ".phy", ".dx80.vtx", ".dx90.vtx", ".sw.vtx", ".vvd" };
				
				for (new i = 1;; i++)
				{
					IntToString(i, s3, sizeof(s3));
					KvGetString(g_hConfig, s3, s4, sizeof(s4));
					if (!s4[0]) break;
					
					for (new is = 0; is < sizeof(extensions); is++)
					{
						Format(s5, sizeof(s5), "%s%s", s4, extensions[is]);
						AddFileToDownloadsTable(s5);
					}
				}
			}
		}
		while (KvGotoNextKey(g_hConfig));
		
		KvGoBack(g_hConfig);
	}
	
	return true;
}

bool:IsProfileValid(const String:sProfile[])
{
	return bool:(FindStringInArray(GetBossProfileList(), sProfile) != -1);
}

stock GetProfileNum(const String:sProfile[], const String:keyValue[], defaultValue=0)
{
	if (!IsProfileValid(sProfile)) return defaultValue;
	
	KvRewind(g_hConfig);
	KvJumpToKey(g_hConfig, sProfile);
	
	return KvGetNum(g_hConfig, keyValue, defaultValue);
}

stock Float:GetProfileFloat(const String:sProfile[], const String:keyValue[], Float:defaultValue=0.0)
{
	if (!IsProfileValid(sProfile)) return defaultValue;
	
	KvRewind(g_hConfig);
	KvJumpToKey(g_hConfig, sProfile);
	
	return KvGetFloat(g_hConfig, keyValue, defaultValue);
}

stock bool:GetProfileVector(const String:sProfile[], const String:keyValue[], Float:buffer[3], const Float:defaultValue[3]=NULL_VECTOR)
{
	for (new i = 0; i < 3; i++) buffer[i] = defaultValue[i];
	
	if (!IsProfileValid(sProfile)) return false;
	
	KvRewind(g_hConfig);
	KvJumpToKey(g_hConfig, sProfile);
	
	KvGetVector(g_hConfig, keyValue, buffer, defaultValue);
	return true;
}

stock bool:GetProfileColor(const String:sProfile[], 
	const String:keyValue[], 
	&r, 
	&g, 
	&b, 
	&a,
	dr=255,
	dg=255,
	db=255,
	da=255)
{
	r = dr;
	g = dg;
	b = db;
	a = da;
	
	if (!IsProfileValid(sProfile)) return false;
	
	KvRewind(g_hConfig);
	KvJumpToKey(g_hConfig, sProfile);
	
	decl String:sValue[64];
	KvGetString(g_hConfig, keyValue, sValue, sizeof(sValue));
	
	if (strlen(sValue) != 0)
	{
		KvGetColor(g_hConfig, keyValue, r, g, b, a);
	}
	
	return true;
}

stock bool:GetProfileString(const String:sProfile[], const String:keyValue[], String:buffer[], bufferlen, const String:defaultValue[]="")
{
	strcopy(buffer, bufferlen, defaultValue);
	
	if (!IsProfileValid(sProfile)) return false;
	
	KvRewind(g_hConfig);
	KvJumpToKey(g_hConfig, sProfile);
	
	KvGetString(g_hConfig, keyValue, buffer, bufferlen, defaultValue);
	return true;
}

// Code originally from FF2. Credits to the original authors Rainbolt Dash and FlaminSarge.
stock bool:GetRandomStringFromProfile(const String:sProfile[], const String:strKeyValue[], String:buffer[], bufferlen, index=-1)
{
	strcopy(buffer, bufferlen, "");
	
	if (!IsProfileValid(sProfile)) return false;
	
	KvRewind(g_hConfig);
	KvJumpToKey(g_hConfig, sProfile);
	
	if (!KvJumpToKey(g_hConfig, strKeyValue)) return false;
	
	decl String:s[32], String:s2[PLATFORM_MAX_PATH];
	
	new i = 1;
	for (;;)
	{
		IntToString(i, s, sizeof(s));
		KvGetString(g_hConfig, s, s2, sizeof(s2));
		if (!s2[0]) break;
		
		i++;
	}
	
	if (i == 1) return false;
	
	IntToString(index < 0 ? GetRandomInt(1, i - 1) : index, s, sizeof(s));
	KvGetString(g_hConfig, s, buffer, bufferlen);
	return true;
}

/**
 *	Returns an array of strings of the profile names of every valid boss.
 */
Handle:GetBossProfileList()
{
	return g_hBossProfileList;
}

/**
 *	Returns an array of strings of the profile names of every valid boss that can be randomly selected.
 */
Handle:GetSelectableBossProfileList()
{
	return g_hSelectableBossProfileList;
}