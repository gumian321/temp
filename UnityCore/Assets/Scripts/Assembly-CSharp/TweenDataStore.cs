using UnityEngine;

public class TweenDataStore : MonoBehaviour
{
	public static float GetTweenDuration(TweenDuration a)
	{
		return a switch
		{
			TweenDuration.Super_Short => 0.25f, 
			TweenDuration.Very_Short => 0.5f, 
			TweenDuration.Short => 1f, 
			TweenDuration.Medium => 1.5f, 
			TweenDuration.Long => 3f, 
			TweenDuration.Very_Long => 6f, 
			_ => 0.5f, 
		};
	}

	public static float GetShakeStrength()
	{
		return 10f;
	}

	public static int GetShakeVibration()
	{
		return 25;
	}
}
