using System;
using System.Collections.Generic;

public class GameAchievementsManager : Singleton<GameAchievementsManager>
{
	private SteamAchievementsManager steamAchievementsManager;

	private SteamStatsManager steamStatsManager;

	private Dictionary<AchievementTypes, int> AchievementTypesDictionary;

	private Dictionary<AchievementTypes, Achievement> AchievementsDictionary;

	private int MiniBossKilled;

	private int MidBossKilled;

	private int EndBossKilled;

	private int bossesKilled;

	private int packsOpened;

	private int scrapsCollected;

	private int bulletsFired;

	private int shipsDestroyed;

	private int fleetsDestroyed;

	private int stationsDestroyed;

	private int asteroidsDestroyed;

	private int containersDestroyed;

	private void Start()
	{
		steamAchievementsManager = Singleton<SteamAchievementsManager>.Instance;
		steamStatsManager = Singleton<SteamStatsManager>.Instance;
		BuildAchievements();
	}

	public void ActivateAchievement(string ID)
	{
		steamAchievementsManager?.SetAchievement(ID);
	}

	public void BuildAchievements()
	{
		AchievementsDictionary = new Dictionary<AchievementTypes, Achievement>();
		Achievement achievement = new Achievement(AchievementTypes.minesCount, 50, Complete_MINES_50);
		AchievementsDictionary.Add(achievement.achievementType, achievement);
		achievement = new Achievement(AchievementTypes.dronesCount, 40, Complete_DRONES_40);
		AchievementsDictionary.Add(achievement.achievementType, achievement);
		achievement = new Achievement(AchievementTypes.HQDronesCount, 25, Complete_HIVEMIND);
		AchievementsDictionary.Add(achievement.achievementType, achievement);
		achievement = new Achievement(AchievementTypes.shieldCount, 5, Complete_SHIELD_5);
		AchievementsDictionary.Add(achievement.achievementType, achievement);
		achievement = new Achievement(AchievementTypes.fuelCount, 5, Complete_FUEL_5);
		AchievementsDictionary.Add(achievement.achievementType, achievement);
		achievement = new Achievement(AchievementTypes.chipsCount, 5, Complete_CHIPS_6);
		AchievementsDictionary.Add(achievement.achievementType, achievement);
	}

	public void ResetStats()
	{
		ResetBossStats();
		ResetBuildStats();
		ResetPewStats();
		AchievementTypesDictionary = new Dictionary<AchievementTypes, int>();
		foreach (AchievementTypes value in Enum.GetValues(typeof(AchievementTypes)))
		{
			AchievementTypesDictionary.Add(value, 0);
		}
	}

	public void SaveStats()
	{
		SaveBossStats();
		SaveBuildStats();
		SavePewStats();
		steamStatsManager?.SaveStats();
	}

	public void Add_AchievementTypes(AchievementTypes AchievementType, int amount = 1)
	{
		AchievementTypesDictionary[AchievementType] += amount;
		CheckAchievementTypesDictionary(AchievementType, AchievementTypesDictionary[AchievementType]);
	}

	private void CheckAchievementTypesDictionary(AchievementTypes AchievementType, int amount)
	{
		if (AchievementsDictionary.ContainsKey(AchievementType) && AchievementsDictionary[AchievementType].completedAmount <= amount)
		{
			AchievementsDictionary[AchievementType].completedAction();
		}
	}

	private void SaveBossStats()
	{
		steamStatsManager?.ADDINTStat("stat_MiniBossKilled", MiniBossKilled);
		steamStatsManager?.ADDINTStat("stat_MidBossKilled", MidBossKilled);
		steamStatsManager?.ADDINTStat("stat_EndBossKilled", EndBossKilled);
		steamStatsManager?.ADDINTStat("stat_BossesKilled", bossesKilled);
	}

	private void ResetBossStats()
	{
		MiniBossKilled = 0;
		MidBossKilled = 0;
		EndBossKilled = 0;
		bossesKilled = 0;
	}

	public void Add_BossKilled(AIThreatLevel aIThreatLevel)
	{
		switch (aIThreatLevel)
		{
		case AIThreatLevel.MiniBoss:
			MiniBossKilled++;
			break;
		case AIThreatLevel.MidBoss:
			MidBossKilled++;
			break;
		case AIThreatLevel.Boss:
			EndBossKilled++;
			break;
		}
		bossesKilled++;
	}

