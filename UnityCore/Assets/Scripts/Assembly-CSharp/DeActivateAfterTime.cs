using UnityEngine;

public class DeActivateAfterTime : MonoBehaviour
{
	[SerializeField]
	private PrefabTypes prefabType;

	[SerializeField]
	private float duration = 3f;

	private void OnEnable()
	{
		Invoke("DeActivate", duration);
	}

	public void SetDuration(float newDuration)
	{
		CancelInvoke();
		Invoke("DeActivate", newDuration);
	}

	public void DeActivate()
	{
		CancelInvoke();
		MasterPool.ReturnToPoolTransform(base.gameObject, prefabType);
	}
}
