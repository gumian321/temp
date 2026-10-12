using System.Collections.Generic;
using System.Linq;
using TMPro;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

public class ToggleResearchUIManager : SceneSingleton<ToggleResearchUIManager>
{
	[SerializeField]
	private GameObject selectedButton;

	[SerializeField]
	private Vector3 CamPos;

	[Space]
	[SerializeField]
	private GameObject backButton;

	[SerializeField]
	private Button applyButton;

	[SerializeField]
	private TextMeshProUGUI rewardsCountText;

	[SerializeField]
	private GameObject playRewardsActivated;

	[SerializeField]
	private GameObject playRewardsDeActivated;

	private List<ToggleRewardController> toggleRewardControllersList;

	private List<Reward> rewards;

	private int toggledRewardsCount;

	[Header("Research Cost")]
	private static string saveString = "ToggleResearches";

	[SerializeField]
	private int researchCost = 200;

	[SerializeField]
	private TextMeshProUGUI costText;

	[Space]
	[SerializeField]
	private GameObject buttonsPanel;

	[SerializeField]
	private GameObject ResearchPanel;

	[SerializeField]
	private Button ResearchButton;

	[SerializeField]
	private GameObject scrapsAmountUI;

	[SerializeField]
	private GameObject demoButton;

	private void Start()
	{
		toggleRewardControllersList = GetComponentsInChildren<ToggleRewardController>().ToList();
		RefreshRewards();
	}

	private void OnEnable()
	{
		Singleton<MetaEconomySystem>.Instance.OnMetaChange += OnMetaChange;
	}

	private void OnDisable()
	{
		Singleton<MetaEconomySystem>.Instance.OnMetaChange -= OnMetaChange;
	}

	private void OnMetaChange(int metaPoints)
	{
		RefreshButtons();
	}

	public void ShowMenu()
	{
		SceneSingleton<MainMenuManager>.Instance.SetOnEscKeyPressed(BackButton);
		SceneSingleton<MainMenuCameraManager>.Instance.SetCamTargetPos(CamPos, () =>
		{
			GetComponent<CanvasGroup>().interactable = true;
			EventSystem.current.SetSelectedGameObject(selectedButton);
			backButton.SetActive(value: true);
			backButton.GetComponent<Button>().interactable = true;
		});
		SceneSingleton<MainMenuCameraManager>.Instance.SetCamTargetZoom();
		LoadRewards();
		RefreshButtons();
	}

	public void BackButton()
	{
		GetComponent<CanvasGroup>().interactable = false;
		backButton.SetActive(value: false);
		backButton.GetComponent<Button>().interactable = false;
		SceneSingleton<PlayUIManager>.Instance.ShowPlayMenu();
	}

	public void ToggleAllButton()
	{
		foreach (ToggleRewardController toggleRewardControllers in toggleRewardControllersList)
		{
			toggleRewardControllers.ToggleReward(flag: true);
		}
		RefreshRewards();
	}

	public void ToggleNoneButton()
	{
		foreach (ToggleRewardController toggleRewardControllers in toggleRewardControllersList)
		{
			toggleRewardControllers.ToggleReward(flag: false);
		}
		RefreshRewards();
	}

	public void ApplyButton()
	{
		applyButton.interactable = false;
		SaveRewards();
		SaveSystem.SaveGame();
		BackButton();
	}

	private void LoadRewards()
	{
		foreach (ToggleRewardController toggleRewardControllers in toggleRewardControllersList)
		{
			toggleRewardControllers.SetReward();
		}
		RefreshRewards();
	}

	public void RefreshRewards()
	{
		toggledRewardsCount = 0;
		int num = 0;
		foreach (ToggleRewardController toggleRewardControllers in toggleRewardControllersList)
		{
			toggleRewardControllers.RefreshReward();
			if (toggleRewardControllers.IsToggled())
			{
				toggledRewardsCount++;
			}
			if (toggleRewardControllers.IsTogglable())
			{
				num++;
			}
		}
		rewardsCountText.text = toggledRewardsCount + "/" + RewardDataStore.MinToggableRewards;
		playRewardsDeActivated.SetActive(toggledRewardsCount == num);
		playRewardsActivated.SetActive(toggledRewardsCount != num);
		applyButton.interactable = CanApplyToggles();
		rewardsCountText.color = Singleton<RewardDataStore>.Instance.GetRewardPercentBuffColor(CanApplyToggles() ? 1 : 0);
	}

	public void SaveRewards()
	{
		foreach (ToggleRewardController toggleRewardControllers in toggleRewardControllersList)
		{
			if (toggleRewardControllers.IsToggled())
			{
				toggleRewardControllers.ToggleAllRewards();
			}
			else
			{
				toggleRewardControllers.UnToggleAllRewards();
			}
		}
	}

	private bool CanApplyToggles()
	{
		return toggledRewardsCount >= RewardDataStore.MinToggableRewards;
	}

	public void RefreshButtons()
	{
		demoButton.SetActive(value: false);
		if (Singleton<DemoBuildManager>.Instance != null && Singleton<DemoBuildManager>.Instance.IsDemoEnabled())
		{
			demoButton.SetActive(value: true);
			ResearchPanel.gameObject.SetActive(value: false);
			scrapsAmountUI.gameObject.SetActive(value: false);
			buttonsPanel.SetActive(value: false);
		}
		else
		{
			buttonsPanel.SetActive(isToggleResearchesUnlocked());
			ResearchPanel.gameObject.SetActive(!isToggleResearchesUnlocked());
			scrapsAmountUI.gameObject.SetActive(!isToggleResearchesUnlocked());
			ResearchButton.interactable = Singleton<MetaEconomySystem>.Instance.CanSpendMetaPoints(researchCost);
			costText.text = researchCost.ToString();
		}
	}

	public void ResearchSystem()
	{
		Singleton<MetaEconomySystem>.Instance.ModifyMetaPoints(-researchCost);
		SaveSystem.UnlockSystem(saveString);
		RefreshButtons();
		EventSystem.current.SetSelectedGameObject(selectedButton);
	}

	public bool isToggleResearchesUnlocked()
	{
		if (Singleton<GameBuildManager>.Instance != null && Singleton<GameBuildManager>.Instance.IsSteamBeta())
		{
			return true;
		}
		return SaveSystem.IsSystemUnlocked(saveString);
	}
}
