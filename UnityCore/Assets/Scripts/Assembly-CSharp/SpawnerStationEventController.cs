using UnityEngine;

public class SpawnerStationEventController : MapNodeEventController, IMapNode
{
	private GameObject StationSpawnerObject;

	private GameObject disabledPart;

	[SerializeField]
	private SpriteRenderer MapIcon;

	[Space]
	[Header("Event Classes")]
	[SerializeField]
	private AIGuardsSpawner aIGuardsSpawner;

	public override void ActivateNode()
	{
		if (disabledPart != null)
		{
			MasterPool.ReturnToPoolTransform(disabledPart, PrefabTypes.AI_Part_Disabled);
			disabledPart = null;
		}
		if (StationSpawnerObject != null)
		{
			MasterPool.ReturnToPoolTransform(StationSpawnerObject, PrefabTypes.SpawnerStation);
			StationSpawnerObject = null;
		}
		aIGuardsSpawner?.SpawnGuards(AIFaction.Red, Random.Range(0.5f, 1f));
		StationSpawnerObject = MasterPool.GetPos(PrefabTypes.SpawnerStation, base.transform);
		StationSpawnerObject.GetComponent<SpawnerStation>().SpawnStation();
		MapIcon.color = Singleton<AIDataStore>.Instance.GetFactionColor(AIFaction.Red);
	}

	public override void DeactivateNode()
	{
		if (StationSpawnerObject != null)
		{
			MasterPool.ReturnToPoolTransform(StationSpawnerObject, PrefabTypes.SpawnerStation);
			StationSpawnerObject = null;
		}
		if (disabledPart != null)
		{
			MasterPool.ReturnToPoolTransform(disabledPart, PrefabTypes.AI_Part_Disabled);
			disabledPart = null;
		}
		aIGuardsSpawner?.DisableGuards();
		base.gameObject.SetActive(value: false);
	}

	public override void DestroyEvent()
	{
		base.DestroyEvent();
		SpawnStationDisabled();
		MapIcon.color = Singleton<AIDataStore>.Instance.GetDisabledColor();
		Singleton<GameAchievementsManager>.Instance?.Add_StationsDestroyed();
		MasterPool.ReturnToPoolTransform(StationSpawnerObject, PrefabTypes.SpawnerStation);
		StationSpawnerObject = null;
	}

	private void SpawnStationDisabled()
	{
		disabledPart = MasterPool.GetPos(PrefabTypes.AI_Part_Disabled, base.transform.position, base.transform.rotation);
		disabledPart.GetComponent<SpriteRenderer>().sprite = StationSpawnerObject.GetComponent<SpriteRenderer>().sprite;
		disabledPart.GetComponent<SpriteRenderer>().sortingOrder = 5;
		disabledPart.transform.parent = base.transform;
	}
}
