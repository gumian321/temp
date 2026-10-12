using UnityEngine;

[CreateAssetMenu(fileName = "New Main Turret Reward", menuName = "ScriptableObjects/Rewards/New Main Turret Reward")]
public class MainCoreTurretReward : Reward
{
	[Space]
	[Space]
	[Header("MainCoreTurret Reward Data")]
	public Core core;

	public override bool CanSelectReward()
	{
		if (!SceneSingleton<PlayerTurretManager>.Instance.IsSameCore(core))
		{
			return base.CanSelectReward();
		}
		return false;
	}

	public override void SelectReward()
	{
		SceneSingleton<PlayerTurretManager>.Instance.BuildPlayerTurret(SceneSingleton<PlayerCoresManager>.Instance.GetMainCoreController(), core);
		SceneSingleton<PlayerCoresManager>.Instance.RefreshMainCoreHealth();
	}

	public override int GetRewardLevel()
	{
		return Singleton<PlayerDataStore>.Instance.GetLevelUpRewardsCount(core);
	}

	public override string GetRewardTitle()
	{
		return string.Format(Singleton<LocalizationSystem>.Instance.GetIDString("Part_HQ"), core.GetCoreTitle());
	}

	public override Sprite GetRewardSprite()
	{
		return core.GetCoreSprite();
	}

	public override void AddRewardPopUpText()
	{
		string iDString = Singleton<LocalizationSystem>.Instance.GetIDString("PopUpText_HQTurret");
		iDString = string.Format(iDString, core.GetCoreTitle());
		SceneSingleton<PopUpTextManager>.Instance.AddPopUpText(iDString);
	}
}
