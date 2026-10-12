using UnityEngine;

[CreateAssetMenu(fileName = "New Radar Configuration", menuName = "ScriptableObjects/Radar Configuration/New Biggest Target Radar Configuration")]
public class BiggestTargetRadarConfiguration : RadarConfiguration
{
	private float maxhealth;

	public override void SetUpConfiguration()
	{
		maxhealth = 0f;
	}

	public override bool RunConfigurationTargetTest(Transform target, Vector2 radarPos)
	{
		IDamageable component = target.GetComponent<IDamageable>();
		if (component == null)
		{
			return false;
		}
		float maxHealth = component.GetMaxHealth();
		if (maxHealth > maxhealth)
		{
			maxhealth = maxHealth;
			return true;
		}
		return false;
	}
}
