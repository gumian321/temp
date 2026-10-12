using System;
using System.Collections;
using TMPro;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.UI;

public class BindingUIAnimation : MonoBehaviour
{
	[SerializeField]
	private bool LoadOnAwake;

	[Header("Container Control Action")]
	[SerializeField]
	private InputActionReference inputActionReference;

	private InputBinding inputBinding;

	[Space]
	[Header("Container Behavior")]
	[SerializeField]
	private TweenDuration tweenDuration = TweenDuration.Very_Short;

	[SerializeField]
	private BindingUIAnimationType bindingUIAnimationType;

	[SerializeField]
	private GameObject holdObject;

	[SerializeField]
	private Image holdImage;

	[Space]
	[Header("Container Componments")]
	[SerializeField]
	private CanvasGroup bindingCG;

	[SerializeField]
	private Image bindingImage;

	[SerializeField]
	private GameObject bindingTextObject;

	[SerializeField]
	private TextMeshProUGUI bindingText;

	private bool isActivated;

	private float startSize;

	private float clickSize;

	private void OnEnable()
	{
		startSize = base.transform.localScale.x;
		clickSize = startSize * 0.75f;
		InputDataStore instance = Singleton<InputDataStore>.Instance;
		instance.OnControlChanged = (Action)Delegate.Combine(instance.OnControlChanged, new Action(SetBindingImage));
		InputDataStore instance2 = Singleton<InputDataStore>.Instance;
		instance2.OnControlApplied = (Action)Delegate.Combine(instance2.OnControlApplied, new Action(SetBindingImage));
		if (!isActivated && LoadOnAwake)
		{
			StartCoroutine(WaitToActivate());
		}
	}

	private IEnumerator WaitToActivate()
	{
		yield return null;
		ActivatePanel(inputActionReference, bindingUIAnimationType);
	}

	public void ActivatePanel(InputActionReference inputActionReference, BindingUIAnimationType bindingUIAnimationType)
	{
		base.gameObject.SetActive(value: true);
		this.inputActionReference = inputActionReference;
		this.bindingUIAnimationType = bindingUIAnimationType;
		SetBindingImage();
		OnActiveComplete();
		isActivated = true;
	}

	private void OnDisable()
	{
		InputDataStore instance = Singleton<InputDataStore>.Instance;
		instance.OnControlChanged = (Action)Delegate.Remove(instance.OnControlChanged, new Action(SetBindingImage));
		InputDataStore instance2 = Singleton<InputDataStore>.Instance;
		instance2.OnControlApplied = (Action)Delegate.Remove(instance2.OnControlApplied, new Action(SetBindingImage));
	}

	public void ShowPanel()
	{
		bindingCG.alpha = 1f;
	}

	public void HidePanel()
	{
		bindingCG.alpha = 0f;
	}

	private void OnActiveComplete()
	{
		if (bindingUIAnimationType == BindingUIAnimationType.Click)
		{
			PlayClickAnimation();
		}
		if (bindingUIAnimationType == BindingUIAnimationType.Hold)
		{
			PlayHoldAnimation();
		}
	}

	private void PlayClickAnimation()
	{
		TweenController.DelayedCall(tweenDuration, () =>
		{
			TweenController.ScaleV3(base.transform, startSize, clickSize, tweenDuration, ignoreTimeScale: true, OnPlayClickAnimationComplete);
		}, ignoreTimeScale: true);
	}

	private void OnPlayClickAnimationComplete()
	{
		TweenController.ScaleV3(base.transform, clickSize, startSize, tweenDuration, ignoreTimeScale: true, PlayClickAnimation);
	}

	private void PlayHoldAnimation()
	{
		TweenController.DelayedCall(tweenDuration, () =>
		{
			TweenController.ScaleV3(base.transform, startSize, clickSize, tweenDuration, ignoreTimeScale: true, OnPlayClickHoldAnimationComplete);
		}, ignoreTimeScale: true);
	}

	private void OnPlayClickHoldAnimationComplete()
	{
		holdObject.SetActive(value: true);
		holdImage.fillAmount = 0f;
		ImageSystem.Alphalizer(holdImage, 1f, tweenDuration, IgnoreTimeScale: true, () =>
		{
			TweenController.DOFloat(0f, 1f, tweenDuration, (float fill) =>
			{
				holdImage.fillAmount = fill;
			}, ignoreTimeScale: true, OnHoldComplete);
		});
	}

	private void OnHoldComplete()
	{
		ImageSystem.Alphalizer(holdImage, 0f, tweenDuration, IgnoreTimeScale: true, () =>
		{
			holdObject.SetActive(value: false);
			TweenController.ScaleV3(base.transform, clickSize, startSize, tweenDuration, ignoreTimeScale: true, PlayHoldAnimation);
		});
	}

	public void SetBindingImage()
	{
		SetBindingActionInfo();
		Sprite deviceBindingIcon = Singleton<InputDataStore>.Instance.GetDeviceBindingIcon(inputBinding.effectivePath);
		if (deviceBindingIcon != null)
		{
			bindingImage.gameObject.SetActive(value: true);
			bindingTextObject.gameObject.SetActive(value: false);
			bindingImage.sprite = deviceBindingIcon;
		}
		else
		{
			bindingImage.gameObject.SetActive(value: false);
			bindingTextObject.gameObject.SetActive(value: true);
			string humanReadableBinding = InputDataStore.GetHumanReadableBinding(inputBinding);
			bindingText.text = humanReadableBinding;
		}
	}

	private void SetBindingActionInfo()
	{
		if (inputActionReference == null)
		{
			Debug.LogError("InputActionReference is null", base.gameObject);
		}
		else if (inputActionReference.action != null)
		{
			InputAction inputAction = Singleton<InputDataStore>.Instance.GetInputAction(inputActionReference.action.name);
			// Editor / disconnected devices can leave an action without resolved controls.
            int bindingIndexForControl = inputAction.controls.Count > 0 ? inputAction.GetBindingIndexForControl(inputAction.controls[0]) : -1;
            if (bindingIndexForControl < 0 && inputAction.bindings.Count > 0) bindingIndexForControl = 0;
            if (bindingIndexForControl >= 0) inputBinding = inputAction.bindings[bindingIndexForControl];
		}
		else
		{
			Debug.LogError("InputActionReference is missing from the control container");
		}
	}
}
