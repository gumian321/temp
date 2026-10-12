using UnityEngine;

public abstract class Core : ScriptableObject
{
	public int coreSortingOrder = 1;

	[SerializeField]
	protected string coreNameID;

	[Space]
	public float CoreHealth;

	public int coreHeat = 1;

	public int coreRatePrize = 1;

	public int coreScraps = 1;

	[Space]
	public bool isChipable = true;

	public bool isClockable = true;

	public abstract void BuildCore(CoreController coreController);

	public virtual void DestroyCore(CoreController coreController)
	{
		SceneSingleton<ScrapsManager>.Instance.SpawnScraps(coreController.transform.position, coreScraps, Singleton<PlayerDataStore>.Instance.GetScrapSpriteList());
	}

	public abstract void DisableCoreArt(CoreController coreController);

	public abstract void DisableCore(CoreController coreController);

	public abstract void ActivateCore(CoreController coreController);

	public abstract void SpawnCoreObject(CoreController coreController);

	public abstract void PreviewCore(CoreController coreController, bool showPreview = false);

	public virtual void StunCore(CoreController coreController, bool isStunned)
	{
	}

	public virtual void RefreshCore(CoreController coreController)
	{
		_ = isChipable;
	}

	public virtual bool CanBeHighlighted(ChipTypes ChipType)
	{
		return false;
	}

	public abstract Sprite GetCoreSprite();

	public virtual string GetCoreTitle()
	{
		return Singleton<LocalizationSystem>.Instance.GetIDString(coreNameID);
	}
}
