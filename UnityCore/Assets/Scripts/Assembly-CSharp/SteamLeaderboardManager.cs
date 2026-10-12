using System.Collections;
using System.Collections.Generic;
using Steamworks;
using UnityEngine;

public class SteamLeaderboardManager : Singleton<SteamLeaderboardManager>
{
	public bool isSteamInitialized;

	private SteamLeaderboard_t currnetLeaderboard;

	private bool leaderBoardFound;

	private bool findLeaderboardCallCompleted;

	[SerializeField]
	private int entriesToLoad = 8;

	private void Start()
	{
		isSteamInitialized = SteamManager.Initialized;
		if (isSteamInitialized && Singleton<GameLeaderboardManager>.Instance != null)
		{
			Singleton<GameLeaderboardManager>.Instance.LoadAllLeaderboards();
		}
	}

	public void FindLeaderBoard(string leaderboardName)
	{
		currnetLeaderboard = default;
		findLeaderboardCallCompleted = false;
		SteamAPICall_t hAPICall = SteamUserStats.FindLeaderboard(leaderboardName);
		CallResult<LeaderboardFindResult_t>.Create().Set(hAPICall, (LeaderboardFindResult_t leaderboardFindResult, bool failure) =>
		{
			if (!failure && leaderboardFindResult.m_bLeaderboardFound == 1)
			{
				currnetLeaderboard = leaderboardFindResult.m_hSteamLeaderboard;
				leaderBoardFound = true;
			}
			else
			{
				leaderBoardFound = false;
			}
			findLeaderboardCallCompleted = true;
		});
	}

	public void UploadScore(string leaderboardName, int score)
	{
		StopAllCoroutines();
		StartCoroutine(UploadLeaderBoardScore(leaderboardName, score));
	}

	public bool IsUserAccount(string name)
	{
		return SteamFriends.GetPersonaName() == name;
	}

	public IEnumerator UploadLeaderBoardScore(string leaderboardName, int score)
	{
		FindLeaderBoard(leaderboardName);
		while (!findLeaderboardCallCompleted)
		{
			yield return null;
		}
		if (!leaderBoardFound)
		{
			MonoBehaviour.print("Error finding leaderboard.");
			yield break;
		}
		bool error = false;
		LeaderboardScoreUploaded_t leaderboardScore = default;
		bool uploadLeaderboardScoreCallCompleted = false;
		SteamAPICall_t hAPICall = SteamUserStats.UploadLeaderboardScore(currnetLeaderboard, ELeaderboardUploadScoreMethod.k_ELeaderboardUploadScoreMethodKeepBest, score, new int[0], 0);
		CallResult<LeaderboardScoreUploaded_t>.Create().Set(hAPICall, (LeaderboardScoreUploaded_t scoreUploadedResult, bool failure) =>
		{
			if (!failure && scoreUploadedResult.m_bSuccess == 1)
			{
				leaderboardScore = scoreUploadedResult;
			}
			else
			{
				error = true;
			}
			uploadLeaderboardScoreCallCompleted = true;
		});
		while (!uploadLeaderboardScoreCallCompleted)
		{
			yield return null;
		}
		if (error)
		{
			MonoBehaviour.print("Error uploading to leaderboard.");
		}
		else if (leaderboardScore.m_bScoreChanged == 1)
		{
			Singleton<GameLeaderboardManager>.Instance.IsNewHighScore(leaderboardScore.m_nGlobalRankNew);
		}
	}

	public void GetLeaderboardDataset(string leaderBoardName)
	{
		StartCoroutine(LoadLeaderboardDataset(leaderBoardName, entriesToLoad));
	}

	public IEnumerator LoadLeaderboardDataset(string leaderboardName, int entries = 8)
	{
		FindLeaderBoard(leaderboardName);
		while (!findLeaderboardCallCompleted)
		{
			yield return null;
		}
		if (!leaderBoardFound)
		{
			MonoBehaviour.print("Error finding leaderboard " + leaderboardName);
			yield break;
		}
		SteamAPICall_t hAPICall = SteamUserStats.DownloadLeaderboardEntries(currnetLeaderboard, ELeaderboardDataRequest.k_ELeaderboardDataRequestGlobal, 1, entries);
		CallResult<LeaderboardScoresDownloaded_t>.Create().Set(hAPICall, OnLeaderboardDownloadResult);
		hAPICall = SteamUserStats.DownloadLeaderboardEntries(currnetLeaderboard, ELeaderboardDataRequest.k_ELeaderboardDataRequestGlobalAroundUser, 1, 1);
		CallResult<LeaderboardScoresDownloaded_t>.Create().Set(hAPICall, OnLeaderboardUserDownloadResult);
	}

	private void OnLeaderboardDownloadResult(LeaderboardScoresDownloaded_t pCallback, bool failure)
	{
		Singleton<GameLeaderboardManager>.Instance.LeaderBoardDownloadState(failure);
		if (!failure)
		{
			List<LeaderboardData> list = new List<LeaderboardData>();
			LeaderboardData item = default;
			for (int i = 0; i < pCallback.m_cEntryCount; i++)
			{
				SteamUserStats.GetDownloadedLeaderboardEntry(pCallback.m_hSteamLeaderboardEntries, i, out var pLeaderboardEntry, null, 0);
				item.username = SteamFriends.GetFriendPersonaName(pLeaderboardEntry.m_steamIDUser);
				item.userAvatar = SteamUtilsManager.GetSteamAvatar(pLeaderboardEntry.m_steamIDUser);
				item.rank = pLeaderboardEntry.m_nGlobalRank;
				item.score = pLeaderboardEntry.m_nScore;
				list.Add(item);
			}
			Singleton<GameLeaderboardManager>.Instance.SetTopLeaderboard(list);
		}
	}

	private void OnLeaderboardUserDownloadResult(LeaderboardScoresDownloaded_t pCallback, bool failure)
	{
		Singleton<GameLeaderboardManager>.Instance.LeaderBoardDownloadState(failure);
		if (!failure)
		{
			SteamUserStats.GetDownloadedLeaderboardEntry(pCallback.m_hSteamLeaderboardEntries, 0, out var pLeaderboardEntry, null, 0);
			LeaderboardData userLeaderboard = default;
			userLeaderboard.username = SteamFriends.GetFriendPersonaName(pLeaderboardEntry.m_steamIDUser);
			userLeaderboard.userAvatar = SteamUtilsManager.GetSteamAvatar(pLeaderboardEntry.m_steamIDUser);
			userLeaderboard.rank = pLeaderboardEntry.m_nGlobalRank;
			userLeaderboard.score = pLeaderboardEntry.m_nScore;
			Singleton<GameLeaderboardManager>.Instance.SetUserLeaderboard(userLeaderboard);
		}
	}
}
