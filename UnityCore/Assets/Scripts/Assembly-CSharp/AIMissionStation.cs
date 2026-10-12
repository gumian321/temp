using System;
using System.Collections.Generic;
using UnityEngine;

public class AIMissionStation : MonoBehaviour
{
	private Action onStationDestroy;

	private AIFaction aIFaction;

	[SerializeField]
	private float stationRange = 3.25f;

	[SerializeField]
	private List<AIStationPart> aIStationPartsList;

	private List<AIStationPartController> stationPartsList;

	private List<GameObject> stationDisabledPartsList;

	private SpriteRenderer spriteRenderer;

	private int currentAngle;

	private StationMissionManager stationMissionManager;

	private Dictionary<RadarSystem, List<AIStationPartController>> radarSystemsCovrageDict;

	private RadarSystem radarSystem;

	[Space]
	[Header("Radar Values")]
	private DetectionType targetDetectionType = DetectionType.Player;

	[SerializeField]
	private RadarConfiguration rct;

	[SerializeField]
	private float radarRange = 10f;

	[SerializeField]
	private int stationPartsPerRadar = 10;

	private bool centerRadarPos;

	public void BuildStation(Action OnDestroyAction, AIFaction aIFaction, StationMissionManager stationMissionManager)
	{
		this.stationMissionManager = stationMissionManager;
		onStationDestroy = OnDestroyAction.Invoke;
		spriteRenderer = GetComponent<SpriteRenderer>();
		this.aIFaction = aIFaction;
		targetDetectionType = Singleton<DetectionDataStore>.Instance.GetTargetDetectionType(base.gameObject);
		SpawnParts();
		GetComponent<AutoRotator>().SetIsRotating(IsRotating: true);
	}

	private void SpawnParts()
	{
		radarSystemsCovrageDict = new Dictionary<RadarSystem, List<AIStationPartController>>();
		stationPartsList = new List<AIStationPartController>();
		stationDisabledPartsList = new List<GameObject>();
		currentAngle = 0;
		int num = 0;
		CreateNewRadar();
		foreach (AIStationPart aIStationParts in aIStationPartsList)
		{
			GameObject gameObject = SpawnPart(aIStationParts);
			currentAngle += 360 / aIStationPartsList.Count;
			num++;
			if (num >= stationPartsPerRadar)
			{
				num = 0;
				CreateNewRadar();
			}
			if (num >= stationPartsPerRadar / 2 && !centerRadarPos)
			{
				radarSystem.transform.position = gameObject.transform.position;
				centerRadarPos = true;
			}
		}
	}

	private GameObject SpawnPart(AIStationPart aIStationPart)
	{
		GameObject pos = MasterPool.GetPos(aIStationPart.prefabType, base.transform);
		AIStationPartController componentInChildren = pos.GetComponentInChildren<AIStationPartController>();
		componentInChildren.GetComponent<SpriteRenderer>().sprite = stationMissionManager.GetStationPartSprite(aIStationPart.aIThreatLevel);
		componentInChildren.gameObject.layer = base.gameObject.layer;
		componentInChildren.transform.position = new Vector2(0f, stationRange);
		pos.transform.eulerAngles = new Vector3(0f, 0f, currentAngle);
		pos.transform.localScale = Vector3.one;
		componentInChildren.SetStationPart(PartDestroyed, aIStationPart, radarSystem, aIFaction);
		componentInChildren.SetMaxHealth(stationMissionManager.GetPartHealth(aIStationPart.aIThreatLevel));
		stationPartsList.Add(componentInChildren);
		radarSystemsCovrageDict[radarSystem].Add(componentInChildren);
		return componentInChildren.gameObject;
	}

	public void PartDestroyed(AIStationPartController aIStationPart, Sprite sprite)
	{
		if (stationPartsList.Count != 0)
		{
			GameObject pos = MasterPool.GetPos(PrefabTypes.AI_Part_Disabled, aIStationPart.transform.position, aIStationPart.transform.rotation);
			pos.GetComponent<SpriteRenderer>().sprite = sprite;
			pos.transform.parent = base.transform;
			stationDisabledPartsList.Add(pos);
			stationPartsList.Remove(aIStationPart);
			radarSystemsCovrageDict[aIStationPart.GetUnitRadarSystem()].Remove(aIStationPart);
			if (radarSystemsCovrageDict[aIStationPart.GetUnitRadarSystem()].Count == 0)
			{
				MasterPool.ReturnToPoolTransform(aIStationPart.GetUnitRadarSystem().gameObject, PrefabTypes.ShipSystem_Radar);
			}
			if (stationPartsList.Count == 0)
			{
				SpawnStationDisabledCenter();
				GetComponent<AutoRotator>().SetIsRotating(IsRotating: false);
				onStationDestroy();
			}
		}
	}

	private void SpawnStationDisabledCenter()
	{
		GameObject pos = MasterPool.GetPos(PrefabTypes.AI_Part_Disabled, base.transform.position, base.transform.rotation);
		pos.GetComponent<SpriteRenderer>().sprite = spriteRenderer.sprite;
		pos.GetComponent<SpriteRenderer>().sortingOrder = -1;
		pos.transform.parent = base.transform;
		pos.transform.localScale = spriteRenderer.transform.localScale;
		stationDisabledPartsList.Add(pos);
		spriteRenderer.enabled = false;
	}

	public int GetSurvivedPartsCount()
	{
		return stationPartsList.Count;
	}

	public void CreateNewRadar()
	{
		centerRadarPos = false;
		radarSystem = MasterPool.Get(PrefabTypes.ShipSystem_Radar, base.transform).GetComponent<RadarSystem>();
		radarSystem.SetRadarSystem(radarRange, targetDetectionType, null, rct);
		radarSystemsCovrageDict.Add(radarSystem, new List<AIStationPartController>());
	}
}
