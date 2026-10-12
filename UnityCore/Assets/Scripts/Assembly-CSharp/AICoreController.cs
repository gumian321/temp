using UnityEngine;

public class AICoreController : CoreController
{
	[SerializeField]
	public Core core;

	[SerializeField]
	private bool GetCoreFromDataStore;

	public void BuildCore()
	{
		if (GetCoreFromDataStore)
		{
			BuildCore(Singleton<AIDataStore>.Instance.GetAICore());
		}
		else if (!(core == null))
		{
			BuildCore(core);
		}
	}

	public void BuildCore(Core core)
	{
		GameObject gameObject = GetCoreObject();
		if (gameObject != null)
		{
			currentCore.DestroyCore(this);
			Object.Destroy(gameObject);
		}
		if (core != null)
		{
			currentCore = core;
		}
		else
		{
			currentCore = Singleton<AIDataStore>.Instance.GetAICore();
		}
		currentCore.SpawnCoreObject(this);
		currentCore.BuildCore(this);
		EndStun();
		if (disableCoreSprite)
		{
			currentCore.DisableCoreArt(this);
		}
		OverrideDamage(SceneSingleton<GameMissionManager>.Instance.enemiesDamageModifier);
	}

	public void UnitDestroyed()
	{
		GameObject gameObject = GetCoreObject();
		currentCore.DestroyCore(this);
		EndStun();
		if (gameObject != null)
		{
			Object.Destroy(gameObject);
		}
	}

	public void UpdateRange(float percent)
	{
		if (coreObject.GetComponent<ProjectileTurretController>() != null)
		{
			coreObject.GetComponent<ProjectileTurretController>().UpdateRange(percent);
		}
		else if (coreObject.GetComponent<DroneTurretController>() != null)
		{
			coreObject.GetComponent<DroneTurretController>().UpdateDronesRange(percent * 1.5f);
		}
	}

	public void OverrideDamage(float percent)
	{
		if (coreObject.GetComponent<ProjectileTurretController>() != null)
		{
			coreObject.GetComponent<ProjectileTurretController>().OverrideDamageModifer(percent);
		}
	}

	public float GetCoreRadarRange()
	{
		if (currentCore is ProjectileCore)
		{
			return ((ProjectileCore)currentCore).GetTurretRange();
		}
		return -1f;
	}

	public void OverrideCoreRadar(RadarSystem radarSystem)
	{
		if (coreObject != null && coreObject.GetComponent<ProjectileTurretController>() != null)
		{
			coreObject.GetComponent<ProjectileTurretController>().OverrideTurretRadar(radarSystem);
		}
	}
}
