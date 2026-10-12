using UnityEngine;

public class HomingProjectileController : ProjectileController
{
	private Transform targetTransform;

	[SerializeField]
	private TrailRenderer trailRenderer;

	private float maxMovingSpeed;

	private float acceleration;

	[SerializeField]
	private float currentMovingSpeed;

	[Space]
	private float maxRotSpeed;

	private float rotAcceleration;

	[SerializeField]
	private float currentRotSpeed;

	private HomingProjectile p;

	private bool activateProjectile;

	private RadarSystem radarSystem;

	public override void SetProjectile(Projectile projectile, DetectionType turretTargetDetectionType, ChipsContainer chipsContainer = null, Transform projectileTarget = null)
	{
		base.SetProjectile(projectile, turretTargetDetectionType, chipsContainer, projectileTarget);
		if (trailRenderer != null)
		{
			trailRenderer.Clear();
		}
		p = (HomingProjectile)projectile;
		maxMovingSpeed = p.maxMovingSpeed;
		acceleration = p.acceleration;
		maxRotSpeed = p.maxRotSpeed;
		rotAcceleration = p.rotAcceleration;
		radarSystem = SceneSingleton<PlayerCenterRadar>.Instance.GetRadarSystem(turretTargetDetectionType);
		activateProjectile = false;
		Invoke("ActivateProjectile", p.projectileTargetDelay);
	}

	private void ActivateProjectile()
	{
		activateProjectile = true;
		targetTransform = null;
		GetNewTarget();
	}

	public override void FixedUpdate()
	{
		base.FixedUpdate();
		if (activateProjectile)
		{
			if (targetTransform != null)
			{
				if (!targetTransform.gameObject.activeSelf)
				{
					GetNewTarget();
				}
				else
				{
					RotateProjectile();
				}
			}
			else
			{
				GetNewTarget();
			}
		}
		MoveProjectile();
	}

	private void GetNewTarget()
	{
		targetTransform = radarSystem.GetTarget(projectileTransform.position, p.radarConfiguration);
	}

	private void MoveProjectile()
	{
		if (projectileTransform == null)
		{
			DisableProjectile();
			return;
		}
		currentMovingSpeed = Mathf.Lerp(currentMovingSpeed, maxMovingSpeed, acceleration * Time.fixedDeltaTime);
		projectileTransform.Translate(Vector3.up * currentMovingSpeed * Time.fixedDeltaTime);
	}

	private void RotateProjectile()
	{
		Vector3 vector = projectileTransform.position - targetTransform.position;
		Quaternion to = Quaternion.AngleAxis(Mathf.Atan2(vector.y, vector.x) * 57.29578f + 90f, Vector3.forward);
		currentRotSpeed = Mathf.Lerp(currentRotSpeed, maxRotSpeed, rotAcceleration * Time.fixedDeltaTime);
		projectileTransform.rotation = Quaternion.RotateTowards(projectileTransform.rotation, to, currentRotSpeed * Time.fixedDeltaTime);
	}
}
