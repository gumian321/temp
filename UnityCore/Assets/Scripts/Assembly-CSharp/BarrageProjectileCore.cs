using UnityEngine;

[CreateAssetMenu(fileName = "New Barrage Core", menuName = "ScriptableObjects/New Core/Barrage Core")]
public class BarrageProjectileCore : ProjectileCore
{
	[Space]
	public float barrageInterval = 0.1f;

	public int barrageProjectileCount = 10;
}
