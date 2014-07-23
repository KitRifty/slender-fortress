#if defined _sf2_npc_methodmap_included
 #endinput
#endif
#define _sf2_npc_methodmap_included

enum SF2NPC_BaseNPC
{
};

methodmap SF2NPC_BaseNPC
{
	property int Index
	{
		public get() { return int(this); }
	}
	
	property int Type
	{
		public get() { return NPCGetType(this.Index); }
	}
	
	property int ProfileIndex
	{
		public get() { return NPCGetProfileIndex(this.Index); }
	}
	
	property int UniqueProfileIndex
	{
		public get() { return NPCGetUniqueProfileIndex(this.Index); }
	}
	
	property int EntIndex
	{
		public get() { return NPCGetEntIndex(this.Index); }
	}
	
	property int Flags
	{
		public get() { return NPCGetFlags(this.Index); }
		public set(int flags) { NPCSetFlags(this.Index); }
	}
	
	property float ModelScale
	{
		public get() { return NPCGetModelScale(this.Index) };
	}
	
	property float TurnRate
	{
		public get() { return NPCGetTurnRate(this.Index) };
	}
	
	property float FOV
	{
		public get() { return NPCGetFOV(this.Index); }
	}
	
	property float Anger
	{
		public get() { return NPCGetAnger(this.Index); }
		public set(float amount) { NPCSetAnger(this.Index, amount); }
	}
	
	property float AngerAddOnPageGrab
	{
		public get() { return NPCGetAngerAddOnPageGrab(this.Index); }
	}
	
	property float AngerAddOnPageGrabTimeDiff
	{
		public get() { return NPCGetAngerAddOnPageGrabTimeDiff(this.Index); }
	}
	
	property float SearchRadius
	{
		public get() { return NPCGetSearchRadius(this.Index); }
	}
	
	property float ScareRadius
	{
		public get() { return NPCGetScareRadius(this.Index); }
	}
	
	property float ScareCooldown
	{
		public get() { return NPCGetScareCooldown(this.Index); }
	}
	
	property float InstantKillRadius
	{
		public get() { return NPCGetInstantKillRadius(this.Index); }
	}
	
	property int TeleportType
	{
		public get() { return NPCGetTeleportType(this.Index); }
	}
	
	public SF2NPC_BaseNPC(int index)
	{
		return SF2NPC_BaseNPC:index;
	}
	
	public bool IsValid()
	{
		return NPCIsValid(this.Index);
	}
	
	public void GetProfile(char[] buffer, int bufferlen) 
	{
		NPCGetProfile(this.Index, buffer, bufferlen);
	}
	
	public void SetProfile(const char[] profileName)
	{
		NPCSetProfile(this.Index, profileName);
	}
	
	public float GetSpeed(int difficulty)
	{
		return NPCGetSpeed(this.Index, difficulty);
	}
	
	public float GetMaxSpeed(int difficulty)
	{
		return NPCGetMaxSpeed(this.Index, difficulty);
	}
	
	public void GetEyePosition(float buffer[3], const float defaultValue[3] = { 0.0, 0.0, 0.0 })
	{
		NPCGetEyePosition(this.Index, buffer, defaultValue);
	}
	
	public void GetEyePositionOffset(float buffer[3])
	{
		NPCGetEyePositionOffset(this.Index, buffer);
	}
	
	public void AddAnger(float amount)
	{
		NPCAddAnger(this.Index, amount);
	}
	
	public void Remove()
	{
		NPCRemove(this.Index);
	}
}