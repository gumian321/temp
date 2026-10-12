using System;
using System.Collections.Generic;
using UnityEngine;

[Serializable]
public class EndlessBossesFleet
{
	public List<EndlessBossFleet> BossFleetWaves;

	[HideInInspector]
	public int stepIndex;

	[SerializeField]
	private PrefabTypes PrefabToAddAfterMaxWaves;

	public void SpawnFleet()
	{
		Transform targetTransform = SceneSingleton<AIBossSpawner>.Instance.SpawnBossWave(BossFleetWaves[stepIndex].BossFleetWaves, Singleton<AIDataStore>.Instance.GetBossSpawningRadius());
		SceneSingleton<PlayerArrowsManager>.Instance.SpawnArrow(targetTransform, Singleton<AIDataStore>.Instance.bossSprite, Singleton<AIDataStore>.Instance.GetFactionColor(AIFaction.Red));
		stepIndex++;
		if (stepIndex >= BossFleetWaves.Count)
		{
			stepIndex--;
			BossFleetWaves[stepIndex].BossFleetWaves.Add(PrefabToAddAfterMaxWaves);
		}
	}
}
