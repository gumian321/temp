using System.Collections.Generic;
using UnityEngine;

public class GAModeManager : MonoBehaviour, IMissionModeManager
{
	[Space]
	[Header("Mode Bonus Rating")]
	[SerializeField]
	private int MissionRating = 25000;

	[SerializeField]
	private float BonusRatingPerTraderSurvived = 20f;

	[Space]
	[Header("Mode Logic")]
	[SerializeField]
	private TraderFleetManager traderFleetManager;

	[SerializeField]
	private List<BossesFleet> BossesFleetsList;

	[Space]
	[Header("Fleet Goal")]
	[SerializeField]
	private float fleetGoalXOffset;

	[SerializeField]
	private Transform fleetGoal;

	[SerializeField]
	private SpriteRenderer fleetGoalMapIcon;

	public void SetUpMode()
	{
		SceneSingleton<GameHeatManager>.Instance.OnHeatTimerChange += SpawnBossesFleet;
		SetMissionGoal();
		SceneSingleton<BossTimerUIController>.Instance.SetBossTimer(BossesFleetsList[0].fleetPercent);
	}

	public void StartMode()
	{
		StartFleetMovement();
		Object.FindObjectOfType<DistancePanelController>().SetController(GetModeTarget(), fleetGoal);
	}

	public void EndMode(bool isPlayerWon)
	{
		if (isPlayerWon && SceneSingleton<GameMissionManager>.Instance.IsMissionHard())
		{
			Singleton<GameAchievementsManager>.Instance?.GAMissionCompleted(traderFleetManager.fleetPercent);
		}
		SceneSingleton<GameHeatManager>.Instance.OnHeatTimerChange -= SpawnBossesFleet;
	}

	public Transform GetModeTarget()
	{
		return traderFleetManager.transform.GetChild(0);
	}

	public int GetMissionCompletedRating()
	{
		return MissionRating;
	}

	public int GetBonusRating(bool isPlayerWon)
	{
		return (int)((float)traderFleetManager.GetTraderSurvivedCount() * BonusRatingPerTraderSurvived);
	}

	private void SpawnBossesFleet(float timePercentage)
	{
		for (int i = 0; i < BossesFleetsList.Count; i++)
		{
			if (BossesFleetsList[i].CanSpawnFleet(timePercentage))
			{
				BossesFleetsList[i].SpawnFleet();
				if (i + 1 < BossesFleetsList.Count)
				{
					SceneSingleton<BossTimerUIController>.Instance.SetBossTimer(BossesFleetsList[i + 1].fleetPercent);
				}
				else
				{
					SceneSingleton<BossTimerUIController>.Instance.EndBossTimer();
				}
			}
		}
	}

	private void StartFleetMovement()
	{
		traderFleetManager.Setup(runAway: false);
		SceneSingleton<GameMissionManager>.Instance.SetMissionMainArrow(traderFleetManager.transform.GetChild(0));
		Invoke("CameraTargetFleet", 2f);
	}

	private void CameraTargetFleet()
	{
		if (!SaveSystem.GetSkipBossSetting())
		{
			SceneSingleton<GameCameraManager>.Instance.SetCameraTarget(traderFleetManager.transform.GetChild(0), null, SceneSingleton<GameMissionManager>.Instance.GetCameraSizeOffset());
		}
	}

	private void SetMissionGoal()
	{
		fleetGoal.transform.position = new Vector2(fleetGoalXOffset, 0f);
		SceneSingleton<GameMissionManager>.Instance.SetMissionMainArrow(fleetGoal, fleetGoal.GetComponent<SpriteRenderer>().sprite);
		fleetGoalMapIcon.color = SceneSingleton<GameMissionManager>.Instance.GetMapIconColor();
	}
}
