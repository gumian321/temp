using UnityEngine;

[CreateAssetMenu(fileName = "New Pack Core", menuName = "ScriptableObjects/New Core/Pack Core")]
public class PackCore : Core
{
	public Turret coreTurret;

	public int minPacksCount = 2;

	public int maxPacksCount = 4;

	public override void SpawnCoreObject(CoreController coreController)
	{
		if (!(coreTurret == null))
		{
			coreController.SetCoreObject(Object.Instantiate(coreTurret.turretObject, coreController.transform));
		}
	}

	public override void PreviewCore(CoreController coreController, bool showPreview = false)
	{
	}

	public override void BuildCore(CoreController coreController)
	{
	}

	public override void DisableCoreArt(CoreController coreController)
	{
	}

	public override void StunCore(CoreController coreController, bool isStunned)
	{
	}

	public override void DisableCore(CoreController coreController)
	{
	}

	public override void ActivateCore(CoreController coreController)
	{
	}

	public override void DestroyCore(CoreController coreController)
	{
		base.DestroyCore(coreController);
		Singleton<GameAchievementsManager>.Instance?.ActivateAchievement("ACH_BOX");
		int num = Random.Range(minPacksCount, maxPacksCount + 1);
		for (int i = 0; i < num; i++)
		{
			RewardPack levelUpRewardPack = Singleton<RewardDataStore>.Instance.GetLevelUpRewardPack();
			new RewardPackController().SetRewardPack(levelUpRewardPack);
			SceneSingleton<RewardSystemManager>.Instance.SpawnRewardPack(coreController.transform.position, levelUpRewardPack);
		}
	}

	public override Sprite GetCoreSprite()
	{
		return coreTurret.turretSprite;
	}
}
