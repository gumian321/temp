using UnityEngine;

[CreateAssetMenu(fileName = "New SonicWave Projectile", menuName = "ScriptableObjects/Projectiles/New SonicWave Projectile")]
public class SonicBasicProjectile : BasicProjectile
{
	public float sonicWaveLength = 4f;

	public float pushBackForce;
}
