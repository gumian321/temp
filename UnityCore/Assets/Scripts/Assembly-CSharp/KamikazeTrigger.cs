using UnityEngine;

public class KamikazeTrigger : MonoBehaviour
{
	private DetectionType kamikazeTargetDetectionType = DetectionType.Player;

	private AISwarmingUnit aISwarmingUnit;

	[SerializeField]
	private float explosionArea = 1f;

	[SerializeField]
	private Damage explosionDamage;

	private void Awake()
	{
		aISwarmingUnit = GetComponent<AISwarmingUnit>();
	}

	private void OnTriggerEnter2D(Collider2D other)
	{
		IDetectable component = other.GetComponent<IDetectable>();
		if (component != null && component.IsDetectionType(kamikazeTargetDetectionType))
		{
			other.GetComponent<IDamageable>()?.TakeDamage(explosionDamage.GetDamage(other.gameObject));
			TriggerExplosion();
			aISwarmingUnit.DestroyUnit();
		}
	}

	public void TriggerExplosion()
	{
		ExplosionSystem.TriggerExplosion(explosionArea, base.transform.position, kamikazeTargetDetectionType, explosionDamage);
	}
}
