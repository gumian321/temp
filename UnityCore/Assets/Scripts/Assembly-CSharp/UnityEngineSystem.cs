using UnityEngine;

public class UnityEngineSystem : MonoBehaviour
{
	public static float GetPerSecAmount(float amountPerSec, float percent = 0f)
	{
		return 1f / CalcPercent(amountPerSec, percent);
	}

	public static float GetTickAmount(float amountPerSec, float percent = 0f)
	{
		return CalcPercent(amountPerSec, percent) / (1f / Time.fixedDeltaTime);
	}

	public static float GetPercent(float value, float percent)
	{
		return value * percent;
	}

	public static float CalcPercent(float value, float percent)
	{
		if (percent < 0f)
		{
			return SubtractPercent(value, 0f - percent);
		}
		return AddPercent(value, percent);
	}

	private static float AddPercent(float value, float percent)
	{
		return value + value * percent;
	}

	private static float SubtractPercent(float value, float percent)
	{
		if (percent >= 1f)
		{
			percent = 0.99f;
		}
		return value - value * percent;
	}
}
