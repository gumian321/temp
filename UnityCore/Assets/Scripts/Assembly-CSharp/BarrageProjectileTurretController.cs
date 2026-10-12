using UnityEngine;

public class BarrageProjectileTurretController : ProjectileTurretController
{
	private float barrageInterval = 0.1f;

	private int barrageProjectileCount = 10;

	private int projectilesFired;

	private bool barrageActive;

	private float timerInterval;

	public override void SetTurret(Core core)
	{
		base.SetTurret(core);
		BarrageProjectileCore barrageProjectileCore = (BarrageProjectileCore)core;
		barrageInterval = barrageProjectileCore.barrageInterval;
		barrageProjectileCount = barrageProjectileCore.barrageProjectileCount;
		projectilesFired = 0;
		if (barrageInterval == 0f)
		{
			isPlayProjectileSound = false;
		}
	}

	public override void ShootTurret(bool isFiring)
	{
		if (barrageActive)
		{
			if (barrageInterval == 0f)
			{
				FireAllProjectiles();
			}
			else if (TimeToShootProjectile())
			{
				FireProjectile();
			}
		}
		else if (isFiring && TimeToShoot())
		{
			FireBarrage();
		}
	}

	public void FireBarrage()
	{
		turretBarrelsController.ResetBarrels();
		projectilesFired = 0;
		barrageActive = true;
	}

	public void EndBarrage()
	{
		barrageActive = false;
		timer = Time.time + turretRateOfFire;
	}

	public override GameObject FireProjectile()
	{
		if (projectilesFired >= barrageProjectileCount)
		{
			EndBarrage();
			return null;
		}
		base.FireProjectile();
		projectilesFired++;
		return null;
	}

	public void FireAllProjectiles()
	{
		while (projectilesFired < barrageProjectileCount)
		{
			audioManager.PlaySFX(fireAudioClipType, turretTransform.position);
			base.FireProjectile();
			projectilesFired++;
		}
		EndBarrage();
	}

	private bool TimeToShootProjectile()
	{
		if (timerInterval < Time.time)
		{
			timerInterval = Time.time + barrageInterval;
			return true;
		}
		return false;
	}
}
