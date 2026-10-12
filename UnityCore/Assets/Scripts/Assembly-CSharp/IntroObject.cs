using System;
using TMPro;
using UnityEngine;

[Serializable]
public class IntroObject
{
	[SerializeField]
	private SpriteRenderer objImage;

	[SerializeField]
	private TextMeshPro objText;

	public void HideObject()
	{
		if (objImage != null)
		{
			ImageSystem.Alphalizer(objImage, 0f);
		}
		if (objText != null)
		{
			ImageSystem.Alphalizer(objText, 0f);
		}
	}

	public void AnimateObject(TweenDuration tweenDuration)
	{
		if (objImage != null)
		{
			ImageSystem.Alphalizer(objImage, 1f, tweenDuration, IgnoreTimeScale: true, () =>
			{
				ImageSystem.Alphalizer(objImage, 0f, tweenDuration, IgnoreTimeScale: true);
			});
		}
		if (objText != null)
		{
			ImageSystem.Alphalizer(objText, 1f, tweenDuration, () =>
			{
				ImageSystem.Alphalizer(objText, 0f, tweenDuration);
			});
		}
	}
}
