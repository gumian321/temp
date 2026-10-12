using System;

[Serializable]
public class LetterRating : IComparable<LetterRating>
{
	public string title;

	public int scoreValue;

	public int metaPoints;

	public int CompareTo(LetterRating that)
	{
		return scoreValue.CompareTo(that.scoreValue);
	}
}
