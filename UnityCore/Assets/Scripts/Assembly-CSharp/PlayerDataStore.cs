using System.Collections.Generic;
using UnityEngine;

public class PlayerDataStore : Singleton<PlayerDataStore>
{
	public Color playerHitColor;

	public Color playerRepairColor;

	[SerializeField]
	private List<Sprite> PlayerScrapsSprites;

	[Space]
	[Header("Stats Variables")]
	[SerializeField]
	private float maxStatsPercentage = 2f;

	[SerializeField]
	private float minStatsPercentage = -0.99f;

	private List<LevelUpReward> levelUpRewardsList;

	private static int levelUpsAllowed = 3;

	private float CoresRangePercent;

	private float CoresRateOfFirePercent;

	private float CoresDamagePercent;

	private float coresHealthPercent;

	[HideInInspector]
	public float mainCoreHealthPercent;

	private float mainCoreSpeedPercent;

	private float mainCoreBoostPercent;

	private float mainCoreRateOfFireBoostPercent;

	private float mainCoreDamagBoostPercent;

	private float mainCoreRangeBoostPercent;

	[Space(10f)]
	[Header("HQ Data")]
	[SerializeField]
	private TurretCore mainTurretCore;

	public Core HQCore;

	[Space]
	[SerializeField]
	private List<Drone> playerDronesList;

	[SerializeField]
	private int maxHQDronesCount = 30;

	private static float damageModifier = 1f;

	private static float accelrationPower = 0.25f;

	private static float deaccelrationPower = 0.5f;

	private static float fuelRechargeRate = 25f;

	private static float fuelConsumptionRate = 50f;

	private static float fuelRechargeDelay = 2f;

	private static int playerDetectionRange = 25;

	[Space]
	[Header("Player Building")]
	[SerializeField]
	private int maxBuiltCores = 60;

	[Space]
	[SerializeField]
	private int buildingLimitX = 5;

	[SerializeField]
	private int buildingLimitY = 5;

	[Space]
	[Header("Player Engine Variable")]
	[SerializeField]
	private float minEnginePower = 2f;

	[SerializeField]
	private float enginePower = 3f;

	[SerializeField]
	private float maxEnginePower = 4f;

	[Space]
	[SerializeField]
	private float boostEnginePower = 2f;

	[SerializeField]
	private float maxBoostEnginePower = 4f;

	private static float startEngineSize = 0.25f;

	private static float boostEngineSize = 0.6f;

	public List<Sprite> GetScrapSpriteList()
	{
		return PlayerScrapsSprites;
	}

	public bool CanAddPercent(float currentPercent, float percent)
	{
		float num = currentPercent + percent;
		if (num >= minStatsPercentage)
		{
			return num <= maxStatsPercentage;
		}
		return false;
	}

	private float clampPercent(float percnet)
	{
		return Mathf.Clamp(percnet, minStatsPercentage, maxStatsPercentage);
	}

	public void ResetPlayerDataStore()
	{
		levelUpRewardsList = new List<LevelUpReward>();
		mainCoreSpeedPercent = 0f;
		mainCoreBoostPercent = 0f;
		coresHealthPercent = 0f;
		mainCoreHealthPercent = 0f;
		CoresRateOfFirePercent = 0f;
		CoresDamagePercent = 0f;
		CoresRangePercent = 0f;
		mainCoreRateOfFireBoostPercent = 0f;
		mainCoreDamagBoostPercent = 0f;
		mainCoreRangeBoostPercent = 0f;
	}

	public void AddLevelUpReward(LevelUpReward levelUpReward)
	{
		levelUpRewardsList.Add(levelUpReward);
		foreach (Core cores in levelUpReward.coresList)
		{
			SceneSingleton<PlayerCoresManager>.Instance.RefreshCores(cores);
			if (SceneSingleton<PlayerTurretManager>.Instance.GetTurretCore() == cores)
			{
				SceneSingleton<PlayerTurretManager>.Instance.RefreshTurret();
				SceneSingleton<PlayerCoresManager>.Instance.RefreshMainCoreHealth();
			}
		}
	}

	public bool CheckLevelUpRewardsCount(LevelUpReward levelUpReward)
	{
		return GetLevelUpRewardsCount(levelUpReward) < levelUpsAllowed;
	}

	public int GetLevelUpRewardsCount(LevelUpReward levelUpReward)
	{
		int num = 0;
		foreach (LevelUpReward levelUpRewards in levelUpRewardsList)
		{
			if (levelUpRewards == levelUpReward)
			{
				num++;
			}
		}
		return num;
	}

