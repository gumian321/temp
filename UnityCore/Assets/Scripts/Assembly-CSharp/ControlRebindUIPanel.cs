using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class ControlRebindUIPanel : SceneSingleton<ControlRebindUIPanel>
{
	[SerializeField]
	private CanvasGroup panelCG;

	[SerializeField]
	private TextMeshProUGUI panelTitleText;

	[SerializeField]
	private TextMeshProUGUI panelBindingText;

	[SerializeField]
	private Image panelBindingImage;

	[SerializeField]
	private TextMeshProUGUI panelNotifyText;

	[SerializeField]
	private GameObject controlCancelUIImage;

	public void ShowRebindPanel(string actionName, string keyCode)
	{
		SetRebindPanel(actionName);
		panelBindingImage.gameObject.SetActive(value: false);
		panelBindingText.gameObject.SetActive(value: true);
		panelBindingText.text = keyCode;
		controlCancelUIImage.SetActive(value: true);
	}

	public void ShowRebindPanel(string actionName, Sprite keySprite)
	{
		SetRebindPanel(actionName);
		panelBindingText.gameObject.SetActive(value: false);
		panelBindingImage.gameObject.SetActive(value: true);
		panelBindingImage.sprite = keySprite;
		controlCancelUIImage.SetActive(value: true);
	}

	private void SetRebindPanel(string actionName)
	{
		SceneSingleton<ControlUIManager>.Instance.OnRebindStarted();
		InputRebindManager.OnRebindIsDuplicate += OnRebindDuplicate;
		InputRebindManager.OnRebindIsExcluded += OnRebindExcluded;
		if (panelCG.alpha != 1f)
		{
			TweenController.DOFloat(0f, 1f, TweenDuration.Super_Short, (float f) =>
			{
				panelCG.alpha = f;
			}, ignoreTimeScale: true, () =>
			{
				panelCG.interactable = true;
				panelCG.blocksRaycasts = true;
			});
		}
		panelTitleText.text = Singleton<LocalizationSystem>.Instance.GetIDString("Controls_ReBinding") + " " + actionName;
	}

	public void HideRebindPanel()
	{
		InputRebindManager.OnRebindIsDuplicate -= OnRebindDuplicate;
		InputRebindManager.OnRebindIsExcluded -= OnRebindExcluded;
		TweenController.DOFloat(1f, 0f, TweenDuration.Super_Short, (float f) =>
		{
			panelCG.alpha = f;
		}, ignoreTimeScale: true, OnHideRebindPanelComplete);
		controlCancelUIImage.SetActive(value: false);
	}

	private void OnHideRebindPanelComplete()
	{
		SceneSingleton<ControlUIManager>.Instance.OnRebindEnded();
		panelNotifyText.gameObject.SetActive(value: false);
		panelCG.interactable = false;
		panelCG.blocksRaycasts = false;
	}

	public void OnRebindDuplicate()
	{
		Singleton<AudioManager>.Instance.PlaySFX(AudioClipTypes.Game_Feedback_Negative);
		panelNotifyText.text = Singleton<LocalizationSystem>.Instance.GetIDString("Controls_KeyAlreadyInUse");
		AnimateNotifyText();
	}

	public void OnRebindExcluded()
	{
		Singleton<AudioManager>.Instance.PlaySFX(AudioClipTypes.Game_Feedback_Negative);
		panelNotifyText.text = Singleton<LocalizationSystem>.Instance.GetIDString("Controls_KeyExcluded");
		AnimateNotifyText();
	}

	private void AnimateNotifyText()
	{
		panelNotifyText.gameObject.SetActive(value: true);
		TweenController.KillTweens(panelNotifyText.transform);
		TweenController.PunchScale(panelNotifyText.transform, 0.1f, TweenDuration.Very_Short, ignoreTimeScale: true);
	}
}
