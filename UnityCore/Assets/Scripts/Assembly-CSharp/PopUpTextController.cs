using TMPro;
using UnityEngine;

public class PopUpTextController : MonoBehaviour
{
	private TextMeshProUGUI popUpText;

	private RectTransform rectTransform;

	private void Awake()
	{
		popUpText = GetComponent<TextMeshProUGUI>();
		rectTransform = GetComponent<RectTransform>();
	}

	public void SetPopUpText(PopUpContent popUpContent, RectTransform startRectTransform, RectTransform endRectTransform, TweenDuration tweenDuration)
	{
		popUpText.text = popUpContent.text;
		popUpText.alignment = popUpContent.alignmentOption;
		ImageSystem.Alphalizer(popUpText, 1f, tweenDuration, snap: true);
		ImageSystem.Alphalizer(popUpText, 0f, tweenDuration);
		rectTransform.anchoredPosition = startRectTransform.anchoredPosition;
		TweenController.KillTweens(rectTransform);
		TweenController.LocalRectMove(rectTransform, endRectTransform, tweenDuration, ignoreTimeScale: true, Disable);
	}

	private void Disable()
	{
		SceneSingleton<PopUpTextManager>.Instance.SpawnNextPopUpText();
		MasterPool.ReturnToPoolTransform(base.gameObject, PrefabTypes.UI_PopUpText);
	}
}
