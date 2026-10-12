using System.Collections.Generic;
using UnityEngine;

public class UpgradeTreeDataStore : Singleton<UpgradeTreeDataStore>
{
	[SerializeField]
	private List<RarityTreeValue> rarityTreeValuesList;

	[SerializeField]
	private float scrapBaseValue = 10f;

	[SerializeField]
	private float subRate = 0.5f;

	private float GetRarityValue(RarityTypes rarity)
	{
		foreach (RarityTreeValue rarityTreeValues in rarityTreeValuesList)
		{
			if (rarityTreeValues.rarity == rarity)
			{
				return rarityTreeValues.rarityValue;
			}
		}
		return 1f;
	}

	public int GetRewardPrice(RarityTypes rarity, float baseValue, int subIndex)
	{
		float num = scrapBaseValue * baseValue;
		if (subIndex == 0)
		{
			return RoundTo5(num * GetRarityValue(rarity));
		}
		return RoundTo5(num * GetRarityValue(rarity) + (float)subIndex * subRate * num);
	}

	public int RoundTo5(float num)
	{
		return (int)(Mathf.Sign(num) * Mathf.Ceil(Mathf.Abs(num) / 5f) * 5f);
	}
}
