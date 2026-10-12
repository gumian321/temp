using UnityEngine;

public class ProjectileTimeDisabler : MonoBehaviour
{
	private ProjectileController projectileController;

	protected float timer;

	public void SetTimer(ProjectileController projectileController, float time)
	{
		this.projectileController = projectileController;
		timer = Time.time + time;
	}

	public virtual void FixedUpdate()
	{
		if (timer < Time.time)
		{
			projectileController.DisableProjectile();
		}
	}
}
