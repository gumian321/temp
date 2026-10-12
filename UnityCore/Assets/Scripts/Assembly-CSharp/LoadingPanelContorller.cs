using System.Collections;
using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class LoadingPanelContorller : SceneSingleton<LoadingPanelContorller>
{
	[SerializeField]
	private CanvasGroup canvasGroup;

	private bool isLoading = true;

	[Space]
	[Header("Tips")]
	[SerializeField]
	private List<TipObject> tipsList;

	private int tipIndex;

	[SerializeField]
	private TextMeshProUGUI tipsText;

	[SerializeField]
	private PanelVideoPlayer panelVideoPlayer;

	[Space]
	[Header("Loading")]
	[SerializeField]
	private GameObject doneLoadingObject;

	[SerializeField]
	private GameObject loadingObject;

	[SerializeField]
	private TextMeshProUGUI loadingText;

	[SerializeField]
	private Image loadingPanel;

	private int dotCount;

	private int maxDotCount = 3;

	public void StartLoading()
	{
		Singleton<InputDataStore>.Instance.SetLoadingActionMap();
		SetUpTips();
		isLoading = true;
		StartCoroutine(AnimateText());
		loadingObject.SetActive(value: true);
		doneLoadingObject.SetActive(value: false);
		TweenController.KillTweens(loadingText.transform);
		TweenController.ScaleV3(loadingText.transform, 0f, 1f, TweenDuration.Very_Short, ignoreTimeScale: true);
	}

	public void EndLoading()
	{
		StopAllCoroutines();
		loadingObject.SetActive(value: false);
		doneLoadingObject.SetActive(value: true);
		isLoading = false;
	}

	public void DisableLoadingScreen()
	{
		if (!isLoading)
		{
			isLoading = true;
			TweenController.DOFloat(1f, 0f, TweenDuration.Super_Short, (float alpha) =>
			{
				canvasGroup.alpha = alpha;
			}, ignoreTimeScale: true, DisablePanel);
		}
	}

	public void DisablePanel()
	{
		base.gameObject.SetActive(value: false);
		SceneSingleton<GameManager>.Instance.EndLoading();
	}

	private void SetUpTips()
	{
		Singleton<LocalizationSystem>.Instance.GetIDString("Loading_NextTip");
		tipIndex = Random.Range(0, tipsList.Count);
		NextTip();
	}

	public void NextTip()
	{
		tipsText.text = tipsList[tipIndex].GetTipText();
		if (tipsList[tipIndex].tipVideoClip != null)
		{
			panelVideoPlayer.gameObject.SetActive(value: true);
			panelVideoPlayer.SetVideo(tipsList[tipIndex].tipVideoClip);
		}
		else
		{
			panelVideoPlayer.gameObject.SetActive(value: false);
		}
		tipIndex++;
		if (tipIndex >= tipsList.Count)
		{
			tipIndex = 0;
		}
	}

	private IEnumerator AnimateText()
	{
		dotCount = 0;
		WaitForSecondsRealtime delay = new WaitForSecondsRealtime(0.25f);
		while (true)
		{
			loadingText.text = Singleton<LocalizationSystem>.Instance.GetIDString("InGame_Loading");
			dotCount++;
			if (dotCount > maxDotCount)
			{
				dotCount = 0;
			}
			for (int i = 0; i < dotCount; i++)
			{
				loadingText.text += ".";
			}
			yield return delay;
		}
	}
}
