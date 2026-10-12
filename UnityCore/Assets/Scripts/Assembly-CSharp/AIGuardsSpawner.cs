using System.Collections.Generic;
using UnityEngine;

public class AIGuardsSpawner : MonoBehaviour
{
	[SerializeField]
	private List<Transform> AIGuardSpawnPointsList;

	private List<Transform> currentAIGuardSpawnPointsList;

	private List<AIGuardUnitController> guardsList;

	private AIFaction aIFaction;

	private RadarSystem radarSystem;

	[Space]
	[Header("Radar Values")]
	[SerializeField]
	private DetectionType targetDetectionType = DetectionType.Player;

	[SerializeField]
	private RadarConfiguration rct;

	[SerializeField]
	private float radarRange = 10f;

	public void SpawnGuards(AIFaction aIFaction, AIThreatLevel aIThreatLevel = AIThreatLevel.None)
	{
		if (aIThreatLevel == AIThreatLevel.None)
		{
			aIThreatLevel = (AIThreatLevel)Random.Range(0, 3);
		}
		float percent = 1f;
		switch (aIThreatLevel)
		{
		case AIThreatLevel.High:
			percent = Random.Range(0.75f, 1f);
			break;
		case AIThreatLevel.Mid:
			percent = Random.Range(0.4f, 0.75f);
			break;
		case AIThreatLevel.Low:
			percent = Random.Range(0.1f, 0.4f);
			break;
		}
		SpawnGuards(aIFaction, percent);
	}

	public void SpawnGuards(AIFaction aIFaction, float percent)
	{
		this.aIFaction = aIFaction;
		if (guardsList == null)
		{
			guardsList = new List<AIGuardUnitController>();
		}
		ActivateRadar(radarRange, targetDetectionType, rct);
		radarSystem.RescaleRadar(radarRange);
		currentAIGuardSpawnPointsList = new List<Transform>(AIGuardSpawnPointsList);
		for (int i = 0; (float)i < (float)currentAIGuardSpawnPointsList.Count * percent; i++)
		{
			SpawnGuard(currentAIGuardSpawnPointsList[i]);
		}
		GetComponent<AutoRotator>().SetRandomSpeed(10f);
	}

	private void SpawnGuard(Transform aIGuardSpawnPoint)
	{
		AIGuardUnit aIGuardUnit = Singleton<AIDataStore>.Instance.GetAIGuardUnit();
		AIGuardUnitController component = MasterPool.GetPos(aIGuardUnit.prefabType, aIGuardSpawnPoint.transform).GetComponent<AIGuardUnitController>();
		component.SetGuard(this, aIGuardSpawnPoint, aIGuardUnit, aIFaction, radarSystem);
		guardsList.Add(component);
	}

	public void GuardDestroyed(AIGuardUnitController unit, Transform aIGuardSpawnPoint)
	{
		if (guardsList.Count != 0)
		{
			guardsList.Remove(unit);
			currentAIGuardSpawnPointsList.Remove(aIGuardSpawnPoint);
			if (guardsList.Count == 0 && radarSystem != null)
			{
				MasterPool.ReturnToPoolTransform(radarSystem.gameObject, PrefabTypes.ShipSystem_Radar);
				radarSystem = null;
			}
		}
	}

	public void DisableGuards()
	{
		foreach (AIGuardUnitController guards in guardsList)
		{
			guards.DisableUnit();
		}
		guardsList.Clear();
		if (radarSystem != null)
		{
			MasterPool.ReturnToPoolTransform(radarSystem.gameObject, PrefabTypes.ShipSystem_Radar);
			radarSystem = null;
		}
	}

	public void ActivateRadar(float turretRange, DetectionType radarDetectionType, RadarConfiguration rct)
	{
		if (radarSystem != null)
		{
			MasterPool.ReturnToPoolTransform(radarSystem.gameObject, PrefabTypes.ShipSystem_Radar);
			radarSystem = null;
		}
		radarSystem = MasterPool.Get(PrefabTypes.ShipSystem_Radar, base.transform).GetComponent<RadarSystem>();
		radarSystem.SetRadarSystem(turretRange, radarDetectionType, null, rct);
	}
}
