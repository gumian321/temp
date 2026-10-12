using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class ToggleRewardController : MonoBehaviour
{
	public List<Reward> rewardsList;

	[SerializeField]
	private Image rewardRarity;

	[SerializeField]
	private Image rewardIcon;

	[SerializeField]
	private Image rewardOverlay;

	[SerializeField]
	private GameObject rewardLock;

	[SerializeField]
	private CanvasGroup canvasGroup;

	[SerializeField]
	private Button rewardButton;

	private bool isToggled;

	private void Awake()
	{
		SetReward();
	}

	public void SetReward()
	{
		rewardRarity.color = Singleton<RewardDataStore>.Instance.GetRarityColor(rewardsList[0].rarity);
		rewardIcon.sprite = rewardsList[0].GetRewardSprite();
		rewardOverlay.sprite = rewardsList[0].GetRewardOverlaySprite();
		rewardOverlay.gameObject.SetActive(rewardOverlay.sprite != null);
		isToggled = rewardsList[0].IsRewardToggled();
		RefreshReward();
	}

	public void RefreshReward()
	{
		if (rewardsList[0].IsRewardUnlocked())
		{
			rewardLock.SetActive(value: false);
			if (isToggled)
			{
				canvasGroup.alpha = 1f;
			}
			else
			{
				canvasGroup.alpha = 0.7f;
			}
			rewardButton.interactable = true;
		}
		else
		{
			rewardButton.interactable = false;
			rewardLock.SetActive(value: true);
			canvasGroup.alpha = 0.25f;
		}
	}

	public void ToggleReward()
	{
		if (SceneSingleton<ToggleResearchUIManager>.Instance.isToggleResearchesUnlocked())
		{
			isToggled = !isToggled;
			SceneSingleton<ToggleResearchUIManager>.Instance.RefreshRewards();
		}
	}

	public void ToggleReward(bool flag)
	{
		isToggled = flag;
	}

	public bool IsToggled()
	{
		if (isToggled)
		{
			return rewardsList[0].IsRewardUnlocked();
		}
		return false;
	}

	public bool IsTogglable()
	{
		return rewardsList[0].IsRewardUnlocked();
	}

	public void ToggleAllRewards()
	{
		foreach (Reward rewards in rewardsList)
		{
			rewards.ToggleReward();
		}
	}

	public void UnToggleAllRewards()
	{
		foreach (Reward rewards in rewardsList)
		{
			rewards.UnToggleReward();
		}
	}
}
