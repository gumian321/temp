using System;
using System.Collections.Generic;
using UnityEngine;

public class UIBackKeyManager
{
	private static Stack<Action> OnEscKeyPressedStack = new Stack<Action>();

	private static bool isDebugOn = false;

	public static void BackUI()
	{
		if ((!(SceneSingleton<ControlUIManager>.Instance != null) || !SceneSingleton<ControlUIManager>.Instance.isRebinding) && OnEscKeyPressedStack.Count > 0)
		{
			if (isDebugOn)
			{
				Debug.Log("Before BackUI " + OnEscKeyPressedStack.Count);
			}
			new Action(OnEscKeyPressedStack.Pop().Invoke)();
			if (isDebugOn)
			{
				Debug.Log("After BackUI " + OnEscKeyPressedStack.Count);
			}
		}
	}

	public static void AddOnBackKeyPressed(Action OnEscKeyPressed)
	{
		OnEscKeyPressedStack.Push(OnEscKeyPressed);
		if (isDebugOn)
		{
			Debug.Log("AddOnBackKeyPressed " + OnEscKeyPressedStack.Count);
		}
	}

	public static void ClearQueue()
	{
		if (isDebugOn)
		{
			Debug.Log("ClearQueue " + OnEscKeyPressedStack.Count);
		}
		OnEscKeyPressedStack.Clear();
	}
}
