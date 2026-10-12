using System;
using UnityEngine;

public class InGameEconomySystem : SceneSingleton<InGameEconomySystem>
{
	private float ScrapsPerCore = 2f;

	private int currentScraps;

	private int currentLevel;

	private int ScrapsToLevel = 10;

	private InGameEconomyUISystem inGameEconomyUISystem;

	private PlayerCoresManager playerCoresManager;

	private RewardSystemManager rewardSystemManager;

	public event Action<int> OnScrapChange;

	public event Action OnLevelUp;

	private void Start()
	{
		playerCoresManager = SceneSingleton<PlayerCoresManager>.Instance;
		rewardSystemManager = SceneSingleton<RewardSystemManager>.Instance;
		inGameEconomyUISystem = UnityEngine.Object.FindObjectOfType<InGameEconomyUISystem>();
		ScrapsPerCore = Singleton<RewardDataStore>.Instance.GetScrapsPerRewardPack();
		UpdateScrapsToLevelUp();
	}

	public int GetCurretLevel()
	{
		return currentLevel;
	}

	public void AddScraps(int scrap)
	{
		currentScraps += scrap;
		if (currentScraps >= ScrapsToLevel)
		{
			currentScraps -= ScrapsToLevel;
			if (currentScraps < 0)
			{
				currentScraps = 0;
			}
			AddLevel();
		}
		if (OnScrapChange != null)
		{
			OnScrapChange(currentScraps);
		}
		inGameEconomyUISystem.UpdateXP(currentScraps);
	}

	public void AddLevel()
	{
		currentLevel++;
		if (OnLevelUp != null)
		{
			OnLevelUp();
		}
		UpdateScrapsToLevelUp();
	}

	public void UpdateScrapsToLevelUp()
	{
		int num = playerCoresManager.GetCoresCount() + rewardSystemManager.GetAvilableRewardsCount();
		ScrapsToLevel = Mathf.RoundToInt(ScrapsPerCore * (float)((num == 0) ? 1 : num));
		inGameEconomyUISystem.SetMaxXP(ScrapsToLevel);
	}

	public int GetCurrentPackCost()
	{
		int coresCount = playerCoresManager.GetCoresCount();
		ScrapsToLevel = Mathf.RoundToInt(ScrapsPerCore * (float)((coresCount == 0) ? 1 : coresCount));
		return ScrapsToLevel;
	}
}
