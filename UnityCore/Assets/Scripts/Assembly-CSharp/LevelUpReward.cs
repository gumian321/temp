using System.Collections.Generic;
using UnityEngine;

[CreateAssetMenu(fileName = "New Level Up Reward", menuName = "ScriptableObjects/Rewards/Level Up Rewards/New Level Up Reward")]
public class LevelUpReward : Reward
{
	[Space]
	[Space]
	[Header("LevelUp Reward Data")]
	[Space]
	public List<Core> coresList;

	[Range(0f, 1f)]
	public float CoreHealthPercent;

	public override int GetRewardLevel()
	{
		return Singleton<PlayerDataStore>.Instance.GetLevelUpRewardsCount(this) + 1;
	}

	public int CanRewardStarCount()
	{
		return Singleton<PlayerDataStore>.Instance.GetLevelUpRewardsCount(this);
	}

	public override bool CanSelectReward()
	{
		if (Singleton<PlayerDataStore>.Instance.CheckLevelUpRewardsCount(this))
		{
			return base.CanSelectReward();
		}
		return false;
	}

	public override void SelectReward()
	{
		Singleton<PlayerDataStore>.Instance.AddLevelUpReward(this);
	}

	public override string GetRewardTitle()
	{
		return string.Format(Singleton<LocalizationSystem>.Instance.GetIDString("PopUpText_LevelUp"), coresList[0].GetCoreTitle());
	}

	public override Sprite GetRewardSprite()
	{
		return coresList[0].GetCoreSprite();
	}

	public override void AddRewardPopUpText()
	{
		string iDString = Singleton<LocalizationSystem>.Instance.GetIDString("PopUpText_LevelUp");
		iDString = string.Format(iDString, coresList[0].GetCoreTitle());
		SceneSingleton<PopUpTextManager>.Instance.AddPopUpText(iDString);
	}
}
