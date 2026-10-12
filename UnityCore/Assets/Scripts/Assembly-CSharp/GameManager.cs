using UnityEngine;

public class GameManager : SceneSingleton<GameManager>
{
	private PauseMenuManager pauseMenuManager;

	private GameMissionManager gameMissionManager;

	private bool isGameManagerOn;

	private bool isGameOver;

	private int bossesActivated;

	private bool isPaused;

	private bool isBuilding;

	private bool isCameraTargeting;

	private void Start()
	{
		Singleton<TimeScaleManager>.Instance.StartGame();
		pauseMenuManager = Object.FindObjectOfType<PauseMenuManager>();
		gameMissionManager = SceneSingleton<GameMissionManager>.Instance;
		Object.FindObjectOfType<LoadingPanelContorller>(includeInactive: true).gameObject.SetActive(value: true);
		Object.FindObjectOfType<LoadingPanelContorller>().StartLoading();
		Singleton<InputManager>.Instance.DisableInput();
		SceneSingleton<PlayerMovement>.Instance.isMoving = false;
		isGameManagerOn = false;
		Singleton<BackgroundAudioManager>.Instance.PlayBackgroundAudio(Singleton<AudioDataStore>.Instance.InGameAudioClipsList);
		Invoke("LoadGameScripts", 1f);
	}

	private void LoadGameScripts()
	{
		gameMissionManager.LoadMissionData();
		SceneSingleton<BackgroundColorChanger>.Instance.SetBackgroundColor();
		Singleton<GameAchievementsManager>.Instance?.ResetStats();
		Singleton<AudioManager>.Instance.Reset(SceneSingleton<PlayerManager>.Instance.GetPlayerTransform());
		Singleton<RewardDataStore>.Instance.BuildRewardPacksList();
		Singleton<PlayerDataStore>.Instance.ResetPlayerDataStore();
		SceneSingleton<PlayerManager>.Instance.Reset();
		PauseAI();
		SceneSingleton<RatingSystemManager>.Instance.RefreshSystem();
		Singleton<TimeScaleManager>.Instance.PauseGame();
		Object.FindObjectOfType<LoadingPanelContorller>().EndLoading();
	}

	public void EndLoading()
	{
		Singleton<TimeScaleManager>.Instance.StartGame();
		StartGameScripts();
	}

	private void StartGameScripts()
	{
		float gameTimeSec = SceneSingleton<GameMissionManager>.Instance.GetGameTimeSec();
		SceneSingleton<GameHeatManager>.Instance.StartTimer(gameTimeSec);
		SceneSingleton<GameTimeManager>.Instance.StartTimer();
		SceneSingleton<BackgroundColorChanger>.Instance.StartBackgroundColorChange(gameTimeSec);
		TweenController.DelayedCall(2f, () =>
		{
			SceneSingleton<TutorialMenuController>.Instance.StartTutorial();
		});
		SceneSingleton<PlayerMovement>.Instance.isMoving = true;
		isGameManagerOn = true;
		StartAI();
		gameMissionManager.StartMissionMode();
		Singleton<InputManager>.Instance.EnableInput();
		Singleton<InputManager>.Instance.GameEndedDisableInput();
		Singleton<InputDataStore>.Instance.SetGameplayActionMap();
	}

	public void EndGame(bool isPlayerWon)
	{
		if (!isGameOver)
		{
			isGameOver = true;
			SceneSingleton<GameMissionManager>.Instance.EndMissionMode(isPlayerWon);
			CloseBuildMode();
			Singleton<InputManager>.Instance.GameEndedEnableInput();
			Singleton<InputManager>.Instance.DisableInput();
			SceneSingleton<PlayerMovement>.Instance.isMoving = false;
			isGameManagerOn = false;
			EndGameScripts(isPlayerWon);
			TweenController.DelayedCall(1f, () =>
			{
				Object.FindObjectOfType<GameOverMenuManager>().ShowGameOverUI(isPlayerWon);
				Singleton<TimeScaleManager>.Instance.EndGame();
			}, ignoreTimeScale: true);
		}
	}

