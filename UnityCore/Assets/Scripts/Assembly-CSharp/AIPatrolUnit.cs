using UnityEngine;

[RequireComponent(typeof(SpriteRenderer))]
[RequireComponent(typeof(AIPatrolUnitMovement))]
public class AIPatrolUnit : AIUnitController
{
	[Space]
	private AIPatrolManager aIPatrolManager;

	private AIPatrolUnitMovement aIPatrolUnitMovement;

	public override void BuildUnit()
	{
		base.BuildUnit();
		aIPatrolUnitMovement = GetComponent<AIPatrolUnitMovement>();
		OverrideDamage(SceneSingleton<GameMissionManager>.Instance.enemiesDamageModifier);
		unitObject.SetOnHealthDamageAction(OnHealthDamage);
	}

	public void SetAIPatrolManager(AIPatrolManager aIPatrolManager)
	{
		this.aIPatrolManager = aIPatrolManager;
	}

	public override void DestroyUnit()
	{
		aIPatrolManager.UnitDestroyed(aIPatrolUnitMovement);
		base.DestroyUnit();
	}

	public void OnHealthDamage(float currentHealth)
	{
		aIPatrolManager.StartChasingPlayer();
	}
}
