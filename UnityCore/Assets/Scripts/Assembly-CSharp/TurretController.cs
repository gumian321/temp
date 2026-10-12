using UnityEngine;

public abstract class TurretController : MonoBehaviour
{
	protected Transform targetTransform;

	protected Transform turretTransform;

	private SpriteRenderer turretBodySprite;

	protected CoreController coreController;

	protected ChipsContainer turretChipsContainer;

	protected bool IsPlayerControlled;

	protected TurretBarrelsController turretBarrelsController;

	private void OnEnable()
	{
		turretBodySprite = GetComponent<SpriteRenderer>();
	}

	public virtual void SetIsPlayerControlled(bool IsPlayerControlled = true)
	{
		this.IsPlayerControlled = IsPlayerControlled;
	}

	public virtual void PreviewTurret(Core core, bool showPreview = false)
	{
		if (turretBodySprite == null)
		{
			turretBodySprite = GetComponent<SpriteRenderer>();
		}
		turretBodySprite.sprite = core.GetCoreSprite();
	}

	public virtual void BuildTurret(CoreController coreController, Core core)
	{
		this.coreController = coreController;
		turretChipsContainer = coreController.GetChipsContainer();
		TurretCore turretCore = (TurretCore)core;
		if (turretBodySprite == null)
		{
			turretBodySprite = GetComponent<SpriteRenderer>();
		}
		turretBodySprite.sprite = turretCore.GetCoreSprite();
		turretTransform = base.transform;
		SetTurret(turretCore);
	}

	public void DisableTurretArt()
	{
		turretBodySprite.sprite = null;
	}

	public Transform GetBarrelTransform()
	{
		if (turretBarrelsController != null)
		{
			return turretBarrelsController.GetNextBarrel();
		}
		return turretTransform;
	}

	public virtual void RefreshTurret()
	{
		turretChipsContainer = coreController.GetChipsContainer();
		if (turretChipsContainer != null)
		{
			Singleton<GameAchievementsManager>.Instance?.Complete_SUPERWEAPON(turretChipsContainer.GetChipsCount());
		}
	}

	public abstract void DisableTurret();

	public abstract void StunTurret(bool isStunned);

	public abstract void ActivateTurret();

	public abstract void SetTurret(Core core);

	public abstract void DestroyTurret();
}
