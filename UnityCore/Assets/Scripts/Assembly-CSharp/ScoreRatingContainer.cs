using System;

[Serializable]
public class ScoreRatingContainer
{
	public string title;

	public int value;

	public ScoreRatingContainer(string title, int value)
	{
		this.title = title;
		this.value = value;
	}
}
