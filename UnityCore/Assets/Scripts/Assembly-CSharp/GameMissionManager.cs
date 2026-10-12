using UnityEngine;

public class GameMissionManager : SceneSingleton<GameMissionManager>
{
	private MissionDataStore missionDataStore;

	[HideInInspector]
	public Mission currentMission;

	[HideInInspector]
	public Difficulty currentMissionDifficulty;

	[HideInInspector]
	public MissionObjective currentMissionObjective;

	[HideInInspector]
	public float gameTime;

	[HideInInspector]
	public float enemiesDamageModifier = 1f;

	[HideInInspector]
	public float enemiesHealthModifier = 1f;

	[Space]
	[Header("Game Mission UI")]
	[SerializeField]
	private GameObject GameMissionTimerPanel;

	[SerializeField]
	private GameObject gameTimer;

	[SerializeField]
	private GameObject gameDistanceCounter;

	[SerializeField]
	private GameObject gameBossTimer;

	[SerializeField]
	private GameObject fullBarBackground;

	[SerializeField]
	private GameObject timerBackground;

	[HideInInspector]
	public bool isCountingDown;

	[HideInInspector]
	public bool hasTimer;

	private IMissionModeManager iMissionModeManager;

	private GameHeatManager gameHeatManager;

	public void LoadMissionData()
	{
		GameMissionTimerPanel.SetActive(value: false);
		gameHeatManager = SceneSingleton<GameHeatManager>.Instance;
		missionDataStore = Singleton<MissionDataStore>.Instance;
		currentMission = missionDataStore.GetCurrentMission();
		currentMissionObjective = missionDataStore.GetCurrentMissionObjective();
		currentMissionDifficulty = missionDataStore.GetCurrentMissionDifficulty();
		enemiesDamageModifier = currentMissionDifficulty.enemiesDamageModifier;
		enemiesHealthModifier = currentMissionDifficulty.enemiesHealthModifier;
		gameTimer.SetActive(currentMission.hasTimer);
		isCountingDown = currentMission.isTimerCountingDown;
		gameDistanceCounter.SetActive(currentMission.hasDistanceCounter);
		gameBossTimer.SetActive(currentMission.hasBossBars);
		timerBackground.SetActive(!currentMission.hasBossBars);
		fullBarBackground.SetActive(currentMission.hasBossBars);
		gameTime = currentMissionObjective.objectiveTime;
		iMissionModeManager = Object.Instantiate(currentMissionObjective.objectivePrefab, base.transform).GetComponent<IMissionModeManager>();
		iMissionModeManager.SetUpMode();
		Singleton<AIDataStore>.Instance.SetUpMissionAIConfiguration(currentMissionObjective.objectiveAIConfiguration);
		SceneSingleton<MapNodesManager>.Instance.Setup(currentMissionObjective.objectiveAIConfiguration);
	}

	public void MissionTimerRunOut()
	{
		if (currentMission.isTimeEndCondition)
		{
			SceneSingleton<GameManager>.Instance.EndGame(currentMission.isPlayerWinWhenTimerIsOver);
		}
	}

	public void CalculateScoreRatings(bool isPlayerWon)
	{
		if (isPlayerWon)
		{
			if (isPlayerWon && currentMission.CanBeCompleted)
			{
				SceneSingleton<RatingSystemManager>.Instance.AddRating(RatingTypes.MissionCompleted, iMissionModeManager.GetMissionCompletedRating());
			}
			int bonusRating = iMissionModeManager.GetBonusRating(isPlayerWon);
			if (bonusRating != -1)
			{
				SceneSingleton<RatingSystemManager>.Instance.AddRating(RatingTypes.BonusRating, bonusRating);
			}
		}
	}

	public void StartMissionMode()
	{
		GameMissionTimerPanel.SetActive(value: true);
		iMissionModeManager.StartMode();
	}

	public void EndMissionMode(bool isPlayerWon)
	{
		iMissionModeManager.EndMode(isPlayerWon);
		if (isPlayerWon && currentMissionObjective.objectiveACHID != "")
		{
			Singleton<GameAchievementsManager>.Instance?.ActivateAchievement(currentMissionObjective.objectiveACHID);
		}
	}

	public Transform GetMissionTarget()
	{
		return iMissionModeManager.GetModeTarget();
	}

	public float GetGameTimeSec()
	{
		return gameTime * 60f;
	}

	public void SetMissionMainArrow(Transform missionTargetTransform, Sprite iconSprite = null)
	{
		if (iconSprite == null)
		{
			SceneSingleton<PlayerArrowsManager>.Instance.SpawnMainArrow(missionTargetTransform, currentMission.MissionArrowIcon, currentMission.MissionArrowColor);
		}
		else
		{
			SceneSingleton<PlayerArrowsManager>.Instance.SpawnMainArrow(missionTargetTransform, iconSprite, currentMission.MissionArrowColor);
		}
	}

	public void SetMapIcon(SpriteRenderer spriteRenderer)
	{
		spriteRenderer.sprite = currentMission.MissionArrowIcon;
		spriteRenderer.color = currentMission.MissionArrowColor;
	}

	public Sprite GetMapIconSprite()
	{
		return currentMission.MissionArrowIcon;
	}

	public Color GetMapIconColor()
	{
		return currentMission.MissionArrowColor;
	}

	public bool IsOffsetPlayer()
	{
		return currentMission.isOffsetPlayer;
	}

	public float GetCameraSizeOffset()
	{
		return currentMission.cameraTargetSizeOffset;
	}

	public float GetPlayerOffset()
	{
		return currentMission.playerYOffset;
	}

	public bool IsMissionEndless()
	{
		return currentMission.isEndless;
	}

	public float GetMissionEndlessSpeedHeat()
	{
		return gameHeatManager.GetTimerHeatPercent() - 0.5f;
	}

	public bool IsMissionHard()
	{
		return currentMissionObjective.missionDiffeculty == DifficultyTypes.Hard;
	}
}