	private void EndGameScripts(bool playerWon)
	{
		SceneSingleton<GameTimeManager>.Instance.StopTimer();
		PauseAI();
		Singleton<CurserManager>.Instance.SetCurser(CurserTypes.Normal);
		SceneSingleton<CameraManager>.Instance.GameOverZoomOut();
		SceneSingleton<RatingSystemManager>.Instance.CalculateScoreRatings(playerWon);
		Singleton<MetaEconomySystem>.Instance.ModifyMetaPoints(SceneSingleton<RatingSystemManager>.Instance.GetWonMetaPoints());
		Singleton<AnalyticsManager>.Instance?.SendRunCompletedAnalytics(playerWon);
		Singleton<GameAchievementsManager>.Instance?.SaveStats();
		SaveSystem.SaveGame();
		if ((playerWon || SceneSingleton<GameMissionManager>.Instance.IsMissionEndless()) && SceneSingleton<GameMissionManager>.Instance.IsMissionHard())
		{
			Singleton<GameLeaderboardManager>.Instance?.UploadScore(SceneSingleton<GameMissionManager>.Instance.currentMission.MissionLeaderBoardName, SceneSingleton<RatingSystemManager>.Instance.GetTotalScore());
		}
	}

	public void ActivateBoss()
	{
		bossesActivated++;
		Singleton<BackgroundAudioManager>.Instance.PlayBackgroundAudio(Singleton<AudioDataStore>.Instance.InGameBossAudioClipsList);
		SpawnersAcitvateBoss();
	}

	public void DectivateBoss()
	{
		bossesActivated--;
		if (bossesActivated == 0)
		{
			SpawnersDeacitvateBoss();
			Singleton<BackgroundAudioManager>.Instance.PlayBackgroundAudio(Singleton<AudioDataStore>.Instance.InGameAudioClipsList);
		}
	}

	public void BossWaveDestroyed()
	{
		PauseAI();
		Invoke("StartAI", Singleton<AIDataStore>.Instance.GetSpawningPauseAfterBoss());
	}

	private void StartAI()
	{
		SceneSingleton<AIWaveSpawner>.Instance.ResumeSpawner();
		SceneSingleton<AIPatrolSpawner>.Instance.ResumeSpawner();
		SceneSingleton<AISwarmingSpawner>.Instance.ResumeSpawner();
	}

	private void PauseAI()
	{
		SceneSingleton<AIWaveSpawner>.Instance.PauseSpawner();
		SceneSingleton<AIPatrolSpawner>.Instance.PauseSpawner();
		SceneSingleton<AISwarmingSpawner>.Instance.PauseSpawner();
	}

	private void SpawnersAcitvateBoss()
	{
		SceneSingleton<AIWaveSpawner>.Instance.BossActivated();
		SceneSingleton<AIPatrolSpawner>.Instance.BossActivated();
		SceneSingleton<AISwarmingSpawner>.Instance.BossActivated();
	}

	private void SpawnersDeacitvateBoss()
	{
		SceneSingleton<AIWaveSpawner>.Instance.BossDectivated();
		SceneSingleton<AIPatrolSpawner>.Instance.BossDectivated();
		SceneSingleton<AISwarmingSpawner>.Instance.BossDectivated();
	}

	public void GoToLab()
	{
		PlayerPrefs.SetInt("GoToLab", 1);
		Singleton<ScenesManager>.Instance.GoToMainMenuScene();
	}

	public void RestartGame(bool pauseMenu = false)
	{
		SceneSingleton<RatingSystemManager>.Instance.CalculateScoreRatings(playerWon: false);
		if (pauseMenu)
		{
			Singleton<AnalyticsManager>.Instance?.SendRunRestartAnalytics();
		}
		Singleton<ScenesManager>.Instance.GoToGameScene();
	}

	public void GoToMainMenu()
	{
		if (Singleton<GameLeaderboardManager>.Instance != null)
		{
			Singleton<GameLeaderboardManager>.Instance.LoadAllLeaderboards();
		}
		PlayerPrefs.SetInt("GoToLab", 0);
		Singleton<ScenesManager>.Instance.GoToMainMenuScene();
	}

