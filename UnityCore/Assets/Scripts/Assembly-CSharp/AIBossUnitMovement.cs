using System.Collections.Generic;
using UnityEngine;

public class AIBossUnitMovement : AISwarmingUnitMovement, IBossBoost
{
	private AIBossUnit aIBossUnit;

	[SerializeField]
	private List<Engine> enginesList;

	[SerializeField]
	private float boostEnginePower = 5f;

	[SerializeField]
	private float speedDecreaseModifier = 0.75f;

	[Space]
	[Header("Heat Speed")]
	[SerializeField]
	private bool changeSpeedWithHeat;

	[SerializeField]
	private float speedAfterTimerModifier;

	private bool isBoostOn;

	private void Start()
	{
		aIBossUnit = GetComponent<AIBossUnit>();
	}

	public void AllowChangeSpeedWithHeat()
	{
		changeSpeedWithHeat = true;
	}

	public void ChangeSpeed(float percent)
	{
		if (changeSpeedWithHeat && !isBoostOn)
		{
			movingSpeed = enginePower * percent;
			rotSpeed = enginePower * rotEngineModifier * percent;
			if (percent > 1f)
			{
				movingSpeed *= speedAfterTimerModifier;
				rotSpeed *= speedAfterTimerModifier;
			}
		}
	}

	public void ActivateBoost()
	{
		isBoostOn = true;
		TweenController.DOFloat(movingSpeed, enginePower + boostEnginePower, TweenDuration.Short, (float speed) =>
		{
			movingSpeed = speed;
		});
		rotSpeed = 0f;
		foreach (Engine engines in enginesList)
		{
			engines.SetEngineBoostState(state: true);
		}
	}

	public bool CanBoost()
	{
		return aIBossUnit.isBossActivated;
	}

	public void DeactivateBoost()
	{
		isBoostOn = false;
		TweenController.DOFloat(enginePower + boostEnginePower, enginePower, TweenDuration.Short, (float speed) =>
		{
			movingSpeed = speed;
		});
		rotSpeed = enginePower * rotEngineModifier;
		foreach (Engine engines in enginesList)
		{
			engines.SetEngineBoostState(state: false);
		}
	}
}
