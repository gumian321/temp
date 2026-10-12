using UnityEngine;

[CreateAssetMenu(fileName = "New Percent Reward", menuName = "ScriptableObjects/Rewards/New Percent Reward")]
public class PercentBasicReward : BasicReward
{
	[Range(-1f, 1f)]
	[SerializeField]
	private float percent = 0.5f;

	public override bool CanSelectReward()
	{
		if (SceneSingleton<PlayerRewardsManager>.Instance.CanSelectPercentReward(rewardType, percent))
		{
			return base.CanSelectReward();
		}
		return false;
	}

	public override void SelectReward()
	{
		SceneSingleton<PlayerRewardsManager>.Instance.SelectPercentReward(rewardType, percent);
	}

	public override void AddRewardPopUpText()
	{
		SceneSingleton<PopUpTextManager>.Instance.AddPopUpText(Singleton<LocalizationSystem>.Instance.GetIDString(rewardTextID), percent);
	}
}
