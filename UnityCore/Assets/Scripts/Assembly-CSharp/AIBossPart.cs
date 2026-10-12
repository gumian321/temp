using System.Collections.Generic;
using UnityEngine;

[CreateAssetMenu(fileName = "New AIBossPart", menuName = "ScriptableObjects/AI/New AIBossPart")]
public class AIBossPart : ScriptableObject
{
	public AIThreatLevel bossThreatLevel;

	public AIBossPartTypes aIBossPartType;

	public List<Core> coresList;
}
