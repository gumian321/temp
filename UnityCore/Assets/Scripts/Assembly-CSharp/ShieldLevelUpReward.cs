using UnityEngine;

[CreateAssetMenu(fileName = "New Shield Level Up Reward", menuName = "ScriptableObjects/Rewards/Level Up Rewards/New Shield Level Up Reward")]
public class ShieldLevelUpReward : LevelUpReward
{
	[Range(0f, 1f)]
	public float ShieldHealthPercent;

	[Range(0f, 1f)]
	public float ShieldRechargeRatePercent;

	[Range(-1f, 0f)]
	public float ShieldRechargeDelayPercent;

	[Range(0f, 1f)]
	public float ShieldRangePercent;
}
