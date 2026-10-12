using UnityEngine;

public class ShieldTurretController : TurretController
{
	private ShieldController shieldController;

	private GameObject turretRange;

	private bool isStunned;

	public override void DestroyTurret()
	{
		if (shieldController != null)
		{
			MasterPool.ReturnToPoolTransform(shieldController.gameObject, PrefabTypes.ShipSystem_Shield);
			if (Singleton<DetectionDataStore>.Instance.IsEnemyLayer(coreController.GetCoreTargetDetectionType()))
			{
				Singleton<GameAchievementsManager>.Instance?.Add_AchievementTypes(AchievementTypes.shieldCount, -1);
			}
		}
	}

	public override void StunTurret(bool isStunned)
	{
		if (this.isStunned != isStunned)
		{
			this.isStunned = isStunned;
			if (isStunned)
			{
				DisableTurret();
			}
			else
			{
				ActivateTurret();
			}
		}
	}

	public override void DisableTurret()
	{
		shieldController.SetTurretStunState(flag: false);
	}

	public override void ActivateTurret()
	{
		shieldController.SetTurretStunState(flag: true);
	}

	public override void SetTurret(Core core)
	{
		if (shieldController == null)
		{
			shieldController = MasterPool.GetPos(PrefabTypes.ShipSystem_Shield, base.transform, Vector2.zero).GetComponent<ShieldController>();
			shieldController.SetShield(this, (ShieldCore)core, coreController.GetCoreDetectionType());
			shieldController.enabled = true;
			if (Singleton<DetectionDataStore>.Instance.IsEnemyLayer(coreController.GetCoreTargetDetectionType()))
			{
				Singleton<GameAchievementsManager>.Instance?.Add_AchievementTypes(AchievementTypes.shieldCount);
			}
		}
	}

	public override void PreviewTurret(Core core, bool showPreview = false)
	{
		base.PreviewTurret(core, showPreview);
		ShieldCore shieldCore = (ShieldCore)core;
		if (turretRange == null)
		{
			turretRange = MasterPool.CreateNew(PrefabTypes.Range_Shield, base.transform);
		}
		if (showPreview)
		{
			TweenController.Scale(turretRange.transform, 0f, shieldCore.GetShieldRange(), TweenDuration.Short, ignoreTimeScale: true);
		}
		else
		{
			turretRange.SetActive(value: false);
		}
	}

	public override void RefreshTurret()
	{
		base.RefreshTurret();
		shieldController.RefreshShield(turretChipsContainer);
	}
}
