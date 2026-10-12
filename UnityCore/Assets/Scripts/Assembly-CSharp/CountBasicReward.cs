using UnityEngine;

[CreateAssetMenu(fileName = "New Count Reward", menuName = "ScriptableObjects/Rewards/New Count Reward")]
public class CountBasicReward : BasicReward
{
	[Space]
	[Space]
	[Header("Count Reward Data")]
	public int rewardCount = 1;

	public override string GetRewardTitle()
	{
		if (rewardCount == 1)
		{
			return Singleton<LocalizationSystem>.Instance.GetIDString(rewardTextID);
		}
		return "x" + rewardCount + " " + Singleton<LocalizationSystem>.Instance.GetIDString(rewardTextID);
	}

	public override void SelectReward()
	{
		SceneSingleton<PlayerRewardsManager>.Instance.SelectCountReward(rewardType, rewardCount);
		Singleton<CurserManager>.Instance.SetCurser(CurserTypes.Hand, rewardCount);
	}

	public override bool CanSelectReward()
	{
		if (SceneSingleton<PlayerRewardsManager>.Instance.CanSelectReward(rewardType, rewardCount))
		{
			return base.CanSelectReward();
		}
		return false;
	}
}
