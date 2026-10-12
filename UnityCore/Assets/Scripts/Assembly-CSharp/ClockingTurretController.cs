using System.Collections.Generic;
using UnityEngine;

public class ClockingTurretController : TurretController
{
	private RepairCore repairCore;

	private float repairAmountPerSec;

	private List<CoreController> clockedCoresList;

	private bool isTurretActive = true;

	private GameObject turretRangeObject;

	public override void StunTurret(bool isStunned)
	{
		isTurretActive = !isStunned;
		if (isStunned)
		{
			UnClockCores();
		}
		else
		{
			ClockCores();
		}
		SceneSingleton<PlayerCoresManager>.Instance.RefreshCores(coreController.GetCurrentCore());
	}

	public override void DisableTurret()
	{
		isTurretActive = false;
		UnClockCores();
	}

	public override void ActivateTurret()
	{
		isTurretActive = true;
		ClockCores();
	}

	public override void SetTurret(Core core)
	{
		if (clockedCoresList != null)
		{
			UnClockCores();
		}
		isTurretActive = true;
		clockedCoresList = new List<CoreController>();
		RefreshClockedCores();
	}

	public override void PreviewTurret(Core core, bool showPreview = false)
	{
		base.PreviewTurret(core, showPreview);
		if (turretRangeObject == null)
		{
			turretRangeObject = MasterPool.CreateNew(PrefabTypes.Range_Clock, base.transform.parent);
		}
		turretRangeObject.SetActive(showPreview);
	}

	public override void RefreshTurret()
	{
		base.RefreshTurret();
		RefreshClockedCores();
	}

	private void RefreshClockedCores()
	{
		UnClockCores();
		clockedCoresList = coreController.GetBuilder().GetSurroundingCoreControllers(coreController);
		ClockCores();
	}

	public void ClockCores()
	{
		if (!isTurretActive)
		{
			return;
		}
		foreach (CoreController clockedCores in clockedCoresList)
		{
			if (!(clockedCores == null))
			{
				clockedCores.ClockCore();
			}
		}
	}

	public void UnClockCores()
	{
		foreach (CoreController clockedCores in clockedCoresList)
		{
			if (!(clockedCores == null))
			{
				clockedCores.UnClockCore();
			}
		}
	}

	public override void DestroyTurret()
	{
		UnClockCores();
		SceneSingleton<PlayerCoresManager>.Instance.RefreshCores(coreController.GetCurrentCore());
	}
}
