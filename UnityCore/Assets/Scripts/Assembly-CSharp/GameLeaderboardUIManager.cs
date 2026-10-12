using System.Collections.Generic;
using UnityEngine;

public class GameLeaderboardUIManager : SceneSingleton<GameLeaderboardUIManager>
{
	[SerializeField]
	private GameObject leaderboardFailedToLoadText;

	[SerializeField]
	private GameObject leaderboardEmptyText;

	[Space]
	[SerializeField]
	private List<LeaderboardUIContainer> leaderboardUIContainersList;

	[SerializeField]
	private LeaderboardUIContainer userLeaderboardUIContainers;

	private bool isUserAccountInTop;

	public void LoadMissionLeaderboard(Mission mission)
	{
		ResetLeaderboardUI();
		if (Singleton<GameLeaderboardManager>.Instance == null)
		{
			return;
		}
		MissionLeaderboard missionLeaderboard = Singleton<GameLeaderboardManager>.Instance.GetMissionLeaderboard(mission);
		if (missionLeaderboard != null)
		{
			if (missionLeaderboard.topLeaderboardDataList.Count == 0)
			{
				leaderboardEmptyText.SetActive(value: true);
				return;
			}
			SetTopLeaderboard(missionLeaderboard.topLeaderboardDataList);
			if (!isUserAccountInTop)
			{
				SetUserLeaderboard(missionLeaderboard.userLeaderboardData);
			}
		}
		else
		{
			leaderboardFailedToLoadText.SetActive(value: true);
		}
	}

	public void RefreshUI()
	{
		LoadMissionLeaderboard(Singleton<MissionDataStore>.Instance.GetCurrentMission());
	}

	public void ResetLeaderboardUI()
	{
		leaderboardFailedToLoadText.SetActive(value: false);
		leaderboardEmptyText.SetActive(value: false);
		isUserAccountInTop = false;
		foreach (LeaderboardUIContainer leaderboardUIContainers in leaderboardUIContainersList)
		{
			leaderboardUIContainers.gameObject.SetActive(value: false);
		}
		userLeaderboardUIContainers.gameObject.SetActive(value: false);
	}

	public void SetTopLeaderboard(List<LeaderboardData> leaderboardDataList)
	{
		for (int i = 0; i < leaderboardDataList.Count; i++)
		{
			if (Singleton<GameLeaderboardManager>.Instance.IsUserAccount(leaderboardDataList[i].username))
			{
				isUserAccountInTop = true;
			}
			leaderboardUIContainersList[i].SetContainer(leaderboardDataList[i]);
		}
	}

	public void SetUserLeaderboard(LeaderboardData leaderboardData)
	{
		if (Singleton<GameLeaderboardManager>.Instance.IsUserAccount(leaderboardData.username))
		{
			userLeaderboardUIContainers.SetContainer(leaderboardData);
		}
	}
}
