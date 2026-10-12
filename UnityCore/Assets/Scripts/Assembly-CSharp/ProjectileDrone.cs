using UnityEngine;

[CreateAssetMenu(fileName = "New Projectile Drone", menuName = "ScriptableObjects/Drones/New Projectile Drone")]
public class ProjectileDrone : Drone
{
	[Header("Projectile Drone Variables")]
	public Projectile droneProjectile;

	public float droneRateOfFire;

	public float GetDroneRateOfFire(float percent = 0f)
	{
		return UnityEngineSystem.GetPerSecAmount(droneRateOfFire, percent);
	}

	public override ChipsContainer GetCoreChipsContainer()
	{
		return droneProjectile.activatableChips;
	}
}
