using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class GameLeaderboardManager : Singleton<GameLeaderboardManager>
{
	private List<MissionLeaderboard> MissionLeaderboardsList;

	private MissionLeaderboard currentMissionLeaderboard;

	private bool isTopListSet;

	private bool isUserSet;

	public MissionLeaderboard GetMissionLeaderboard(Mission mission)
	{
		if (MissionLeaderboardsList != null)
		{
			foreach (MissionLeaderboard missionLeaderboards in MissionLeaderboardsList)
			{
				if (missionLeaderboards.leaderboardName == mission.MissionLeaderBoardName)
				{
					return missionLeaderboards;
				}
			}
		}
		return null;
	}

	public void LoadAllLeaderboards()
	{
		if (Singleton<SteamLeaderboardManager>.Instance.isSteamInitialized)
		{
			StartCoroutine(LoadAllLeaderboardsCoroutine());
		}
	}

	public IEnumerator LoadAllLeaderboardsCoroutine()
	{
		List<Mission> allMissions = Singleton<MissionDataStore>.Instance.GetAllMissions();
		MissionLeaderboardsList = new List<MissionLeaderboard>();
		currentMissionLeaderboard = new MissionLeaderboard();
		foreach (Mission item in allMissions)
		{
			isTopListSet = false;
			isUserSet = false;
			currentMissionLeaderboard = new MissionLeaderboard();
			currentMissionLeaderboard.leaderboardName = item.MissionLeaderBoardName;
			Singleton<SteamLeaderboardManager>.Instance.GetLeaderboardDataset(item.MissionLeaderBoardName);
			while (!isTopListSet)
			{
				yield return null;
			}
			while (!isUserSet)
			{
				yield return null;
			}
			MissionLeaderboardsList.Add(currentMissionLeaderboard);
		}
		if (SceneSingleton<GameLeaderboardUIManager>.Instance != null)
		{
			SceneSingleton<GameLeaderboardUIManager>.Instance.RefreshUI();
		}
	}

	public void SetTopLeaderboard(List<LeaderboardData> leaderboardDatas)
	{
		currentMissionLeaderboard.topLeaderboardDataList = leaderboardDatas;
		isTopListSet = true;
	}

	public void SetUserLeaderboard(LeaderboardData leaderboardDatas)
	{
		currentMissionLeaderboard.userLeaderboardData = leaderboardDatas;
		isUserSet = true;
	}

	public void LeaderBoardDownloadState(bool failed)
	{
		if (failed)
		{
			StopAllCoroutines();
		}
	}

	public void UploadScore(string leaderboardName, int score)
	{
		Singleton<SteamLeaderboardManager>.Instance.UploadScore(leaderboardName, score);
	}

	public bool IsUserAccount(string name)
	{
		return Singleton<SteamLeaderboardManager>.Instance.IsUserAccount(name);
	}

	public void IsNewHighScore(int currentRank)
	{
		Object.FindObjectOfType<GameOverMenuManager>().SetNewRank(currentRank);
	}
}
