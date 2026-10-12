using UnityEngine;

[CreateAssetMenu(fileName = "New Repair Core", menuName = "ScriptableObjects/New Core/Repair Core")]
public class RepairCore : TurretCore
{
	public float repairAmountPerSec;

	public float GetRepairAmount(float percent = 0f)
	{
		return UnityEngineSystem.GetTickAmount(repairAmountPerSec, percent);
	}
}
