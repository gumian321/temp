using System.Collections.Generic;
using UnityEngine;

public class DemoBuildManager : Singleton<DemoBuildManager>
{
	[SerializeField]
	private List<Reward> avilableDemoRewardsList;

	[SerializeField]
	private List<Mission> avilableDemoMissionsList;

	private bool isDemoEnabled;

	public void StartDemo()
	{
		isDemoEnabled = true;
	}

	public bool IsDemoEnabled()
	{
		return isDemoEnabled;
	}

	public bool IsRewardAvilable(Reward reward)
	{
		return avilableDemoRewardsList.Contains(reward);
	}

	public bool IsMissionAvilable(Mission mission)
	{
		return avilableDemoMissionsList.Contains(mission);
	}
}
