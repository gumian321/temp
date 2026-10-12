using UnityEngine;

[CreateAssetMenu(fileName = "New Chip Core", menuName = "ScriptableObjects/New Core/New Chip Core")]
public class ChipCore : Core
{
	public Chip coreChip;

	private ChipController chipController;

	public ChipTypes GetCoreChipType()
	{
		return coreChip.chipType;
	}

	public override void SpawnCoreObject(CoreController coreController)
	{
		coreController.SetCoreObject(Object.Instantiate(coreChip.chipObject, coreController.transform));
	}

	public override void PreviewCore(CoreController coreController, bool showPreview = false)
	{
		if (coreController.GetCoreObject() != null)
		{
			coreController.GetCoreObject().GetComponent<ChipController>().PreviewChip(this, showPreview);
		}
	}

	public override void BuildCore(CoreController coreController)
	{
		if (coreController.GetCoreObject() != null)
		{
			coreController.GetCoreObject().GetComponent<ChipController>().BuildChip(coreController, this);
		}
		if (Singleton<DetectionDataStore>.Instance.IsEnemyLayer(coreController.GetCoreTargetDetectionType()))
		{
			Singleton<GameAchievementsManager>.Instance?.Add_AchievementTypes(AchievementTypes.chipsCount);
		}
	}

	public override void DestroyCore(CoreController coreController)
	{
		base.DestroyCore(coreController);
		if (Singleton<DetectionDataStore>.Instance.IsEnemyLayer(coreController.GetCoreTargetDetectionType()))
		{
			Singleton<GameAchievementsManager>.Instance?.Add_AchievementTypes(AchievementTypes.chipsCount, -1);
		}
	}

	public override void DisableCoreArt(CoreController coreController)
	{
		if (coreController.GetCoreObject() != null)
		{
			coreController.GetCoreObject().GetComponent<SpriteRenderer>().sprite = null;
		}
	}

	public override void DisableCore(CoreController coreController)
	{
		if (coreController.GetCoreObject() != null)
		{
			coreController.GetCoreObject().GetComponent<ChipController>()?.DisableCore();
		}
	}

	public override void ActivateCore(CoreController coreController)
	{
		if (coreController.GetCoreObject() != null)
		{
			coreController.GetCoreObject().GetComponent<ChipController>()?.ActivateCore();
		}
	}

	public override Sprite GetCoreSprite()
	{
		return coreChip.chipSprite;
	}

	public void SetChipRangeState(CoreController coreController, bool state)
	{
		if (coreController.GetCoreObject() != null)
		{
			coreController.GetCoreObject().GetComponent<ChipController>()?.SetChipRangeState(state);
		}
	}
}
