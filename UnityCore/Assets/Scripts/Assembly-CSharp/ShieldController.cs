using UnityEngine;

public class ShieldController : MonoBehaviour
{
	private SpriteRenderer shieldSpriteRenderer;

	private SpritePulseEffector spritePulseEffector;

	private Collider2D shieldCollider2D;

	private DestructibleObject shieldObject;

	private Transform shieldTransform;

	private ShieldTurretController shieldTurretController;

	private ShieldCore shieldCore;

	private AudioManager audioManager;

	private float shieldRechargeDelay;

	private float shieldRechargeDestroyedDelay;

	private float shieldRechargeRate;

	private bool isShieldDestroyed;

	private bool canRecharge;

	private bool isDelay;

	private float delayTimer;

	private float shieldRange;

	private bool isTurretActive = true;

	public void SetShield(ShieldTurretController shieldTurretController, ShieldCore core, DetectionType shieldDetectionType)
	{
		shieldSpriteRenderer = GetComponent<SpriteRenderer>();
		spritePulseEffector = GetComponent<SpritePulseEffector>();
		shieldCollider2D = GetComponent<Collider2D>();
		this.shieldTurretController = shieldTurretController;
		audioManager = Singleton<AudioManager>.Instance;
		shieldTransform = base.transform;
		base.gameObject.layer = Singleton<DetectionDataStore>.Instance.GetLayer(shieldDetectionType);
		shieldCore = core;
		shieldRechargeRate = core.GetShieldRechargeRate();
		shieldRechargeDelay = core.GetShieldRechargeDelay();
		shieldRechargeDestroyedDelay = core.maxShieldHealth / 2f / core.shieldRechargeRate;
		shieldRange = core.ShieldRange;
		shieldObject = GetComponent<DestructibleObject>();
		shieldObject.SetObject(shieldDetectionType, base.transform);
		shieldObject.SetObjectHealth(OnDestroyAction, OnHealthDamageAction, UpdateShieldSprite, core.maxShieldHealth);
		StartShieldController();
	}

	private void StartShieldController()
	{
		UpdateShieldSprite(shieldCore.maxShieldHealth);
		isShieldDestroyed = true;
		isTurretActive = true;
		ActivateShield();
	}

	public void RefreshShield(ChipsContainer chipsContainer)
	{
		if (Singleton<PlayerDataStore>.Instance.CanLevelUp(shieldCore))
		{
			ShieldLevelUpReward shieldLevelUpReward = (ShieldLevelUpReward)Singleton<PlayerDataStore>.Instance.GetLevelUpReward(shieldCore);
			float num = Singleton<PlayerDataStore>.Instance.GetLevelUpRewardsCount(shieldCore);
			float num2 = UnityEngineSystem.CalcPercent(shieldCore.maxShieldHealth, shieldLevelUpReward.ShieldHealthPercent * num);
			shieldObject.UpdateObjectHealth(num2);
			shieldRechargeRate = shieldCore.GetShieldRechargeRate(shieldLevelUpReward.ShieldRechargeRatePercent * num);
			shieldRechargeDelay = shieldCore.GetShieldRechargeDelay(shieldLevelUpReward.ShieldRechargeDelayPercent * num);
			shieldRechargeDestroyedDelay = num2 / 2f / UnityEngineSystem.CalcPercent(shieldCore.shieldRechargeRate, shieldLevelUpReward.ShieldRechargeRatePercent * num);
			shieldRange = shieldCore.GetShieldRange(shieldLevelUpReward.ShieldRangePercent * num);
			if (chipsContainer != null && chipsContainer.IsChipActivated(ChipTypes.Mammoth))
			{
				shieldRange = Singleton<ChipsDataStore>.Instance.GetMammothArea(shieldRange, chipsContainer.GetChipLevel(ChipTypes.Mammoth));
			}
		}
		else if (chipsContainer != null && chipsContainer.IsChipActivated(ChipTypes.Mammoth))
		{
			shieldRange = Singleton<ChipsDataStore>.Instance.GetMammothArea(shieldCore.GetShieldRange(), chipsContainer.GetChipLevel(ChipTypes.Mammoth));
		}
		if (!isShieldDestroyed)
		{
			TweenController.Scale(shieldTransform, shieldTransform.localScale.x, shieldRange, TweenDuration.Short, ignoreTimeScale: true);
		}
	}

	private void StartShieldDelay(float delay)
	{
		isDelay = true;
		delayTimer = Time.time + delay;
	}

	public void OnHealthDamageAction(float currentShieldHealth)
	{
		audioManager.PlaySFX(AudioClipTypes.Shield_Hit, shieldTransform.position);
		UpdateShieldSprite(currentShieldHealth);
		DeactivateShield();
	}

	private void OnDestroyAction()
	{
		shieldCollider2D.enabled = false;
		isShieldDestroyed = true;
		audioManager.PlaySFX(AudioClipTypes.Shield_Down, shieldTransform.position);
		TweenController.Scale(shieldTransform, shieldRange, 0f, TweenDuration.Short, ignoreTimeScale: true);
		StartShieldDelay(shieldRechargeDestroyedDelay);
	}

	private void ActivateShield()
	{
		if (isShieldDestroyed)
		{
			isShieldDestroyed = false;
			if (shieldObject.CanRepair())
			{
				shieldObject.Repair(shieldObject.GetMaxHealth() / 2f);
			}
			audioManager.PlaySFX(AudioClipTypes.Shield_Up, shieldTransform.position);
			TweenController.Scale(shieldTransform, 0f, shieldRange, TweenDuration.Short, ignoreTimeScale: true, () =>
			{
				shieldCollider2D.enabled = true;
			});
		}
		canRecharge = true;
		isDelay = false;
	}

	private void DeactivateShield()
	{
		canRecharge = false;
		if (shieldObject.CanRepair() && !isShieldDestroyed)
		{
			StartShieldDelay(shieldRechargeDelay);
		}
	}

	public bool IsShieldDestroyed()
	{
		return isShieldDestroyed;
	}

	public void SetTurretStunState(bool flag)
	{
		isTurretActive = flag;
	}

	private void FixedUpdate()
	{
		if (!isTurretActive)
		{
			return;
		}
		if (isDelay)
		{
			if (delayTimer < Time.time)
			{
				ActivateShield();
			}
		}
		else if (canRecharge)
		{
			if (!shieldObject.CanRepair())
			{
				canRecharge = false;
			}
			else
			{
				shieldObject.Repair(shieldRechargeRate);
			}
		}
	}

	public void UpdateShieldSprite(float currentShieldHealth)
	{
		spritePulseEffector.StopEffect();
		ImageSystem.Alphalizer(shieldSpriteRenderer, currentShieldHealth / shieldObject.GetMaxHealth());
	}

	public float GetProjectileShieldHitPoint()
	{
		if (shieldTurretController == null)
		{
			return shieldRange;
		}
		return shieldRange * shieldTurretController.transform.localScale.x;
	}
}
