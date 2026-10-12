using UnityEngine;

public class LineProjectileController : ProjectileController
{
	private LineRenderer projectileLineRenderer;

	public override void SetProjectile(Projectile projectile, DetectionType turretTargetDetectionType, ChipsContainer chipsContainer = null, Transform projectileTarget = null)
	{
		chainTargetJumpCount = projectile.targetPiercingCount - 1;
		base.SetProjectile(projectile, turretTargetDetectionType, chipsContainer, projectileTarget);
		SetUpLineRenderer();
		Invoke("ActivateProjectile", 0.05f);
	}

	private void ActivateProjectile()
	{
		if (projectileTarget != null)
		{
			if (Singleton<DetectionDataStore>.Instance.IsShieldLayer(projectileTarget.gameObject))
			{
				chainTargetJumpCount = 0;
				targetsCount = 0;
			}
			ActivateChips(projectileTarget.gameObject);
			TriggerProjectile(projectileTarget.gameObject);
		}
	}

	public override void CheckChips()
	{
		isChipsActivated = true;
		if (IsChipActive(ChipTypes.Chain))
		{
			chainTargetJumpCount += Singleton<ChipsDataStore>.Instance.GetChainTargetJumpCount(chipsContainer.GetChipLevel(ChipTypes.Chain));
		}
		if (IsChipActive(ChipTypes.Piercing))
		{
			chainTargetJumpCount += Singleton<ChipsDataStore>.Instance.GetPiercingTargetCount(chipsContainer.GetChipLevel(ChipTypes.Piercing));
		}
		if (projectileLineRenderer == null)
		{
			projectileLineRenderer = GetComponent<LineRenderer>();
		}
		if (IsChipActive(ChipTypes.Mammoth))
		{
			float mammothProjectileSize = Singleton<ChipsDataStore>.Instance.GetMammothProjectileSize(1f, chipsContainer.GetChipLevel(ChipTypes.Mammoth));
			projectileLineRenderer.SetWidth(mammothProjectileSize, mammothProjectileSize);
		}
		else
		{
			projectileLineRenderer.SetWidth(1f, 1f);
		}
	}

	private void SetUpLineRenderer()
	{
		if (!(projectileTarget == null) && !(projectileTransform == null))
		{
			Vector3 position = projectileTarget.position;
			Vector3 position2 = projectileTransform.position;
			projectileLineRenderer = GetComponent<LineRenderer>();
			projectileLineRenderer.SetPosition(0, position2);
			if (Singleton<DetectionDataStore>.Instance.IsShieldLayer(projectileTarget.gameObject))
			{
				float num = Vector3.Distance(position, position2);
				float projectileShieldHitPoint = projectileTarget.GetComponent<ShieldController>().GetProjectileShieldHitPoint();
				Vector3 vector = MoveByDistance(position2, position, num - projectileShieldHitPoint);
				position = ((!(Vector3.Distance(position2, position) < Vector3.Distance(vector, position))) ? vector : position2);
				projectileLineRenderer.SetPosition(1, position);
				ParticlesSystem.PlayProjectieShieldImpactParticle(position);
			}
			else
			{
				projectileLineRenderer.SetPosition(1, position);
				ParticlesSystem.PlayProjectileImpactParticle(position);
			}
		}
	}

	public Vector3 MoveByDistance(Vector3 point1, Vector3 point2, float distance)
	{
		return distance * Vector3.Normalize(point2 - point1) + point1;
	}
}
