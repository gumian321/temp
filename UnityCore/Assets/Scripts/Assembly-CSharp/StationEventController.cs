using UnityEngine;

public class StationEventController : MapNodeEventController, IMapNode
{
	private AIFaction aIFaction;

	private AIThreatLevel aIThreatLevel;

	[SerializeField]
	private float explosionSize = 4f;

	private AIMapIconController aIMapIconController;

	private AIStation aIStation;

	private AIGuardsSpawner aIGuardsSpawner;

	private void SpawnStation()
	{
		aIFaction = ((Random.Range(0, 100) > 50) ? AIFaction.Red : AIFaction.Blue);
		aIStation = GetComponentInChildren<AIStation>();
		aIStation.BuildStation(aIFaction, DestroyStation);
		aIThreatLevel = aIStation.GetStationThreatLevel();
		aIGuardsSpawner = GetComponentInChildren<AIGuardsSpawner>();
		aIGuardsSpawner?.SpawnGuards(aIFaction, aIThreatLevel);
		aIMapIconController = GetComponentInChildren<AIMapIconController>();
		aIMapIconController.SetUpAIMapIconController(Singleton<AIDataStore>.Instance.GetStationThreatLevelSprite(aIThreatLevel), Singleton<AIDataStore>.Instance.GetFactionColor(aIFaction));
	}

	public override void ActivateNode()
	{
		SpawnStation();
	}

	public override void DeactivateNode()
	{
		aIGuardsSpawner?.DisableGuards();
		aIStation.DeactivateNode();
		base.gameObject.SetActive(value: false);
	}

	private void DestroyStation()
	{
		aIMapIconController.SetUpAIMapIconController(Singleton<AIDataStore>.Instance.GetStationThreatLevelSprite(aIThreatLevel), Singleton<AIDataStore>.Instance.GetDisabledColor());
		ParticlesSystem.PlayExplosionParticle(base.transform.position, explosionSize);
		Singleton<GameAchievementsManager>.Instance?.Add_StationsDestroyed();
		DestroyEvent();
	}
}
