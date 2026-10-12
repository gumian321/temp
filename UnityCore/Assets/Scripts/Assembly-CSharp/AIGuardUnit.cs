using System.Collections.Generic;
using UnityEngine;

[CreateAssetMenu(fileName = "New AIGuardUnit", menuName = "ScriptableObjects/AI/New AIGuardUnit")]
public class AIGuardUnit : ScriptableObject
{
	public int unitProbabilty = 1;

	public PrefabTypes prefabType;

	public AIThreatLevel aIThreatLevel;

	public List<Core> coresList;
}
