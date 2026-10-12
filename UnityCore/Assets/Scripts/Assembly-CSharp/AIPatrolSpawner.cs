using UnityEngine;

public class AIPatrolSpawner : SceneSingleton<AIPatrolSpawner>, ISpawner
{
	private int activePatrolShips;

	private float spawningRadius;

	private Transform targetTransform;

	private AIDataStore aIDataStore;

	private float spawningBossPercent;

	private bool isActivated;

	private bool isSpawning;

	private bool isBossActive;

	public void SetUp(bool isActivated, bool isPlayerTargeting)
	{
		this.isActivated = isActivated;
		activePatrolShips = 0;
		aIDataStore = Singleton<AIDataStore>.Instance;
		spawningRadius = aIDataStore.GetPatrolSpawningRadius();
		spawningBossPercent = aIDataStore.GetPatrolBossPercent();
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

	public void CalculateSpawningUnits()
	{
		int num = aIDataStore.PatrolUnitsNumber - activePatrolShips;
		if (isBossActive)
		{
			num = (int)((float)num * spawningBossPercent);
		}
		if (num > 0)
		{
			SpawnPatrols(num);
		}
	}

	public void SpawnPatrols(int count)
	{
		if (isActivated && isSpawning)
		{
			for (int i = 0; i < count; i++)
			{
				SpawnNewPatrol();
			}
		}
	}

	public void PatrolDestroyed()
	{
		activePatrolShips--;
		CalculateSpawningUnits();
	}

	public void SpawnNewPatrol()
	{
		activePatrolShips++;
		ObjectSystem.SetOnRandomEdgePos(Object.Instantiate(aIDataStore.GetAIPatrol()).transform, targetTransform, spawningRadius);
	}

	public Vector3 GetRandomInsidePos()
	{
		return targetTransform.position + (Vector3)(Random.insideUnitCircle * spawningRadius);
	}

	public void BossActivated()
	{
		isBossActive = true;
	}

	public void BossDectivated()
	{
		isBossActive = false;
	}
}
