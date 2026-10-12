using UnityEngine;

public class Singleton<T> : MonoBehaviour where T : Singleton<T>
{
	private static T instance;

	public static T Instance => instance;

	public static bool IsInitialized => instance != null;

	protected virtual void Awake()
	{
		if (instance != null)
		{
			Object.Destroy(base.gameObject);
			return;
		}
		instance = (T)this;
		Object.DontDestroyOnLoad(base.gameObject);
	}
}
