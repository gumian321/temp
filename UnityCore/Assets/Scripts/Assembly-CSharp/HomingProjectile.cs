using UnityEngine;

[CreateAssetMenu(fileName = "New Homing Projectile", menuName = "ScriptableObjects/Projectiles/New Homing Projectile")]
public class HomingProjectile : Projectile
{
	[Space]
	public float projectileTargetDelay;

	public RadarConfiguration radarConfiguration;

	[Space]
	[Header("Homing Variable")]
	public float maxMovingSpeed;

	public float acceleration;

	[Space]
	public float maxRotSpeed;

	public float rotAcceleration;
}
