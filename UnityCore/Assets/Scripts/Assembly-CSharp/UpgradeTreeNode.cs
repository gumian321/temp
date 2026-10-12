using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

public class UpgradeTreeNode : MonoBehaviour
{
	[SerializeField]
	private float nodeBaseValue;

	[Space]
	private UpgradeTreeManager upgradeTreeManager;

	[SerializeField]
	private UpgradeTreeNode previousUpgradeTreeNode;

	[Space]
	[Header("Rewards")]
	private Reward nodeCurrentReward;

	private Reward nodeMainReward;

	[SerializeField]
	private UpgradeTreeReward upgradeTreeMainReward;

	[Space]
	[SerializeField]
	private List<Reward> nodeRewardsList;

	[SerializeField]
	private List<UpgradeTreeReward> upgradeTreeRewardsList;

	[Space]
	[SerializeField]
	private List<GameObject> LocksList;

	[Space]
	[Header("Contents")]
	[SerializeField]
	private GameObject activeNodeContent;

	[SerializeField]
	private GameObject deactiveNodeContent;

	[Space]
	[Header("Collideres")]
	[SerializeField]
	private CanvasGroup canvasGroup;

	[Space]
	[Header("Video")]
	[SerializeField]
	private PanelVideoPlayer panelVideoPlayer;

	[Space]
	[Header("Node UI")]
	[SerializeField]
	private TextMeshProUGUI nodeTitle;

	[SerializeField]
	private TextMeshProUGUI nodeDesc;

	[SerializeField]
	private UpgradeTreeStatsController upgradeTreeStatsController;

	[Space]
	[SerializeField]
	private Button unlockButton;

	[SerializeField]
	private TextMeshProUGUI unlockButtonText;

	[Space]
	[SerializeField]
	private GameObject unlockButtonPricePanel;

	[SerializeField]
	private TextMeshProUGUI unlockPriceText;

	[Space]
	[SerializeField]
	private GameObject unlockActiveButtonPricePanel;

	[SerializeField]
	private TextMeshProUGUI unlockActivePriceText;

	[SerializeField]
	private GameObject backButton;

	private bool canBeUnlocked;

	private int lockIndex;

	private bool isNodeActive;

	private bool isActive;

	public List<Reward> GetNodeRewardsList()
	{
		return nodeRewardsList;
	}

	private void OnEnable()
	{
		Singleton<MetaEconomySystem>.Instance.OnMetaChange += OnMetaChange;
	}

	private void OnDisable()
	{
		Singleton<MetaEconomySystem>.Instance.OnMetaChange -= OnMetaChange;
	}

	private void Awake()
	{
		nodeMainReward = nodeRewardsList[0];
		upgradeTreeManager = Object.FindObjectOfType<UpgradeTreeManager>();
		GetComponent<Button>().interactable = true;
		activeNodeContent.SetActive(value: false);
		SetUpNodeRewards();
		ShowCaseNextReward();
		ShowCaseReward(nodeRewardsList[0]);
	}

	private void ShowCaseNextReward()
	{
		if (IsNodeFullyUnlocked())
		{
			ShowCaseReward(nodeRewardsList[0]);
		}
		else
		{
			ShowCaseReward(GetNextReward());
		}
	}

	private void SetUpNodeRewards()
	{
		if (nodeRewardsList.Count > upgradeTreeRewardsList.Count)
		{
			Debug.LogError("Rewards counts in Node is greater than the UI places it only should be 5 rewards");
		}
		foreach (GameObject locks in LocksList)
		{
			locks.SetActive(value: false);
		}
		lockIndex = 0;
		for (int i = 0; i < nodeRewardsList.Count; i++)
		{
			upgradeTreeRewardsList[i].gameObject.SetActive(value: true);
			upgradeTreeRewardsList[i].SetUI(this, nodeRewardsList[i]);
			if (!nodeRewardsList[i].IsRewardUnlocked())
			{
				LocksList[lockIndex].SetActive(value: true);
				lockIndex++;
			}
			if (i == nodeRewardsList.Count - 1)
			{
				upgradeTreeRewardsList[i].HideArrow();
			}
		}
	}

