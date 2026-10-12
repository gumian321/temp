using Steamworks;

public class SteamAchievementsManager : Singleton<SteamAchievementsManager>
{
	private bool isSteamInitialized;

	private void Start()
	{
		isSteamInitialized = SteamManager.Initialized;
		if (isSteamInitialized)
		{
			SteamUserStats.RequestCurrentStats();
		}
	}

	public void SetAchievement(string achievementAPI_Name)
	{
		if (isSteamInitialized)
		{
			SteamUserStats.GetAchievement(achievementAPI_Name, out var pbAchieved);
			if (!pbAchieved)
			{
				SteamUserStats.SetAchievement(achievementAPI_Name);
				SteamUserStats.StoreStats();
			}
		}
	}

	public void ResetAchievements()
	{
		if (isSteamInitialized)
		{
			SteamUserStats.ResetAllStats(bAchievementsToo: true);
		}
	}
}
