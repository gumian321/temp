using UnityEngine;

[CreateAssetMenu(fileName = "New Engineer Drone", menuName = "ScriptableObjects/Drones/New Engineer Drone")]
public class EngineerDrone : Drone
{
	[Header("Engineer Drone Variables")]
	public float droneRepairAmountPerSec;

	public float GetDroneRepairAmount(float percent = 0f)
	{
		return UnityEngineSystem.GetTickAmount(droneRepairAmountPerSec, percent);
	}
}
