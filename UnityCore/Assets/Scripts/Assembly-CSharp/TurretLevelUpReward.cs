using UnityEngine;

[CreateAssetMenu(fileName = "New Turret Level Up Reward", menuName = "ScriptableObjects/Rewards/Level Up Rewards/New Turret Level Up Reward")]
public class TurretLevelUpReward : LevelUpReward
{
	[Range(0f, 1f)]
	public float DamagePercent;

	[Range(0f, 1f)]
	public float RateOfFirePercent;

	[Range(0f, 1f)]
	public float RangePercent;
}
