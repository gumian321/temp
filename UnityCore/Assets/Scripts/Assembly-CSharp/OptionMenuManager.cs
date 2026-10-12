using System.Collections;
using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

public class OptionMenuManager : MonoBehaviour
{
	[SerializeField]
	private GameObject selectedButton;

	[SerializeField]
	private Vector3 OptionCamPos;

	[Space]
	[SerializeField]
	private CanvasGroup canvasGroup;

	private int resolutionsIndex;

	[SerializeField]
	private List<Resolution> resolutions;

	[Space]
	private int screenModesIndex;

	[SerializeField]
	private List<ScreenMode> screenModesList;

	[Space]
	private int languageIndex;

	[SerializeField]
	private List<LanguageOption> languagesList;

	[Space]
	[Header("UI")]
	[SerializeField]
	private TextMeshProUGUI resolutionText;

	[SerializeField]
	private TextMeshProUGUI screenModeText;

	[SerializeField]
	private TextMeshProUGUI languageText;

	[SerializeField]
	private Slider MasterAudioSlider;

	[SerializeField]
	private Slider MusicAudioSlider;

	[SerializeField]
	private Slider SFXAudioSlider;

	[Space]
	[SerializeField]
	private Button applyButton;

	[Space]
	[SerializeField]
	private GameObject backButton;

	[Space]
	[SerializeField]
	private GameObject ResetButton;

	[SerializeField]
	private GameObject ApplyResetButton;

	[Space]
	private bool isSkipBoss;

	[SerializeField]
	private GameObject activateSkipBossButton;

	[SerializeField]
	private GameObject deactivateSkipBossButton;

	public void ShowOptionMenu()
	{
		SceneSingleton<MainMenuManager>.Instance.SetOnEscKeyPressed(BackButton);
		LoadSettingsValues();
		SceneSingleton<MainMenuCameraManager>.Instance.SetCamTargetPos(OptionCamPos, () =>
		{
			GetComponent<CanvasGroup>().interactable = true;
			EventSystem.current.SetSelectedGameObject(selectedButton);
			backButton.SetActive(value: true);
			backButton.GetComponent<Button>().interactable = true;
		});
		SceneSingleton<MainMenuCameraManager>.Instance.SetCamTargetZoom();
		ObjectSystem.ReScale(ResetButton, 1f);
		ObjectSystem.ReScale(ApplyResetButton, 0f);
		ResetButton.GetComponent<Button>().interactable = true;
	}

	private void Start()
	{
		LoadSettingsValues();
	}

	private void SaveSettingsValues()
	{
		SaveSystem.SaveResulationSetting(resolutionsIndex);
		SaveSystem.SaveScreenModeSetting(screenModesIndex);
		SaveSystem.SaveLanguageSetting(languageIndex);
		AudioSlidersController.SetMasterSlider(MasterAudioSlider.value);
		AudioSlidersController.SetMusicSlider(MusicAudioSlider.value);
		AudioSlidersController.SetSFXSlider(SFXAudioSlider.value);
		Singleton<AudioSlidersController>.Instance.OnSlidersChange();
	}

	private void LoadSettingsValues()
	{
		resolutionsIndex = SaveSystem.GetResulationSetting();
		resolutionText.text = resolutions[resolutionsIndex].width + " X " + resolutions[resolutionsIndex].height;
		screenModesIndex = SaveSystem.GetScreenModeSetting();
		screenModeText.text = Singleton<LocalizationSystem>.Instance.GetIDString(screenModesList[screenModesIndex].Text);
		languageIndex = SaveSystem.GetLanguageSetting();
		languageText.text = Singleton<LocalizationSystem>.Instance.GetIDString(languagesList[languageIndex].Text);
		isSkipBoss = SaveSystem.GetSkipBossSetting();
		activateSkipBossButton.SetActive(!isSkipBoss);
		deactivateSkipBossButton.SetActive(isSkipBoss);
		MasterAudioSlider.value = AudioSlidersController.GetMasterSlider();
		MusicAudioSlider.value = AudioSlidersController.GetMusicSlider();
		SFXAudioSlider.value = AudioSlidersController.GetSFXSlider();
		RefreshApplyButton();
	}

	private bool IsSettingsValuesChanged()
	{
		if (resolutionsIndex != SaveSystem.GetResulationSetting())
		{
			return true;
		}
		if (screenModesIndex != SaveSystem.GetScreenModeSetting())
		{
			return true;
		}
		if (languageIndex != SaveSystem.GetLanguageSetting())
		{
			return true;
		}
		if (MasterAudioSlider.value != AudioSlidersController.GetMasterSlider())
		{
			return true;
		}
		if (MusicAudioSlider.value != AudioSlidersController.GetMusicSlider())
		{
			return true;
		}
		if (SFXAudioSlider.value != AudioSlidersController.GetSFXSlider())
		{
			return true;
		}
		return false;
	}

	private IEnumerator WaitAtLeastAFrameAndSave()
	{
		yield return new WaitForEndOfFrame();
		ApplySettings();
		SaveSettingsValues();
		RefreshApplyButton();
	}

	private void ApplySettings()
	{
		if (resolutionsIndex != SaveSystem.GetResulationSetting() || screenModesIndex != SaveSystem.GetScreenModeSetting())
		{
			Screen.SetResolution(resolutions[resolutionsIndex].width, resolutions[resolutionsIndex].height, screenModesList[screenModesIndex].screenMode);
			resolutionText.text = resolutions[resolutionsIndex].width + " X " + resolutions[resolutionsIndex].height;
		}
		Singleton<LocalizationSystem>.Instance.ChangeLanguage(languagesList[languageIndex].Language);
		SaveSystem.SaveGame();
		screenModeText.text = Singleton<LocalizationSystem>.Instance.GetIDString(screenModesList[screenModesIndex].Text);
		languageText.text = Singleton<LocalizationSystem>.Instance.GetIDString(languagesList[languageIndex].Text);
	}