	public void EndlessMissionCompleted(float secondsSurvived)
	{
		int num = (int)(secondsSurvived / 60f);
		if (num >= 15)
		{
			ActivateAchievement("ACH_ENDLESS_15");
		}
		if (num >= 30)
		{
			ActivateAchievement("ACH_ENDLESS_30");
		}
	}

	public void GAMissionCompleted(float fleetPercent)
	{
		if (fleetPercent >= 1f)
		{
			ActivateAchievement("ACH_GA100");
		}
	}

	public void BHMissionCompleted(bool isBossKilled)
	{
		if (!isBossKilled)
		{
			ActivateAchievement("ACH_WEASEL");
		}
	}

	public void SProtectMissionCompleted(float stationPercent)
	{
		if (stationPercent >= 0.75f)
		{
			ActivateAchievement("ACH_SP75");
		}
	}

	private void SaveBuildStats()
	{
		steamStatsManager?.ADDINTStat("stat_PacksOpened", packsOpened);
		steamStatsManager?.ADDINTStat("stat_ScrapsCollected", scrapsCollected);
	}

	private void ResetBuildStats()
	{
		packsOpened = 0;
		scrapsCollected = 0;
	}

	public void Add_PacksOpened(int amount = 1)
	{
		packsOpened += amount;
	}

	public void Add_ScrapsCollected(int amount = 1)
	{
		scrapsCollected += amount;
	}

	private void Complete_MINES_50()
	{
		ActivateAchievement("ACH_MINES_50");
	}

	private void Complete_DRONES_40()
	{
		ActivateAchievement("ACH_DRONES_40");
	}

	private void Complete_HIVEMIND()
	{
		ActivateAchievement("ACH_HIVEMIND");
	}

	private void Complete_SHIELD_5()
	{
		ActivateAchievement("ACH_SHIELD_5");
	}

	private void Complete_FUEL_5()
	{
		ActivateAchievement("ACH_FUEL_5");
	}

	private void Complete_CHIPS_6()
	{
		ActivateAchievement("ACH_CHIPS_6");
	}

	public void Complete_SUPERWEAPON(int chipsCount)
	{
		if (chipsCount >= 4)
		{
			ActivateAchievement("ACH_SUPERWEAPON");
		}
	}

	private void SavePewStats()
	{
		steamStatsManager?.ADDINTStat("stat_BulletsFired", bulletsFired);
		steamStatsManager?.ADDINTStat("stat_ShipsDestroyed", shipsDestroyed);
		steamStatsManager?.ADDINTStat("stat_FleetsDestroyed", fleetsDestroyed);
		steamStatsManager?.ADDINTStat("stat_StationsDestroyed", stationsDestroyed);
		steamStatsManager?.ADDINTStat("stat_AsteroidsDestroyed", asteroidsDestroyed);
		steamStatsManager?.ADDINTStat("stat_ContainersDestroyed", containersDestroyed);
	}

	private void ResetPewStats()
	{
		bulletsFired = 0;
		shipsDestroyed = 0;
		fleetsDestroyed = 0;
		stationsDestroyed = 0;
		asteroidsDestroyed = 0;
		containersDestroyed = 0;
	}

	public void Add_BulletsFired(int amount = 1)
	{
		bulletsFired += amount;
	}

	public void Add_ShipsDestroyed(int amount = 1)
	{
		shipsDestroyed += amount;
	}

	public void Add_PatrolsDestroyed(int amount = 1)
	{
		fleetsDestroyed += amount;
	}

	public void Add_StationsDestroyed(int amount = 1)
	{
		stationsDestroyed += amount;
	}

	public void Add_AsteroidsDestroyed(int amount = 1)
	{
		asteroidsDestroyed += amount;
	}

	public void Add_ContainersDestroyed(int amount = 1)
	{
		containersDestroyed += amount;
	}

	public void Complete_LabHalfUnlocked()
	{
		ActivateAchievement("ACH_LAB_HALF");
	}

	public void Complete_LabFullUnlocked()
	{
		ActivateAchievement("ACH_LAB_FULL");
	}

	public void Complete_LabCommonUnlocked()
	{
		ActivateAchievement("ACH_LAB_COMMON");
	}

	public void Complete_LabRareUnlocked()
	{
		ActivateAchievement("ACH_LAB_RARE");
	}

	public void Complete_LabEpicUnlocked()
	{
		ActivateAchievement("ACH_LAB_EPIC");
	}

	public void Complete_LabLegendaryUnlocked()
	{
		ActivateAchievement("ACH_LAB_LEGENDARY");
	}
}