	public void ShowCaseReward(Reward reward)
	{
		nodeCurrentReward = reward;
		nodeTitle.text = reward.GetRewardTitle();
		nodeDesc.text = Singleton<LocalizationSystem>.Instance.GetIDString(reward.rewardDesc);
		upgradeTreeStatsController.SetUpRewardsStats(reward.rewardStats);
		if (reward.rewardVideoClip != null)
		{
			panelVideoPlayer.SetVideo(reward.rewardVideoClip);
		}
		upgradeTreeMainReward.SetUI(this, reward);
		SetUpButton();
		ShowShowcase();
		upgradeTreeMainReward.ShowShowcase(IsNodeFullyUnlocked());
	}

	private void ShowShowcase()
	{
		foreach (UpgradeTreeReward upgradeTreeRewards in upgradeTreeRewardsList)
		{
			upgradeTreeRewards.ShowShowcase(flag: false);
		}
		upgradeTreeRewardsList[nodeRewardsList.IndexOf(nodeCurrentReward)].ShowShowcase(flag: true);
	}

	private void SetUpButton()
	{
		if (Singleton<DemoBuildManager>.Instance != null && Singleton<DemoBuildManager>.Instance.IsDemoEnabled() && !Singleton<DemoBuildManager>.Instance.IsRewardAvilable(nodeCurrentReward))
		{
			unlockButton.interactable = false;
			unlockButtonText.text = Singleton<LocalizationSystem>.Instance.GetIDString("Lab_Demo");
			SetButtonPrice(flag: false);
			unlockActiveButtonPricePanel.SetActive(value: false);
			return;
		}
		if (previousUpgradeTreeNode != null && IsNodeFullyLocked() && !previousUpgradeTreeNode.IsMainNodeUnlocked())
		{
			unlockButton.interactable = false;
			unlockButtonText.text = Singleton<LocalizationSystem>.Instance.GetIDString("Lab_UnlockPrevious");
			SetButtonPrice(flag: true);
		}
		else if (IsNodeFullyUnlocked())
		{
			unlockButton.interactable = false;
			unlockButtonText.text = Singleton<LocalizationSystem>.Instance.GetIDString("Lab_AllUnlocked");
			unlockActiveButtonPricePanel.SetActive(value: false);
			SetButtonPrice(flag: false);
		}
		else if (!nodeCurrentReward.IsRewardUnlocked())
		{
			unlockButton.interactable = CanUnlockReward() && Singleton<MetaEconomySystem>.Instance.CanSpendMetaPoints(GetCurrentRewardPrice());
			if (CanUnlockReward())
			{
				unlockButtonText.text = Singleton<LocalizationSystem>.Instance.GetIDString("Lab_Unlock");
			}
			else
			{
				unlockButtonText.text = Singleton<LocalizationSystem>.Instance.GetIDString("Lab_UnlockPrevious");
			}
			SetButtonPrice(flag: true);
		}
		else
		{
			unlockButton.interactable = false;
			unlockButtonText.text = Singleton<LocalizationSystem>.Instance.GetIDString("Lab_Unlocked");
			SetButtonPrice(flag: false);
		}
		canBeUnlocked = unlockButton.interactable;
	}

	private void SetButtonPrice(bool flag)
	{
		unlockButtonPricePanel.SetActive(flag);
		if (flag)
		{
			unlockPriceText.text = GetCurrentRewardPrice().ToString();
			unlockActivePriceText.text = GetCurrentRewardPrice().ToString();
		}
	}

	private bool CanUnlockReward()
	{
		for (int num = nodeRewardsList.IndexOf(nodeCurrentReward) - 1; num >= 0; num--)
		{
			if (!nodeRewardsList[num].IsRewardUnlocked())
			{
				return false;
			}
		}
		return true;
	}

