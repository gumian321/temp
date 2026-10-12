using System;
using UnityEngine;

[Serializable]
public class RewardStats
{
	[Range(0f, 6f)]
	public int HullDamage;

	[Range(0f, 6f)]
	public int ShieldDamage;

	[Range(0f, 6f)]
	public int Range;

	[Range(0f, 6f)]
	public int RateOfFire;

	[Range(0f, 6f)]
	public int PartsCount;

	[Range(0f, 6f)]
	public int DronesCount;

	public bool LevelUp;

	public Reward LinkedReward;

	public int GetStatTypes(StatTypes statType)
	{
		switch (statType)
		{
		case StatTypes.HullDamage:
			return HullDamage;
		case StatTypes.ShieldDamage:
			return ShieldDamage;
		case StatTypes.Range:
			return Range;
		case StatTypes.RateOfFire:
			return RateOfFire;
		case StatTypes.PartsCount:
			return PartsCount;
		case StatTypes.DronesCount:
			return DronesCount;
		case StatTypes.LevelUp:
			if (!LevelUp)
			{
				return 0;
			}
			return 1;
		default:
			return 0;
		}
	}

	public bool IsEmpty()
	{
		if (HullDamage == 0 && ShieldDamage == 0 && Range == 0 && RateOfFire == 0 && PartsCount == 0)
		{
			return DronesCount == 0;
		}
		return false;
	}
}
