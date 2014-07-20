#if defined _sf2_profiles_included
 #endinput
#endif
#define _sf2_profiles_included

#define FILE_PROFILES "configs/sf2/profiles.cfg"

static Handle:g_hBossProfileList = INVALID_HANDLE;
static Handle:g_hSelectableBossProfileList = INVALID_HANDLE;

InitializeProfiles()
{
	g_hBossProfileList = CreateArray(SF2_MAX_PROFILE_NAME_LENGTH);
	g_hSelectableBossProfileList = CreateArray(SF2_MAX_PROFILE_NAME_LENGTH);
}

ReloadProfiles()
{
	if (g_hConfig != INVALID_HANDLE)
	{
		CloseHandle(g_hConfig);
		g_hConfig = INVALID_HANDLE;
	}
	
	// Clear the lists.
	ClearArray(g_hBossProfileList);
	ClearArray(g_hSelectableBossProfileList);
	
	decl String:buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, sizeof(buffer), FILE_PROFILES);
	new Handle:kv = CreateKeyValues("root");
	if (!FileToKeyValues(kv, buffer))
	{
		CloseHandle(kv);
		SetFailState("Failed to load profiles! File not found!");
	}
	else
	{
		KvRewind(kv);
		if (KvGotoFirstSubKey(kv))
		{
			g_hConfig = kv;
		
			decl String:strName[64];
			new Handle:hArray = CreateArray(64);
		
			do
			{
				KvGetSectionName(g_hConfig, strName, sizeof(strName));
				PushArrayString(hArray, strName);
			}
			while KvGotoNextKey(g_hConfig);
			
			new size = GetArraySize(hArray);
			for (new i = 0; i < size; i++)
			{
				GetArrayString(hArray, i, strName, sizeof(strName));
				LoadProfile(strName);
			}
			
			CloseHandle(hArray);
			
			LogMessage("Boss profiles successfully loaded!");
		}
		else
		{
			CloseHandle(kv);
			SetFailState("Failed to load boss profiles! No entries found!");
		}
	}
}

static LoadProfile(const String:strName[])
{
	if (g_hConfig == INVALID_HANDLE) return;
	
	KvRewind(g_hConfig);
	if (!KvJumpToKey(g_hConfig, strName)) return;
	if (!KvGotoFirstSubKey(g_hConfig)) return;
	
	decl String:sBuffer[64];
	KvGetString(g_hConfig, "name", sBuffer, sizeof(sBuffer));
	if (!sBuffer[0]) strcopy(sBuffer, sizeof(sBuffer), strName);
	
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
			new String:extensions[][] = { ".mdl", ".phy", ".dx80.vtx", ".dx90.vtx", ".sw.vtx", ".vvd" };
			
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
	
	// Add to the boss list.
	PushArrayString(g_hBossProfileList, strName);
	
	if (bool:KvGetNum(g_hConfig, "enable_random_selection", 1))
	{
		// Add to the selectable boss list.
		PushArrayString(g_hSelectableBossProfileList, strName);
	}
	
	LogMessage("Successfully loaded boss %s", sBuffer);
}

bool:IsProfileValid(const String:sProfile[])
{
	return bool:(FindStringInArray(GetBossProfileList(), sProfile) != -1);
}

stock GetProfileNum(const String:strName[], const String:keyValue[], defaultValue=0)
{
	if (!IsProfileValid(strName)) return defaultValue;
	
	KvRewind(g_hConfig);
	KvJumpToKey(g_hConfig, strName);
	
	return KvGetNum(g_hConfig, keyValue, defaultValue);
}

stock Float:GetProfileFloat(const String:strName[], const String:keyValue[], Float:defaultValue=0.0)
{
	if (!IsProfileValid(strName)) return defaultValue;
	
	KvRewind(g_hConfig);
	KvJumpToKey(g_hConfig, strName);
	
	return KvGetFloat(g_hConfig, keyValue, defaultValue);
}

stock bool:GetProfileVector(const String:strName[], const String:keyValue[], Float:buffer[3], const Float:defaultValue[3]=NULL_VECTOR)
{
	for (new i = 0; i < 3; i++) buffer[i] = defaultValue[i];
	
	if (!IsProfileValid(strName)) return false;
	
	KvRewind(g_hConfig);
	KvJumpToKey(g_hConfig, strName);
	
	KvGetVector(g_hConfig, keyValue, buffer, defaultValue);
	return true;
}

stock bool:GetProfileColor(const String:strName[], 
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
	
	if (!IsProfileValid(strName)) return false;
	
	KvRewind(g_hConfig);
	KvJumpToKey(g_hConfig, strName);
	
	KvGetColor(g_hConfig, keyValue, r, g, b, a);
	return true;
}

stock bool:GetProfileString(const String:strName[], const String:keyValue[], String:buffer[], bufferlen, const String:defaultValue[]="")
{
	strcopy(buffer, bufferlen, defaultValue);
	
	if (!IsProfileValid(strName)) return false;
	
	KvRewind(g_hConfig);
	KvJumpToKey(g_hConfig, strName);
	
	KvGetString(g_hConfig, keyValue, buffer, bufferlen, defaultValue);
	return true;
}

// Code originally from FF2. Credits to the original authors Rainbolt Dash and FlaminSarge.
stock bool:GetRandomStringFromProfile(const String:strName[], const String:strKeyValue[], String:buffer[], bufferlen, index=-1)
{
	strcopy(buffer, bufferlen, "");
	
	if (!IsProfileValid(strName)) return false;
	
	KvRewind(g_hConfig);
	KvJumpToKey(g_hConfig, strName);
	
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