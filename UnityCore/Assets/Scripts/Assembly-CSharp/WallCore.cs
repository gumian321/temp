using UnityEngine;

[CreateAssetMenu(fileName = "New Wall Core", menuName = "ScriptableObjects/New Core/Wall Core")]
public class WallCore : Core
{
	public Turret coreTurret;

	public override void SpawnCoreObject(CoreController coreController)
	{
		if (!(coreTurret == null))
		{
			coreController.SetCoreObject(Object.Instantiate(coreTurret.turretObject, coreController.transform));
		}
	}

	public override void PreviewCore(CoreController coreController, bool showPreview = false)
	{
		if (coreController.GetCoreObject() != null && showPreview)
		{
			SpriteRenderer component = coreController.GetCoreObject().GetComponent<SpriteRenderer>();
			component.sprite = coreTurret.turretSprite;
			component.flipX = Random.Range(0, 100) > 50;
			component.flipY = Random.Range(0, 100) > 50;
		}
	}

	public override void DisableCoreArt(CoreController coreController)
	{
		if (coreController.GetCoreObject() != null)
		{
			coreController.GetCoreObject().GetComponent<SpriteRenderer>().sprite = null;
		}
	}

	public override void BuildCore(CoreController coreController)
	{
		if (Singleton<DetectionDataStore>.Instance.IsEnemyLayer(coreController.GetCoreTargetDetectionType()))
		{
			Singleton<GameAchievementsManager>.Instance?.Add_AchievementTypes(AchievementTypes.wallCount);
		}
	}

	public override void DestroyCore(CoreController coreController)
	{
		base.DestroyCore(coreController);
		if (Singleton<DetectionDataStore>.Instance.IsEnemyLayer(coreController.GetCoreTargetDetectionType()))
		{
			Singleton<GameAchievementsManager>.Instance?.Add_AchievementTypes(AchievementTypes.wallCount, -1);
		}
	}

	public override void DisableCore(CoreController coreController)
	{
	}

	public override void ActivateCore(CoreController coreController)
	{
	}

	public override Sprite GetCoreSprite()
	{
		return coreTurret.turretSprite;
	}
}
