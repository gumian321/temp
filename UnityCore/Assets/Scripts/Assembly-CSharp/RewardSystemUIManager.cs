using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

public class RewardSystemUIManager : MonoBehaviour
{
	[SerializeField]
	private Transform rewardPacksUIPanelParent;

	[SerializeField]
	private List<RewardUIPanelController> rewardUIPanelControllersList = new List<RewardUIPanelController>();

	[SerializeField]
	private RectTransform CurrentRewardLayoutPos;

	[Space]
	[Header("Texts")]
	private bool isSpaceActive;

	[SerializeField]
	private TextMeshProUGUI ProcessText;

	[SerializeField]
	private TextMeshProUGUI rewardsCount;

	private RewardPackUIController currentRewardPackUI;

	private Queue<RewardPackUIController> avilableRewardPacks;

	private RewardSystemManager rewardSystemManager;

	[SerializeField]
	private Button recycleButton;

	private bool isPanelShown;

	private void Awake()
	{
		rewardSystemManager = Object.FindObjectOfType<RewardSystemManager>();
		avilableRewardPacks = new Queue<RewardPackUIController>();
		ObjectSystem.ReScale(recycleButton.gameObject, 0f);
		UpdateRewardsCountText();
	}

	private void Start()
	{
		Singleton<LocalizationSystem>.Instance.GetIDString("InGame_Open");
	}

	public void SetUpRewardsUI(List<Reward> rewardsList)
	{
		UpdateRewardsCountText();
		if (rewardsList.Count > rewardUIPanelControllersList.Count)
		{
			Debug.LogError(rewardsList.Count + " Rewards count is far greater than the Reward Panels");
		}
		if (rewardsList.Count < 3)
		{
			Debug.LogError(rewardsList.Count + " Rewards count is less than 3");
		}
		for (int i = 0; i < rewardsList.Count; i++)
		{
			rewardUIPanelControllersList[i].gameObject.SetActive(value: true);
			rewardUIPanelControllersList[i].SetPanelReward(rewardsList[i]);
			TweenController.KillTweens(rewardUIPanelControllersList[i].transform);
			TweenController.ScaleV3(rewardUIPanelControllersList[i].transform, 0f, 1f, TweenDuration.Very_Short, ignoreTimeScale: true);
		}
		GetComponent<CanvasGroup>().interactable = true;
		recycleButton.interactable = true;
		TweenController.KillTweens(recycleButton.transform);
		TweenController.ScaleV3(recycleButton.transform, 0f, 1f, TweenDuration.Very_Short, ignoreTimeScale: true);
		foreach (RewardUIPanelController rewardUIPanelControllers in rewardUIPanelControllersList)
		{
			if (rewardUIPanelControllers.rewardSelectButton.interactable)
			{
				EventSystem.current.SetSelectedGameObject(rewardUIPanelControllersList[0].gameObject);
				return;
			}
		}
		EventSystem.current.SetSelectedGameObject(recycleButton.gameObject);
	}

	public void AddRewardPack(RewardPackController rewardPackController)
	{
		UpdateRewardsCountText();
		UpdatePressSpaceText(state: true);
		GameObject gameObject = MasterPool.Get(PrefabTypes.UI_RewardPackLayoutPos);
		gameObject.transform.parent = rewardPacksUIPanelParent;
		ObjectSystem.ReScale(gameObject, 1f);
		GameObject rewardPackUI = MasterPool.Get(PrefabTypes.UI_RewardPack);
		RewardPackUIController component = rewardPackUI.GetComponent<RewardPackUIController>();
		component.SetRewardPack(rewardPackController);
		rewardPackUI.transform.parent = rewardPacksUIPanelParent;
		ObjectSystem.ReScale(rewardPackUI, 1f);
		LayoutRebuilder.ForceRebuildLayoutImmediate((RectTransform)rewardPacksUIPanelParent);
		component.SetLayoutPos(gameObject.GetComponent<RectTransform>());
		TweenController.ScaleV3(rewardPackUI.transform.GetChild(0), 0f, 1.5f, TweenDuration.Super_Short, ignoreTimeScale: true, () =>
		{
			TweenController.ScaleV3(rewardPackUI.transform.GetChild(0), 1.5f, 1f, TweenDuration.Very_Short, ignoreTimeScale: true);
		});
		avilableRewardPacks.Enqueue(component);
	}

	public void ActivateNextRewardPack(List<Reward> rewardsList)
	{
		UpdatePressSpaceText(state: false);
		currentRewardPackUI = avilableRewardPacks.Dequeue();
		isPanelShown = true;
		MasterPool.ReturnToPoolTransform(currentRewardPackUI.layoutPos.gameObject, PrefabTypes.UI_RewardPack);
		LayoutRebuilder.ForceRebuildLayoutImmediate((RectTransform)rewardPacksUIPanelParent);
		foreach (RewardPackUIController avilableRewardPack in avilableRewardPacks)
		{
			avilableRewardPack.RefreshUI();
		}
		TweenController.LocalRectMove((RectTransform)currentRewardPackUI.transform, CurrentRewardLayoutPos, TweenDuration.Super_Short, ignoreTimeScale: true, () =>
		{
			TweenController.ScaleV3(currentRewardPackUI.transform.GetChild(0), 1f, 0f, TweenDuration.Super_Short, ignoreTimeScale: true, () =>
			{
				SetUpRewardsUI(rewardsList);
			});
		});
	}

	public void HideUI()
	{
		UpdateRewardsCountText();
		MasterPool.ReturnToPoolTransform(currentRewardPackUI.gameObject, PrefabTypes.UI_RewardPack);
		foreach (RewardUIPanelController v in rewardUIPanelControllersList)
		{
			v.DisableButton();
			TweenController.KillTweens(v.transform);
			TweenController.ScaleV3(v.transform, 1f, 0f, TweenDuration.Super_Short, ignoreTimeScale: true, () =>
			{
				v.gameObject.SetActive(value: false);
			});
		}
		recycleButton.interactable = false;
		GetComponent<CanvasGroup>().interactable = false;
		TweenController.KillTweens(recycleButton.transform);
		TweenController.ScaleV3(recycleButton.transform, 1f, 0f, TweenDuration.Super_Short, ignoreTimeScale: true);
		isPanelShown = false;
	}

	public bool IsPanelShown()
	{
		return isPanelShown;
	}

	private void UpdateRewardsCountText()
	{
		rewardsCount.text = rewardSystemManager.GetAvilableRewardsCount().ToString();
		TweenController.KillTweens(rewardsCount.transform);
		TweenController.PunchScale(rewardsCount.transform, 0.2f, TweenDuration.Very_Short, ignoreTimeScale: true);
	}

	private void UpdatePressSpaceText(bool state)
	{
		if (state != isSpaceActive)
		{
			if (state)
			{
				TweenController.KillTweens(ProcessText.transform);
				TweenController.ScaleV3(ProcessText.transform, 0f, 1f, TweenDuration.Short, ignoreTimeScale: true);
				isSpaceActive = true;
			}
			else
			{
				TweenController.KillTweens(ProcessText.transform);
				TweenController.ScaleV3(ProcessText.transform, 1f, 0f, TweenDuration.Very_Short, ignoreTimeScale: true);
				isSpaceActive = false;
			}
		}
	}
}