	public void LeftResolution()
	{
		resolutionsIndex--;
		if (resolutionsIndex < 0)
		{
			resolutionsIndex = 0;
		}
		resolutionText.text = resolutions[resolutionsIndex].width + " X " + resolutions[resolutionsIndex].height;
		RefreshApplyButton();
	}

	public void RightResolution()
	{
		resolutionsIndex++;
		if (resolutionsIndex > resolutions.Count - 1)
		{
			resolutionsIndex = resolutions.Count - 1;
		}
		resolutionText.text = resolutions[resolutionsIndex].width + " X " + resolutions[resolutionsIndex].height;
		RefreshApplyButton();
	}

	public void LefScreenMode()
	{
		screenModesIndex--;
		if (screenModesIndex < 0)
		{
			screenModesIndex = screenModesList.Count - 1;
		}
		screenModeText.text = Singleton<LocalizationSystem>.Instance.GetIDString(screenModesList[screenModesIndex].Text);
		RefreshApplyButton();
	}

	public void RighScreenMode()
	{
		screenModesIndex++;
		if (screenModesIndex > screenModesList.Count - 1)
		{
			screenModesIndex = 0;
		}
		screenModeText.text = Singleton<LocalizationSystem>.Instance.GetIDString(screenModesList[screenModesIndex].Text);
		RefreshApplyButton();
	}

	public void LeftLanguage()
	{
		languageIndex--;
		if (languageIndex < 0)
		{
			languageIndex = languagesList.Count - 1;
		}
		languageText.text = Singleton<LocalizationSystem>.Instance.GetIDString(languagesList[languageIndex].Text);
		RefreshApplyButton();
	}

	public void RightLanguage()
	{
		languageIndex++;
		if (languageIndex > languagesList.Count - 1)
		{
			languageIndex = 0;
		}
		languageText.text = Singleton<LocalizationSystem>.Instance.GetIDString(languagesList[languageIndex].Text);
		RefreshApplyButton();
	}

	public void ActivateSkipBoss()
	{
		isSkipBoss = true;
		activateSkipBossButton.SetActive(!isSkipBoss);
		deactivateSkipBossButton.SetActive(isSkipBoss);
		EventSystem.current.SetSelectedGameObject(deactivateSkipBossButton);
		SaveSystem.SaveSkipBossSetting(isSkipBoss);
	}

	public void DeActivateSkipBoss()
	{
		isSkipBoss = false;
		activateSkipBossButton.SetActive(!isSkipBoss);
		deactivateSkipBossButton.SetActive(isSkipBoss);
		EventSystem.current.SetSelectedGameObject(activateSkipBossButton);
		SaveSystem.SaveSkipBossSetting(isSkipBoss);
	}

	public void MasterAudioSliderChanged()
	{
		AudioSlidersController.SetMasterSlider(MasterAudioSlider.value);
		Singleton<AudioSlidersController>.Instance.OnSlidersChange();
	}

	public void MusicAudioSliderChanged()
	{
		AudioSlidersController.SetMusicSlider(MusicAudioSlider.value);
		Singleton<AudioSlidersController>.Instance.OnSlidersChange();
	}

	public void SFXAudioSliderChanged()
	{
		AudioSlidersController.SetSFXSlider(SFXAudioSlider.value);
		Singleton<AudioSlidersController>.Instance.OnSlidersChange();
	}

	public void RefreshApplyButton()
	{
		applyButton.interactable = IsSettingsValuesChanged();
	}

	public void ApplySettingsButton()
	{
		StartCoroutine(WaitAtLeastAFrameAndSave());
		GetComponent<CanvasGroup>().interactable = true;
		EventSystem.current.SetSelectedGameObject(selectedButton);
	}

	public void BackButton()
	{
		GetComponent<CanvasGroup>().interactable = false;
		backButton.SetActive(value: false);
		backButton.GetComponent<Button>().interactable = false;
		LoadSettingsValues();
		SaveSystem.SaveGame();
		SceneSingleton<MainMenuManager>.Instance.ShowMainMenu();
	}

	public void ResettButton()
	{
		ResetButton.GetComponent<Button>().interactable = false;
		TweenController.ScaleV3(ResetButton.transform, 1f, 0f, TweenDuration.Super_Short, ignoreTimeScale: true, () =>
		{
			TweenController.ScaleV3(ApplyResetButton.transform, 0f, 1f, TweenDuration.Super_Short, ignoreTimeScale: true, () =>
			{
				ApplyResetButton.GetComponent<Button>().interactable = true;
				EventSystem.current.SetSelectedGameObject(ApplyResetButton);
			});
		});
	}

	public void ApplyResettButton()
	{
		if (Singleton<SaveSystem>.Instance != null && Singleton<ScenesManager>.Instance != null && Singleton<AnalyticsManager>.Instance != null)
		{
			if (Object.FindObjectOfType<UpgradeTreeManager>() != null)
			{
				Singleton<AnalyticsManager>.Instance.CallResetGameButtonEvent(Object.FindObjectOfType<UpgradeTreeManager>().GetTreeNodesUnlockedCount());
			}
			SaveSystem.ResetGame();
			Singleton<ScenesManager>.Instance.GoToIntroScene();
		}
	}
}
