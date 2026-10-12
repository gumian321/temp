using System.Collections.Generic;
using UnityEngine;

public class PlayerMovement : SceneSingleton<PlayerMovement>
{
	private float targetEnginePower;

	private float lerpingSpeed = 2f;

	private float enginePower;

	private float currentEnginePower;

	private float accPower;

	private float deaccPower;

	private float currentHorSpeed;

	private float currentVerSpeed;

	private InputDataStore inputDataStore;

	[HideInInspector]
	public bool isMoving;

	private float boostEnginePower;

	private float HorDir;

	private float VerDir;

	private bool isMoveUpClicked;

	private bool isMoveDownClicked;

	private bool isMoveLeftClicked;

	private bool isMoveRightClicked;

	private List<Engine> enginesUpList = new List<Engine>();

	private bool enginesUpState;

	private List<Engine> enginesDownList = new List<Engine>();

	private bool enginesDownState;

	private List<Engine> enginesLeftList = new List<Engine>();

	private bool enginesLeftState;

	private List<Engine> enginesRightList = new List<Engine>();

	private bool enginesRightState;

	private bool prevBoostState;

	public void Setup()
	{
		inputDataStore = Singleton<InputDataStore>.Instance;
		enginePower = Singleton<PlayerDataStore>.Instance.GetEnginePower();
		accPower = PlayerDataStore.GetAccelrationPower();
		deaccPower = PlayerDataStore.GetDeaccelrationPower();
		targetEnginePower = enginePower;
		HorDir = 0f;
		VerDir = 0f;
	}

	private void Update()
	{
		if (isMoving)
		{
			float horDir = HorDir;
			float verDir = VerDir;
			float num = enginePower * Time.deltaTime;
			num = ((horDir != 0f) ? (num * accPower) : (num * deaccPower));
			float num2 = enginePower * Time.deltaTime;
			currentVerSpeed = Mathf.MoveTowards(maxDelta: (verDir != 0f) ? (num2 * accPower) : (num2 * deaccPower), current: currentVerSpeed, target: verDir);
			currentHorSpeed = Mathf.MoveTowards(currentHorSpeed, horDir, num);
			Vector3 vector = new Vector3(currentHorSpeed, currentVerSpeed, 0f);
			if (vector.magnitude > 1f)
			{
				vector = vector.normalized;
			}
			currentEnginePower = Mathf.Lerp(currentEnginePower, targetEnginePower, lerpingSpeed * Time.deltaTime);
			base.transform.position += vector * currentEnginePower * Time.deltaTime;
		}
	}

	public void ActivateEngineBoost(float boostEnginePower)
	{
		this.boostEnginePower = boostEnginePower;
		targetEnginePower += boostEnginePower;
		SetEnginesBoostState(newState: true);
	}

	public void deactivateEngineBoost()
	{
		boostEnginePower = 0f;
		targetEnginePower = enginePower;
		SetEnginesBoostState(newState: false);
	}

	public void UpdateEngine(float enginePower)
	{
		this.enginePower = enginePower;
		targetEnginePower -= boostEnginePower;
		targetEnginePower = enginePower;
		targetEnginePower += boostEnginePower;
	}

	public void MoveUpClicked(bool down)
	{
		if (!Singleton<InputManager>.Instance.isPlayerInputOn)
		{
			down = false;
		}
		if (isMoveUpClicked != down)
		{
			if (down)
			{
				VerDir++;
			}
			else
			{
				VerDir--;
			}
			enginesDownState = SetEnginesState(enginesDownList, enginesDownState, down);
			VerDir = Mathf.Clamp(VerDir, -1f, 1f);
			isMoveUpClicked = down;
		}
	}

	public void MoveDownClicked(bool down)
	{
		if (!Singleton<InputManager>.Instance.isPlayerInputOn)
		{
			down = false;
		}
		if (isMoveDownClicked != down)
		{
			if (down)
			{
				VerDir--;
			}
			else
			{
				VerDir++;
			}
			enginesUpState = SetEnginesState(enginesUpList, enginesUpState, down);
			VerDir = Mathf.Clamp(VerDir, -1f, 1f);
			isMoveDownClicked = down;
		}
	}

