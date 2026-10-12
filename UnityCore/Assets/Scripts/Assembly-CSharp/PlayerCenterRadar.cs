using UnityEngine;

public class PlayerCenterRadar : SceneSingleton<PlayerCenterRadar>
{
	private RadarSystem enemyRadarSystem;

	private RadarSystem playerRadarSystem;

	public void ActivateRadar()
	{
		float radarRange = PlayerDataStore.GetPlayerDetectionRange();
		enemyRadarSystem = MasterPool.Get(PrefabTypes.ShipSystem_Radar, base.transform).GetComponent<RadarSystem>();
		enemyRadarSystem.SetRadarSystem(radarRange, DetectionType.Enemy);
		playerRadarSystem = MasterPool.Get(PrefabTypes.ShipSystem_Radar, base.transform).GetComponent<RadarSystem>();
		playerRadarSystem.SetRadarSystem(radarRange, DetectionType.Player);
	}

	public void UpdateRadars()
	{
		enemyRadarSystem.gameObject.SetActive(value: false);
		enemyRadarSystem.gameObject.SetActive(value: true);
		playerRadarSystem.gameObject.SetActive(value: false);
		playerRadarSystem.gameObject.SetActive(value: true);
	}

	public RadarSystem GetRadarSystem(DetectionType targetDetectionType)
	{
		if (targetDetectionType == DetectionType.Player)
		{
			return playerRadarSystem;
		}
		return enemyRadarSystem;
	}

	public Transform GetTarget(Transform pos, RadarConfiguration rct, DetectionType targetDetectionType, Transform ignoreTarget = null, float range = -1f)
	{
		return targetDetectionType switch
		{
			DetectionType.Player => playerRadarSystem.GetTarget(pos.position, rct, ignoreTarget, range), 
			DetectionType.Enemy => enemyRadarSystem.GetTarget(pos.position, rct, ignoreTarget, range), 
			_ => null, 
		};
	}
}
