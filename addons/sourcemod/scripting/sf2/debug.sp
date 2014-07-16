#if defined _sf2_debug_included
 #endinput
#endif
#define _sf2_debug_included

#if !defined DEBUG
 #endinput
#endif

new g_iPlayerDebugFlags[MAXPLAYERS + 1];


stock DebugMessage(const String:sMessage[], ...)
{
	decl String:sDebugMessage[1024], String:sTemp[1024];
	VFormat(sTemp, sizeof(sTemp), sMessage, 2);
	Format(sDebugMessage, sizeof(sDebugMessage), "SF2: %s", sTemp);
	//PrintToServer(sDebugMessage);
	LogMessage(sDebugMessage);
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
		if (!IsClientInGame(i) || IsFakeClient(i)) continue;
		
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
		PrintToChat(client, "Disabled debugging player stress.");
	}
	
	return Plugin_Handled;
}

public Action:Command_DebugBossProxies(client, args)
{
	new bool:bInMode = bool:(g_iPlayerDebugFlags[client] & DEBUG_BOSS_PROXIES);
	if (!bInMode)
	{
		g_iPlayerDebugFlags[client] |= DEBUG_BOSS_PROXIES;
		PrintToChat(client, "Enabled debugging boss proxies.");
	}
	else
	{
		g_iPlayerDebugFlags[client] &= ~DEBUG_BOSS_PROXIES;
		PrintToChat(client, "Disabled debugging boss proxies.");
	}
	
	return Plugin_Handled;
}