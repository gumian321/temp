using UnityEngine;

public class ObjectTriggersController : MonoBehaviour
{
	[SerializeField]
	private AudioClipTypes clickAudioClip = AudioClipTypes.UI_Click;

	[SerializeField]
	private AudioClipTypes hoverAudioClip = AudioClipTypes.UI_Hover;

	public void OnMouseEnter()
	{
		Singleton<CurserManager>.Instance.SetCurser(CurserTypes.Hand);
		Singleton<AudioManager>.Instance.PlaySFX(hoverAudioClip);
	}

	private void OnMouseOver()
	{
		if (Input.GetKeyDown(KeyCode.Mouse0))
		{
			OnMouseClick();
		}
	}

	public void OnMouseExit()
	{
		Singleton<CurserManager>.Instance.SetCurser(CurserTypes.Normal);
	}

	public void OnMouseClick()
	{
		Singleton<AudioManager>.Instance.PlaySFX(clickAudioClip);
	}
}
