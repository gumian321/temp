using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;

public class InputRebindManager : Singleton<InputRebindManager>
{
	private static PlayerInputActions baseInputActions;

	private static List<string> IgnoredBindingActions = new List<string>();

	private static InputActionRebindingExtensions.RebindingOperation currentRebindingOperation = null;

	private static bool isDebugOn = false;

	public static bool isRebinding => currentRebindingOperation != null;

	public static event Action OnRebindComplete;

	public static event Action OnRebindIsDuplicate;

	public static event Action OnRebindIsExcluded;

	public static event Action OnRebindCanceled;

	public static event Action<InputAction, int> OnRebindStarted;

	private void OnEnable()
	{
		InputDataStore inputDataStore = Singleton<InputDataStore>.Instance;
		inputDataStore.OnControlChanged = (Action)Delegate.Combine(inputDataStore.OnControlChanged, new Action(OnControlChanged));
		IgnoredBindingActions = Singleton<InputDataStore>.Instance.IgnoredBindings;
	}

	private void OnDisable()
	{
		InputDataStore inputDataStore = Singleton<InputDataStore>.Instance;
		inputDataStore.OnControlChanged = (Action)Delegate.Remove(inputDataStore.OnControlChanged, new Action(OnControlChanged));
	}

	private void OnControlChanged()
	{
		if (currentRebindingOperation != null)
		{
			currentRebindingOperation.Cancel();
		}
	}

	public static void DoRebind(InputAction actionToRebind, int bindingIndex)
	{
		baseInputActions = InputDataStore.baseInputActions;
		if (actionToRebind == null || bindingIndex < 0)
		{
			return;
		}
		actionToRebind.Disable();
		currentRebindingOperation = actionToRebind.PerformInteractiveRebinding(bindingIndex);
		foreach (string deviceCancelKey in Singleton<InputDataStore>.Instance.GetDeviceCancelKeys())
		{
			currentRebindingOperation.WithCancelingThrough(deviceCancelKey);
		}
		foreach (string fixedIgnoredKey in InputDataStore.fixedIgnoredKeys)
		{
			currentRebindingOperation.WithControlsExcluding(fixedIgnoredKey);
		}
		currentRebindingOperation.OnComplete((InputActionRebindingExtensions.RebindingOperation operation) =>
		{
			actionToRebind.Enable();
			operation.Dispose();
			if (IsCancelKey(actionToRebind, bindingIndex))
			{
				currentRebindingOperation.Cancel();
				currentRebindingOperation = null;
			}
			else if (IsDuplicate(actionToRebind, bindingIndex))
			{
				SaveSystem.LoadPlayerInput();
				DoRebind(actionToRebind, bindingIndex);
				OnRebindIsDuplicate?.Invoke();
			}
			else if (IsExcluded(actionToRebind, bindingIndex))
			{
				SaveSystem.LoadPlayerInput();
				DoRebind(actionToRebind, bindingIndex);
				OnRebindIsExcluded?.Invoke();
			}
			else
			{
				OnRebindComplete?.Invoke();
				currentRebindingOperation = null;
				if (isDebugOn)
				{
					Debug.Log(actionToRebind?.ToString() + " Completed Rebinding");
				}
			}
		});
		currentRebindingOperation.OnCancel((InputActionRebindingExtensions.RebindingOperation operation) =>
		{
			actionToRebind.Enable();
			operation.Dispose();
			SaveSystem.LoadPlayerInput();
			OnRebindCanceled?.Invoke();
			currentRebindingOperation = null;
			if (isDebugOn)
			{
				Debug.Log(actionToRebind?.ToString() + " Canceled Rebinding");
			}
		});
		currentRebindingOperation.OnMatchWaitForAnother(0.1f);
		currentRebindingOperation.Start();
		OnRebindStarted?.Invoke(actionToRebind, bindingIndex);
		if (isDebugOn)
		{
			Debug.Log(actionToRebind?.ToString() + " Started Rebinding");
		}
	}

	public static bool IsCancelKey(InputAction actionToRebind, int bindingIndex)
	{
		InputBinding inputBinding = actionToRebind.bindings[bindingIndex];
		List<string> list = new List<string>();
		list.AddRange(Singleton<InputDataStore>.Instance.GetDeviceCancelKeys());
		if (isDebugOn && list.Contains(inputBinding.effectivePath))
		{
			InputBinding inputBinding2 = inputBinding;
			Debug.Log("Canceled binding found: " + inputBinding2.ToString());
		}
		return list.Contains(inputBinding.effectivePath);
	}

	public static bool IsExcluded(InputAction actionToRebind, int bindingIndex)
	{
		InputBinding inputBinding = actionToRebind.bindings[bindingIndex];
		List<string> list = new List<string>();
		list.AddRange(InputDataStore.fixedIgnoredKeys);
		list.AddRange(Singleton<InputDataStore>.Instance.GetDeviceIgnoredKeys());
		if (list.Contains(inputBinding.effectivePath))
		{
			if (isDebugOn)
			{
				Debug.Log("Excluded binding found: " + inputBinding.effectivePath);
			}
			return true;
		}
		return false;
	}

	public static bool IsDuplicate(InputAction actionToRebind, int bindingIndex)
	{
		InputBinding inputBinding = actionToRebind.bindings[bindingIndex];
		foreach (InputBinding binding in actionToRebind.actionMap.bindings)
		{
			if (!(binding.action == inputBinding.action) && !IgnoredBindingActions.Contains(binding.action) && binding.effectivePath == inputBinding.effectivePath)
			{
				if (isDebugOn)
				{
					InputBinding inputBinding2 = inputBinding;
					string text = inputBinding2.ToString();
					inputBinding2 = binding;
					Debug.Log("Duplicate binding found: " + text + " with " + inputBinding2.ToString());
				}
				return true;
			}
		}
		return false;
	}

	public static void CopyControlsBinding(InputActionReference copyAction, InputActionReference pasteAction)
	{
		InputAction inputAction = Singleton<InputDataStore>.Instance.GetInputAction(copyAction.action.name);
		int bindingIndexForControl = inputAction.GetBindingIndexForControl(inputAction.controls[0]);
		InputBinding bindingOverride = inputAction.bindings[bindingIndexForControl];
		InputAction inputAction2 = Singleton<InputDataStore>.Instance.GetInputAction(pasteAction.action.name);
		int bindingIndexForControl2 = inputAction2.GetBindingIndexForControl(inputAction2.controls[0]);
		_ = inputAction2.bindings[bindingIndexForControl2];
		if (isDebugOn)
		{
			Debug.Log("CopyControlsBinding " + inputAction.name + " -> " + inputAction2.name);
		}
		inputAction2.ApplyBindingOverride(bindingIndexForControl, bindingOverride);
	}
}
