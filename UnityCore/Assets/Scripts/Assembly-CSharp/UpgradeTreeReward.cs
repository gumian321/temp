using UnityEngine;
using UnityEngine.UI;

public class UpgradeTreeReward : MonoBehaviour
{
	private UpgradeTreeNode upgradeTreeNode;

	private Reward reward;

	[SerializeField]
	private Image rewardBackImage;

	[SerializeField]
	private Image rewardSprite;

	[SerializeField]
	private Image rewardOverlay;

	[SerializeField]
	private GameObject rewardLock;

	[SerializeField]
	private GameObject rewardShowcaseObject;

	[SerializeField]
	private GameObject rewardArrowObject;

	public void SetUI(UpgradeTreeNode upgradeTreeNode, Reward reward)
	{
		this.upgradeTreeNode = upgradeTreeNode;
		this.reward = reward;
		rewardSprite.sprite = reward.GetRewardSprite();
		rewardOverlay.sprite = reward.GetRewardOverlaySprite();
		rewardOverlay.gameObject.SetActive(rewardOverlay.sprite != null);
		rewardBackImage.color = Singleton<RewardDataStore>.Instance.GetRarityColor(reward.rarity);
		rewardLock.SetActive(!reward.IsRewardUnlocked());
	}

	public void ShowShowcase(bool flag)
	{
		if (rewardShowcaseObject.activeSelf != flag)
		{
			rewardShowcaseObject.SetActive(flag);
			if (flag)
			{
				TweenController.ScaleV3(rewardShowcaseObject.transform, 0f, 1f, TweenDuration.Super_Short, ignoreTimeScale: true);
			}
		}
	}

	public void HideLock()
	{
		rewardLock.SetActive(value: false);
	}

	public void RefreshLock()
	{
		if (rewardLock.activeSelf)
		{
			TweenController.PunchScale(rewardLock.transform, 0.25f, TweenDuration.Short, ignoreTimeScale: true);
		}
	}

	public void HideArrow()
	{
		rewardArrowObject.SetActive(value: false);
	}

	public void ShowReward()
	{
		upgradeTreeNode.ShowCaseReward(reward);
	}
}