	private Reward GetNextReward()
	{
		foreach (Reward nodeRewards in nodeRewardsList)
		{
			if (!nodeRewards.IsRewardUnlocked())
			{
				return nodeRewards;
			}
		}
		return null;
	}

	public void OnMetaChange(int points)
	{
		SetUpNodeRewards();
		nodeCurrentReward = GetNextReward();
		if (nodeCurrentReward != null)
		{
			unlockButton.interactable = points >= GetCurrentRewardPrice() && canBeUnlocked;
			if (isActive)
			{
				ShowCaseReward(nodeCurrentReward);
			}
		}
		else
		{
			ShowCaseReward(nodeRewardsList[0]);
		}
		if (isActive)
		{
			if (!unlockButton.interactable)
			{
				EventSystem.current.SetSelectedGameObject(upgradeTreeRewardsList[nodeRewardsList.IndexOf(nodeCurrentReward)].gameObject);
			}
			else
			{
				EventSystem.current.SetSelectedGameObject(unlockButton.gameObject);
			}
		}
	}

	public void ButtonPressed()
	{
		Singleton<AudioManager>.Instance.PlaySFX(AudioClipTypes.UI_ClickTree);
		nodeCurrentReward.UnlockReward();
		Singleton<MetaEconomySystem>.Instance.ModifyMetaPoints(-GetCurrentRewardPrice());
		if (Singleton<AnalyticsManager>.Instance != null)
		{
			Singleton<AnalyticsManager>.Instance.CallLabNodeUnlockedEvent(nodeCurrentReward.name);
		}
		upgradeTreeManager.TreeNodeUnlocked();
	}

	public void ShowReward()
	{
		if (!isActive && upgradeTreeManager.CanAvctivateNode())
		{
			ActivateNode();
		}
	}

	public void ActivateNode()
	{
		isActive = true;
		GetComponent<Button>().interactable = false;
		activeNodeContent.SetActive(value: true);
		deactiveNodeContent.SetActive(value: false);
		upgradeTreeManager.ActivateNode(this);
		panelVideoPlayer.PlayVideo();
		GetComponent<ObjectTriggersController>().enabled = false;
		Singleton<CurserManager>.Instance.SetCurser(CurserTypes.Normal);
		ResetTweenNode();
		TweenController.DelayedCall(0.25f, () =>
		{
			TweenNode();
		}, ignoreTimeScale: true);
		ShowCaseNextReward();
		EventSystem.current.SetSelectedGameObject(upgradeTreeRewardsList[nodeRewardsList.IndexOf(nodeCurrentReward)].gameObject);
	}

	public void DeactivateNode()
	{
		isActive = false;
		GetComponent<Button>().interactable = true;
		activeNodeContent.SetActive(value: false);
		deactiveNodeContent.SetActive(value: true);
		panelVideoPlayer.StopVideo();
		ShowCaseReward(nodeRewardsList[0]);
		GetComponent<ObjectTriggersController>().enabled = true;
		if (IsMainNodeUnlocked())
		{
			upgradeTreeMainReward.HideLock();
		}
		upgradeTreeManager.DeactivateNode();
	}

	private void ResetTweenNode()
	{
		foreach (UpgradeTreeReward upgradeTreeRewards in upgradeTreeRewardsList)
		{
			ObjectSystem.ReScale(upgradeTreeRewards.gameObject, 0f);
		}
		ObjectSystem.ReScale(panelVideoPlayer.gameObject, 0f);
		ObjectSystem.ReScale(nodeTitle.gameObject, 0f);
		ObjectSystem.ReScale(upgradeTreeStatsController.gameObject, 0f);
		ObjectSystem.ReScale(nodeDesc.transform.parent.gameObject, 0f);
		ObjectSystem.ReScale(unlockButton.gameObject, 0f);
		ObjectSystem.ReScale(unlockButtonPricePanel.gameObject, 0f);
		ObjectSystem.ReScale(backButton.gameObject, 0f);
	}

