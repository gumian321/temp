using System.Collections.Generic;
using UnityEngine;

public class MovementArrowsController : MonoBehaviour
{
	[SerializeField]
	private TweenDuration tweenDuration = TweenDuration.Very_Short;

	[SerializeField]
	private List<SpriteRenderer> arrowsObjects;

	private int arrowsIndex;

	private void OnEnable()
	{
		arrowsIndex = 0;
		foreach (SpriteRenderer arrowsObject in arrowsObjects)
		{
			ImageSystem.Alphalizer(arrowsObject, 0.25f);
		}
		PlayNextArrow();
	}

	private void PlayNextArrow()
	{
		ImageSystem.Alphalizer(arrowsObjects[arrowsIndex], 0.25f);
		ImageSystem.Alphalizer(arrowsObjects[arrowsIndex], 1f, tweenDuration, IgnoreTimeScale: false, () =>
		{
			ImageSystem.Alphalizer(arrowsObjects[arrowsIndex], 0.25f, tweenDuration);
			arrowsIndex++;
			if (arrowsIndex >= arrowsObjects.Count)
			{
				arrowsIndex = 0;
			}
			PlayNextArrow();
		});
	}

	private void OnDisable()
	{
		foreach (SpriteRenderer arrowsObject in arrowsObjects)
		{
			TweenController.KillTweens(arrowsObject.transform);
		}
	}
}
