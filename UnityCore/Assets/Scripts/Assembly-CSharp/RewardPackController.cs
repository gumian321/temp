using System.Collections.Generic;
using UnityEngine;

public class RewardPackController : MonoBehaviour
{
	protected RewardPack rewardPack;

	protected RarityTypes packRarityType;

	private List<Reward> packRewardsList;

	private List<Reward> lockedPackRewardsList;

	private List<RarityTypes> temp_rewardRarityList;

	private List<Reward> temp_packRewardsList;

	private List<Reward> temp_lockedPackRewardsList;

	private List<float> temp_packCumulativeProbabilityList;

	private List<RarityTypes> rewardRarityList;

	private List<float> packCumulativeProbabilityList;

	public RewardPack GetRewardPack()
	{
		return rewardPack;
	}

	public RarityTypes GetPackRarityType()
	{
		return packRarityType;
	}

	public virtual void SetRewardPack(RewardPack rewardPack, RarityTypes rarityType = RarityTypes.None)
	{
		this.rewardPack = rewardPack;
		SetUpPack();
		if (rarityType == RarityTypes.None)
		{
			packRarityType = GetRandomPackRarity();
		}
		else
		{
			packRarityType = rarityType;
		}
	}

	public virtual void SetRewardPack(RewardPackController rewardPackController)
	{
		rewardPack = rewardPackController.GetRewardPack();
		SetUpPack();
		packRarityType = rewardPackController.GetPackRarityType();
	}

	public List<Reward> GetRandomRewardList(int count = 3)
	{
		temp_packRewardsList = new List<Reward>(packRewardsList);
		temp_lockedPackRewardsList = new List<Reward>(lockedPackRewardsList);
		temp_rewardRarityList = Singleton<RewardDataStore>.Instance.GetRewardsRarityTypesList(temp_packRewardsList);
		temp_packCumulativeProbabilityList = Singleton<RewardDataStore>.Instance.GetPackRewardsCumulativeProbabilityList(temp_rewardRarityList);
		RarityTypes temp_RandomRewardRarity = packRarityType;
		List<Reward> list = new List<Reward>();
		FilterRewards();
		while (list.Count < count)
		{
			if (temp_RandomRewardRarity == RarityTypes.None)
			{
				if (temp_lockedPackRewardsList.Count != 0)
				{
					Reward item = temp_lockedPackRewardsList[Random.Range(0, temp_lockedPackRewardsList.Count)];
					list.Add(item);
					temp_lockedPackRewardsList.Remove(item);
					continue;
				}
				if (list.Count > 0)
				{
					list.Add(list[0]);
				}
				else
				{
					list.Add(null);
				}
			}
			Reward randomReward = GetRandomReward(temp_RandomRewardRarity);
			if (randomReward == null)
			{
				temp_rewardRarityList.Remove(temp_RandomRewardRarity);
				temp_packCumulativeProbabilityList = Singleton<RewardDataStore>.Instance.GetPackRewardsCumulativeProbabilityList(temp_rewardRarityList);
				temp_RandomRewardRarity = GetTemp_RandomRewardRarity();
				continue;
			}
			temp_packRewardsList.Remove(randomReward);
			temp_rewardRarityList = Singleton<RewardDataStore>.Instance.GetRewardsRarityTypesList(temp_packRewardsList);
			temp_packCumulativeProbabilityList = Singleton<RewardDataStore>.Instance.GetPackRewardsCumulativeProbabilityList(temp_rewardRarityList);
			list.Add(randomReward);
			FilterRewards(list);
			temp_RandomRewardRarity = GetTemp_RandomRewardRarity();
		}
		if (Singleton<RewardDataStore>.Instance.CanAddPackReward())
		{
			list[list.Count - 1] = Singleton<RewardDataStore>.Instance.GetPackReward();
		}
		return list;
	}

	private Reward GetRandomReward(RarityTypes rewardRarityType)
	{
		List<Reward> rewardListByRarity = GetRewardListByRarity(rewardRarityType);
		if (rewardListByRarity.Count == 0)
		{
			return null;
		}
		return rewardListByRarity[Random.Range(0, rewardListByRarity.Count)];
	}

	private List<Reward> GetRewardListByRarity(RarityTypes rewardRarityType)
	{
		List<Reward> list = new List<Reward>();
		foreach (Reward temp_packRewards in temp_packRewardsList)
		{
			if (temp_packRewards.rarity == rewardRarityType)
			{
				list.Add(temp_packRewards);
			}
		}
		return list;
	}

	private void FilterRewards(List<Reward> selectedRewards = null)
	{
		List<Reward> list = new List<Reward>();
		foreach (Reward temp_packRewards in temp_packRewardsList)
		{
			if (!temp_packRewards.CanSelectReward())
			{
				continue;
			}
			bool flag = false;
			if (selectedRewards != null)
			{
				foreach (Reward selectedReward in selectedRewards)
				{
					if (temp_packRewards.CanConflictReward(selectedReward))
					{
						flag = true;
						break;
					}
				}
			}
			if (!flag)
			{
				list.Add(temp_packRewards);
			}
		}
		temp_packRewardsList = new List<Reward>(list);
		temp_rewardRarityList = Singleton<RewardDataStore>.Instance.GetRewardsRarityTypesList(temp_packRewardsList);
		temp_packCumulativeProbabilityList = Singleton<RewardDataStore>.Instance.GetPackRewardsCumulativeProbabilityList(temp_rewardRarityList);
	}

	public void SetUpPack()
	{
		packRewardsList = GetUnLockedRewardsList();
		lockedPackRewardsList = GetLockedRewardsList();
		rewardRarityList = Singleton<RewardDataStore>.Instance.GetRewardsRarityTypesList(packRewardsList);
		packCumulativeProbabilityList = Singleton<RewardDataStore>.Instance.GetPackRewardsCumulativeProbabilityList(rewardRarityList);
	}

	private List<Reward> GetLockedRewardsList()
	{
		List<Reward> list = new List<Reward>();
		foreach (Reward packRewards in rewardPack.packRewardsList)
		{
			if (!packRewards.IsRewardUnlocked())
			{
				list.Add(packRewards);
			}
		}
		return list;
	}

	private List<Reward> GetUnLockedRewardsList()
	{
		List<Reward> list = new List<Reward>();
		foreach (Reward packRewards in rewardPack.packRewardsList)
		{
			if (packRewards.IsRewardUnlocked())
			{
				list.Add(packRewards);
			}
		}
		return list;
	}

	public RarityTypes GetRandomPackRarity()
	{
		int randomRewardRarityIndex = GetRandomRewardRarityIndex(packCumulativeProbabilityList);
		return rewardRarityList[randomRewardRarityIndex];
	}

	public RarityTypes GetTemp_RandomRewardRarity()
	{
		if (temp_rewardRarityList.Count == 0)
		{
			return RarityTypes.None;
		}
		int randomRewardRarityIndex = GetRandomRewardRarityIndex(temp_packCumulativeProbabilityList);
		return temp_rewardRarityList[randomRewardRarityIndex];
	}

	public int GetRandomRewardRarityIndex(List<float> packCumulativeProbabilityList)
	{
		return ProbabilitySystem.GetItemByProbabilityRarity(packCumulativeProbabilityList);
	}
}
