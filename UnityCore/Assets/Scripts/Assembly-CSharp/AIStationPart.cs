using System.Collections.Generic;
using UnityEngine;

[CreateAssetMenu(fileName = "New AIStationPart", menuName = "ScriptableObjects/AI/New AIStationPart")]
public class AIStationPart : ScriptableObject
{
	public int partProbabilty = 1;

	[Space]
	public AIThreatLevel aIThreatLevel;

	public PrefabTypes prefabType;

	[Space]
	[Header("Cores")]
	public List<Core> coresList;

	[Space]
	[Header("Rewards Packs")]
	public RarityTypes packRarityType;

	public List<RewardPack> rewardPacksList;
}
