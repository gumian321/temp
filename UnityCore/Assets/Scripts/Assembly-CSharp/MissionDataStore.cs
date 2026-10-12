using System.Collections.Generic;
using UnityEngine;

public class MissionDataStore : Singleton<MissionDataStore>
{
	[SerializeField]
	private List<Mission> missionsList;

	private Mission currentMission;

	private MissionObjective currentMissionObjective;

	private Difficulty currentMissionDifficulty;

	[SerializeField]
	private List<Difficulty> DifficultiesList;

	private void OnEnable()
	{
		Singleton<MissionDataStore>.Instance.RefreshData();
	}

	public void RefreshData()
	{
		currentMissionDifficulty = DifficultiesList[GetCurrentMissionDifficultyIndex()];
		if (currentMission == null)
		{
			currentMission = missionsList[GetCurrentMissionIndex()];
		}
		currentMissionObjective = currentMission.MissionsObjectiveList[(int)currentMissionDifficulty.difficultyType];
	}

	public Mission GetCurrentMission()
	{
		return currentMission;
	}

	public int GetCurrentMissionIndex()
	{
		return PlayerPrefs.GetInt("CurrentMissionPlayCanvas", 0);
	}

	public Mission GetCurrentMission(int index)
	{
		return missionsList[index];
	}

	public List<Mission> GetAllMissions()
	{
		return missionsList;
	}

	public int GetMissionsCount()
	{
		return missionsList.Count;
	}

	public void SetCurrentMission(int index)
	{
		PlayerPrefs.SetInt("CurrentMissionPlayCanvas", index);
		currentMission = missionsList[index];
		currentMissionObjective = currentMission.MissionsObjectiveList[(int)currentMissionDifficulty.difficultyType];
	}

	public void SetTestingMission(Mission testingMission, DifficultyTypes testingDifficulty)
	{
		currentMission = testingMission;
		currentMissionObjective = currentMission.MissionsObjectiveList[(int)testingDifficulty];
	}

	public MissionObjective GetCurrentMissionObjective()
	{
		return currentMissionObjective;
	}

	public bool IsAllMissionUnlocked()
	{
		foreach (Mission missions in missionsList)
		{
			if (!missions.IsMissionUnlocked())
			{
				return false;
			}
		}
		return true;
	}

	public Difficulty GetCurrentMissionDifficulty()
	{
		return currentMissionDifficulty;
	}

	public int GetCurrentMissionDifficultyIndex()
	{
		return PlayerPrefs.GetInt("Difficulty Type", 1);
	}

	public string GetDifficultyText(DifficultyTypes difficulty)
	{
		foreach (Difficulty difficulties in DifficultiesList)
		{
			if (difficulty == difficulties.difficultyType)
			{
				return Singleton<LocalizationSystem>.Instance.GetIDString(difficulties.diffecultyTextID);
			}
		}
		return Singleton<LocalizationSystem>.Instance.GetIDString(DifficultiesList[0].diffecultyTextID);
	}

	public int GetDifficultyCount()
	{
		return DifficultiesList.Count;
	}

	public void SetMissionDifficulty(int difficultyType)
	{
		PlayerPrefs.SetInt("Difficulty Type", difficultyType);
		currentMissionDifficulty = DifficultiesList[difficultyType];
		currentMissionObjective = currentMission.MissionsObjectiveList[(int)currentMissionDifficulty.difficultyType];
	}
}
