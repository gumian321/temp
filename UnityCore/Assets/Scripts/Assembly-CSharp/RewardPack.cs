using System.Collections.Generic;
using UnityEngine;

[CreateAssetMenu(fileName = "New RewardPack", menuName = "ScriptableObjects/Rewards/New RewardPack")]
public class RewardPack : ScriptableObject
{
	public Sprite packSprite;

	public int packGameFreq;

	public int packLevelUpFreq;

	[Space]
	public List<Reward> packRewardsList;

	public RarityTypes GetRandomRarityType()
	{
		List<RarityTypes> rewardsRarityTypesList = Singleton<RewardDataStore>.Instance.GetRewardsRarityTypesList(packRewardsList, onlyUnlocked: true);
		int itemByProbabilityRarity = ProbabilitySystem.GetItemByProbabilityRarity(Singleton<RewardDataStore>.Instance.GetPackRewardsCumulativeProbabilityList(rewardsRarityTypesList));
		return rewardsRarityTypesList[itemByProbabilityRarity];
	}

	public RarityTypes CheckRarityTypeAvilablity(RarityTypes rarityType)
	{
		List<RarityTypes> rewardsRarityTypesList = Singleton<RewardDataStore>.Instance.GetRewardsRarityTypesList(packRewardsList, onlyUnlocked: true);
		if (rewardsRarityTypesList.Contains(rarityType))
		{
			return rarityType;
		}
		return Singleton<RewardDataStore>.Instance.DownGradeRarityType(rewardsRarityTypesList, rarityType);
	}

	public bool CanSpawnRewardPack()
	{
		foreach (Reward packRewards in packRewardsList)
		{
			if (packRewards.IsRewardUnlocked())
			{
				return true;
			}
		}
		return false;
	}

	public bool CanSelectRewardPack()
	{
		foreach (Reward packRewards in packRewardsList)
		{
			if (packRewards.CanSelectReward())
			{
				return true;
			}
		}
		return false;
	}

	public bool ContainRewardRarity(RarityTypes rarityType)
	{
		foreach (Reward packRewards in packRewardsList)
		{
			if (packRewards.CanSelectReward() && packRewards.IsRewardUnlocked() && packRewards.rarity == rarityType)
			{
				return true;
			}
		}
		return false;
	}
}