	public void PauseKeyPressed()
	{
		if (isGameManagerOn)
		{
			if (Singleton<TimeScaleManager>.Instance.IsPaused())
			{
				unPauseGame();
			}
			else
			{
				PauseGame();
			}
		}
	}

	public void PauseGame()
	{
		if (!Singleton<TimeScaleManager>.Instance.IsPaused() && !isPaused)
		{
			isPaused = true;
			pauseMenuManager.ShowPauseUI();
			Singleton<CurserManager>.Instance.SetCurser(CurserTypes.Normal);
			Singleton<TimeScaleManager>.Instance.PauseGame();
			Singleton<InputManager>.Instance.isPlayerInputOn = false;
			SceneSingleton<GameTimeManager>.Instance.PauseTimer();
		}
	}

	public void unPauseGame()
	{
		if (Singleton<TimeScaleManager>.Instance.IsPaused() && isPaused)
		{
			isPaused = false;
			Singleton<InputDataStore>.Instance.SetGameplayActionMap();
			pauseMenuManager.HidePauseUI();
			SceneSingleton<PlayerTurretManager>.Instance.SetCurser();
			Singleton<TimeScaleManager>.Instance.UnpauseGame();
			Singleton<InputManager>.Instance.isPlayerInputOn = true;
			SceneSingleton<GameTimeManager>.Instance.ResumeTimer();
		}
	}

	private void OnApplicationFocus(bool hasFocus)
	{
		if (!hasFocus && isGameManagerOn)
		{
			PauseGame();
		}
	}

	private void Update()
	{
		if (isBuilding && CanEndBuildMode())
		{
			CloseBuildMode();
		}
	}

	public void IsCameraTargeting(bool isCameraTargeting)
	{
		this.isCameraTargeting = isCameraTargeting;
	}

	private bool CanEndBuildMode()
	{
		if (SceneSingleton<PlayerBuildingManager>.Instance.CanEndBuildMode())
		{
			return SceneSingleton<RewardSystemManager>.Instance.CanEndBuildMode();
		}
		return false;
	}

	public bool IsBuildingMode()
	{
		return isBuilding;
	}

	public void OpenBuildMode()
	{
		if (isGameManagerOn && !isCameraTargeting && !isBuilding)
		{
			isBuilding = true;
			Singleton<TimeScaleManager>.Instance.PauseGame();
			SceneSingleton<PlayerCoresManager>.Instance.EnterBuildMode();
			Singleton<InputManager>.Instance.ActivateBuildMode();
			SceneSingleton<CameraManager>.Instance.SetRadarMode(x: false);
			SceneSingleton<CameraManager>.Instance.SetBuildingMode(flag: true);
			SceneSingleton<RewardSystemManager>.Instance.ActivateNextRewardPack();
			SetPlayerStatsUIState(flag: true);
			Singleton<InputDataStore>.Instance.SetUIActionMap();
		}
	}

	public void CloseBuildMode()
	{
		if (isBuilding)
		{
			isBuilding = false;
			Singleton<TimeScaleManager>.Instance.UnpauseGame();
			SceneSingleton<CameraManager>.Instance.SetBuildingMode(flag: false);
			SceneSingleton<PlayerTurretManager>.Instance.SetCurser();
			SceneSingleton<PlayerCoresManager>.Instance.ExitBuildMode();
			SetPlayerStatsUIState(flag: false);
			Singleton<InputManager>.Instance.EndBuildMode();
			Singleton<InputDataStore>.Instance.SetGameplayActionMap();
			SceneSingleton<PointerManager>.Instance.DisablePointer();
		}
	}

	private void SetPlayerStatsUIState(bool flag)
	{
		SceneSingleton<PlayerDronesManager>.Instance.SetUIState(flag);
		SceneSingleton<PlayerCoresManager>.Instance.SetUIState(flag);
		SceneSingleton<PlayerStatsUIController>.Instance.SetUIState(flag);
	}

	public bool CanOpenBuildMode()
	{
		if (Singleton<InputManager>.Instance.isInputOn && !isBuilding)
		{
			return !Singleton<TimeScaleManager>.Instance.IsPaused();
		}
		return false;
	}
}
