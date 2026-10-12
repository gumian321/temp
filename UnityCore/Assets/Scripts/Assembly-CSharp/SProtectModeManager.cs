using System.Collections.Generic;
using UnityEngine;

public class SProtectModeManager : MonoBehaviour, IMissionModeManager
{
	private Transform targetTransform;

	[Space]
	[Header("Mode Bonus Rating")]
	[SerializeField]
	private int MissionRating = 25000;

	[SerializeField]
	private float BonusRatingPerStationPartSurvived = 20f;

	[Space]
	[Header("Mode Logic")]
	[SerializeField]
	private SpriteRenderer mapIconSpriteRenderer;

	[SerializeField]
	private List<BossesFleet> BossesFleetsList;

	public void SetUpMode()
	{
		SceneSingleton<GameHeatManager>.Instance.OnHeatTimerChange += SpawnBossesFleet;
		targetTransform = GetComponentInChildren<StationMissionManager>().transform;
		SceneSingleton<BossTimerUIController>.Instance.SetBossTimer(BossesFleetsList[0].fleetPercent);
	}

	public void StartMode()
	{
		BuildStation();
	}

	public void EndMode(bool isPlayerWon)
	{
		if (isPlayerWon && SceneSingleton<GameMissionManager>.Instance.IsMissionHard())
		{
			Singleton<GameAchievementsManager>.Instance?.SProtectMissionCompleted(GetComponentInChildren<StationMissionManager>().GetSurvivedPartsPercent());
		}
		SceneSingleton<GameHeatManager>.Instance.OnHeatTimerChange -= SpawnBossesFleet;
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
		return (int)((float)GetComponentInChildren<StationMissionManager>().GetSurvivedPartsCount() * BonusRatingPerStationPartSurvived);
	}

	private void SpawnBossesFleet(float timePercent)
	{
		for (int i = 0; i < BossesFleetsList.Count; i++)
		{
			if (BossesFleetsList[i].CanSpawnFleet(timePercent))
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

	private void BuildStation()
	{
		GetComponentInChildren<StationMissionManager>().SpawnStation(StationDestroyed, AIFaction.None);
		SceneSingleton<GameMissionManager>.Instance.SetMissionMainArrow(base.transform);
		SceneSingleton<GameMissionManager>.Instance.SetMapIcon(mapIconSpriteRenderer);
		Invoke("CameraTargetStation", 2f);
	}

	public void StationDestroyed()
	{
		SceneSingleton<GameManager>.Instance.EndGame(isPlayerWon: false);
	}

	private void CameraTargetStation()
	{
		if (!SaveSystem.GetSkipBossSetting())
		{
			SceneSingleton<GameCameraManager>.Instance.SetCameraTarget(base.transform, null, SceneSingleton<GameMissionManager>.Instance.GetCameraSizeOffset());
		}
	}
}
