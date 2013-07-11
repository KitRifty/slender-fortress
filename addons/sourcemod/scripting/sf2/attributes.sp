#if defined _sf2_attributes_included
 #endinput
#endif
#define _sf2_attributes_included


stock bool:SlenderHasAttribute(iBossIndex, const String:sAttribute[])
{
	if (g_hConfig == INVALID_HANDLE) return false;
	if (!g_strSlenderProfile[iBossIndex][0] || !sAttribute[0]) return false;
	
	KvRewind(g_hConfig);
	if (!KvJumpToKey(g_hConfig, g_strSlenderProfile[iBossIndex])) return false;
	if (!KvJumpToKey(g_hConfig, "attributes")) return false;
	
	return KvJumpToKey(g_hConfig, sAttribute);
}

stock Float:SlenderGetAttributeValue(iBossIndex, const String:sAttribute[], Float:flDefaultValue=0.0)
{
	if (!SlenderHasAttribute(iBossIndex, sAttribute)) return flDefaultValue;
	return KvGetFloat(g_hConfig, "value", flDefaultValue);
}