using System.Collections.Generic;
using UnityEngine;

public class SDestroyModeManager : MonoBehaviour, IMissionModeManager
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
	private SpriteRenderer mapIconSpriteRenderer;

	[SerializeField]
	private List<BossesFleet> BossesFleetsList;

	public void SetUpMode()
	{
		targetTransform = SceneSingleton<PlayerManager>.Instance.GetPlayerTransform();
		SceneSingleton<GameHeatManager>.Instance.OnHeatTimerChange += SpawnBossesFleet;
		SceneSingleton<BossTimerUIController>.Instance.SetBossTimer(BossesFleetsList[0].fleetPercent);
	}

	public void StartMode()
	{
		BuildStation();
	}

	public void EndMode(bool isPlayerWon)
	{
		SceneSingleton<GameHeatManager>.Instance.OnHeatTimerChange -= SpawnBossesFleet;
		if (!isPlayerWon)
		{
			WarpStationEndGame();
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
		GetComponentInChildren<StationMissionManager>().SpawnStation(StationDestroyed, AIFaction.Red);
		SceneSingleton<GameMissionManager>.Instance.SetMissionMainArrow(base.transform);
		SceneSingleton<GameMissionManager>.Instance.SetMapIcon(mapIconSpriteRenderer);
		Invoke("CameraTargetStation", 2f);
	}

	private void WarpStationEndGame()
	{
	}

	public void StationDestroyed()
	{
		SceneSingleton<GameManager>.Instance.EndGame(isPlayerWon: true);
	}

	private void CameraTargetStation()
	{
		if (!SaveSystem.GetSkipBossSetting())
		{
			SceneSingleton<GameCameraManager>.Instance.SetCameraTarget(base.transform, null, SceneSingleton<GameMissionManager>.Instance.GetCameraSizeOffset());
		}
	}
}
