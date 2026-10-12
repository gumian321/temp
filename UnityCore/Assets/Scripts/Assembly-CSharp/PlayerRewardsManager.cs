public class PlayerRewardsManager : SceneSingleton<PlayerRewardsManager>
{
	private PlayerDataStore playerDataStore;

	private PlayerCoresManager playerCoresManager;

	private void Start()
	{
		playerDataStore = Singleton<PlayerDataStore>.Instance;
		playerCoresManager = SceneSingleton<PlayerCoresManager>.Instance;
	}

	public bool CanSelectReward(RewardTypes rewardType, int count)
	{
		switch (rewardType)
		{
		case RewardTypes.DuplicateCoresCount:
			if (playerCoresManager.GetCoresCount() >= 1)
			{
				return playerCoresManager.CanAddCore(count);
			}
			return false;
		case RewardTypes.SwitchCoresCount:
			return playerCoresManager.GetCoresCount() >= 2;
		case RewardTypes.MoveCoresCount:
			return playerCoresManager.GetCoresCount() >= 1;
		case RewardTypes.WallCoresCount:
			if (playerCoresManager.GetCoresCount() >= count)
			{
				return playerCoresManager.CanWallCores(count);
			}
			return false;
		default:
			return true;
		}
	}

	public void SelectReward(RewardTypes rewardType)
	{
	}

	public void SelectCountReward(RewardTypes rewardType, int count)
	{
		switch (rewardType)
		{
		case RewardTypes.DuplicateCoresCount:
			SceneSingleton<PlayerBuildingManager>.Instance.ActivateDuplicate(count);
			break;
		case RewardTypes.SwitchCoresCount:
			SceneSingleton<PlayerBuildingManager>.Instance.ActivateSwitchs(count);
			break;
		case RewardTypes.MoveCoresCount:
			SceneSingleton<PlayerBuildingManager>.Instance.ActivateMove(count);
			break;
		case RewardTypes.WallCoresCount:
			SceneSingleton<PlayerBuildingManager>.Instance.ActivateWall(count);
			break;
		}
	}

	public bool CanSelectPercentReward(RewardTypes rewardType, float percent)
	{
		switch (rewardType)
		{
		case RewardTypes.EngineBoostPercent:
			if (playerDataStore.CanAddPercent(playerDataStore.GetMainCoreBoostPercent(), percent))
			{
				return !playerDataStore.IsMaxEngineBoostPower();
			}
			return false;
		case RewardTypes.ShipSpeedUpPercent:
			if (playerDataStore.CanAddPercent(playerDataStore.GetMainCoreSpeedPercent(), percent))
			{
				return playerDataStore.CanChangeEnginePower(percent);
			}
			return false;
		case RewardTypes.TurretsRangePercent:
			return playerDataStore.CanAddPercent(playerDataStore.GetCoresRangePercent(), percent);
		case RewardTypes.TurretsRateOfFirePercent:
			return playerDataStore.CanAddPercent(playerDataStore.GetCoresRateOfFirePercent(), percent);
		case RewardTypes.PartsHealthPercent:
			return playerDataStore.CanAddPercent(playerDataStore.GetCoresHealthPercent(), percent);
		case RewardTypes.TurretsDamagePercent:
			return playerDataStore.CanAddPercent(playerDataStore.GetCoresDamagePercent(), percent);
		case RewardTypes.HQHealthPercent:
			return playerDataStore.CanAddPercent(playerDataStore.GetMainCoreHealthPercent(), percent);
		case RewardTypes.HQGunRateOfFirePercent:
			return playerDataStore.CanAddPercent(playerDataStore.GetMainCoreRateOfFirePercent(), percent);
		case RewardTypes.HQGunDamagePercent:
			return playerDataStore.CanAddPercent(playerDataStore.GetMainCoreDamagePercent(), percent);
		case RewardTypes.HQGunRangePercent:
			return playerDataStore.CanAddPercent(playerDataStore.GetMainCoreRangePercent(), percent);
		default:
			return false;
		}
	}

	public void SelectPercentReward(RewardTypes rewardType, float percent)
	{
		switch (rewardType)
		{
		case RewardTypes.EngineBoostPercent:
			playerDataStore.AddMainCoreBoostPercent(percent);
			break;
		case RewardTypes.ShipSpeedUpPercent:
			playerDataStore.AddMainCoreSpeedPercent(percent);
			break;
		case RewardTypes.TurretsRangePercent:
			playerDataStore.AddRangePercent(percent);
			break;
		case RewardTypes.TurretsRateOfFirePercent:
			playerDataStore.AddRateOfFirePercent(percent);
			break;
		case RewardTypes.PartsHealthPercent:
			playerDataStore.AddCoresHealthPercent(percent);
			break;
		case RewardTypes.TurretsDamagePercent:
			playerDataStore.AddTurretsDamagePercent(percent);
			break;
		case RewardTypes.HQHealthPercent:
			playerDataStore.AddMainCoreHealthPercent(percent);
			break;
		case RewardTypes.HQGunRateOfFirePercent:
			playerDataStore.AddMainCoreRateOfFireBoost(percent);
			break;
		case RewardTypes.HQGunDamagePercent:
			playerDataStore.AddMainCoreDamageBoost(percent);
			break;
		case RewardTypes.HQGunRangePercent:
			playerDataStore.AddMainCoreRangeBoost(percent);
			break;
		}
		SceneSingleton<PlayerStatsUIController>.Instance.RefreshUI();
	}
}
