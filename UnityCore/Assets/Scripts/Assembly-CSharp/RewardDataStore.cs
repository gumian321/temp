using System.Collections.Generic;
using System.Linq;
using UnityEngine;

public class RewardDataStore : Singleton<RewardDataStore>
{
	public static int MinToggableRewards = 5;

	[SerializeField]
	private float ScrapsPerRewardPack = 1.25f;

	[SerializeField]
	[Range(0f, 1f)]
	private float ScrapsRecyclePercent = 0.5f;

	[SerializeField]
	[Range(0f, 1f)]
	private float packRewardChance = 0.05f;

	[SerializeField]
	private Reward packReward;

	[Space]
	public List<Reward> rewardsUnlockedList;

	[Space]
	[SerializeField]
	private List<RewardRarity> rewardRarityList;

	[Space]
	[Header("Reward Buffs and Debuffs")]
	[SerializeField]
	private Color buffRewardColor;

	[SerializeField]
	private Color deBuffRewardColor;

	[Space]
	[Header("Rewards Packs")]
	[SerializeField]
	private RewardPack cursedRewardPack;

	[SerializeField]
	private List<RewardPack> allRewardPacksList;

	private List<RewardPack> levelUpRewardPacksList;

	private int levelUpRewardPacksIndex;

	private List<RewardPack> gameRewardPacksList;

	private int gameRewardPacksIndex;

	public static int PacksInventoryCount = 6;

	[Space]
	[Header("Rarity Data")]
	private Dictionary<RarityTypes, Color> RarityColorDict;

	private Dictionary<RarityTypes, float> RarityChanceDict;

	public float GetScrapsPerRewardPack()
	{
		return ScrapsPerRewardPack;
	}

	public float GetScrapsRecyclePercent()
	{
		return ScrapsRecyclePercent;
	}

	public bool CanAddPackReward()
	{
		if (Random.value < packRewardChance)
		{
			return SceneSingleton<PlayerCoresManager>.Instance.CanAddCore();
		}
		return false;
	}

	public Reward GetPackReward()
	{
		if (!packReward.IsRewardUnlocked())
		{
			packReward.UnlockReward();
		}
		if (!packReward.IsRewardToggled())
		{
			packReward.ToggleReward();
		}
		return packReward;
	}

	public void BuildRewardPacksList()
	{
		levelUpRewardPacksList = new List<RewardPack>();
		gameRewardPacksList = new List<RewardPack>();
		List<List<RewardPack>> list = new List<List<RewardPack>>();
		List<List<RewardPack>> list2 = new List<List<RewardPack>>();
		int num = 0;
		int num2 = 0;
		foreach (RewardPack allRewardPacks in allRewardPacksList)
		{
			if (allRewardPacks.CanSpawnRewardPack())
			{
				if (allRewardPacks.packLevelUpFreq > num)
				{
					num = allRewardPacks.packLevelUpFreq;
				}
				if (allRewardPacks.packGameFreq > num2)
				{
					num2 = allRewardPacks.packGameFreq;
				}
			}
		}
		for (int i = 0; i < num; i++)
		{
			list.Add(new List<RewardPack>());
		}
		for (int j = 0; j < num2; j++)
		{
			list2.Add(new List<RewardPack>());
		}
		foreach (RewardPack allRewardPacks2 in allRewardPacksList)
		{
			if (allRewardPacks2.CanSpawnRewardPack())
			{
				for (int k = 0; k < allRewardPacks2.packLevelUpFreq; k++)
				{
					list[k].Add(allRewardPacks2);
				}
				for (int l = 0; l < allRewardPacks2.packGameFreq; l++)
				{
					list2[l].Add(allRewardPacks2);
				}
			}
		}
		list = Randomizer.Randomize(list);
		list2 = Randomizer.Randomize(list2);
		foreach (List<RewardPack> item in list)
		{
			foreach (RewardPack item2 in Randomizer.Randomize(item))
			{
				levelUpRewardPacksList.Add(item2);
			}
		}
		foreach (List<RewardPack> item3 in list2)
		{
			foreach (RewardPack item4 in Randomizer.Randomize(item3))
			{
				gameRewardPacksList.Add(item4);
			}
		}
		if (levelUpRewardPacksList.Count == 0)
		{
			Debug.LogError("No Level Up Reward Packs is allowed to be loaded.");
		}
		if (gameRewardPacksList.Count == 0)
		{
			Debug.LogError("No Game Reward Packs is allowed to be loaded.");
		}
		levelUpRewardPacksIndex = -1;
		gameRewardPacksIndex = -1;
	}

	public Color GetRewardPercentBuffColor(float percent)
	{
		if (percent > 0f)
		{
			return buffRewardColor;
		}
		return deBuffRewardColor;
	}

