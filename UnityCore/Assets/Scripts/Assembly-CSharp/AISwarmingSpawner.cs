using System.Collections.Generic;
using UnityEngine;

public class AISwarmingSpawner : SceneSingleton<AISwarmingSpawner>, ISpawner
{
	private GameMissionManager gameMissionManager;

	private int activeSwarmingShips;

	private float spawningRadius;

	private Transform targetTransform;

	private AIDataStore aIDataStore;

	private float swarmingSpawningDelay;

	private float spawningBossPercent;

	private AIFaction swarmAIFaction;

	private bool isActivated;

	private bool isSpawning;

	private bool isBossActive;

	private List<Transform> spawningPointsList = new List<Transform>();

	public void SetUpAIFaction(AIFaction swarmAIFaction)
	{
		this.swarmAIFaction = swarmAIFaction;
	}

	public void SetUp(bool isActivated, bool isPlayerTargeting)
	{
		gameMissionManager = SceneSingleton<GameMissionManager>.Instance;
		this.isActivated = isActivated;
		activeSwarmingShips = 0;
		aIDataStore = Singleton<AIDataStore>.Instance;
		swarmingSpawningDelay = aIDataStore.GetSwarmingSpawningDelay();
		spawningBossPercent = aIDataStore.GetSwarmingBossPercent();
		spawningRadius = aIDataStore.GetSwarmSpawningRadius();
		if (isPlayerTargeting)
		{
			targetTransform = SceneSingleton<PlayerManager>.Instance.GetPlayerTransform();
		}
		else
		{
			targetTransform = SceneSingleton<GameMissionManager>.Instance.GetMissionTarget();
		}
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

	public void CalculateSpawningUnits()
	{
		int num = aIDataStore.SwarmingUnitsNumber;
		if (isBossActive)
		{
			num = (int)((float)num * spawningBossPercent);
		}
		int num2 = num - activeSwarmingShips;
		if (num2 > 0)
		{
			SpawnUnits(num2);
		}
	}

	public void SpawnUnits(int count)
	{
		if (isActivated && isSpawning)
		{
			for (int i = 0; i < count; i++)
			{
				activeSwarmingShips++;
				Invoke("SpawnNewUnit", swarmingSpawningDelay);
			}
		}
	}

	public void SpawnNewUnit()
	{
		GameObject gameObject = MasterPool.Get(aIDataStore.GetAISwarming());
		AIUnitController component = gameObject.GetComponent<AIUnitController>();
		if (spawningPointsList.Count == 0)
		{
			ObjectSystem.SetOnRandomEdgePos(gameObject.transform, targetTransform, spawningRadius);
		}
		else
		{
			gameObject.transform.position = spawningPointsList[Random.Range(0, spawningPointsList.Count)].position;
		}
		component.SetAIFaction(swarmAIFaction);
		component.BuildUnit();
		if (!(component is AIFollowingUnit))
		{
			ObjectSystem.RotateAt(gameObject.transform, targetTransform);
		}
		component.GetComponent<AISpawner>()?.SetTarget(targetTransform);
		component.SetOnDestroyAction(SwarmingShipDestroyed);
		if (!gameMissionManager.IsMissionEndless())
		{
			return;
		}
		float missionEndlessSpeedHeat = gameMissionManager.GetMissionEndlessSpeedHeat();
		if (!(missionEndlessSpeedHeat <= 0f))
		{
			AIUnitMovement component2 = gameObject.GetComponent<AIUnitMovement>();
			if (component2 != null)
			{
				component2.AddEnginePowerPercent(missionEndlessSpeedHeat);
			}
		}
	}

	private void SwarmingShipDestroyed()
	{
		activeSwarmingShips--;
		CalculateSpawningUnits();
	}

	public void SetSpawningPoints(List<Transform> spawningPoints)
	{
		spawningPointsList = new List<Transform>(spawningPoints);
	}
}
