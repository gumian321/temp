using UnityEngine;

[CreateAssetMenu(fileName = "New Main Drone Reward", menuName = "ScriptableObjects/Rewards/New Main Drone Reward")]
public class MainCoreDroneReward : Reward
{
	[Space]
	[Space]
	[Header("MainCoreDrone Reward Data")]
	public Drone drone;

	public int dronesCount = 1;

	public override bool CanSelectReward()
	{
		if (Singleton<PlayerDataStore>.Instance.CanAddHQDrones(dronesCount))
		{
			return base.CanSelectReward();
		}
		return false;
	}

	public override int GetRewardLevel()
	{
		return Singleton<PlayerDataStore>.Instance.GetLevelUpRewardsCount(drone);
	}

	public override void SelectReward()
	{
		for (int i = 0; i < dronesCount; i++)
		{
			SceneSingleton<PlayerDronesManager>.Instance.AddDrone(drone);
		}
		SceneSingleton<PlayerDronesManager>.Instance.RefreshUI();
	}

	public override bool CanConflictReward(Reward reward)
	{
		if (!(reward is MainCoreDroneReward))
		{
			return false;
		}
		return ((MainCoreDroneReward)reward).drone == drone;
	}

	public override string GetRewardTitle()
	{
		string iDString = Singleton<LocalizationSystem>.Instance.GetIDString("Part_HQ");
		if (dronesCount == 1)
		{
			return string.Format(iDString, drone.GetDroneTitle());
		}
		return "x" + dronesCount + " " + string.Format(iDString, drone.GetDroneTitle());
	}

	public override Sprite GetRewardSprite()
	{
		return drone.droneSprite;
	}

	public override void AddRewardPopUpText()
	{
		string iDString = Singleton<LocalizationSystem>.Instance.GetIDString("PopUpText_HQDrones");
		iDString = string.Format(iDString, drone.GetDroneTitle());
		if (dronesCount == 1)
		{
			SceneSingleton<PopUpTextManager>.Instance.AddPopUpText(iDString);
		}
		else
		{
			SceneSingleton<PopUpTextManager>.Instance.AddPopUpText("x" + dronesCount + " " + iDString);
		}
	}
}
