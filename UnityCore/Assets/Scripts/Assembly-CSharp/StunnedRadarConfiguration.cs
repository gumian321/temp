using UnityEngine;

[CreateAssetMenu(fileName = "New Radar Configuration", menuName = "ScriptableObjects/Radar Configuration/New Stunned Target Radar Configuration")]
public class StunnedRadarConfiguration : RadarConfiguration
{
	public override void SetUpConfiguration()
	{
	}

	public override bool RunConfigurationTargetTest(Transform target, Vector2 radarPos)
	{
		if (target.GetComponent<IStunnable>() != null)
		{
			return true;
		}
		return false;
	}
}