	public RewardPack GetLevelUpRewardPack()
	{
		if (!CanSelectedRewardPackFromList(levelUpRewardPacksList))
		{
			return cursedRewardPack;
		}
		do
		{
			levelUpRewardPacksIndex++;
			if (levelUpRewardPacksIndex >= levelUpRewardPacksList.Count)
			{
				levelUpRewardPacksIndex = 0;
			}
		}
		while (!levelUpRewardPacksList[levelUpRewardPacksIndex].CanSelectRewardPack());
		return levelUpRewardPacksList[levelUpRewardPacksIndex];
	}

	private RewardPack GetGameRewardPack()
	{
		if (!CanSelectedRewardPackFromList(gameRewardPacksList))
		{
			return cursedRewardPack;
		}
		do
		{
			gameRewardPacksIndex++;
			if (gameRewardPacksIndex >= gameRewardPacksList.Count)
			{
				gameRewardPacksIndex = 0;
			}
		}
		while (!gameRewardPacksList[gameRewardPacksIndex].CanSelectRewardPack());
		return gameRewardPacksList[gameRewardPacksIndex];
	}

	public RewardPack GetRandomRewardPack(RarityTypes rarityTypes = RarityTypes.None)
	{
		if (rarityTypes == RarityTypes.None)
		{
			return GetGameRewardPack();
		}
		List<RewardPack> selectedRewardPacksList = GetSelectedRewardPacksList(gameRewardPacksList);
		if (selectedRewardPacksList.Count == 0)
		{
			return cursedRewardPack;
		}
		List<RewardPack> rarityFilterdRewardPacksList = GetRarityFilterdRewardPacksList(selectedRewardPacksList, rarityTypes);
		if (rarityFilterdRewardPacksList.Count > 0)
		{
			return rarityFilterdRewardPacksList[Random.Range(0, rarityFilterdRewardPacksList.Count)];
		}
		return GetGameRewardPack();
	}

	public RewardPack GetRewardPack(List<RewardPack> rewardPacksList, RarityTypes rarityTypes = RarityTypes.None)
	{
		List<RewardPack> selectedRewardPacksList = GetSelectedRewardPacksList(rewardPacksList);
		if (selectedRewardPacksList.Count == 0)
		{
			return cursedRewardPack;
		}
		if (rarityTypes == RarityTypes.None)
		{
			return selectedRewardPacksList[Random.Range(0, selectedRewardPacksList.Count)];
		}
		List<RewardPack> rarityFilterdRewardPacksList = GetRarityFilterdRewardPacksList(selectedRewardPacksList, rarityTypes);
		if (rarityFilterdRewardPacksList.Count > 0)
		{
			return rarityFilterdRewardPacksList[Random.Range(0, rarityFilterdRewardPacksList.Count)];
		}
		return selectedRewardPacksList[Random.Range(0, selectedRewardPacksList.Count)];
	}

	private List<RewardPack> GetSelectedRewardPacksList(List<RewardPack> rewardPacksList)
	{
		List<RewardPack> list = new List<RewardPack>();
		foreach (RewardPack rewardPacks in rewardPacksList)
		{
			if (rewardPacks.CanSelectRewardPack())
			{
				list.Add(rewardPacks);
			}
		}
		return list;
	}

	private bool CanSelectedRewardPackFromList(List<RewardPack> rewardPacksList)
	{
		foreach (RewardPack rewardPacks in rewardPacksList)
		{
			if (rewardPacks.CanSelectRewardPack())
			{
				return true;
			}
		}
		return false;
	}

	private List<RewardPack> GetRarityFilterdRewardPacksList(List<RewardPack> rewardPacksList, RarityTypes rarityTypes)
	{
		List<RewardPack> list = new List<RewardPack>();
		foreach (RewardPack rewardPacks in rewardPacksList)
		{
			if (rewardPacks.ContainRewardRarity(rarityTypes))
			{
				list.Add(rewardPacks);
			}
		}
		return list;
	}

	private List<RewardPack> BuildPacksProbabiltyList(List<RewardPack> selectedRewardPacksList)
	{
		List<RewardPack> list = new List<RewardPack>();
		foreach (RewardPack selectedRewardPacks in selectedRewardPacksList)
		{
			for (int i = 0; i < selectedRewardPacks.packGameFreq; i++)
			{
				list.Add(selectedRewardPacks);
			}
		}
		return list;
	}

	public List<float> GetPackRewardsCumulativeProbabilityList(List<RarityTypes> rewardsRarityList)
	{
		List<float> list = new List<float>();
		foreach (RarityTypes rewardsRarity in rewardsRarityList)
		{
			list.Add(GetRarityChance(rewardsRarity));
		}
		return ProbabilitySystem.MakeCumulativeByProbabilityRarity(list);
	}

