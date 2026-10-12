using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class UpgradeTreeStatsController : MonoBehaviour
{
	[SerializeField]
	private List<UpgradeTreeStat> upgradeTreeStatsList;

	private bool isDisabling;

	public void SetUpRewardsStats(RewardStats rewardStats)
	{
		if (rewardStats.IsEmpty())
		{
			if (base.gameObject.activeSelf && !isDisabling)
			{
				isDisabling = true;
				TweenController.KillTweens(base.transform);
				TweenController.ScaleV3(base.transform, 1f, 0f, TweenDuration.Very_Short, ignoreTimeScale: true, () =>
				{
					base.gameObject.SetActive(value: false);
				});
			}
			return;
		}
		foreach (UpgradeTreeStat upgradeTreeStats in upgradeTreeStatsList)
		{
			int statTypes = rewardStats.GetStatTypes(upgradeTreeStats.GetStatType());
			int addedValue = 0;
			if (rewardStats.LevelUp && rewardStats.LinkedReward != null && upgradeTreeStats.GetStatType() != StatTypes.PartsCount)
			{
				addedValue = statTypes;
				statTypes = rewardStats.LinkedReward.rewardStats.GetStatTypes(upgradeTreeStats.GetStatType());
			}
			upgradeTreeStats.SetStat(statTypes, addedValue);
		}
		if (!base.gameObject.activeSelf || isDisabling)
		{
			isDisabling = false;
			TweenController.KillTweens(base.transform);
			TweenController.ScaleV3(base.transform, 0f, 1f, TweenDuration.Very_Short, ignoreTimeScale: true);
		}
		base.gameObject.SetActive(value: true);
		LayoutRebuilder.ForceRebuildLayoutImmediate(base.transform as RectTransform);
	}
}
