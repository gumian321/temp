using System.Collections.Generic;
using UnityEngine;

public class AIWaveSpawner : SceneSingleton<AIWaveSpawner>, ISpawner
{
	private float timer;

	private AIDataStore aIDataStore;

	private Transform targetTransform;

	private float spawningRadius;

	private int activeWaveShips;

	private bool isBossOn;

	private bool isSpawning;

	private AIFaction fleetAIFaction;

	private float spawningBossPercent;

	private bool isActivated;

	private bool isBossActive;

	public void SetUp(bool isActivated, bool isPlayerTargeting)
	{
		this.isActivated = isActivated;
		activeWaveShips = 0;
		aIDataStore = Singleton<AIDataStore>.Instance;
		spawningRadius = aIDataStore.GetWaveSpawningRadius();
		spawningBossPercent = aIDataStore.GetWaveBossPercent();
		if (isPlayerTargeting)
		{
			targetTransform = SceneSingleton<PlayerManager>.Instance.GetPlayerTransform();
		}
		else
		{
			targetTransform = SceneSingleton<GameMissionManager>.Instance.GetMissionTarget();
		}
		StartTimer();
		isSpawning = false;
	}

	public void SetUpAIFaction(AIFaction fleetAIFaction)
	{
		this.fleetAIFaction = fleetAIFaction;
	}

	public void PauseSpawner()
	{
		isSpawning = false;
	}

	public void ResumeSpawner()
	{
		isSpawning = true;
	}

	public void BossActivated()
	{
		isBossActive = true;
	}

	public void BossDectivated()
	{
		isBossActive = false;
	}

	public void StartTimer()
	{
		timer = Time.time + Singleton<AIDataStore>.Instance.GetNextWaveTimer();
	}

	private void FixedUpdate()
	{
		if (isActivated && isSpawning && timer < Time.time)
		{
			SpawnNextWave();
			StartTimer();
		}
	}

	private void SpawnNextWave()
	{
		int num = Singleton<AIDataStore>.Instance.GetWaveCount();
		if (isBossActive)
		{
			num = (int)((float)num * spawningBossPercent);
		}
		if (num > 0)
		{
			List<PrefabTypes> list = new List<PrefabTypes>();
			for (int i = 0; i < num; i++)
			{
				list.Add(aIDataStore.GetAIWaveSwarm());
			}
			MasterPool.CreateNew(PrefabTypes.AIFleetManager).GetComponent<AIFleetManager>().SetUpRadius(list, targetTransform, spawningRadius, null, changeSpeedWithHeat: false, fleetAIFaction);
		}
	}
}
