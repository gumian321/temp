using System;
using UnityEngine;

[Serializable]
public class SwarmingAIHeat
{
	public PrefabTypes AIPrefab;

	[Range(0f, 1f)]
	public float entryHeatPercent;

	[Range(0f, 1f)]
	public float exitHeatPercent;

	public int probablity;

	public bool IsHeatSuitable(float heatPercentage)
	{
		if (entryHeatPercent <= heatPercentage)
		{
			return exitHeatPercent >= heatPercentage;
		}
		return false;
	}
}
