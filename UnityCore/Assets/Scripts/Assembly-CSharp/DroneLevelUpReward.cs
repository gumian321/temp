using System.Collections.Generic;
using UnityEngine;

[CreateAssetMenu(fileName = "New Drones Level Up Reward", menuName = "ScriptableObjects/Rewards/Level Up Rewards/New Drones Level Up Reward")]
public class DroneLevelUpReward : LevelUpReward
{
	[SerializeField]
	public List<Drone> dronesList;

	public int addDronesCount;

	[Range(0f, 1f)]
	public float enginePowerPercent;

	[Range(0f, 1f)]
	public float efficiencyPercent;

	[Range(0f, 1f)]
	public float rangePercent;

	public override string GetRewardTitle()
	{
		return string.Format(Singleton<LocalizationSystem>.Instance.GetIDString("PopUpText_LevelUp"), dronesList[0].GetDroneTitle());
	}

	public override Sprite GetRewardSprite()
	{
		return ((DroneCore)coresList[0]).coreDrone.droneSprite;
	}
}