	public int GetLevelUpRewardsCount(Core core)
	{
		int num = 0;
		foreach (LevelUpReward levelUpRewards in levelUpRewardsList)
		{
			foreach (Core cores in levelUpRewards.coresList)
			{
				if (cores == core)
				{
					num++;
				}
			}
		}
		return num;
	}

	public int GetLevelUpRewardsCount(Drone drone)
	{
		int num = 0;
		foreach (LevelUpReward levelUpRewards in levelUpRewardsList)
		{
			if (!(levelUpRewards is DroneLevelUpReward))
			{
				continue;
			}
			foreach (Drone drones in ((DroneLevelUpReward)levelUpRewards).dronesList)
			{
				if (drones == drone)
				{
					num++;
				}
			}
		}
		return num;
	}

	public LevelUpReward GetLevelUpReward(Core core)
	{
		foreach (LevelUpReward levelUpRewards in levelUpRewardsList)
		{
			foreach (Core cores in levelUpRewards.coresList)
			{
				if (cores == core)
				{
					return levelUpRewards;
				}
			}
		}
		return null;
	}

	public DroneLevelUpReward GetLevelUpReward(Drone drone)
	{
		foreach (LevelUpReward levelUpRewards in levelUpRewardsList)
		{
			if (!(levelUpRewards is DroneLevelUpReward))
			{
				continue;
			}
			DroneLevelUpReward droneLevelUpReward = (DroneLevelUpReward)levelUpRewards;
			foreach (Drone drones in droneLevelUpReward.dronesList)
			{
				if (drones == drone)
				{
					return droneLevelUpReward;
				}
			}
		}
		return null;
	}

	public bool CanLevelUp(Core core)
	{
		foreach (LevelUpReward levelUpRewards in levelUpRewardsList)
		{
			foreach (Core cores in levelUpRewards.coresList)
			{
				if (cores == core)
				{
					return true;
				}
			}
		}
		return false;
	}

	public float GetLevelUpHealthPercent(Core core)
	{
		LevelUpReward levelUpReward = GetLevelUpReward(core);
		if (levelUpReward == null)
		{
			return 0f;
		}
		return levelUpReward.CoreHealthPercent * (float)GetLevelUpRewardsCount(core);
	}

	public float GetCoresRangePercent()
	{
		return CoresRangePercent;
	}

	public void AddRangePercent(float addedPercent)
	{
		CoresRangePercent += addedPercent;
		CoresRangePercent = clampPercent(CoresRangePercent);
		SceneSingleton<PlayerCoresManager>.Instance.RefreshCores();
	}

	public float GetCoresRateOfFirePercent()
	{
		return CoresRateOfFirePercent;
	}

	public void AddRateOfFirePercent(float addedPercent)
	{
		CoresRateOfFirePercent += addedPercent;
		CoresRateOfFirePercent = clampPercent(CoresRateOfFirePercent);
		SceneSingleton<PlayerCoresManager>.Instance.RefreshCores();
	}

	public float GetCoresDamagePercent()
	{
		return CoresDamagePercent;
	}

	public void AddTurretsDamagePercent(float addedPercent)
	{
		CoresDamagePercent += addedPercent;
		CoresDamagePercent = clampPercent(CoresDamagePercent);
		SceneSingleton<PlayerCoresManager>.Instance.RefreshCores();
	}

	public float GetCoresHealthPercent()
	{
		return coresHealthPercent;
	}

	public void AddCoresHealthPercent(float addedPercent)
	{
		coresHealthPercent += addedPercent;
		coresHealthPercent = clampPercent(coresHealthPercent);
		SceneSingleton<PlayerCoresManager>.Instance.RefreshCoresHealth();
	}

	public float GetCoreHealthPercent(Core core)
	{
		return coresHealthPercent + GetLevelUpHealthPercent(core);
	}

	public float GetMainCoreHealthPercent()
	{
		return mainCoreHealthPercent;
	}

	public void AddMainCoreHealthPercent(float addedPercent)
	{
		mainCoreHealthPercent += addedPercent;
		mainCoreHealthPercent = clampPercent(mainCoreHealthPercent);
		SceneSingleton<PlayerCoresManager>.Instance.RefreshMainCoreHealth();
	}

	public float GetMainCoreHealthPercent(Core core)
	{
		return mainCoreHealthPercent + GetLevelUpHealthPercent(core);
	}

	public float GetMainCoreSpeedPercent()
	{
		return mainCoreSpeedPercent;
	}

	public void AddMainCoreSpeedPercent(float addedPercent)
	{
		mainCoreSpeedPercent += addedPercent;
		mainCoreSpeedPercent = clampPercent(mainCoreSpeedPercent);
		float num = GetEnginePower();
		SceneSingleton<PlayerMovement>.Instance.UpdateEngine(num);
	}

