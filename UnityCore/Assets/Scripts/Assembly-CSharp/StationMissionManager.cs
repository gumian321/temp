using System;
using System.Collections.Generic;
using UnityEngine;

public class StationMissionManager : MonoBehaviour
{
	[SerializeField]
	private LayerMask stationLayer;

	[SerializeField]
	private List<Sprite> stationsPartSpritesList;

	[SerializeField]
	private float explosionSize = 5f;

	[SerializeField]
	private List<AIMissionStation> aIStationsList;

	[Space]
	[SerializeField]
	private List<StationPartsHealth> stationPartsHealthsList;

	private int stationsCount;

	private float currentAngle;

	private Action OnStationDestroy;

	[Space]
	[Header("Spawners")]
	[SerializeField]
	private bool ActivateSpawners;

	[SerializeField]
	private List<SpawnerRims> SpawnerRimsList;

	private List<Transform> SpawnerTransformsList;

	private int totalPartsCount;

	public float GetPartHealth(AIThreatLevel aIThreatLevel)
	{
		foreach (StationPartsHealth stationPartsHealths in stationPartsHealthsList)
		{
			if (stationPartsHealths.aIThreatLevel == aIThreatLevel)
			{
				return stationPartsHealths.partHealth;
			}
		}
		Debug.LogError(aIThreatLevel.ToString() + " station part is not in the stationPartsHealthsList");
		return 1f;
	}

	public void SpawnStation(Action OnStationDestroy, AIFaction aIFaction)
	{
		this.OnStationDestroy = OnStationDestroy;
		stationsCount = aIStationsList.Count;
		foreach (AIMissionStation aIStations in aIStationsList)
		{
			aIStations.gameObject.layer = Singleton<DetectionDataStore>.Instance.GetLayerNumber(stationLayer);
			aIStations.BuildStation(DestroyStation, aIFaction, this);
		}
		if (ActivateSpawners)
		{
			SpawnSpawners();
		}
		totalPartsCount = GetSurvivedPartsCount();
	}

	private void SpawnSpawners()
	{
		foreach (SpawnerRims spawnerRims in SpawnerRimsList)
		{
			currentAngle = 0f;
			for (int i = 0; i < spawnerRims.spawnerCount; i++)
			{
				SpawnSpawner(spawnerRims);
				currentAngle += 360 / spawnerRims.spawnerCount;
			}
			spawnerRims.rimObject.GetComponent<AutoRotator>().SetIsRotating(IsRotating: true);
		}
		RefreshSpawningPointsList();
	}

	public Sprite GetStationPartSprite(AIThreatLevel aIThreatLevel)
	{
		return stationsPartSpritesList[(int)aIThreatLevel];
	}

	private void SpawnSpawner(SpawnerRims spawnerRims)
	{
		GameObject pos = MasterPool.GetPos(PrefabTypes.AI_Station_Spawner, spawnerRims.rimObject.transform);
		pos.transform.GetChild(0).transform.position = new Vector2(0f, spawnerRims.spawnersYPos);
		pos.transform.GetChild(0).transform.localScale = Vector3.one * 0.75f;
		pos.transform.eulerAngles = new Vector3(0f, 0f, currentAngle);
		pos.transform.localScale = Vector3.one;
		pos.GetComponentInChildren<AIUnitController>().BuildUnit();
		pos.GetComponentInChildren<AIUnitController>().SetOnDestroyAction(RefreshSpawningPointsList);
	}

	private void RefreshSpawningPointsList()
	{
		if (!ActivateSpawners)
		{
			return;
		}
		SpawnerTransformsList = new List<Transform>();
		foreach (SpawnerRims spawnerRims in SpawnerRimsList)
		{
			AIUnitController[] componentsInChildren = spawnerRims.rimObject.GetComponentsInChildren<AIUnitController>();
			foreach (AIUnitController aIUnitController in componentsInChildren)
			{
				if (aIUnitController.gameObject.activeSelf)
				{
					SpawnerTransformsList.Add(aIUnitController.transform);
				}
			}
		}
		SceneSingleton<AISwarmingSpawner>.Instance.SetSpawningPoints(SpawnerTransformsList);
		if (SpawnerTransformsList.Count == 0)
		{
			SceneSingleton<AISwarmingSpawner>.Instance.PauseSpawner();
		}
	}

	private void DestroyStation()
	{
		stationsCount--;
		if (stationsCount == 0)
		{
			ParticlesSystem.PlayExplosionParticle(base.transform.position, explosionSize);
			OnStationDestroy();
		}
	}

	public int GetSurvivedPartsCount()
	{
		int num = 0;
		foreach (AIMissionStation aIStations in aIStationsList)
		{
			num += aIStations.GetSurvivedPartsCount();
		}
		return num;
	}

	public float GetSurvivedPartsPercent()
	{
		return (float)GetSurvivedPartsCount() / (float)totalPartsCount;
	}
}
