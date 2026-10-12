using System.Collections.Generic;
using System.Linq;

public class RatingSystemManager : SceneSingleton<RatingSystemManager>
{
	private List<ScoreRatingContainer> scoreRatingsList;

	private ScoreRatingContainer scoreContainer;

	private LetterRating scoreRating;

	private Dictionary<RatingTypes, int> ratingsScoresDict;

	public List<ScoreRatingContainer> GetScoreRatingContainers()
	{
		return scoreRatingsList;
	}

	public ScoreRatingContainer GetScoreContainer()
	{
		return scoreContainer;
	}

	public int GetTotalScore()
	{
		return scoreContainer.value;
	}

	public LetterRating GetScoreRating()
	{
		return scoreRating;
	}

	public void RefreshSystem()
	{
		ratingsScoresDict = new Dictionary<RatingTypes, int>();
		foreach (RatingType ratingType in Singleton<RatingDataStore>.Instance.GetRatingTypes())
		{
			ratingsScoresDict.Add(ratingType.ratingType, 0);
		}
	}

	public void AddRating(RatingTypes ratingTypes, int value = -1)
	{
		if (value == -1)
		{
			value = Singleton<RatingDataStore>.Instance.GetRatingTypeValue(ratingTypes);
		}
		ratingsScoresDict[ratingTypes] += value;
	}

	public void ClearRating(RatingTypes ratingTypes)
	{
		ratingsScoresDict[ratingTypes] = 0;
	}

	public int GetRating(RatingTypes ratingTypes)
	{
		return ratingsScoresDict[ratingTypes];
	}

	public bool IsRatingCompleted(RatingTypes ratingTypes)
	{
		return ratingsScoresDict[ratingTypes] != 0;
	}

	public int GetWonMetaPoints()
	{
		return Singleton<RatingDataStore>.Instance.GetLetterMetaPoints(scoreRating);
	}

	public void CalculateScoreRatings(bool playerWon)
	{
		SceneSingleton<GameMissionManager>.Instance.CalculateScoreRatings(playerWon);
		int num = ratingsScoresDict.Values.Sum();
		scoreContainer = new ScoreRatingContainer("GameOver_Score", num);
		scoreRating = Singleton<RatingDataStore>.Instance.GetLetterRating(num);
		scoreRatingsList = new List<ScoreRatingContainer>();
		foreach (KeyValuePair<RatingTypes, int> item in ratingsScoresDict)
		{
			if (item.Value != 0)
			{
				ScoreRatingContainer scoreRatingContainer = new ScoreRatingContainer(Singleton<RatingDataStore>.Instance.GetRatingTypeTitle(item.Key), item.Value);
				if (item.Key == RatingTypes.TimeSurvived)
				{
					scoreRatingContainer.title = Singleton<LocalizationSystem>.Instance.GetIDString(scoreRatingContainer.title);
					scoreRatingContainer.title = scoreRatingContainer.title + " " + SceneSingleton<GameTimeManager>.Instance.GetTimeSurvived();
				}
				scoreRatingsList.Add(scoreRatingContainer);
			}
		}
	}
}
