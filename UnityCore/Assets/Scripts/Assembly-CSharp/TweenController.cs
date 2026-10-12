using System;
using System.Collections.Generic;
using DG.Tweening;
using UnityEngine;

public class TweenController : MonoBehaviour
{
	private void Awake()
	{
		DOTween.SetTweensCapacity(500, 50);
	}

	public static void KillTweens(Transform objTransform)
	{
		DOTween.Kill(objTransform);
	}

	public static void Shake(Transform objTransform, Vector3 originalScale, float duration, bool ignoreTimeScale = false)
	{
		objTransform.DOShakeScale(duration, 0.1f).SetUpdate(ignoreTimeScale).OnComplete(() =>
		{
			objTransform.transform.localScale = originalScale;
		});
	}

	public static void Scale(Transform objTransform, float startScale, float endScale, TweenDuration tweenDuration, bool ignoreTimeScale = false, TweenCallback tweenCallback = null)
	{
		Ease ease = ((!(startScale > endScale)) ? Ease.OutBack : Ease.InBack);
		objTransform.localScale = Vector2.one * startScale;
		objTransform.DOScale(Vector2.one * endScale, TweenDataStore.GetTweenDuration(tweenDuration)).SetEase(ease).SetUpdate(ignoreTimeScale)
			.OnComplete(tweenCallback);
	}

	public static void ScaleV3(Transform objTransform, float startScale, float endScale, TweenDuration tweenDuration, bool ignoreTimeScale = false, TweenCallback tweenCallback = null)
	{
		Ease ease = ((!(startScale > endScale)) ? Ease.OutBack : Ease.InBack);
		objTransform.localScale = Vector3.one * startScale;
		objTransform.DOScale(Vector3.one * endScale, TweenDataStore.GetTweenDuration(tweenDuration)).SetEase(ease).SetUpdate(ignoreTimeScale)
			.OnComplete(tweenCallback);
	}

	public static void PunchScale(Transform objTransform, float Power, TweenDuration tweenDuration, bool ignoreTimeScale = false, TweenCallback tweenCallback = null)
	{
		objTransform.localScale = Vector2.one;
		objTransform.DOPunchScale(Vector2.one * Power, TweenDataStore.GetTweenDuration(tweenDuration)).SetEase(Ease.InOutBack).SetUpdate(ignoreTimeScale)
			.OnComplete(tweenCallback);
	}

	public static void LocalMove(Transform objTransform, Vector3 targetLocalPostion, TweenDuration tweenDuration, bool ignoreTimeScale = false, TweenCallback tweenCallback = null)
	{
		objTransform.DOLocalMove(targetLocalPostion, TweenDataStore.GetTweenDuration(tweenDuration)).SetUpdate(ignoreTimeScale).OnComplete(tweenCallback);
	}

	public static void DelayedCall(TweenDuration tweenDuration, TweenCallback tweenCallback = null, bool ignoreTimeScale = false)
	{
		DOVirtual.DelayedCall(TweenDataStore.GetTweenDuration(tweenDuration), tweenCallback, ignoreTimeScale);
	}

	public static void DelayedCall(float delay, TweenCallback tweenCallback = null, bool ignoreTimeScale = false)
	{
		DOVirtual.DelayedCall(delay, tweenCallback, ignoreTimeScale);
	}

	public static void LocalRectMove(RectTransform objTransform, RectTransform targetTransform, TweenDuration tweenDuration, bool ignoreTimeScale = false, TweenCallback tweenCallback = null)
	{
		DOTween.To(() => objTransform.anchoredPosition, (Vector2 x) =>
		{
			objTransform.anchoredPosition = x;
		}, targetTransform.anchoredPosition, TweenDataStore.GetTweenDuration(tweenDuration)).SetUpdate(ignoreTimeScale).OnComplete(tweenCallback);
	}

	public static void LocalMove(Transform objTransform, Vector3 targetLocalPostion, float duration, TweenCallback tweenCallback = null)
	{
		objTransform.DOLocalMove(targetLocalPostion, duration).OnComplete(tweenCallback);
	}

	public static void DOFloat(float from, float to, TweenDuration tweenDuration, TweenCallback<float> tweenCallUpdate, bool ignoreTimeScale = false, TweenCallback tweenCallBack = null)
	{
		DOVirtual.Float(from, to, TweenDataStore.GetTweenDuration(tweenDuration), (float floatValue) =>
		{
			tweenCallUpdate(floatValue);
		}).SetUpdate(ignoreTimeScale).OnComplete(tweenCallBack);
	}

	public static void DOColor(SpriteRenderer spriteRenderer, Color endColor, TweenDuration tweenDuration, bool ignoreTimeScale = false, TweenCallback tweenCallback = null)
	{
		spriteRenderer.DOColor(endColor, TweenDataStore.GetTweenDuration(tweenDuration)).SetUpdate(ignoreTimeScale).OnComplete(tweenCallback);
	}

	public static void DOCameraColor(Camera cam, Color endColor, TweenDuration tweenDuration, bool ignoreTimeScale = false, TweenCallback tweenCallback = null)
	{
		DOCameraColor(cam, endColor, TweenDataStore.GetTweenDuration(tweenDuration), ignoreTimeScale, tweenCallback);
	}

	public static void DOCameraColor(Camera cam, Color endColor, float tweenDuration, bool ignoreTimeScale = false, TweenCallback tweenCallback = null)
	{
		cam.DOColor(endColor, tweenDuration).SetUpdate(ignoreTimeScale).OnComplete(tweenCallback);
	}

	public static void ScatterItem(Vector2 centerPos, Transform itemTransform, Action<Transform> action = null)
	{
		itemTransform.localPosition = centerPos;
		KillTweens(itemTransform);
		Scale(itemTransform, 0f, 1f, TweenDuration.Medium);
		RotateAngle(itemTransform, UnityEngine.Random.Range(0, 360));
		Vector3 vector = itemTransform.localRotation * Vector3.up * UnityEngine.Random.Range(0.5f, 2f);
		LocalMove(itemTransform, itemTransform.localPosition + vector, TweenDuration.Short, ignoreTimeScale: false, () =>
		{
			action(itemTransform);
		});
	}

	public static List<Transform> ScatterItems(Vector2 centerPos, float itemsCount, PrefabTypes prefabType, Action<Transform> action = null, bool ignoreTimeScale = false)
	{
		float num = 360f / itemsCount;
		float minInclusive = 0f;
		List<Transform> list = new List<Transform>();
		for (int i = 1; (float)i <= itemsCount; i++)
		{
			Transform itemTransform = MasterPool.GetPos(prefabType, centerPos).transform;
			ObjectSystem.ReScale(itemTransform, 1f);
			list.Add(itemTransform);
			KillTweens(itemTransform);
			float num2 = (float)i * num;
			RotateAngle(itemTransform, UnityEngine.Random.Range(minInclusive, num2));
			minInclusive = num2;
			Vector3 vector = itemTransform.localRotation * Vector3.up * UnityEngine.Random.Range(0.5f, 2f);
			LocalMove(itemTransform, itemTransform.localPosition + vector, TweenDuration.Very_Short, ignoreTimeScale, () =>
			{
				action(itemTransform);
			});
		}
		return list;
	}

	private static void RotateAngle(Transform obj, float angle)
	{
		Vector3 zero = Vector3.zero;
		zero.z = angle;
		obj.eulerAngles = zero;
	}
}
