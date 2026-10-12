using UnityEngine;

[CreateAssetMenu(fileName = "New Shield Core", menuName = "ScriptableObjects/New Core/Support Cores/Shield Core")]
public class ShieldCore : TurretCore
{
	public float ShieldRange;

	public float maxShieldHealth;

	public float shieldRechargeRate;

	public float shieldRechargeDelay;

	public ChipsContainer activatableChips;

	public float GetShieldRange(float percent)
	{
		return UnityEngineSystem.CalcPercent(ShieldRange, percent);
	}

	public float GetShieldRange()
	{
		ShieldLevelUpReward shieldLevelUpReward = (ShieldLevelUpReward)Singleton<PlayerDataStore>.Instance.GetLevelUpReward(this);
		if (shieldLevelUpReward == null)
		{
			return ShieldRange;
		}
		float num = Singleton<PlayerDataStore>.Instance.GetLevelUpRewardsCount(this);
		if (num == 0f)
		{
			num = 1f;
		}
		return GetShieldRange(shieldLevelUpReward.ShieldRangePercent * num);
	}

	public float GetShieldRechargeRate(float percent = 0f)
	{
		return UnityEngineSystem.GetTickAmount(shieldRechargeRate, percent);
	}

	public float GetShieldRechargeDelay(float percent = 0f)
	{
		return UnityEngineSystem.CalcPercent(shieldRechargeDelay, percent);
	}

	public override bool CanBeHighlighted(ChipTypes ChipType)
	{
		if (!isChipable)
		{
			return false;
		}
		if (activatableChips.IsChipActivated(ChipType))
		{
			return true;
		}
		return false;
	}
}
