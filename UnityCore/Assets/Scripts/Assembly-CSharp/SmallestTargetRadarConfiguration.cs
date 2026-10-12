using UnityEngine;

[CreateAssetMenu(fileName = "New Radar Configuration", menuName = "ScriptableObjects/Radar Configuration/New Smallest Target Radar Configuration")]
public class SmallestTargetRadarConfiguration : RadarConfiguration
{
	private float minhealth;

	public override void SetUpConfiguration()
	{
		minhealth = 9999f;
	}

	public override bool RunConfigurationTargetTest(Transform target, Vector2 radarPos)
	{
		IDamageable component = target.GetComponent<IDamageable>();
		if (component == null)
		{
			return false;
		}
		float maxHealth = component.GetMaxHealth();
		if (maxHealth < minhealth)
		{
			minhealth = maxHealth;
			return true;
		}
		return false;
	}
}
