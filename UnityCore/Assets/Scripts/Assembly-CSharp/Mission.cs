using System.Collections.Generic;
using UnityEngine;

[CreateAssetMenu(fileName = "New Mission", menuName = "ScriptableObjects/Missions/New Mission")]
public class Mission : ScriptableObject
{
	[Space]
	public string MissionLeaderBoardName;

	[Space]
	[Header("Strings")]
	public string MissionNameTextID;

	public string MissionDescTextID;

	[Space]
	[Header("Mission Main Arrow")]
	public Sprite MissionArrowIcon;

	public Color MissionArrowColor;

	[Space]
	[Header("Values")]
	public int MissionCost;

	[Space]
	[Header("Mission Rating")]
	public bool CanBeCompleted = true;

	[Space]
	public List<MissionObjective> MissionsObjectiveList = new List<MissionObjective>
	{
		new MissionObjective(),
		new MissionObjective(),
		new MissionObjective()
	};

	[Space]
	[Header("Timers")]
	public bool isEndless;

	public bool hasTimer;

	public bool isTimeEndCondition;

	public bool isPlayerWinWhenTimerIsOver;

	public bool isTimerCountingDown;

	[Space]
	public bool hasDistanceCounter;

	public bool hasBossBars;

	[Space]
	[Header("Camera")]
	public bool isOffsetPlayer;

	public float playerYOffset;

	public float cameraTargetSizeOffset = -1f;

	public bool CanUnlockMission()
	{
		return Singleton<MetaEconomySystem>.Instance.CanSpendMetaPoints(MissionCost);
	}

	public void UnlockMission()
	{
		Singleton<MetaEconomySystem>.Instance.ModifyMetaPoints(-MissionCost);
		SaveSystem.UnlockSystem(base.name);
	}

	public bool IsMissionUnlocked()
	{
		if (Singleton<GameBuildManager>.Instance != null && Singleton<GameBuildManager>.Instance.IsSteamBeta())
		{
			return true;
		}
		if (!SaveSystem.IsSystemUnlocked(base.name))
		{
			return MissionCost == 0;
		}
		return true;
	}
}
