using UnityEngine;

public class SceneSingleton<T> : MonoBehaviour where T : SceneSingleton<T>
{
	private static T instance;

	public static T Instance => instance;

	public static bool IsInitialized => instance != null;

	protected virtual void Awake()
	{
		if (instance != null)
		{
			Debug.LogErrorFormat("[Singleton] Trying to instantiate a second instance of singleton class {0}", GetType().Name);
		}
		else
		{
			instance = (T)this;
		}
	}

	public virtual void OnDestroy()
	{
		if (instance == this)
		{
			instance = null;
		}
	}
}
