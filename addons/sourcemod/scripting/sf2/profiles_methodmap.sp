#if defined _sf2_profiles_methodmap_included
 #endinput
#endif
#define _sf2_profiles_methodmap_included

methodmap SF2BossProfile
{
	property int Index
	{
		public get() { return int(this); }
	}
	
	property int UniqueProfileIndex
	{
		public get() { return GetBossProfileUniqueProfileIndex(this.Index); }
	}
	
	property int Skin
	{
		public get() { return GetBossProfileSkin(this.Index); }
	}
	
	property int BodyGroups
	{
		public get() { return GetBossProfileBodyGroups(this.Index); }
	}
	
	property float ModelScale
	{
		public get() { return GetBossProfileModelScale(this.Index); }
	}
	
	property int Type
	{
		public get() { return GetBossProfileType(this.Index); }
	}
	
	property int Flags
	{
		public get() { return GetBossProfileFlags(this.Index); }
	}
	
	property float SearchRadius
	{
		public get() { return GetBossProfileSearchRadius(this.Index); }
	}
	
	property float FOV
	{
		public get() { return GetBossProfileFOV(this.Index); }
	}
	
	property float TurnRate
	{
		public get() { return GetBossProfileTurnRate(this.Index); }
	}
	
	property float AngerStart
	{
		public get() { return GetBossProfileAngerStart(this.Index); }
	}
	
	property float AngerAddOnPageGrab
	{
		public get() { return GetBossProfileAngerAddOnPageGrab(this.Index); }
	}
	
	property float AngerAddOnPageGrabTimeDiff
	{
		public get() { return GetBossProfileAngerPageGrabTimeDiff(this.Index); }
	}
	
	property float InstantKillRadius
	{
		public get() { return GetBossProfileInstantKillRadius(this.Index); }
	}
	
	property float ScareRadius
	{
		public get() { return GetBossProfileScareRadius(this.Index); }
	}
	
	property float ScareCooldown
	{
		public get() { return GetBossProfileScareCooldown(this.Index); }
	}
	
	property int TeleportType
	{
		public get() { return GetBossProfileTeleportType(this.Index); }
	}
	
	public float GetSpeed(int difficulty)
	{
		return GetBossProfileSpeed(this.Index, difficulty);
	}
	
	public float GetMaxSpeed(int difficulty)
	{
		return GetBossProfileMaxSpeed(this.Index, difficulty);
	}
	
	public void GetEyePositionOffset(float buffer[3])
	{
		GetBossProfileEyePositionOffset(this.Index, buffer);
	}
	
	public void GetEyeAngleOffset(float buffer[3])
	{
		GetBossProfileEyeAngleOffset(this.Index, buffer);
	}
}