	private void TweenNode()
	{
		foreach (UpgradeTreeReward upgradeTreeRewards in upgradeTreeRewardsList)
		{
			TweenController.KillTweens(upgradeTreeRewards.transform);
			TweenController.Scale(upgradeTreeRewards.transform, 0f, 1f, TweenDuration.Very_Short, ignoreTimeScale: true);
		}
		TweenController.KillTweens(panelVideoPlayer.transform);
		TweenController.Scale(panelVideoPlayer.transform, 0f, 1f, TweenDuration.Very_Short, ignoreTimeScale: true);
		TweenController.KillTweens(nodeTitle.transform);
		TweenController.Scale(nodeTitle.transform, 0f, 1f, TweenDuration.Very_Short, ignoreTimeScale: true);
		TweenController.KillTweens(upgradeTreeStatsController.transform);
		TweenController.Scale(upgradeTreeStatsController.transform, 0f, 1f, TweenDuration.Very_Short, ignoreTimeScale: true);
		TweenController.KillTweens(nodeDesc.transform.parent.transform);
		TweenController.Scale(nodeDesc.transform.parent.transform, 0f, 1f, TweenDuration.Very_Short, ignoreTimeScale: true);
		TweenController.KillTweens(unlockButton.transform);
		TweenController.Scale(unlockButton.transform, 0f, 1f, TweenDuration.Very_Short, ignoreTimeScale: true);
		TweenController.KillTweens(unlockButtonPricePanel.transform);
		TweenController.Scale(unlockButtonPricePanel.transform, 0f, 1f, TweenDuration.Very_Short, ignoreTimeScale: true);
		TweenController.KillTweens(backButton.transform);
		TweenController.Scale(backButton.transform, 0f, 1f, TweenDuration.Very_Short, ignoreTimeScale: true);
	}

	public bool IsMainNodeUnlocked()
	{
		return nodeRewardsList[0].IsRewardUnlocked();
	}

	public bool IsNodeFullyUnlocked()
	{
		bool flag = true;
		foreach (Reward nodeRewards in nodeRewardsList)
		{
			flag &= nodeRewards.IsRewardUnlocked();
		}
		return flag;
	}

	public bool IsNodeFullyLocked()
	{
		bool flag = true;
		foreach (Reward nodeRewards in nodeRewardsList)
		{
			flag &= !nodeRewards.IsRewardUnlocked();
		}
		return flag;
	}

	public void HideNode()
	{
		canvasGroup.gameObject.SetActive(value: false);
		GetComponent<Button>().interactable = false;
	}

	public void ShowNode()
	{
		canvasGroup.gameObject.SetActive(value: true);
		base.gameObject.SetActive(value: false);
		base.gameObject.SetActive(value: true);
		upgradeTreeMainReward.RefreshLock();
		GetComponent<Button>().interactable = true;
	}

	public bool IsFirstNodeUnlocked()
	{
		return nodeRewardsList[0].IsRewardUnlocked();
	}

	private int GetCurrentRewardPrice()
	{
		if (nodeCurrentReward.rewardOverrideCost != -1)
		{
			return nodeCurrentReward.rewardOverrideCost;
		}
		return Singleton<UpgradeTreeDataStore>.Instance.GetRewardPrice(nodeCurrentReward.rarity, nodeBaseValue, nodeRewardsList.IndexOf(nodeCurrentReward));
	}

	public int GetTotalNodePrice()
	{
		int num = 0;
		foreach (Reward nodeRewards in nodeRewardsList)
		{
			num = ((nodeRewards.rewardOverrideCost == -1) ? (num + Singleton<UpgradeTreeDataStore>.Instance.GetRewardPrice(nodeRewards.rarity, nodeBaseValue, nodeRewardsList.IndexOf(nodeRewards))) : (num + nodeRewards.rewardOverrideCost));
		}
		return num;
	}

	public bool IsRarityUnlocked(RarityTypes rarityType)
	{
		foreach (Reward nodeRewards in nodeRewardsList)
		{
			if (!nodeRewards.IsRewardUnlocked() && nodeRewards.rarity == rarityType)
			{
				return false;
			}
		}
		return true;
	}
}
