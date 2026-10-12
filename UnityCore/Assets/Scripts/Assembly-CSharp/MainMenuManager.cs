using System;
using System.Collections;
using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.EventSystems;

public class MainMenuManager : SceneSingleton<MainMenuManager>
{
	[SerializeField]
	private Vector3 mainMenuCamPos;

	[SerializeField]
	private GameObject selectedButton;

	[SerializeField]
	private GameObject demoTextObject;

	[SerializeField]
	private GameObject betaTextObject;

	private Action OnEscKeyPressed;

	private bool CanPressBack = true;

	[Space]
	[SerializeField]
	private List<string> NewsLetterIDsList;

	[SerializeField]
	private TextMeshProUGUI newsletterText;

	private int index = -1;

	protected override void Awake()
	{
		base.Awake();
		Singleton<TimeScaleManager>.Instance.UnpauseGame();
		Singleton<InputDataStore>.Instance.SetUIActionMap();
		Singleton<InputManager>.Instance.GameEndedDisableInput();
		Singleton<InputManager>.Instance.DisableInput();
		if (Singleton<BackgroundAudioManager>.Instance != null)
		{
			Singleton<BackgroundAudioManager>.Instance.PlayBackgroundAudio(Singleton<AudioDataStore>.Instance.MainMenuBackgroundAudioClipsList);
		}
		if (PlayerPrefs.GetInt("GoToLab", 0) == 1)
		{
			UnityEngine.Object.FindObjectOfType<UpgradeTreeManager>().ShowTree();
		}
		else
		{
			ShowMainMenu();
		}
		if (Singleton<DemoBuildManager>.Instance != null)
		{
			demoTextObject.SetActive(Singleton<DemoBuildManager>.Instance.IsDemoEnabled());
		}
		if (Singleton<GameBuildManager>.Instance != null)
		{
			betaTextObject.SetActive(Singleton<GameBuildManager>.Instance.IsSteamBeta());
		}
		Singleton<MetaEconomySystem>.Instance.RefreshMetaSystem();
	}

	private void Start()
	{
		Singleton<AudioManager>.Instance.ResetSources();
	}

	public void PressBack()
	{
		if (CanPressBack && OnEscKeyPressed != null && (!(SceneSingleton<ControlUIManager>.Instance != null) || !SceneSingleton<ControlUIManager>.Instance.isRebinding))
		{
			CanPressBack = false;
			Action action = OnEscKeyPressed.Invoke;
			OnEscKeyPressed = null;
			action();
			StopAllCoroutines();
			StartCoroutine(WaitAtLeastAFrameAndSave());
		}
	}

	private IEnumerator WaitAtLeastAFrameAndSave()
	{
		yield return new WaitForEndOfFrame();
		yield return new WaitForEndOfFrame();
		CanPressBack = true;
	}

	public void SetOnEscKeyPressed(Action OnEscKeyPressed)
	{
		if (OnEscKeyPressed == null)
		{
			this.OnEscKeyPressed = null;
		}
		else
		{
			this.OnEscKeyPressed = OnEscKeyPressed.Invoke;
		}
	}

	public void ShowMainMenu()
	{
		SceneSingleton<MainMenuCameraManager>.Instance.SetCamTargetPos(mainMenuCamPos, () =>
		{
			GetComponent<CanvasGroup>().interactable = true;
			EventSystem.current.SetSelectedGameObject(selectedButton);
		});
		SceneSingleton<MainMenuCameraManager>.Instance.SetCamTargetZoom();
		PlayNextNewsLetter();
	}

	public void DisableMainMenu()
	{
		GetComponent<CanvasGroup>().interactable = false;
	}

	public void ExitApplication()
	{
		SaveSystem.SaveGame();
		ScenesManager.ExitApplication();
	}

	public void PlayNextNewsLetter()
	{
		index++;
		if (index >= NewsLetterIDsList.Count)
		{
			index = 0;
		}
		newsletterText.text = Singleton<LocalizationSystem>.Instance.GetIDString(NewsLetterIDsList[index]);
		ImageSystem.Alphalizer(newsletterText, 0f, TweenDuration.Short, snap: true);
		ImageSystem.Alphalizer(newsletterText, 1f, TweenDuration.Short);
		CancelInvoke();
		Invoke("PlayNextNewsLetter", 3f);
	}

	public void OpenWishListButton()
	{
		if (Singleton<GameBuildManager>.Instance != null)
		{
			Singleton<AnalyticsManager>.Instance?.CallWishListButtonPressedEvent();
			if (Singleton<GameBuildManager>.Instance.GetPlatform() == Platform.Steam)
			{
				Singleton<GoToURL>.Instance.GoToUrl("https://store.steampowered.com/app/1980350/Run_Build_Pew?utm_source=SteamDemo");
			}
			else
			{
				Singleton<GoToURL>.Instance.GoToUrl("https://store.steampowered.com/app/1980350/Run_Build_Pew?utm_source=ItchioPCDemo");
			}
		}
		else
		{
			Singleton<GoToURL>.Instance.GoToUrl("https://store.steampowered.com/app/1980350/Run_Build_Pew");
		}
	}

	public void OpenDiscordButton()
	{
		Singleton<AnalyticsManager>.Instance?.CallDiscordButtonPressedEvent();
		Singleton<GoToURL>.Instance.GoToUrl("https://discord.com/invite/nW2Tc4ShSf");
	}

	public void OpenGameButton()
	{
		Singleton<GoToURL>.Instance.GoToUrl("https://store.steampowered.com/app/2928690/Wandness/?utm_source=RBP");
	}

	public void OpenNewsletter()
	{
		Singleton<AnalyticsManager>.Instance?.CallNewsletterButtonPressedEvent();
		Singleton<GoToURL>.Instance.GoToUrl("http://eepurl.com/ijWdjn");
	}
}
