using System;
using System.Collections.Generic;
using UnityEngine;

public class AIStation : MonoBehaviour
{
	private Action onStationDestroy;

	private AIFaction aIFaction;

	private AIThreatLevel aIThreatLevel;

	[SerializeField]
	private List<Transform> aIStationPartSpawnPointsList;

	private List<AIStationPartController> stationPartsList;

	private List<GameObject> stationDisabledPartsList;

	private List<RewardPack> stationRewardPacksList;

	private SpriteRenderer spriteRenderer;

	private RadarSystem radarSystem;

	[Space]
	[Header("Radar Values")]
	[SerializeField]
	private DetectionType targetDetectionType = DetectionType.Player;

	[SerializeField]
	private RadarConfiguration rct;

	[SerializeField]
	private float radarRange = 10f;

	public void BuildStation(AIFaction aIFaction, Action OnDestroyAction)
	{
		onStationDestroy = OnDestroyAction.Invoke;
		this.aIFaction = aIFaction;
		SpawnParts();
		aIThreatLevel = GenerateStationThreatLevel();
		spriteRenderer = GetComponent<SpriteRenderer>();
		spriteRenderer.sprite = Singleton<AIDataStore>.Instance.GetStationCoreSprite(aIFaction);
		spriteRenderer.enabled = true;
	}

	public AIThreatLevel GetStationThreatLevel()
	{
		return aIThreatLevel;
	}

	private AIThreatLevel GenerateStationThreatLevel()
	{
		int num = 0;
		foreach (AIStationPartController stationParts in stationPartsList)
		{
			if (stationParts.GetPartThreatLevel() == AIThreatLevel.High)
			{
				num += 3;
			}
			else if (stationParts.GetPartThreatLevel() == AIThreatLevel.Mid)
			{
				num += 2;
			}
			else if (stationParts.GetPartThreatLevel() == AIThreatLevel.Low)
			{
				num++;
			}
		}
		if (num <= 4)
		{
			return AIThreatLevel.Low;
		}
		if (num <= 8)
		{
			return AIThreatLevel.Mid;
		}
		return AIThreatLevel.High;
	}

	private void SpawnParts()
	{
		stationRewardPacksList = new List<RewardPack>();
		stationPartsList = new List<AIStationPartController>();
		stationDisabledPartsList = new List<GameObject>();
		ActivateRadar(radarRange, targetDetectionType, rct);
		radarSystem.RescaleRadar(radarRange);
		foreach (Transform aIStationPartSpawnPoints in aIStationPartSpawnPointsList)
		{
			SpawnPart(aIStationPartSpawnPoints);
		}
		GetComponent<AutoRotator>().SetRandomSpeed(10f);
	}

	private void SpawnPart(Transform aIStationPartSpawnPoints)
	{
		AIStationPart aIStationPart = Singleton<AIDataStore>.Instance.GetAIStationPart();
		AIStationPartController component = MasterPool.GetPos(aIStationPart.prefabType, aIStationPartSpawnPoints.transform).GetComponent<AIStationPartController>();
		component.SetStationPart(PartDestroyed, aIStationPart, radarSystem, aIFaction);
		component.SetStationPartSprite();
		stationPartsList.Add(component);
		stationRewardPacksList.AddRange(aIStationPart.rewardPacksList);
	}

	public void DeactivateNode()
	{
		if (radarSystem != null)
		{
			MasterPool.ReturnToPoolTransform(radarSystem.gameObject, PrefabTypes.ShipSystem_Radar);
			radarSystem = null;
		}
		foreach (GameObject stationDisabledParts in stationDisabledPartsList)
		{
			MasterPool.ReturnToPoolTransform(stationDisabledParts, PrefabTypes.AI_Part_Disabled);
			stationDisabledParts.SetActive(value: false);
		}
		stationDisabledPartsList.Clear();
		foreach (AIStationPartController stationParts in stationPartsList)
		{
			stationParts.DisableUnit();
		}
		stationPartsList.Clear();
	}

	public void PartDestroyed(AIStationPartController aIStationPart, Sprite sprite)
	{
		if (stationPartsList.Count == 0)
		{
			return;
		}
		GameObject pos = MasterPool.GetPos(PrefabTypes.AI_Part_Disabled, aIStationPart.transform.position, aIStationPart.transform.rotation);
		pos.GetComponent<SpriteRenderer>().sprite = sprite;
		pos.transform.parent = base.transform;
		stationDisabledPartsList.Add(pos);
		stationPartsList.Remove(aIStationPart);
		if (stationPartsList.Count == 0)
		{
			if (radarSystem != null)
			{
				MasterPool.ReturnToPoolTransform(radarSystem.gameObject, PrefabTypes.ShipSystem_Radar);
				radarSystem = null;
			}
			SpawnStationDisabledCenter();
			GetComponent<AutoRotator>().SetRandomSpeed(0f);
			SpawnRewardPacks();
			SpawnRewardPacks();
			onStationDestroy();
		}
	}

	private void SpawnStationDisabledCenter()
	{
		GameObject pos = MasterPool.GetPos(PrefabTypes.AI_Part_Disabled, base.transform.position, base.transform.rotation);
		pos.GetComponent<SpriteRenderer>().sprite = spriteRenderer.sprite;
		pos.GetComponent<SpriteRenderer>().sortingOrder = 5;
		pos.transform.parent = base.transform;
		stationDisabledPartsList.Add(pos);
		spriteRenderer.enabled = false;
	}

	private void SpawnRewardPacks()
	{
		RarityTypes rarityTypes = RarityTypes.None;
		switch (aIThreatLevel)
		{
		case AIThreatLevel.High:
			rarityTypes = RarityTypes.Legendery;
			break;
		case AIThreatLevel.Mid:
			rarityTypes = RarityTypes.Epic;
			break;
		case AIThreatLevel.Low:
			rarityTypes = RarityTypes.Rare;
			break;
		}
		RewardPack rewardPack = Singleton<RewardDataStore>.Instance.GetRewardPack(stationRewardPacksList, rarityTypes);
		SceneSingleton<RewardSystemManager>.Instance.SpawnRewardPack(base.transform.position, rewardPack, rarityTypes);
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
