using System.Collections.Generic;
using UnityEngine;

public class BHModeManager : MonoBehaviour, IMissionModeManager
{
	private Transform targetTransform;

	[Space]
	[Header("Mode Bonus Rating")]
	[SerializeField]
	private int MissionRating = 25000;

	[SerializeField]
	private float BonusRatingPerSecEarly = 20f;

	[Space]
	[Header("Mode Logic")]
	[SerializeField]
	private TraderFleetManager traderFleetManager;

	[SerializeField]
	private List<BossesFleet> BossesFleetsList;

	private BossesFleet currentBossFleet;

	[Space]
	[SerializeField]
	private float fleetWarpDistance = 50f;

	public void SetUpMode()
	{
		targetTransform = SceneSingleton<PlayerManager>.Instance.GetPlayerTransform();
	}

	public void StartMode()
	{
		StartFleetMovement();
	}

	public void EndMode(bool isPlayerWon)
	{
		if (isPlayerWon && SceneSingleton<GameMissionManager>.Instance.IsMissionHard())
		{
			bool isBossKilled = SceneSingleton<RatingSystemManager>.Instance.IsRatingCompleted(RatingTypes.Boss);
			Singleton<GameAchievementsManager>.Instance?.BHMissionCompleted(isBossKilled);
		}
		if (!isPlayerWon)
		{
			WarpFleetEndGame();
		}
	}

	public Transform GetModeTarget()
	{
		return targetTransform;
	}

	public int GetMissionCompletedRating()
	{
		return MissionRating;
	}

	public int GetBonusRating(bool isPlayerWon)
	{
		float gameTimeSec = SceneSingleton<GameMissionManager>.Instance.GetGameTimeSec();
		float secondsSurvived = SceneSingleton<GameHeatManager>.Instance.GetSecondsSurvived();
		float num = gameTimeSec - secondsSurvived;
		if (num > 0f)
		{
			return (int)(num * BonusRatingPerSecEarly);
		}
		return -1;
	}

	public void SpawnBossesFleet(float fleetDestructionPercent)
	{
		float percent = 1f - fleetDestructionPercent;
		foreach (BossesFleet bossesFleets in BossesFleetsList)
		{
			if (bossesFleets.CanSpawnFleet(percent))
			{
				WarpFleetAway();
				bossesFleets.isSpawned = true;
				currentBossFleet = bossesFleets;
				Invoke("SpawnBoss", 4f);
			}
		}
	}

	public void SpawnBoss()
	{
		if (currentBossFleet != null)
		{
			currentBossFleet.SpawnFleetPoint(traderFleetManager.transform.GetChild(0));
		}
	}

	private void StartFleetMovement()
	{
		traderFleetManager.Setup(runAway: true, SceneSingleton<PlayerManager>.Instance.GetPlayerTransform());
		SceneSingleton<GameMissionManager>.Instance.SetMissionMainArrow(traderFleetManager.transform.GetChild(0));
		Invoke("CameraTargetFleet", 2f);
	}

	private void WarpFleetAway()
	{
		traderFleetManager.WarpFleet(fleetWarpDistance);
	}

	private void WarpFleetEndGame()
	{
		traderFleetManager.WarpFleet(fleetWarpDistance);
	}

	private void CameraTargetFleet()
	{
		if (!SaveSystem.GetSkipBossSetting())
		{
			SceneSingleton<GameCameraManager>.Instance.SetCameraTarget(traderFleetManager.transform.GetChild(0), null, SceneSingleton<GameMissionManager>.Instance.GetCameraSizeOffset());
		}
	}
}
