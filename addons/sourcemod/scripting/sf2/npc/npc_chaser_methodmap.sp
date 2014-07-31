#if defined _sf2_npc_chaser_methodmap_included
 #endinput
#endif
#define _sf2_npc_chaser_methodmap_included


const SF2NPC_Chaser SF2_INVALID_NPC_CHASER = SF2NPC_Chaser:-1;


methodmap SF2NPC_Chaser < SF2NPC_BaseNPC
{
	property float WakeRadius
	{
		public get() { return NPCChaserGetWakeRadius(this.Index); }
	}
	
	property float StepSize
	{
		public get() { return NPCChaserGetStepSize(this.Index); }
	}
	
	property bool StunEnabled
	{
		public get() { return NPCChaserIsStunEnabled(this.Index); }
	}
	
	property bool StunByFlashlightEnabled
	{
		public get() { return NPCChaserIsStunByFlashlightEnabled(this.Index); }
	}
	
	property float StunFlashlightDamage
	{
		public get() { return NPCChaserGetStunFlashlightDamage(this.Index); }
	}
	
	property float StunDuration
	{
		public get() { return NPCChaserGetStunDuration(this.Index); }
	}
	
	property float StunHealth
	{
		public get() { return NPCChaserGetStunHealth(this.Index); }
		public set(float amount) { NPCChaserSetStunHealth(this.Index, amount); }
	}
	
	property float StunInitialHealth
	{
		public get() { return NPCChaserGetStunInitialHealth(this.Index); }
	}
	
	property int State
	{
		public get() { return NPCChaserGetState(this.Index); }
		public set(int state) { NPCChaserSetState(this.Index, state); }
	}
	
	property int MovementActivity
	{
		public get() { return NPCChaserGetMovementActivity(this.Index); }
		public set(int movementActivity) { NPCChaserSetMovementActivity(this.Index, movementActivity); }
	}
	
	public SF2NPC_Chaser(int index)
	{
		return SF2NPC_Chaser:SF2NPC_BaseNPC(index);
	}
	
	public float GetWalkSpeed(int difficulty)
	{
		return NPCChaserGetWalkSpeed(this.Index, difficulty);
	}
	
	public void SetWalkSpeed(int difficulty, float amount)
	{
		NPCChaserSetWalkSpeed(this.Index, difficulty, amount);
	}
	
	public float GetAirSpeed(int difficulty)
	{
		return NPCChaserGetAirSpeed(this.Index, difficulty);
	}
	
	public void SetAirSpeed(int difficulty, float amount)
	{
		NPCChaserSetAirSpeed(this.Index, difficulty, amount);
	}
	
	public float GetMaxWalkSpeed(int difficulty)
	{
		return NPCChaserGetMaxWalkSpeed(this.Index, difficulty);
	}
	
	public void SetMaxWalkSpeed(int difficulty, float amount)
	{
		NPCChaserSetMaxWalkSpeed(this.Index, difficulty, amount);
	}
	
	public float GetMaxAirSpeed(int difficulty)
	{
		return NPCChaserGetMaxAirSpeed(this.Index, difficulty);
	}
	
	public void SetMaxAirSpeed(int difficulty, float amount)
	{
		NPCChaserSetMaxAirSpeed(this.Index, difficulty, amount);
	}
	
	public void AddStunHealth(float amount)
	{
		NPCChaserAddStunHealth(this.Index, amount);
	}
}