using System.Collections.Generic;
using TMPro;
using UnityEngine;

public class PopUpTextManager : SceneSingleton<PopUpTextManager>
{
	[SerializeField]
	private TweenDuration tweenDuration = TweenDuration.Short;

	private Queue<PopUpContent> popUpTextsQueue;

	private bool isPlaying;

	[SerializeField]
	private RectTransform startRectTransform;

	[SerializeField]
	private RectTransform endRectTransform;

	private void Start()
	{
		popUpTextsQueue = new Queue<PopUpContent>();
	}

	public void AddPopUpText(string text1, string text2, float percent1 = 0f, float percent2 = 0f)
	{
		string text3 = buildPopUpTextString(text1, percent1);
		string text4 = buildPopUpTextString(text2, percent2);
		PopUpContent popUpContent = new PopUpContent();
		popUpContent.text = text3 + "\n" + text4;
		popUpContent.alignmentOption = TextAlignmentOptions.MidlineRight;
		QueuePopUpText(popUpContent);
	}

	public void AddPopUpText(string text, float percent = 0f)
	{
		if (!(text == ""))
		{
			PopUpContent popUpContent = new PopUpContent();
			popUpContent.text = buildPopUpTextString(text, percent);
			if (percent == 0f)
			{
				popUpContent.alignmentOption = TextAlignmentOptions.Center;
			}
			else
			{
				popUpContent.alignmentOption = TextAlignmentOptions.MidlineRight;
			}
			QueuePopUpText(popUpContent);
		}
	}

	private void QueuePopUpText(PopUpContent popUpContent)
	{
		popUpTextsQueue.Enqueue(popUpContent);
		if (!isPlaying && popUpTextsQueue.Count != 0)
		{
			isPlaying = true;
			SpawnPopUpText();
		}
	}

	private void SpawnPopUpText()
	{
		GameObject obj = MasterPool.Get(PrefabTypes.UI_PopUpText, base.transform);
		ObjectSystem.ReScale(obj, 1f);
		PopUpContent popUpContent = popUpTextsQueue.Dequeue();
		obj.GetComponent<PopUpTextController>().SetPopUpText(popUpContent, startRectTransform, endRectTransform, tweenDuration);
		isPlaying = true;
	}

	public void SpawnNextPopUpText()
	{
		if (isPlaying)
		{
			if (popUpTextsQueue.Count != 0)
			{
				isPlaying = true;
				SpawnPopUpText();
			}
			else
			{
				isPlaying = false;
			}
		}
	}

	private string buildPopUpTextString(string str, float percent = 0f)
	{
		if (percent != 0f)
		{
			Color rewardPercentBuffColor = Singleton<RewardDataStore>.Instance.GetRewardPercentBuffColor(percent);
			str = ((!(percent < 0f)) ? (str + " <color=#" + ColorHelper.GetHexCode(rewardPercentBuffColor) + "> +" + percent * 100f + "% </color>") : (str + " <color=#" + ColorHelper.GetHexCode(rewardPercentBuffColor) + "> " + percent * 100f + "% </color>"));
		}
		return str;
	}
}
