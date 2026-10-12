using UnityEngine;

[CreateAssetMenu(fileName = "New Basic Reward", menuName = "ScriptableObjects/Rewards/New Basic Reward")]
public class BasicReward : Reward
{
	[Space]
	[Space]
	[Header("Basic Reward Data")]
	[SerializeField]
	protected string rewardTextID;

	[SerializeField]
	protected RewardTypes rewardType;

	[SerializeField]
	protected Sprite rewardSprite;

	public override void SelectReward()
	{
		SceneSingleton<PlayerRewardsManager>.Instance.SelectReward(rewardType);
	}

	public override bool CanConflictReward(Reward reward)
	{
		if (!(reward is BasicReward))
		{
			return false;
		}
		return ((BasicReward)reward).rewardType == rewardType;
	}

	public override string GetRewardTitle()
	{
		return Singleton<LocalizationSystem>.Instance.GetIDString(rewardTextID);
	}

	public override Sprite GetRewardSprite()
	{
		return rewardSprite;
	}

	public override void AddRewardPopUpText()
	{
		SceneSingleton<PopUpTextManager>.Instance.AddPopUpText(Singleton<LocalizationSystem>.Instance.GetIDString(rewardTextID));
	}
}
