using System.Collections.Generic;
using UnityEngine;

[CreateAssetMenu(fileName = "New Radar Configuration", menuName = "ScriptableObjects/Radar Configuration/New Random Radar Configuration")]
public class RandomRadarConfiguration : RadarConfiguration
{
	public override Transform GetTarget(List<Transform> targetsList, Vector2 radarPos = default(Vector2), float range = -1f)
	{
		if (targetsList.Count == 0)
		{
			return null;
		}
		if (targetsList.Count == 0)
		{
			return null;
		}
		return targetsList[Random.Range(0, targetsList.Count)];
	}

	public override void SetUpConfiguration()
	{
	}

	public override bool RunConfigurationTargetTest(Transform target, Vector2 radarPos)
	{
		return true;
	}
}