	public void MoveLeftClicked(bool down)
	{
		if (!Singleton<InputManager>.Instance.isPlayerInputOn)
		{
			down = false;
		}
		if (isMoveLeftClicked != down)
		{
			if (down)
			{
				HorDir--;
			}
			else
			{
				HorDir++;
			}
			enginesRightState = SetEnginesState(enginesRightList, enginesRightState, down);
			HorDir = Mathf.Clamp(HorDir, -1f, 1f);
			isMoveLeftClicked = down;
		}
	}

	public void MoveRightClicked(bool down)
	{
		if (!Singleton<InputManager>.Instance.isPlayerInputOn)
		{
			down = false;
		}
		if (isMoveRightClicked != down)
		{
			if (down)
			{
				HorDir++;
			}
			else
			{
				HorDir--;
			}
			enginesLeftState = SetEnginesState(enginesLeftList, enginesLeftState, down);
			HorDir = Mathf.Clamp(HorDir, -1f, 1f);
			isMoveRightClicked = down;
		}
	}

	public bool SetEnginesState(List<Engine> enginesList, bool prevState, bool newState)
	{
		if (prevState == newState)
		{
			return prevState;
		}
		for (int num = enginesList.Count - 1; num >= 0; num--)
		{
			enginesList[num].SetEngineState(newState);
		}
		return newState;
	}

	public void UpdateEnginesStates(List<Engine> enginesList, bool state)
	{
		for (int num = enginesList.Count - 1; num >= 0; num--)
		{
			enginesList[num].SetEngineState(state);
		}
	}

	public void SetEnginesBoostState(bool newState)
	{
		if (prevBoostState != newState)
		{
			prevBoostState = newState;
			for (int num = enginesUpList.Count - 1; num >= 0; num--)
			{
				enginesUpList[num].SetEngineBoostState(newState);
			}
			for (int num2 = enginesDownList.Count - 1; num2 >= 0; num2--)
			{
				enginesDownList[num2].SetEngineBoostState(newState);
			}
			for (int num3 = enginesLeftList.Count - 1; num3 >= 0; num3--)
			{
				enginesLeftList[num3].SetEngineBoostState(newState);
			}
			for (int num4 = enginesRightList.Count - 1; num4 >= 0; num4--)
			{
				enginesRightList[num4].SetEngineBoostState(newState);
			}
		}
	}

	public void AddEngine(GameObject engine, Vector3 direction)
	{
		if (object.Equals(direction, Vector3.left))
		{
			enginesLeftList.Add(engine.GetComponent<Engine>());
			UpdateEnginesStates(enginesLeftList, enginesLeftState);
		}
		else if (object.Equals(direction, Vector3.right))
		{
			enginesRightList.Add(engine.GetComponent<Engine>());
			UpdateEnginesStates(enginesRightList, enginesRightState);
		}
		else if (object.Equals(direction, Vector3.up))
		{
			enginesUpList.Add(engine.GetComponent<Engine>());
			UpdateEnginesStates(enginesUpList, enginesUpState);
		}
		else if (object.Equals(direction, Vector3.down))
		{
			enginesDownList.Add(engine.GetComponent<Engine>());
			UpdateEnginesStates(enginesDownList, enginesDownState);
		}
	}

	public void RemoveEngine(GameObject engine, Vector3 direction)
	{
		if (object.Equals(direction, Vector3.left))
		{
			enginesLeftList.Remove(engine.GetComponent<Engine>());
			return;
		}
		if (object.Equals(direction, Vector3.right))
		{
			enginesRightList.Remove(engine.GetComponent<Engine>());
			return;
		}
		if (object.Equals(direction, Vector3.up))
		{
			enginesUpList.Remove(engine.GetComponent<Engine>());
			return;
		}
		if (object.Equals(direction, Vector3.down))
		{
			enginesDownList.Remove(engine.GetComponent<Engine>());
			return;
		}
		string text = engine.name;
		Vector3 vector = direction;
		Debug.LogError("Didn't remove:" + text + " from anywhere, direction: " + vector.ToString(), engine);
	}
}
