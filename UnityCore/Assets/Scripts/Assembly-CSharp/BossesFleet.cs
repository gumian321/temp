using System;
using System.Collections.Generic;
using UnityEngine;

[Serializable]
public class BossesFleet
{
	public float fleetPercent;

	public List<PrefabTypes> fleetTypes;

	[HideInInspector]
	public bool isSpawned;

	public bool CanSpawnFleet(float percent)
	{
		if (percent > fleetPercent)
		{
			return !isSpawned;
		}
		return false;
	}

	public void SpawnFleet(Action OnDestroyAction = null)
	{
		isSpawned = true;
		Transform targetTransform = SceneSingleton<AIBossSpawner>.Instance.SpawnBossWave(fleetTypes, Singleton<AIDataStore>.Instance.GetBossSpawningRadius(), OnDestroyAction);
		SceneSingleton<PlayerArrowsManager>.Instance.SpawnArrow(targetTransform, Singleton<AIDataStore>.Instance.bossSprite, Singleton<AIDataStore>.Instance.GetFactionColor(AIFaction.Red));
	}

	public void SpawnFleetPoint(Transform target, Action OnDestroyAction = null)
	{
		isSpawned = true;
		Transform targetTransform = SceneSingleton<AIBossSpawner>.Instance.SpawnBossWave(fleetTypes, Singleton<AIDataStore>.Instance.GetBossSpawningRadius(), OnDestroyAction, changeSpeedWithHeat: false, isRadius: false, target);
		SceneSingleton<PlayerArrowsManager>.Instance.SpawnArrow(targetTransform, Singleton<AIDataStore>.Instance.bossSprite, Singleton<AIDataStore>.Instance.GetFactionColor(AIFaction.Red));
	}
}
