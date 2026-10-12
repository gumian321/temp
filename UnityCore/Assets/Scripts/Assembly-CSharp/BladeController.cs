using UnityEngine;

public class BladeController : MonoBehaviour
{
	[SerializeField]
	private DetectionType projectileTargetDetectionType;

	[SerializeField]
	private Damage damage;

	public virtual void OnTriggerEnter2D(Collider2D other)
	{
		IDetectable component = other.GetComponent<IDetectable>();
		if (component != null && component.IsDetectionType(projectileTargetDetectionType))
		{
			TriggerProjectile(other.gameObject);
		}
	}

	public virtual void TriggerProjectile(GameObject target)
	{
		if (!(target == null))
		{
			target.GetComponent<IDamageable>()?.TakeDamage(damage.GetDamage(target.gameObject));
		}
	}
}
