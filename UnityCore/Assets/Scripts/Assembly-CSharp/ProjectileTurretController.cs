using UnityEngine;

public abstract class ProjectileTurretController : TurretController
{
	protected ProjectileCore turretCore;

	protected Projectile turretProjectile;

	protected DetectionType turretTargetDetectionType;

	protected AudioClipTypes fireAudioClipType;

	protected Vector2 targetPosition;

	protected float turretRateOfFire;

	protected float turretRange;

	protected float turretErrorAngle = 2f;

	protected float turretRotateSpeed;

	protected float damageModifier = 1f;

	private bool isFiring = true;

	private GameObject turretRangeObject;

	protected AudioManager audioManager;

	private bool isTurretActive;

	protected bool isPlayProjectileSound = true;

	protected float timer;

	private RadarSystem radarSystem;

	private bool IsRadarOverriden;

	private bool isRecoiling;

	private float RecoilMaxDistance = TurretsDataStore.GetTurretRecoilRange();

	private Vector3 startPos;

	private float recoilDuration;

	private float recallDuration;

	public override void DestroyTurret()
	{
		if (turretChipsContainer != null && turretChipsContainer.IsChipActivated(ChipTypes.HQControl))
		{
			SceneSingleton<PlayerTurretManager>.Instance.RemoveTurret(this);
		}
		if (radarSystem != null && !IsRadarOverriden)
		{
			MasterPool.ReturnToPoolTransform(radarSystem.gameObject, PrefabTypes.ShipSystem_Radar);
			radarSystem = null;
		}
	}

	public override void StunTurret(bool isStunned)
	{
		isTurretActive = !isStunned;
	}

	public override void DisableTurret()
	{
		isTurretActive = false;
	}

	public override void ActivateTurret()
	{
		isTurretActive = true;
	}

	public override void SetTurret(Core core)
	{
		IsRadarOverriden = false;
		audioManager = Singleton<AudioManager>.Instance;
		turretCore = (ProjectileCore)core;
		turretProjectile = turretCore.coreProjectile;
		turretRotateSpeed = turretCore.turretRotateSpeed;
		turretErrorAngle = turretCore.turretErrorAngle;
		turretRateOfFire = turretCore.GetTurretRateOfFire();
		recoilDuration = turretRateOfFire * 0.25f;
		recallDuration = turretRateOfFire * 0.5f;
		turretRange = turretCore.GetTurretRange();
		damageModifier = 1f;
		turretTargetDetectionType = coreController.GetCoreTargetDetectionType();
		if (!IsPlayerControlled)
		{
			isFiring = false;
			isTurretActive = true;
			isRecoiling = false;
			ActivateRadar(turretCore.GetTurretRange(), turretTargetDetectionType, turretCore.radarConfiguration);
		}
	}

	public override void SetIsPlayerControlled(bool IsPlayerControlled = true)
	{
		base.SetIsPlayerControlled(IsPlayerControlled);
		RefreshTarget();
	}

	public override void PreviewTurret(Core core, bool showPreview = false)
	{
		base.PreviewTurret(core, showPreview);
		if (turretRangeObject == null)
		{
			turretRangeObject = MasterPool.CreateNew(PrefabTypes.Range_Turret, base.transform);
			turretRangeObject.SetActive(value: false);
		}
		float num = ((ProjectileCore)core).GetTurretRange(GetRangePercent(core));
		if (showPreview)
		{
			if (!turretRangeObject.activeSelf)
			{
				turretRangeObject.SetActive(value: true);
				TweenController.Scale(turretRangeObject.transform, 0f, num, TweenDuration.Very_Short, ignoreTimeScale: true);
			}
		}
		else if (turretRangeObject.activeSelf)
		{
			TweenController.Scale(turretRangeObject.transform, num, 0f, TweenDuration.Super_Short, ignoreTimeScale: true, () =>
			{
				turretRangeObject.SetActive(value: false);
			});
		}
	}

	public override void BuildTurret(CoreController coreController, Core core)
	{
		ProjectileTurret projectileTurret = (ProjectileTurret)((TurretCore)core).coreTurret;
		turretTransform = base.transform;
		fireAudioClipType = projectileTurret.fireAudioClipType;
		if (projectileTurret.turretsBarrels != null)
		{
			turretBarrelsController = Object.Instantiate(projectileTurret.turretsBarrels, turretTransform).GetComponent<TurretBarrelsController>();
		}
		base.BuildTurret(coreController, core);
	}

	public override void RefreshTurret()
	{
		base.RefreshTurret();
		if (turretChipsContainer != null)
		{
			if (turretChipsContainer.IsChipActivated(ChipTypes.HQControl))
			{
				SceneSingleton<PlayerTurretManager>.Instance.AddTurret(this);
			}
			else
			{
				SceneSingleton<PlayerTurretManager>.Instance.RemoveTurret(this);
			}
		}
		TurretLevelUpReward turretLevelUpReward = (TurretLevelUpReward)Singleton<PlayerDataStore>.Instance.GetLevelUpReward(turretCore);
		if (turretLevelUpReward != null)
		{
			float num = Singleton<PlayerDataStore>.Instance.GetLevelUpRewardsCount(turretCore);
			UpdateDamageModifer(Singleton<PlayerDataStore>.Instance.GetCoresDamagePercent() + turretLevelUpReward.DamagePercent * num);
			UpdateRateOfFire(Singleton<PlayerDataStore>.Instance.GetCoresRateOfFirePercent() + turretLevelUpReward.RateOfFirePercent * num);
			UpdateRange(Singleton<PlayerDataStore>.Instance.GetCoresRangePercent() + turretLevelUpReward.RangePercent * num);
		}
		else
		{
			UpdateDamageModifer(Singleton<PlayerDataStore>.Instance.GetCoresDamagePercent());
			UpdateRateOfFire(Singleton<PlayerDataStore>.Instance.GetCoresRateOfFirePercent());
			UpdateRange(Singleton<PlayerDataStore>.Instance.GetCoresRangePercent());
		}
	}

