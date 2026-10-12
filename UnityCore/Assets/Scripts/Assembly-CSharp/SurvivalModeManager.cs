using System.Collections.Generic;
using UnityEngine;

public class SurvivalModeManager : MonoBehaviour, IMissionModeManager
{
	private Transform targetTransform;

	[Space]
	[Header("Mode Bonus Rating")]
	[SerializeField]
	private int MissionRating = 25000;

	[SerializeField]
	private float RatingPerSecEarly = 25f;

	[Space]
	[Header("Mode Logic")]
	[Space]
	[SerializeField]
	private BossesFleet MiniBossFleet;

	[Space]
	[SerializeField]
	private BossesFleet MidBossFleet;

	[Space]
	[SerializeField]
	private List<PrefabTypes> EndBossFleetList;

	[SerializeField]
	private float EndBossSpawningRadius = 200f;

	public void SetUpMode()
	{
		targetTransform = SceneSingleton<PlayerManager>.Instance.GetPlayerTransform();
		SceneSingleton<GameHeatManager>.Instance.OnHeatTimerChange += SpawnBoss;
		SceneSingleton<BossTimerUIController>.Instance.SetBossTimer(MiniBossFleet.fleetPercent);
	}

	public void StartMode()
	{
		Invoke("SpawnEndBoss", 15f);
	}

	public void EndMode(bool isPlayerWon)
	{
		SceneSingleton<GameHeatManager>.Instance.OnHeatTimerChange -= SpawnBoss;
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
			return (int)(num * RatingPerSecEarly);
		}
		return -1;
	}

	private void SpawnBoss(float percent)
	{
		if (MiniBossFleet.CanSpawnFleet(percent))
		{
			MiniBossFleet.SpawnFleet();
			SceneSingleton<BossTimerUIController>.Instance.SetBossTimer(MidBossFleet.fleetPercent);
		}
		if (MidBossFleet.CanSpawnFleet(percent))
		{
			MidBossFleet.SpawnFleet(MidBossDestroyed);
			SceneSingleton<BossTimerUIController>.Instance.SetBossTimer(1f);
		}
	}

	private void SpawnEndBoss()
	{
		Transform missionTargetTransform = SceneSingleton<AIBossSpawner>.Instance.SpawnBossWave(EndBossFleetList, EndBossSpawningRadius, EndBossDestroyed, changeSpeedWithHeat: true);
		SceneSingleton<GameMissionManager>.Instance.SetMissionMainArrow(missionTargetTransform);
	}

	public void EndBossDestroyed()
	{
		SceneSingleton<GameManager>.Instance.EndGame(isPlayerWon: true);
	}

	public void MidBossDestroyed()
	{
		if (Singleton<DemoBuildManager>.Instance != null && Singleton<DemoBuildManager>.Instance.IsDemoEnabled())
		{
			SceneSingleton<GameManager>.Instance.EndGame(isPlayerWon: true);
		}
	}
}
