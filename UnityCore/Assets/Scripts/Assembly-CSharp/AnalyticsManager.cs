using System.Collections.Generic;
using UnityEngine.Analytics;

public class AnalyticsManager : Singleton<AnalyticsManager>
{
	public void SendRunCompletedAnalytics(bool playerWon)
	{
		SceneSingleton<RatingSystemManager>.Instance.GetScoreRatingContainers();
		ScoreRatingContainer scoreContainer = SceneSingleton<RatingSystemManager>.Instance.GetScoreContainer();
		LetterRating scoreRating = SceneSingleton<RatingSystemManager>.Instance.GetScoreRating();
		int num = FBPP.GetInt("runIndex");
		CallEvent("Run Completed", new Dictionary<string, object>
		{
			{ "Index", num },
			{ "isWon", playerWon },
			{
				"Time",
				SceneSingleton<GameHeatManager>.Instance.GetSecondsSurvived()
			},
			{ "Score", scoreContainer.value },
			{
				"Meta",
				Singleton<RatingDataStore>.Instance.GetLetterMetaPoints(scoreRating)
			},
			{
				"Bosses",
				SceneSingleton<RatingSystemManager>.Instance.GetRating(RatingTypes.Boss) / Singleton<RatingDataStore>.Instance.GetRatingTypeValue(RatingTypes.Boss)
			},
			{
				"Parts",
				SceneSingleton<RatingSystemManager>.Instance.GetRating(RatingTypes.PartsBuilt)
			},
			{
				"Packs",
				SceneSingleton<RatingSystemManager>.Instance.GetRating(RatingTypes.PacksOpened) / Singleton<RatingDataStore>.Instance.GetRatingTypeValue(RatingTypes.PacksOpened)
			}
		});
		num++;
		FBPP.SetInt("runIndex", num);
	}

	public void SendRunRestartAnalytics()
	{
		SceneSingleton<RatingSystemManager>.Instance.GetScoreRatingContainers();
		int num = FBPP.GetInt("runIndex");
		CallEvent("Run Restarted", new Dictionary<string, object>
		{
			{ "Index", num },
			{
				"Time",
				SceneSingleton<GameHeatManager>.Instance.GetSecondsSurvived()
			},
			{
				"Bosses",
				SceneSingleton<RatingSystemManager>.Instance.GetRating(RatingTypes.Boss) / Singleton<RatingDataStore>.Instance.GetRatingTypeValue(RatingTypes.Boss)
			},
			{
				"Parts",
				SceneSingleton<RatingSystemManager>.Instance.GetRating(RatingTypes.PartsBuilt)
			},
			{
				"Packs",
				SceneSingleton<RatingSystemManager>.Instance.GetRating(RatingTypes.PacksOpened) / Singleton<RatingDataStore>.Instance.GetRatingTypeValue(RatingTypes.PacksOpened)
			}
		});
		num++;
		FBPP.SetInt("runIndex", num);
	}

	public void CallUserRegisterEvent(GameVersion gameVersion, Platform platform)
	{
		CallEvent("BuildRegistered", new Dictionary<string, object>
		{
			{
				"Game Version",
				gameVersion.ToString()
			},
			{
				"Platform",
				platform.ToString()
			}
		});
	}

	public void CallLabNodeUnlockedEvent(string rewardName)
	{
		int num = FBPP.GetInt("runIndex");
		CallEvent("Lab Node Unlocked", new Dictionary<string, object>
		{
			{ "Run Index", num },
			{ "Reward Name", rewardName }
		});
	}

	public void CallLabHalfUnlockedEvent()
	{
		int num = FBPP.GetInt("runIndex");
		CallEvent("Lab Half Unlocked", new Dictionary<string, object> { { "Run Index", num } });
	}

	public void CallLabFullyUnlockedEvent()
	{
		int num = FBPP.GetInt("runIndex");
		CallEvent("Lab Fully Unlocked", new Dictionary<string, object> { { "Run Index", num } });
	}

	public void CallLabFirstNodeUnlockedEvent()
	{
		int num = FBPP.GetInt("runIndex");
		CallEvent("Lab First Node Unlocked", new Dictionary<string, object> { { "Run Index", num } });
	}

	public void CallResetGameButtonEvent(int TreeNodeUnlocked)
	{
		int num = FBPP.GetInt("runIndex");
		CallEvent("Reset Game Button Pressed", new Dictionary<string, object>
		{
			{ "Run Index", num },
			{ "Nodes Unlocked", TreeNodeUnlocked }
		});
	}

	public void CallDiscordButtonPressedEvent()
	{
		int num = FBPP.GetInt("runIndex");
		CallEvent("Discord Button Pressed", new Dictionary<string, object> { { "Run Index", num } });
	}

	public void CallNewsletterButtonPressedEvent()
	{
		int num = FBPP.GetInt("runIndex");
		CallEvent("Newsletter Button Pressed", new Dictionary<string, object> { { "Run Index", num } });
	}

	public void CallWishListButtonPressedEvent()
	{
		int num = FBPP.GetInt("runIndex");
		CallEvent("WishList Button Pressed", new Dictionary<string, object>
		{
			{ "Run Index", num },
			{
				"Platform",
				Singleton<GameBuildManager>.Instance.GetPlatform().ToString()
			}
		});
	}

	private void CallEvent(string eventName)
	{
		AnalyticsEvent.Custom(eventName);
	}

	private void CallEvent(string eventName, Dictionary<string, object> eventData)
	{
		AnalyticsEvent.Custom(eventName, eventData);
	}
}