	public void UpdateRateOfFire(float percent)
	{
		turretRateOfFire = turretCore.GetTurretRateOfFire(percent);
	}

	public void OverrideDamageModifer(float percent)
	{
		damageModifier = percent;
	}

	public void UpdateDamageModifer(float percent)
	{
		damageModifier = UnityEngineSystem.CalcPercent(PlayerDataStore.GetDamageModifier(), percent);
	}

	public virtual void UpdateRange(float percent)
	{
		if (!IsRadarOverriden)
		{
			float radarRange = turretCore.GetTurretRange(percent);
			radarSystem.RescaleRadar(radarRange);
			turretRange = radarRange;
		}
	}

	private float GetRangePercent(Core core)
	{
		float num = Singleton<PlayerDataStore>.Instance.GetCoresRangePercent();
		TurretLevelUpReward turretLevelUpReward = (TurretLevelUpReward)Singleton<PlayerDataStore>.Instance.GetLevelUpReward(core);
		if (turretLevelUpReward != null)
		{
			float num2 = Singleton<PlayerDataStore>.Instance.GetLevelUpRewardsCount(core);
			num += turretLevelUpReward.RangePercent * num2;
		}
		return num;
	}

	public virtual void FixedUpdate()
	{
		if (isTurretActive && !IsPlayerControlled)
		{
			if (targetTransform != null && !isRecoiling)
			{
				RotateToTarget(targetTransform.position);
			}
			else
			{
				isFiring = false;
			}
			ShootTurret(isFiring);
		}
	}

	public void SetTurretTarget(Transform targetTransform)
	{
		if (base.targetTransform != targetTransform)
		{
			base.targetTransform = targetTransform;
		}
	}

	public virtual void StopTurret()
	{
		targetTransform = null;
	}

	public Vector2 GetTurretPosition()
	{
		return turretTransform.position;
	}

	public virtual void RotateToTarget(Vector2 targetPosition)
	{
		this.targetPosition = targetPosition;
		float num = Mathf.Atan2(targetPosition.y - turretTransform.position.y, targetPosition.x - turretTransform.position.x) * 57.29578f;
		num -= 90f;
		Quaternion quaternion = Quaternion.Euler(new Vector3(0f, 0f, num));
		turretTransform.rotation = Quaternion.RotateTowards(turretTransform.rotation, quaternion, turretRotateSpeed * Time.deltaTime);
		float num2 = Quaternion.Angle(turretTransform.rotation, quaternion);
		isFiring = num2 < turretErrorAngle;
	}

	public bool IsFiring()
	{
		return isFiring;
	}

	public abstract void ShootTurret(bool isFiring);

	public virtual GameObject FireProjectile()
	{
		if (isPlayProjectileSound)
		{
			audioManager.PlaySFX(fireAudioClipType, turretTransform.position);
		}
		StartRecoil();
		Transform barrelTransform = GetBarrelTransform();
		GameObject pos = MasterPool.GetPos(turretProjectile.projectilePrefab, barrelTransform.position, barrelTransform.rotation);
		ProjectileController component = pos.GetComponent<ProjectileController>();
		component.SetProjectile(turretProjectile, turretTargetDetectionType, turretChipsContainer, targetTransform);
		component.SetDamageModifier(damageModifier);
		return pos;
	}

	protected bool TimeToShoot()
	{
		if (timer < Time.time)
		{
			timer = Time.time + turretRateOfFire;
			return true;
		}
		return false;
	}

	public void ActivateRadar(float turretRange, DetectionType radarDetectionType, RadarConfiguration rct)
	{
		if (!(radarSystem != null))
		{
			radarSystem = MasterPool.Get(PrefabTypes.ShipSystem_Radar, turretTransform).GetComponent<RadarSystem>();
			radarSystem.SetRadarSystem(turretRange, radarDetectionType, SetTarget, rct);
			IsRadarOverriden = false;
		}
	}

	public void SetTarget(Transform target)
	{
		if (target != null)
		{
			SetTurretTarget(target);
		}
		else
		{
			StopTurret();
		}
	}

	public void RefreshTarget()
	{
		Transform target = radarSystem.GetTarget(turretTransform.position, turretCore.radarConfiguration, targetTransform);
		if (target != null)
		{
			SetTurretTarget(target);
		}
	}

	public void OverrideTurretRadar(RadarSystem overrideRadarSystem)
	{
		if (!IsRadarOverriden && radarSystem.gameObject != null)
		{
			MasterPool.ReturnToPoolTransform(radarSystem.gameObject, PrefabTypes.ShipSystem_Radar);
			radarSystem = null;
		}
		radarSystem = overrideRadarSystem;
		radarSystem.AddTurretActions(SetTarget);
		IsRadarOverriden = true;
	}

	protected void StartRecoil()
	{
		if (!isRecoiling)
		{
			startPos = turretTransform.localPosition;
			Vector3 vector = turretTransform.localRotation * Vector3.down;
			vector = Vector3.ClampMagnitude(vector, RecoilMaxDistance);
			vector += startPos;
			TweenController.LocalMove(turretTransform, vector, recoilDuration, RecallTurret);
			isRecoiling = true;
		}
	}

	private void RecallTurret()
	{
		TweenController.LocalMove(turretTransform, startPos, recallDuration, EndRecoil);
	}

	private void EndRecoil()
	{
		isRecoiling = false;
	}
}
