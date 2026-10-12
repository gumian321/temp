using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class EndlessModeManager : MonoBehaviour, IMissionModeManager
{
	private Transform targetTransform;

	[Space]
	[Header("Mode Bonus Rating")]
	[SerializeField]
	private int MissionRating = 25000;

	[SerializeField]
	private float BonusRatingPerSecSurvived = 20f;

	private int currentRound = 1;

	[Space]
	[Header("Mode Logic")]
	[Space]
	[Header("Bosses Fleets")]
	[SerializeField]
	private List<float> bossesSpawnPercent;

	private List<bool> isBossesSpawnedList;

	[SerializeField]
	private EndlessBossesFleet endlessBossFleet;

	[Space]
	[Header("Endless Fleets Variables")]
	[SerializeField]
	private int SecToAddOneSwarm = 60;

	[SerializeField]
	private int SecToAddOneWave = 60;

	[SerializeField]
	private int SecToAddOnePatrol = 180;

	private WaitForSeconds delay = new WaitForSeconds(1f);

	public void SetUpMode()
	{
		targetTransform = SceneSingleton<PlayerManager>.Instance.GetPlayerTransform();
		currentRound = 1;
		SceneSingleton<GameHeatManager>.Instance.OnHeatTimerChange += SpawnBossesFleets;
		SceneSingleton<GameHeatManager>.Instance.OnHeatTimerChange += GameRoundCompleted;
		SceneSingleton<BossTimerUIController>.Instance.SetBossTimer(bossesSpawnPercent[0]);
		isBossesSpawnedList = new List<bool>();
		foreach (float item in bossesSpawnPercent)
		{
			_ = item;
			isBossesSpawnedList.Add(item: false);
		}
	}

	public void StartMode()
	{
		StartCoroutine(EndlessCounter());
	}

	public void EndMode(bool isPlayerWon)
	{
		StopAllCoroutines();
		if (SceneSingleton<GameMissionManager>.Instance.IsMissionHard())
		{
			Singleton<GameAchievementsManager>.Instance?.EndlessMissionCompleted(SceneSingleton<GameHeatManager>.Instance.GetSecondsSurvived());
		}
		SceneSingleton<GameHeatManager>.Instance.OnHeatTimerChange -= SpawnBossesFleets;
		SceneSingleton<GameHeatManager>.Instance.OnHeatTimerChange -= GameRoundCompleted;
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
		float secondsSurvived = SceneSingleton<GameHeatManager>.Instance.GetSecondsSurvived();
		SceneSingleton<RatingSystemManager>.Instance.AddRating(RatingTypes.TimeSurvived, (int)(BonusRatingPerSecSurvived * secondsSurvived));
		return -1;
	}

	private void SpawnBossesFleets(float percent)
	{
		for (int i = 0; i < bossesSpawnPercent.Count; i++)
		{
			if (percent > bossesSpawnPercent[i] && !isBossesSpawnedList[i])
			{
				isBossesSpawnedList[i] = true;
				endlessBossFleet.SpawnFleet();
				if (i + 1 < bossesSpawnPercent.Count)
				{
					SceneSingleton<BossTimerUIController>.Instance.SetBossTimer(bossesSpawnPercent[i + 1]);
				}
			}
		}
	}

	private void GameRoundCompleted(float percent)
	{
		if (percent >= (float)currentRound)
		{
			for (int i = 0; i < bossesSpawnPercent.Count; i++)
			{
				bossesSpawnPercent[i]++;
			}
			for (int j = 0; j < isBossesSpawnedList.Count; j++)
			{
				isBossesSpawnedList[j] = false;
			}
			SceneSingleton<BackgroundColorChanger>.Instance.ResetBackgroundColor();
			currentRound++;
			SceneSingleton<BossTimerUIController>.Instance.SetBossTimer(bossesSpawnPercent[0]);
		}
	}

	private void AddOneSwarm()
	{
		Singleton<AIDataStore>.Instance.AddedSwarmUnitNumber++;
	}

	private void AddOneWave()
	{
		Singleton<AIDataStore>.Instance.AddedWaveUnitNumber++;
	}

	private void AddOnePatrol()
	{
		Singleton<AIDataStore>.Instance.AddedPatrolNumber++;
	}

	private IEnumerator EndlessCounter()
	{
		int seconds = 0;
		while (true)
		{
			yield return delay;
			seconds++;
			if (seconds % SecToAddOneSwarm == 0)
			{
				AddOneSwarm();
			}
			if (seconds % SecToAddOneWave == 0)
			{
				AddOneWave();
			}
			if (seconds % SecToAddOnePatrol == 0)
			{
				AddOnePatrol();
			}
		}
	}
}
