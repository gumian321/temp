using UnityEngine;

[CreateAssetMenu(fileName = "New Radar Configuration", menuName = "ScriptableObjects/Radar Configuration/New Lowest Health Radar Configuration")]
public class LowestHealthTargetRadarConfiguration : RadarConfiguration
{
	public bool IgnoreShields;

	private float minHealth = 1f;

	public override void SetUpConfiguration()
	{
		minHealth = 1f;
	}

	public override bool RunConfigurationTargetTest(Transform target, Vector2 radarPos)
	{
		if (IgnoreShields && Singleton<DetectionDataStore>.Instance.IsShieldLayer(target.gameObject))
		{
			return false;
		}
		IRepairable component = target.GetComponent<IRepairable>();
		if (component == null)
		{
			return false;
		}
		if (component.IsBeingRepaired())
		{
			return false;
		}
		float damagePercent = component.GetDamagePercent();
		if (damagePercent < minHealth)
		{
			minHealth = damagePercent;
			return true;
		}
		return false;
	}
}
