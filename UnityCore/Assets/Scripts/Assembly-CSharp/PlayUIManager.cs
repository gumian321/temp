using TMPro;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

public class PlayUIManager : SceneSingleton<PlayUIManager>
{
	[SerializeField]
	private GameObject selectedButton;

	[SerializeField]
	private Vector3 CamPos;

	[Space]
	[SerializeField]
	private GameObject backButton;

	[SerializeField]
	private GameObject demoButton;

	[SerializeField]
	private TextMeshProUGUI missionDiffecultyText;

	[SerializeField]
	private IntervalSliderController missionDiffecultySlider;

	private int currentMissionID;

	[Space]
	[SerializeField]
	private TextMeshProUGUI missionText;

	[SerializeField]
	private TextMeshProUGUI missionDescText;

	[SerializeField]
	private Image missionObjectiveImage;

	private Mission currentMission;

	[Header("Research Cost")]
	[SerializeField]
	private GameObject playButton;

	[SerializeField]
	private Button researchButton;

	[SerializeField]
	private TextMeshProUGUI costText;

	[SerializeField]
	private GameObject scrapsAmountUI;

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

	public void ShowPlayMenu()
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
		RefreshButtons();
		currentMissionID = Singleton<MissionDataStore>.Instance.GetCurrentMissionIndex();
		RefreshSliders();
		RefreshMissionUI();
	}

	public void BackButton()
	{
		GetComponent<CanvasGroup>().interactable = false;
		backButton.SetActive(value: false);
		backButton.GetComponent<Button>().interactable = false;
		SceneSingleton<MainMenuManager>.Instance.ShowMainMenu();
	}

	public void ResetModifiers()
	{
		SceneSingleton<ToggleResearchUIManager>.Instance.ToggleAllButton();
		SceneSingleton<ToggleResearchUIManager>.Instance.ApplyButton();
		Singleton<MissionDataStore>.Instance.RefreshData();
		RefreshSliders();
	}

	public void PlayButton()
	{
		Singleton<BackgroundAudioManager>.Instance.PlayBackgroundAudio(Singleton<AudioDataStore>.Instance.InGameAudioClipsList);
		Singleton<ScenesManager>.Instance.GoToGameScene();
	}

	private void RefreshSliders()
	{
		missionDiffecultySlider.SetSlider(Singleton<MissionDataStore>.Instance.GetDifficultyCount() - 1, Singleton<MissionDataStore>.Instance.GetCurrentMissionDifficultyIndex(), Singleton<MissionDataStore>.Instance.SetMissionDifficulty);
		missionObjectiveImage.sprite = Singleton<MissionDataStore>.Instance.GetCurrentMissionObjective().objectiveSprite;
		RefreshSlidersText();
	}

	public void RefreshSlidersText()
	{
		missionDiffecultyText.text = "(" + Singleton<MissionDataStore>.Instance.GetDifficultyText(Singleton<MissionDataStore>.Instance.GetCurrentMissionDifficulty().difficultyType) + ")";
		missionObjectiveImage.sprite = Singleton<MissionDataStore>.Instance.GetCurrentMissionObjective().objectiveSprite;
	}

	private void RefreshMissionUI()
	{
		currentMission = Singleton<MissionDataStore>.Instance.GetCurrentMission(currentMissionID);
		missionText.text = Singleton<LocalizationSystem>.Instance.GetIDString(currentMission.MissionNameTextID);
		missionDescText.text = Singleton<LocalizationSystem>.Instance.GetIDString(currentMission.MissionDescTextID);
		RefreshSliders();
		RefreshButtons();
		SceneSingleton<GameLeaderboardUIManager>.Instance.LoadMissionLeaderboard(Singleton<MissionDataStore>.Instance.GetCurrentMission());
	}

	public void NextMission()
	{
		currentMissionID++;
		if (currentMissionID >= Singleton<MissionDataStore>.Instance.GetMissionsCount())
		{
			currentMissionID = 0;
		}
		Singleton<MissionDataStore>.Instance.SetCurrentMission(currentMissionID);
		RefreshMissionUI();
	}

	public void PreviousMission()
	{
		currentMissionID--;
		if (currentMissionID < 0)
		{
			currentMissionID = Singleton<MissionDataStore>.Instance.GetMissionsCount() - 1;
		}
		Singleton<MissionDataStore>.Instance.SetCurrentMission(currentMissionID);
		RefreshMissionUI();
	}

	public void RefreshButtons()
	{
		Mission mission = Singleton<MissionDataStore>.Instance.GetCurrentMission();
		demoButton.SetActive(value: false);
		if (Singleton<DemoBuildManager>.Instance != null && Singleton<DemoBuildManager>.Instance.IsDemoEnabled() && !Singleton<DemoBuildManager>.Instance.IsMissionAvilable(mission))
		{
			demoButton.SetActive(value: true);
			researchButton.gameObject.SetActive(value: false);
			playButton.SetActive(value: false);
		}
		else
		{
			playButton.SetActive(mission.IsMissionUnlocked());
			researchButton.gameObject.SetActive(!mission.IsMissionUnlocked());
			researchButton.interactable = mission.CanUnlockMission();
			scrapsAmountUI.gameObject.SetActive(!Singleton<MissionDataStore>.Instance.IsAllMissionUnlocked());
			costText.text = mission.MissionCost.ToString();
		}
	}

	public void ResearchMission()
	{
		Singleton<MissionDataStore>.Instance.GetCurrentMission().UnlockMission();
		RefreshButtons();
		EventSystem.current.SetSelectedGameObject(playButton.gameObject);
	}
}
