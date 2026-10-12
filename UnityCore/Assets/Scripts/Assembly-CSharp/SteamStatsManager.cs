using Steamworks;

public class SteamStatsManager : Singleton<SteamStatsManager>
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

	public int GetINTStat(string statAPI_Name)
	{
		if (!isSteamInitialized)
		{
			return 0;
		}
		SteamUserStats.GetStat(statAPI_Name, out int pData);
		return pData;
	}

	public void ADDINTStat(string statAPI_Name, int statAmount)
	{
		if (isSteamInitialized)
		{
			int iNTStat = GetINTStat(statAPI_Name);
			iNTStat += statAmount;
			SetINTStat(statAPI_Name, iNTStat);
		}
	}

	public void SetINTStat(string statAPI_Name, int statAmount)
	{
		if (isSteamInitialized)
		{
			SteamUserStats.SetStat(statAPI_Name, statAmount);
		}
	}

	public void SaveStats()
	{
		if (isSteamInitialized)
		{
			SteamUserStats.StoreStats();
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
