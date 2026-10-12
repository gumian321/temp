using DG.Tweening;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class ImageSystem : MonoBehaviour
{
	public static void Alphalizer(Image image, float alpha)
	{
		Color color = image.color;
		color.a = alpha;
		image.color = color;
	}

	public static void Alphalizer(SpriteRenderer spriteRenderer, float alpha)
	{
		Color color = spriteRenderer.color;
		color.a = alpha;
		spriteRenderer.color = color;
	}

	public static Color Alphalizer(Color c, float alpha)
	{
		Color result = c;
		result.a = alpha;
		return result;
	}

	public static Color Alphalizer(float alpha)
	{
		Color white = Color.white;
		white.a = alpha;
		return white;
	}

	public static void Alphalizer(TextMeshPro text, float goal)
	{
		text.color = Alphalizer(text.color, goal);
	}

	public static void Alphalizer(TextMeshProUGUI text, float goal, TweenDuration tweenDuration, bool snap = false, TweenCallback tweenCallback = null)
	{
		if (snap)
		{
			text.color = Alphalizer(text.color, goal);
			return;
		}
		TweenController.DOFloat(text.color.a, goal, tweenDuration, (float alphaValue) =>
		{
			text.color = Alphalizer(text.color, alphaValue);
		}, ignoreTimeScale: true, tweenCallback);
	}

	public static void Alphalizer(TextMeshPro text, float goal, TweenDuration tweenDuration, TweenCallback tweenCallback = null)
	{
		TweenController.DOFloat(text.color.a, goal, tweenDuration, (float alphaValue) =>
		{
			text.color = Alphalizer(text.color, alphaValue);
		}, ignoreTimeScale: true, tweenCallback);
	}

	public static void Alphalizer(Image image, float goal, TweenDuration tweenDuration, bool IgnoreTimeScale = false, TweenCallback tweenCallback = null)
	{
		TweenController.DOFloat(image.color.a, goal, tweenDuration, (float alphaValue) =>
		{
			image.color = Alphalizer(image.color, alphaValue);
		}, IgnoreTimeScale, tweenCallback);
	}

	public static void Alphalizer(SpriteRenderer spriteRenderer, float goal, TweenDuration tweenDuration, bool IgnoreTimeScale = false, TweenCallback tweenCallback = null)
	{
		TweenController.DOFloat(spriteRenderer.color.a, goal, tweenDuration, (float alphaValue) =>
		{
			spriteRenderer.color = Alphalizer(spriteRenderer.color, alphaValue);
		}, IgnoreTimeScale, tweenCallback);
	}
}
