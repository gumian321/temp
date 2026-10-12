using System;
using TMPro;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.InputSystem;
using UnityEngine.UI;

public class ControlUIContainer : MonoBehaviour
{
	[Header("Container Control Action")]
	[SerializeField]
	private InputActionReference inputActionReference;

	[SerializeField]
	private InputActionReference altInputActionReference;

	private InputBinding inputBinding;

	private InputAction inputAction;

	private int bindingIndex;

	[Space]
	[Header("Container Componments")]
	[SerializeField]
	private TextMeshProUGUI containerTitleText;

	[SerializeField]
	private TextMeshProUGUI containerBindingText;

	[Space]
	[SerializeField]
	private Image containerBindingImage;

	[Space]
	[SerializeField]
	private Button containerRebindButton;

	[Space]
	[Space]
	[SerializeField]
	private bool isDebugOn;

	private void OnEnable()
	{
		InputDataStore instance = Singleton<InputDataStore>.Instance;
		instance.OnControlChanged = (Action)Delegate.Combine(instance.OnControlChanged, new Action(UpdateContainerUI));
	}

	private void OnDisable()
	{
		InputDataStore instance = Singleton<InputDataStore>.Instance;
		instance.OnControlChanged = (Action)Delegate.Remove(instance.OnControlChanged, new Action(UpdateContainerUI));
	}

	public void UpdateContainerUI()
	{
		if (base.gameObject.activeInHierarchy)
		{
			SetBindingActionInfo();
			containerTitleText.text = InputDataStore.GetActionName(inputAction);
			UpdateBindingDisplayUI();
		}
	}

	public void DoRebind()
	{
		if (!SceneSingleton<ControlUIManager>.Instance.isRebinding)
		{
			containerRebindButton.interactable = false;
			InputRebindManager.OnRebindCanceled += OnRebindCanceled;
			InputRebindManager.OnRebindComplete += OnRebindComplete;
			InputRebindManager.DoRebind(inputAction, bindingIndex);
			if (containerBindingText.gameObject.activeSelf)
			{
				SceneSingleton<ControlRebindUIPanel>.Instance.ShowRebindPanel(containerTitleText.text, containerBindingText.text);
			}
			else
			{
				SceneSingleton<ControlRebindUIPanel>.Instance.ShowRebindPanel(containerTitleText.text, containerBindingImage.sprite);
			}
			if (isDebugOn)
			{
				Debug.Log("ReBind Started " + inputAction.name + " " + containerTitleText.text);
			}
		}
	}

	public void OnRebindComplete()
	{
		Singleton<AudioManager>.Instance.PlaySFX(AudioClipTypes.Game_Feedback_Positive);
		if (altInputActionReference != null)
		{
			InputRebindManager.CopyControlsBinding(inputActionReference, altInputActionReference);
		}
		SceneSingleton<ControlUIManager>.Instance.ApplyNewRebind();
		OnRebindEnded();
	}

	public void OnRebindCanceled()
	{
		Singleton<AudioManager>.Instance.PlaySFX(AudioClipTypes.Game_Feedback_Negative);
		OnRebindEnded();
	}

	private void OnRebindEnded()
	{
		InputRebindManager.OnRebindCanceled -= OnRebindCanceled;
		InputRebindManager.OnRebindComplete -= OnRebindComplete;
		SceneSingleton<ControlRebindUIPanel>.Instance.HideRebindPanel();
		SetContainerAsSelectable();
		containerRebindButton.interactable = true;
		UpdateContainerUI();
	}

	private void UpdateBindingDisplayUI()
	{
		Sprite deviceBindingIcon = Singleton<InputDataStore>.Instance.GetDeviceBindingIcon(inputBinding.effectivePath);
		if (deviceBindingIcon != null)
		{
			containerBindingImage.gameObject.SetActive(value: true);
			containerBindingText.gameObject.SetActive(value: false);
			containerBindingImage.sprite = deviceBindingIcon;
		}
		else
		{
			containerBindingImage.gameObject.SetActive(value: false);
			containerBindingText.gameObject.SetActive(value: true);
			string humanReadableBinding = InputDataStore.GetHumanReadableBinding(inputBinding);
			containerBindingText.text = humanReadableBinding;
		}
	}

	public void SetContainerAsSelectable()
	{
		EventSystem.current.SetSelectedGameObject(containerRebindButton.gameObject);
	}

	public GameObject GetContainerSelectable()
	{
		return containerRebindButton.gameObject;
	}

	private void SetBindingActionInfo()
	{
		if (inputActionReference.action != null)
		{
			inputAction = Singleton<InputDataStore>.Instance.GetInputAction(inputActionReference.action.name);
			bindingIndex = inputAction.GetBindingIndexForControl(inputAction.controls[0]);
			inputBinding = inputAction.bindings[bindingIndex];
		}
		else
		{
			Debug.LogError("InputActionReference is missing from the control container");
		}
	}
}
