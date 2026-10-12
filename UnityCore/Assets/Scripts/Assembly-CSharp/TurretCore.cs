using UnityEngine;

[CreateAssetMenu(fileName = "New Turret Core", menuName = "ScriptableObjects/New Core/Turret Core")]
public class TurretCore : Core
{
	[Space]
	public Turret coreTurret;

	public override void SpawnCoreObject(CoreController coreController)
	{
		if (!(coreTurret == null))
		{
			coreController.SetCoreObject(Object.Instantiate(coreTurret.turretObject, coreController.transform));
		}
	}

	public override void PreviewCore(CoreController coreController, bool showPreview = false)
	{
		if (coreController.GetCoreObject() != null)
		{
			coreController.GetCoreObject().GetComponent<TurretController>()?.PreviewTurret(this, showPreview);
		}
	}

	public override void BuildCore(CoreController coreController)
	{
		if (coreController.GetCoreObject() != null)
		{
			coreController.GetCoreObject().GetComponent<TurretController>()?.BuildTurret(coreController, this);
		}
	}

	public override void DisableCoreArt(CoreController coreController)
	{
		if (coreController.GetCoreObject() != null)
		{
			coreController.GetCoreObject().GetComponent<TurretController>()?.DisableTurretArt();
		}
	}

	public override void DestroyCore(CoreController coreController)
	{
		base.DestroyCore(coreController);
		if (coreController.GetCoreObject() != null)
		{
			coreController.GetCoreObject().GetComponent<TurretController>()?.DestroyTurret();
		}
	}

	public override void DisableCore(CoreController coreController)
	{
		if (coreController.GetCoreObject() != null)
		{
			coreController.GetCoreObject().GetComponent<TurretController>()?.DisableTurret();
		}
	}

	public override void StunCore(CoreController coreController, bool isStunned)
	{
		if (coreController.GetCoreObject() != null)
		{
			coreController.GetCoreObject().GetComponent<TurretController>()?.StunTurret(isStunned);
		}
	}

	public override void ActivateCore(CoreController coreController)
	{
		if (coreController.GetCoreObject() != null)
		{
			coreController.GetCoreObject().GetComponent<TurretController>()?.ActivateTurret();
		}
	}

	public override void RefreshCore(CoreController coreController)
	{
		if (coreController.GetCoreObject() != null)
		{
			coreController.GetCoreObject().GetComponent<TurretController>()?.RefreshTurret();
		}
	}

	public override Sprite GetCoreSprite()
	{
		return coreTurret.turretSprite;
	}
}
