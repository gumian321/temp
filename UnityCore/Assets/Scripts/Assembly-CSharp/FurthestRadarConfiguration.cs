using UnityEngine;

[CreateAssetMenu(fileName = "New Radar Configuration", menuName = "ScriptableObjects/Radar Configuration/New Furthest Target Radar Configuration")]
public class FurthestRadarConfiguration : RadarConfiguration
{
	private float maxDistance;

	public override void SetUpConfiguration()
	{
		maxDistance = 0f;
	}

	public override bool RunConfigurationTargetTest(Transform target, Vector2 radarPos)
	{
		float num = Vector2.Distance(radarPos, target.position);
		if (num > maxDistance)
		{
			maxDistance = num;
			return true;
		}
		return false;
	}
}
