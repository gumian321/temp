using UnityEngine;

[RequireComponent(typeof(AIMapIconController))]
public class AIGuardUnitController : AIUnitController
{
	[Space]
	[Header("Guard Data")]
	private AIGuardsSpawner aIGuardsSpawner;

	private AIGuardUnit aIGuardUnit;

	private Transform spawnPoint;

	public void SetGuard(AIGuardsSpawner aIGuardsSpawner, Transform spawnPoint, AIGuardUnit aIGuardUnit, AIFaction aIFaction, RadarSystem radarSystem)
	{
		BuildUnit();
		this.aIGuardUnit = aIGuardUnit;
		this.spawnPoint = spawnPoint;
		SetCores();
		OverrideRadar(radarSystem);
		base.aIFaction = aIFaction;
		aIThreatLevel = aIGuardUnit.aIThreatLevel;
		SetGuardSprite();
		this.aIGuardsSpawner = aIGuardsSpawner;
		UpdateRange(0.25f);
	}

	private void SetGuardSprite()
	{
		GetComponent<SpriteRenderer>().sprite = Singleton<AIDataStore>.Instance.GetGuardLevelSprite(aIFaction, aIThreatLevel);
		GetComponent<AIMapIconController>().SetUpAIMapIconController(Singleton<AIDataStore>.Instance.GetGuardThreatLevelSprite(aIThreatLevel), Singleton<AIDataStore>.Instance.GetFactionColor(aIFaction));
	}

	private void SetCores()
	{
		if (aIGuardUnit.coresList.Count != aICoreControllersList.Count)
		{
			Debug.LogError("AI Spawn Point Cores Count does not match the Guard Level");
		}
		for (int i = 0; i < aIGuardUnit.coresList.Count; i++)
		{
			aICoreControllersList[i].BuildCore(aIGuardUnit.coresList[i]);
		}
	}

	public override void DestroyUnit()
	{
		aIGuardsSpawner.GuardDestroyed(this, spawnPoint);
		base.DestroyUnit();
		DisableUnit();
	}

	public void DisableUnit()
	{
		ClearRadar();
		MasterPool.ReturnToPoolTransform(base.gameObject, aIGuardUnit.prefabType);
	}
}
