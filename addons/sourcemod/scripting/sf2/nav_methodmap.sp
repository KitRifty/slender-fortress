#if defined _sf2_nav_methodmap_included
 #endinput
#endif
#define _sf2_nav_methodmap_included




methodmap NavPath < Handle
{
	property Handle Handle
	{
		public get() { return Handle:this; }
	}

	public int AddNodeToHead(float nodePos[3])
	{
		return NavPathAddNodeToHead(this, nodePos);
	}
	
	public int AddNodeToTail(float nodePos[3])
	{
		return NavPathAddNodeToTail(this, nodePos);
	}
	
	public void GetNodePosition(int nodeIndex, float buffer[3])
	{
		NavPathGetNodePosition(this, nodeIndex, buffer);
	}
	
	public int GetNodeAreaIndex(int nodeIndex)
	{
		return NavPathGetNodeAreaIndex(this, nodeIndex);
	}
	
	public int GetNodeLadderIndex(int nodeIndex)
	{
		return NavPathGetNodeLadderIndex(this, nodeIndex);
	}
	
	public bool ConstructPathFromPoints(float startPos[3], float endPos[3], float nearestAreaRadius, Function costFunction, any costData, bool populateIfIncomplete = true, int &closestAreaIndex = -1)
	{
		return NavPathConstructPathFromPoints(this, startPos, endPos, nearestAreaRadius, costFunction, costData, populateIfIncomplete, closestAreaIndex);
	}
}