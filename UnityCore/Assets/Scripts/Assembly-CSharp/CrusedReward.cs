using UnityEngine;

[CreateAssetMenu(fileName = "New Cursed Reward", menuName = "ScriptableObjects/Rewards/New Cursed Reward")]
public class CrusedReward : Reward
{
	[Space]
	[Space]
	[Header("Cursed Reward Data")]
	public RewardTypes buffRewardType;

	[Range(0f, 1f)]
	public float buffPercent;

	public Sprite buffRewardSprite;

	public Sprite buffRewardOverlaySprite;

	public string buffRewardPopUpText;

	[Space]
	public RewardTypes debuffRewardType;

	[Range(-1f, 0f)]
	public float debuffPercent;

	public Sprite debuffRewardSprite;

	public Sprite debuffRewardOverlaySprite;

	public string debuffRewardPopUpText;

	public override bool CanSelectReward()
	{
		if (SceneSingleton<PlayerRewardsManager>.Instance.CanSelectPercentReward(buffRewardType, buffPercent) && SceneSingleton<PlayerRewardsManager>.Instance.CanSelectPercentReward(debuffRewardType, debuffPercent))
		{
			return base.CanSelectReward();
		}
		return false;
	}

	public override void SelectReward()
	{
		SceneSingleton<PlayerRewardsManager>.Instance.SelectPercentReward(buffRewardType, buffPercent);
		SceneSingleton<PlayerRewardsManager>.Instance.SelectPercentReward(debuffRewardType, debuffPercent);
	}

	public override string GetRewardTitle()
	{
		Color rewardPercentBuffColor = Singleton<RewardDataStore>.Instance.GetRewardPercentBuffColor(buffPercent);
		string iDString = Singleton<LocalizationSystem>.Instance.GetIDString(buffRewardPopUpText);
		string text = iDString + " <color=#" + ColorHelper.GetHexCode(rewardPercentBuffColor) + "> " + buffPercent * 100f + "% </color>";
		rewardPercentBuffColor = Singleton<RewardDataStore>.Instance.GetRewardPercentBuffColor(debuffPercent);
		string iDString2 = Singleton<LocalizationSystem>.Instance.GetIDString(debuffRewardPopUpText);
		string text2 = iDString2 + " <color=#" + ColorHelper.GetHexCode(rewardPercentBuffColor) + "> " + debuffPercent * 100f + "% </color>";
		return text + "\n" + text2;
	}

	public Sprite GetBuffRewardSprite()
	{
		return buffRewardSprite;
	}

	public Sprite GetBuffRewardOverlaySprite()
	{
		return buffRewardOverlaySprite;
	}

	public Sprite GetDebuffRewardSprite()
	{
		return debuffRewardSprite;
	}

	public Sprite GetDebuffRewardOverlaySprite()
	{
		return debuffRewardOverlaySprite;
	}

	public override Sprite GetRewardSprite()
	{
		return null;
	}

	public override void AddRewardPopUpText()
	{
		string iDString = Singleton<LocalizationSystem>.Instance.GetIDString(buffRewardPopUpText);
		string iDString2 = Singleton<LocalizationSystem>.Instance.GetIDString(debuffRewardPopUpText);
		SceneSingleton<PopUpTextManager>.Instance.AddPopUpText(iDString, iDString2, buffPercent, debuffPercent);
	}
}
