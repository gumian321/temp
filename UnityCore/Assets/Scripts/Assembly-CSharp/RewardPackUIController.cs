using UnityEngine;
using UnityEngine.UI;

public class RewardPackUIController : RewardPackController
{
	[SerializeField]
	private Image packColor;

	[SerializeField]
	private Image packIcon;

	public RectTransform layoutPos;

	private RectTransform rectTransform;

	public override void SetRewardPack(RewardPack rewardPack, RarityTypes rarityType = RarityTypes.None)
	{
		base.SetRewardPack(rewardPack, rarityType);
		packColor.color = Singleton<RewardDataStore>.Instance.GetRarityColor(packRarityType);
		packIcon.sprite = rewardPack.packSprite;
	}

	public override void SetRewardPack(RewardPackController rewardPackController)
	{
		base.SetRewardPack(rewardPackController);
		packColor.color = Singleton<RewardDataStore>.Instance.GetRarityColor(packRarityType);
		packIcon.sprite = rewardPack.packSprite;
	}

	public void SetLayoutPos(RectTransform layoutPos)
	{
		this.layoutPos = layoutPos;
		rectTransform = GetComponent<RectTransform>();
		rectTransform.anchorMax = layoutPos.anchorMax;
		rectTransform.anchorMin = layoutPos.anchorMin;
		rectTransform.anchoredPosition = layoutPos.anchoredPosition;
	}

	public void RefreshUI()
	{
		TweenController.KillTweens(rectTransform);
		TweenController.LocalRectMove(rectTransform, layoutPos, TweenDuration.Super_Short, ignoreTimeScale: true);
	}
}
