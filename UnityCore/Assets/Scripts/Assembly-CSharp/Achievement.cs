using System;

[Serializable]
public class Achievement
{
	public AchievementTypes achievementType;

	public int completedAmount;

	public Action completedAction;

	public Achievement(AchievementTypes achievementType, int completedAmount, Action completedAction)
	{
		this.achievementType = achievementType;
		this.completedAmount = completedAmount;
		this.completedAction = completedAction;
	}
}