	public float GetMainCoreBoostPercent()
	{
		return mainCoreBoostPercent;
	}

	public void AddMainCoreBoostPercent(float addedPercent)
	{
		mainCoreBoostPercent += addedPercent;
		mainCoreBoostPercent = clampPercent(mainCoreBoostPercent);
		float num = GetBoostEnginePower();
		SceneSingleton<PlayerEngineBoostController>.Instance.UpdateBoostEngine(num);
	}

	public float GetMainCoreRateOfFirePercent()
	{
		return mainCoreRateOfFireBoostPercent;
	}

	public void AddMainCoreRateOfFireBoost(float addedPercent)
	{
		mainCoreRateOfFireBoostPercent += addedPercent;
		mainCoreRateOfFireBoostPercent = clampPercent(mainCoreRateOfFireBoostPercent);
		SceneSingleton<PlayerTurretManager>.Instance.UpdateTurretRateOfFire(mainCoreRateOfFireBoostPercent);
	}

	public float GetMainCoreDamagePercent()
	{
		return mainCoreDamagBoostPercent;
	}

	public void AddMainCoreDamageBoost(float addedPercent)
	{
		mainCoreDamagBoostPercent += addedPercent;
		mainCoreDamagBoostPercent = clampPercent(mainCoreDamagBoostPercent);
		SceneSingleton<PlayerTurretManager>.Instance.UpdateTurretDamage(mainCoreDamagBoostPercent);
	}

	public float GetMainCoreRangePercent()
	{
		return mainCoreRangeBoostPercent;
	}

	public void AddMainCoreRangeBoost(float addedPercent)
	{
		mainCoreRangeBoostPercent += addedPercent;
		mainCoreRangeBoostPercent = clampPercent(mainCoreRangeBoostPercent);
		SceneSingleton<PlayerTurretManager>.Instance.UpdateTurretRange(mainCoreRangeBoostPercent);
	}

	public TurretCore GetMainTurretCore()
	{
		return mainTurretCore;
	}

	public int GetMaxHQDronesCount()
	{
		return maxHQDronesCount;
	}

	public bool CanAddHQDrones(int count)
	{
		return SceneSingleton<PlayerDronesManager>.Instance.dronesCount + count <= maxHQDronesCount;
	}

	public List<Drone> GetMainCoreDronesList()
	{
		return playerDronesList;
	}

	public static int GetPlayerDetectionRange()
	{
		return playerDetectionRange;
	}

	public static float GetDamageModifier()
	{
		return damageModifier;
	}

	public static float GetAccelrationPower()
	{
		return accelrationPower;
	}

	public static float GetDeaccelrationPower()
	{
		return deaccelrationPower;
	}

	public static float GetFuelRechargeRate(float percent = 0f)
	{
		return UnityEngineSystem.GetTickAmount(fuelRechargeRate, percent);
	}

	public static float GetFuelConsumptionRate(float percent = 0f)
	{
		return UnityEngineSystem.GetTickAmount(fuelConsumptionRate, percent);
	}

	public static float GetFuelRechargeDelay(float percent = 0f)
	{
		return UnityEngineSystem.CalcPercent(fuelRechargeDelay, percent);
	}

	public int GetMaxBuiltCores()
	{
		return maxBuiltCores;
	}

	public int GetBuildingLimitX()
	{
		return buildingLimitX;
	}

	public int GetBuildingLimitY()
	{
		return buildingLimitY;
	}

	public int GetShipMaxSize()
	{
		return (buildingLimitY * 2 + 2) * (buildingLimitX * 2 + 2) - 4;
	}

	public float GetEnginePower()
	{
		return Mathf.Clamp(UnityEngineSystem.CalcPercent(enginePower, mainCoreSpeedPercent), minEnginePower, maxEnginePower);
	}

	public bool CanChangeEnginePower(float percent)
	{
		if (percent < 0f)
		{
			return GetEnginePower() > minEnginePower;
		}
		return GetEnginePower() < maxEnginePower;
	}

	public float GetBossEnginePower()
	{
		return enginePower;
	}

	public float GetBoostEnginePower()
	{
		return Mathf.Clamp(UnityEngineSystem.CalcPercent(boostEnginePower, mainCoreBoostPercent), boostEnginePower, maxBoostEnginePower);
	}

	public bool IsMaxEngineBoostPower()
	{
		return UnityEngineSystem.CalcPercent(boostEnginePower, mainCoreBoostPercent) >= maxBoostEnginePower;
	}

	public static float GetStartEngineSize()
	{
		return startEngineSize;
	}

	public static float GetBoostEngineSize()
	{
		return boostEngineSize;
	}
}
