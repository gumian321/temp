using System;
using UnityEngine;

public class MineController : MonoBehaviour
{
	[SerializeField]
	private float mineSize = 0.5f;

	private SpriteRenderer spriteRenderer;

	private DetectionType mineTargetDetectionType;

	private Action<MineController> OnMineDestroyed;

	private ChipsContainer chipsContainer;

	private ChipsContainer mineChipsContainer;

	private Mine currentMine;

	private Transform mineTransform;

	public void SetMine(Mine currentMine, DetectionType mineTargetDetectionType, ChipsContainer chipsContainer, Action<MineController> OnMineDestroyed = null)
	{
		mineTransform = base.transform;
		this.mineTargetDetectionType = mineTargetDetectionType;
		this.currentMine = currentMine;
		if (OnMineDestroyed != null)
		{
			this.OnMineDestroyed = OnMineDestroyed.Invoke;
		}
		this.chipsContainer = chipsContainer;
		mineChipsContainer = currentMine.activatableChips;
		if (spriteRenderer == null)
		{
			spriteRenderer = GetComponent<SpriteRenderer>();
		}
		spriteRenderer.sprite = currentMine.mineSprite;
		TweenController.KillTweens(mineTransform);
		TweenController.Scale(mineTransform, 0f, mineSize, TweenDuration.Short, ignoreTimeScale: true);
		Singleton<GameAchievementsManager>.Instance?.Add_AchievementTypes(AchievementTypes.minesCount);
	}

	public void UpdateMineChipsContainer(ChipsContainer chipsContainer)
	{
		this.chipsContainer = chipsContainer;
	}

	private void OnTriggerEnter2D(Collider2D other)
	{
		IDetectable component = other.GetComponent<IDetectable>();
		if (component == null || !component.IsDetectionType(mineTargetDetectionType))
		{
			return;
		}
		IDamageable component2 = other.GetComponent<IDamageable>();
		if (component2 != null)
		{
			component2.TakeDamage(currentMine.GetMineDamage(other.gameObject));
			if (OnMineDestroyed != null)
			{
				OnMineDestroyed(this);
			}
			DestroyMine(other.gameObject);
		}
	}

	public void DestroyMine(GameObject target)
	{
		if (IsChipActive(ChipTypes.Shrapnel))
		{
			Singleton<ChipsDataStore>.Instance.ActivateShrapnel(target, currentMine.mineDamage, mineTargetDetectionType, chipsContainer.GetChipLevel(ChipTypes.Shrapnel));
		}
		if (IsChipActive(ChipTypes.Exploding))
		{
			Singleton<ChipsDataStore>.Instance.ActivateExplosion(mineTransform.position, currentMine.mineDamage, mineTargetDetectionType, chipsContainer.GetChipLevel(ChipTypes.Exploding));
		}
		ParticlesSystem.PlayExplosionParticle(mineTransform.position, 0.5f);
		DisableMine();
	}

	public void DisableMine()
	{
		Singleton<GameAchievementsManager>.Instance?.Add_AchievementTypes(AchievementTypes.minesCount, -1);
		SceneSingleton<MinesManager>.Instance?.RemoveMine(this);
		MasterPool.ReturnToPoolTransform(base.gameObject, PrefabTypes.Object_Mine);
	}

	public bool IsChipActive(ChipTypes chipType)
	{
		if (chipsContainer == null)
		{
			return false;
		}
		if (chipsContainer.IsChipActivated(chipType))
		{
			return mineChipsContainer.IsChipActivated(chipType);
		}
		return false;
	}
}
