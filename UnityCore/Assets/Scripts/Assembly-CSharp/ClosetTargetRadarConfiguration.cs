using UnityEngine;

[CreateAssetMenu(fileName = "New Radar Configuration", menuName = "ScriptableObjects/Radar Configuration/New Closet Target Radar Configuration")]
public class ClosetTargetRadarConfiguration : RadarConfiguration
{
	private float minDistance;

	public override void SetUpConfiguration()
	{
		minDistance = 9999f;
	}

	public override bool RunConfigurationTargetTest(Transform target, Vector2 radarPos)
	{
		float num = Vector2.Distance(radarPos, target.position);
		if (num < minDistance)
		{
			minDistance = num;
			return true;
		}
		return false;
	}
}
