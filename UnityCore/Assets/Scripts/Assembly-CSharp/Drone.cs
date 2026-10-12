using UnityEngine;

[CreateAssetMenu(fileName = "New Drone", menuName = "ScriptableObjects/Drones/New Basic Drone")]
public class Drone : ScriptableObject
{
	[SerializeField]
	private string droneNameID;

	public Sprite droneSprite;

	public PrefabTypes dronePrefab;

	public RangeType droneRange;

	[Space]
	[Header("Drone Variable")]
	public RadarConfiguration droneRadarConfiguration;

	public AudioClipTypes droneActionAudioType;

	[Space]
	public float droneActionRange;

	public float droneCoreStopDistance = 0.3f;

	[Space]
	[SerializeField]
	private float droneTargetPingDelay = 2f;

	[Space]
	[Header("Moving Variable")]
	public float maxMovingSpeed;

	public float acceleration;

	[Space]
	public float maxRotSpeed;

	public float rotAcceleration;

	[Space]
	public float slowingDownDis;

	public float GetDroneRange(float percent = 0f)
	{
		return UnityEngineSystem.CalcPercent(TurretsDataStore.GetTurretRange(droneRange), percent);
	}

	public string GetDroneTitle()
	{
		return Singleton<LocalizationSystem>.Instance.GetIDString(droneNameID);
	}

	public WaitForSeconds GetDroneTargetPingNewDelay()
	{
		return new WaitForSeconds(droneTargetPingDelay);
	}

	public virtual ChipsContainer GetCoreChipsContainer()
	{
		return null;
	}
}