	public Color GetRarityColor(RarityTypes rarity)
	{
		if (RarityColorDict == null)
		{
			BuildRarityDict();
		}
		return RarityColorDict[rarity];
	}

	public float GetRarityChance(RarityTypes rarity)
	{
		if (RarityChanceDict == null)
		{
			BuildRarityDict();
		}
		return RarityChanceDict[rarity];
	}

	public RarityTypes GetRandomRarityType()
	{
		if (RarityChanceDict == null)
		{
			BuildRarityDict();
		}
		List<RarityTypes> list = RarityChanceDict.Keys.ToList();
		int itemByProbabilityRarity = ProbabilitySystem.GetItemByProbabilityRarity(Singleton<RewardDataStore>.Instance.GetPackRewardsCumulativeProbabilityList(list));
		return list[itemByProbabilityRarity];
	}

	private void BuildRarityDict()
	{
		RarityColorDict = new Dictionary<RarityTypes, Color>();
		RarityChanceDict = new Dictionary<RarityTypes, float>();
		foreach (RewardRarity rewardRarity in rewardRarityList)
		{
			RarityColorDict.Add(rewardRarity.rarity, rewardRarity.rarityColor);
			RarityChanceDict.Add(rewardRarity.rarity, rewardRarity.rarityChance);
		}
	}

	public List<RarityTypes> GetRewardsRarityTypesList(List<Reward> list, bool onlyUnlocked = false)
	{
		if (onlyUnlocked)
		{
			list = FillterUnlockedRewards(list);
		}
		List<RarityTypes> list2 = new List<RarityTypes>();
		foreach (Reward item in list)
		{
			foreach (RewardRarity rewardRarity in rewardRarityList)
			{
				if (rewardRarity.rarity == item.rarity && !list2.Contains(item.rarity))
				{
					list2.Add(rewardRarity.rarity);
				}
			}
		}
		return list2;
	}

	private List<Reward> FillterUnlockedRewards(List<Reward> list)
	{
		List<Reward> list2 = new List<Reward>();
		foreach (Reward item in list)
		{
			if (item.IsRewardUnlocked())
			{
				list2.Add(item);
			}
		}
		return list2;
	}

	public RarityTypes DownGradeRarityType(List<RarityTypes> rarityTypesList, RarityTypes rarityType)
	{
		if (rarityType == RarityTypes.Common && rarityTypesList.Contains(RarityTypes.Common))
		{
			return RarityTypes.Common;
		}
		if (rarityType == RarityTypes.Rare && rarityTypesList.Contains(RarityTypes.Common))
		{
			return RarityTypes.Common;
		}
		if (rarityType == RarityTypes.Epic)
		{
			if (rarityTypesList.Contains(RarityTypes.Rare))
			{
				return RarityTypes.Rare;
			}
			if (rarityTypesList.Contains(RarityTypes.Common))
			{
				return RarityTypes.Common;
			}
		}
		if (rarityType == RarityTypes.Legendery)
		{
			if (rarityTypesList.Contains(RarityTypes.Epic))
			{
				return RarityTypes.Epic;
			}
			if (rarityTypesList.Contains(RarityTypes.Rare))
			{
				return RarityTypes.Rare;
			}
			if (rarityTypesList.Contains(RarityTypes.Common))
			{
				return RarityTypes.Common;
			}
		}
		return rarityTypesList[Random.Range(0, rarityTypesList.Count)];
	}

	public void LockRewards()
	{
		List<Reward> list = new List<Reward>();
		list.AddRange(Resources.LoadAll<Reward>("Scriptable Objects"));
		foreach (Reward item in list)
		{
			item.LockReward();
		}
		foreach (Reward rewardsUnlocked in rewardsUnlockedList)
		{
			rewardsUnlocked.UnlockReward();
		}
	}

	private void UnLockRewards()
	{
		List<Reward> list = new List<Reward>();
		list.AddRange(Resources.LoadAll<Reward>("Scriptable Objects"));
		foreach (Reward item in list)
		{
			item.UnlockReward();
		}
		SaveSystem.SaveGame();
	}

	public List<Reward> GetRanomTestingRewardsList()
	{
		List<Reward> list = new List<Reward>();
		List<Reward> items = new List<Reward>(Singleton<TestingManager>.Instance.GetTestingRewardsList());
		items = Randomizer.Randomize(items);
		if (items.Count >= 3)
		{
			list.Add(items[0]);
			list.Add(items[1]);
			list.Add(items[2]);
		}
		else
		{
			list.Add(items[Random.Range(0, items.Count)]);
			list.Add(items[Random.Range(0, items.Count)]);
			list.Add(items[Random.Range(0, items.Count)]);
		}
		return list;
	}
}
