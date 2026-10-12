using UnityEngine;

[CreateAssetMenu(fileName = "New Fuel Tank Level Up Reward", menuName = "ScriptableObjects/Rewards/Level Up Rewards/New Fuel Tank Level Up Reward")]
public class FuelTankLevelUpReward : LevelUpReward
{
	[Range(0f, 1f)]
	public float TankCapacityPercent;
}
