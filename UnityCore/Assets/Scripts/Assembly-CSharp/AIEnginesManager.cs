using System.Collections.Generic;
using UnityEngine;

public class AIEnginesManager : MonoBehaviour
{
	public enum MovingDirection
	{
		None = 0,
		Up = 1,
		Down = 2,
		Left = 3,
		Right = 4
	}

	[Header("Engines")]
	private MovingDirection _movingRight;

	private MovingDirection _movingUp;

	[SerializeField]
	private List<Engine> leftEngines;

	[SerializeField]
	private List<Engine> rightEngines;

	[SerializeField]
	private List<Engine> upEngines;

	[SerializeField]
	private List<Engine> downEngines;

	private Vector3 lastMoveDirection;

	private Vector3 previousPosition;

	private MovingDirection movingRight
	{
		get
		{
			return _movingRight;
		}
		set
		{
			if (_movingRight != value)
			{
				_movingRight = value;
				if (_movingRight == MovingDirection.None)
				{
					UpdateEnginesStates(leftEngines, state: false);
					UpdateEnginesStates(rightEngines, state: false);
				}
				else if (_movingRight == MovingDirection.Right)
				{
					UpdateEnginesStates(leftEngines, state: false);
					UpdateEnginesStates(rightEngines, state: true);
				}
				else if (_movingRight == MovingDirection.Left)
				{
					UpdateEnginesStates(leftEngines, state: true);
					UpdateEnginesStates(rightEngines, state: false);
				}
			}
		}
	}

	private MovingDirection movingUp
	{
		get
		{
			return _movingUp;
		}
		set
		{
			if (_movingUp != value)
			{
				_movingUp = value;
				if (_movingUp == MovingDirection.None)
				{
					UpdateEnginesStates(downEngines, state: false);
					UpdateEnginesStates(upEngines, state: false);
				}
				else if (_movingUp == MovingDirection.Up)
				{
					UpdateEnginesStates(downEngines, state: false);
					UpdateEnginesStates(upEngines, state: true);
				}
				else if (_movingUp == MovingDirection.Down)
				{
					UpdateEnginesStates(downEngines, state: true);
					UpdateEnginesStates(upEngines, state: false);
				}
			}
		}
	}

	private void FixedUpdate()
	{
		lastMoveDirection = (base.transform.position - previousPosition).normalized;
		previousPosition = base.transform.position;
		if (lastMoveDirection.x > 0f)
		{
			movingRight = MovingDirection.Left;
		}
		else if (lastMoveDirection.x < 0f)
		{
			movingRight = MovingDirection.Right;
		}
		else
		{
			movingRight = MovingDirection.None;
		}
		if (lastMoveDirection.y > 0f)
		{
			movingUp = MovingDirection.Down;
		}
		else if (lastMoveDirection.y < 0f)
		{
			movingUp = MovingDirection.Up;
		}
		else
		{
			movingUp = MovingDirection.None;
		}
	}

	private void UpdateEnginesStates(List<Engine> enginesList, bool state)
	{
		for (int i = 0; i < enginesList.Count; i++)
		{
			enginesList[i].SetEngineState(state);
		}
	}
}
