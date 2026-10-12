using System.Collections.Generic;
using UnityEngine;

public class RepairTurretController : TurretController
{
	private RepairCore repairCore;

	private float repairAmountPerSec;

	private List<IRepairable> iRepairablesList;

	private List<Transform> partsList;

	private GameObject turretRangeObject;

	private bool isTurretActive = true;

	private AudioManager audioManager;

	private float audioDelay;

	[SerializeField]
	private List<LineRenderer> SparksParticlesList;

	private Vector3 localPos;

	private bool isParticlesOn;

	private int index;

	public override void StunTurret(bool isStunned)
	{
		isTurretActive = !isStunned;
	}

	public override void DisableTurret()
	{
		isTurretActive = false;
		StopParticles();
	}

	public override void ActivateTurret()
	{
		isTurretActive = true;
	}

	public override void PreviewTurret(Core core, bool showPreview = false)
	{
		base.PreviewTurret(core, showPreview);
		if (turretRangeObject == null)
		{
			turretRangeObject = MasterPool.CreateNew(PrefabTypes.Range_Chip, base.transform);
		}
		turretRangeObject.SetActive(showPreview);
	}

	public override void SetTurret(Core core)
	{
		localPos = coreController.transform.localPosition;
		StopParticles();
		audioManager = Singleton<AudioManager>.Instance;
		repairCore = (RepairCore)core;
		repairAmountPerSec = repairCore.GetRepairAmount();
		isTurretActive = true;
	}

	public override void RefreshTurret()
	{
		StopParticles();
		base.RefreshTurret();
		iRepairablesList = new List<IRepairable>();
		partsList = new List<Transform>();
		foreach (CoreController surroundingCoreController in coreController.GetBuilder().GetSurroundingCoreControllers(coreController))
		{
			IRepairable component = surroundingCoreController.GetComponent<IRepairable>();
			if (component != null)
			{
				iRepairablesList.Add(component);
				partsList.Add(surroundingCoreController.transform);
			}
		}
	}

	private void FixedUpdate()
	{
		if (isTurretActive)
		{
			Repair();
		}
	}

	private void Repair()
	{
		List<Transform> list = new List<Transform>();
		for (int i = 0; i < iRepairablesList.Count; i++)
		{
			if (iRepairablesList[i] != null && iRepairablesList[i].CanRepair())
			{
				iRepairablesList[i].Repair(repairAmountPerSec);
				list.Add(partsList[i]);
			}
		}
		if (audioDelay < Time.time)
		{
			audioDelay = Time.time + 0.5f;
			audioManager.PlaySFX(AudioClipTypes.Drone_Engineer);
			AnimateLasers(list);
		}
	}

	public override void DestroyTurret()
	{
	}

	private void AnimateLasers(List<Transform> toRepairList)
	{
		if (isParticlesOn)
		{
			foreach (LineRenderer sparksParticles in SparksParticlesList)
			{
				sparksParticles.gameObject.SetActive(value: false);
			}
		}
		foreach (Transform toRepair in toRepairList)
		{
			SparksParticlesList[index].gameObject.SetActive(value: true);
			SparksParticlesList[index].SetPosition(1, GetEndSparkPoint(toRepair.localPosition));
			index++;
			if (index >= SparksParticlesList.Count)
			{
				index = 0;
			}
			isParticlesOn = true;
		}
	}

	private Vector3 GetEndSparkPoint(Vector3 centerEndPoint)
	{
		return new Vector3(centerEndPoint.x - localPos.x + Random.Range(-0.25f, 0.25f), centerEndPoint.y - localPos.y + Random.Range(-0.25f, 0.25f));
	}

	private void StopParticles()
	{
		if (!isParticlesOn)
		{
			return;
		}
		foreach (LineRenderer sparksParticles in SparksParticlesList)
		{
			sparksParticles.gameObject.SetActive(value: false);
		}
		isParticlesOn = false;
	}
}
