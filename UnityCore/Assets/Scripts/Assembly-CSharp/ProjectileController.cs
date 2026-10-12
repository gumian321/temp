using UnityEngine;

public abstract class ProjectileController : MonoBehaviour
{
	protected DetectionType projectileTargetDetectionType;

	protected Projectile projectile;

	protected ChipsContainer chipsContainer;

	protected ChipsContainer projectileChipsContainer;

	protected float timer;

	protected Transform projectileTarget;

	protected Transform projectileTransform;

	protected bool isChipsActivated = true;

	private GameObject ignoredTarget;

	protected int targetsCount = 1;

	protected int chainTargetJumpCount;

	private Damage overrideDamage;

	private float damageModifier = 1f;

	public virtual void SetProjectile(Projectile projectile, DetectionType turretTargetDetectionType, ChipsContainer chipsContainer = null, Transform projectileTarget = null)
	{
		this.projectile = projectile;
		projectileTargetDetectionType = turretTargetDetectionType;
		this.projectileTarget = projectileTarget;
		this.chipsContainer = chipsContainer;
		projectileChipsContainer = projectile.activatableChips;
		targetsCount = projectile.targetPiercingCount;
		if (GetComponent<SpriteRenderer>() != null)
		{
			GetComponent<SpriteRenderer>().sprite = projectile.projectileSprite;
		}
		timer = Time.time + projectile.projectileLifeTime;
		ignoredTarget = null;
		projectileTransform = base.transform;
		ResetProjectileDamage();
		CheckChips();
		if (Singleton<DetectionDataStore>.Instance.IsEnemyLayer(projectileTargetDetectionType))
		{
			Singleton<GameAchievementsManager>.Instance?.Add_BulletsFired();
		}
	}

	public virtual void FixedUpdate()
	{
		if (timer < Time.time)
		{
			DisableProjectile();
		}
	}

	public virtual void OnTriggerEnter2D(Collider2D other)
	{
		if (!(other.gameObject == ignoredTarget))
		{
			IDetectable component = other.GetComponent<IDetectable>();
			if (component != null && component.IsDetectionType(projectileTargetDetectionType))
			{
				TriggerProjectile(other.gameObject);
				DestroyProjectile(other.gameObject);
			}
		}
	}

	public virtual void TriggerProjectile(GameObject target)
	{
		if (!(target == null))
		{
			target.GetComponent<IDamageable>()?.TakeDamage(GetProjectileDamage(target));
		}
	}

	public void DestroyProjectile(GameObject target)
	{
		if (Singleton<DetectionDataStore>.Instance.IsShieldLayer(target))
		{
			ParticlesSystem.PlayProjectieShieldImpactParticle(projectileTransform.position);
			chainTargetJumpCount = 0;
			targetsCount = 0;
		}
		else
		{
			ParticlesSystem.PlayProjectileImpactParticle(projectileTransform.position);
		}
		targetsCount--;
		if (targetsCount <= 0)
		{
			ActivateChips(target);
			DisableProjectile();
		}
	}

	public void DisableProjectile()
	{
		MasterPool.ReturnToPoolTransform(base.gameObject, projectile.projectilePrefab);
	}

	public void RotateToTarget(Vector3 target)
	{
		Vector3 vector = base.transform.position - target;
		Quaternion rotation = Quaternion.AngleAxis(Mathf.Atan2(vector.y, vector.x) * 57.29578f + 90f, Vector3.forward);
		base.transform.rotation = rotation;
	}

	public void RotateAngle(float a)
	{
		Vector3 zero = Vector3.zero;
		zero.z = a;
		base.transform.eulerAngles = zero;
	}

	public virtual void CheckChips()
	{
		isChipsActivated = true;
		if (IsChipActive(ChipTypes.Piercing))
		{
			targetsCount += Singleton<ChipsDataStore>.Instance.GetPiercingTargetCount(chipsContainer.GetChipLevel(ChipTypes.Piercing));
		}
		if (IsChipActive(ChipTypes.Chain))
		{
			chainTargetJumpCount = Singleton<ChipsDataStore>.Instance.GetChainTargetJumpCount(chipsContainer.GetChipLevel(ChipTypes.Chain));
		}
		else
		{
			chainTargetJumpCount = 0;
		}
		if (IsChipActive(ChipTypes.Mammoth))
		{
			float mammothProjectileSize = Singleton<ChipsDataStore>.Instance.GetMammothProjectileSize(1f, chipsContainer.GetChipLevel(ChipTypes.Mammoth));
			ObjectSystem.ReScale(base.gameObject, mammothProjectileSize);
		}
		else
		{
			ObjectSystem.ReScale(base.gameObject, 1f);
		}
	}

	public virtual void ActivateChips(GameObject target)
	{
		if ((IsChipActive(ChipTypes.Chain) || chainTargetJumpCount > 0) && target != null)
		{
			Singleton<ChipsDataStore>.Instance.ActivateChain(target, projectileTargetDetectionType, projectile, chainTargetJumpCount, chipsContainer);
		}
		if (IsChipActive(ChipTypes.Shrapnel) && target != null)
		{
			Singleton<ChipsDataStore>.Instance.ActivateShrapnel(target, projectile.projectileDamage, projectileTargetDetectionType, chipsContainer.GetChipLevel(ChipTypes.Shrapnel));
		}
		if (IsChipActive(ChipTypes.Exploding) && target != null)
		{
			Singleton<ChipsDataStore>.Instance.ActivateExplosion(projectileTransform.position, projectile.projectileDamage, projectileTargetDetectionType, chipsContainer.GetChipLevel(ChipTypes.Exploding));
		}
	}

	public void SetIgnoreTarget(GameObject target)
	{
		ignoredTarget = target;
	}

	public void SetChainTargetJumpCount(int chainTargetJumpCount)
	{
		this.chainTargetJumpCount = chainTargetJumpCount;
	}

	public void UpdateProjectileChipsContainer(ChipsContainer chipsContainer)
	{
		this.chipsContainer = chipsContainer;
	}

	public bool IsChipActive(ChipTypes chipType)
	{
		if (!isChipsActivated)
		{
			return false;
		}
		if (chipsContainer == null)
		{
			return false;
		}
		if (chipsContainer.IsChipActivated(chipType))
		{
			return projectileChipsContainer.IsChipActivated(chipType);
		}
		return false;
	}

	public void deactivateProjectilesChips()
	{
		isChipsActivated = false;
	}

	public void ResetProjectileDamage()
	{
		damageModifier = 1f;
		overrideDamage = null;
	}

	public float GetProjectileDamage(GameObject target)
	{
		return projectile.GetProjectileDamage(target.gameObject, overrideDamage) * GetDamageModifier();
	}

	public void SetDamageModifier(float damageModifier)
	{
		this.damageModifier = damageModifier;
	}

	public float GetDamageModifier()
	{
		if (IsChipActive(ChipTypes.Mammoth))
		{
			return Singleton<ChipsDataStore>.Instance.GetMammothDamage(damageModifier, chipsContainer.GetChipLevel(ChipTypes.Mammoth));
		}
		return damageModifier;
	}

	public void OverrideProjectileDamage(Damage overrideDamage, float damageModifier = 1f)
	{
		this.overrideDamage = overrideDamage;
		this.damageModifier = damageModifier;
	}
}
