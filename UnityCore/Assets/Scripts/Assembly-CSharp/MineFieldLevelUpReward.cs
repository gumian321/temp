using UnityEngine;

[CreateAssetMenu(fileName = "New Mines Field Level Up Reward", menuName = "ScriptableObjects/Rewards/Level Up Rewards/New Mines Field Level Up Reward")]
public class MineFieldLevelUpReward : LevelUpReward
{
	[Range(0f, 1f)]
	public float maxMinesCountPercent;

	[Range(-1f, 0f)]
	public float minesRechargeRatePercent;
}
