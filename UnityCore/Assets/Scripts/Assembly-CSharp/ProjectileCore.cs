using UnityEngine;

[CreateAssetMenu(fileName = "New Projectile Core", menuName = "ScriptableObjects/New Core/Projectile Core")]
public class ProjectileCore : TurretCore
{
	public RadarConfiguration radarConfiguration;

	[Space]
	[Header("Turret Variables")]
	public RangeType turretRange;

	public float turretRateOfFire;

	public float turretRotateSpeed;

	public float turretErrorAngle = 1.5f;

	[Space]
	[Header("Projectile")]
	public Projectile coreProjectile;

	public float GetTurretRateOfFire(float percent = 0f)
	{
		return UnityEngineSystem.GetPerSecAmount(turretRateOfFire, percent);
	}

	public float GetTurretRange(float percent = 0f)
	{
		return UnityEngineSystem.CalcPercent(TurretsDataStore.GetTurretRange(turretRange), percent);
	}

	public override bool CanBeHighlighted(ChipTypes ChipType)
	{
		if (!isChipable)
		{
			return false;
		}
		if (coreProjectile.activatableChips.IsChipActivated(ChipType))
		{
			return true;
		}
		return false;
	}
}
