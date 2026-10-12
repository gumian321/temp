using System.Collections.Generic;
using UnityEngine;

public class RatingDataStore : Singleton<RatingDataStore>
{
	[SerializeField]
	private float MetaPointsModifer = 1.5f;

	[SerializeField]
	public int AIHealthToDestructionRate = 10;

	[SerializeField]
	private List<LetterRating> LetterRatingsList;

	[SerializeField]
	private List<RatingType> RatingTypesList;

	private void Start()
	{
		LetterRatingsList.Sort();
		LetterRatingsList.Reverse();
	}

	public List<RatingType> GetRatingTypes()
	{
		return RatingTypesList;
	}

	public string GetRatingTypeTitle(RatingTypes ratingType)
	{
		foreach (RatingType ratingTypes in RatingTypesList)
		{
			if (ratingTypes.ratingType == ratingType)
			{
				return ratingTypes.title;
			}
		}
		return "Rating_Bonus";
	}

	public int GetRatingTypeValue(RatingTypes ratingType)
	{
		foreach (RatingType ratingTypes in RatingTypesList)
		{
			if (ratingTypes.ratingType == ratingType)
			{
				return ratingTypes.ratingValue;
			}
		}
		return 0;
	}

	public LetterRating GetLetterRating(int totalScore)
	{
		foreach (LetterRating letterRatings in LetterRatingsList)
		{
			if (letterRatings.scoreValue <= totalScore)
			{
				return letterRatings;
			}
		}
		return LetterRatingsList[LetterRatingsList.Count - 1];
	}

	public int GetLetterMetaPoints(LetterRating letterRating)
	{
		return (int)((float)letterRating.metaPoints * MetaPointsModifer);
	}
}
