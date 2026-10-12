using System;
using UnityEngine;

[Serializable]
public class MissionObjective
{
	public DifficultyTypes missionDiffeculty;

	[Space]
	public Sprite objectiveSprite;

	public float objectiveTime = 600f;

	public GameObject objectivePrefab;

	public MissionAIConfiguration objectiveAIConfiguration;

	public string objectiveACHID;
}
