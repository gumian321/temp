using UnityEngine;

[RequireComponent(typeof(UIEventTriggers))]
public class UIFeedback : MonoBehaviour
{
	[SerializeField]
	private AudioClipTypes clickAudioClip = AudioClipTypes.UI_Click;

	[SerializeField]
	private AudioClipTypes hoverAudioClip = AudioClipTypes.UI_Hover;

	private void Awake()
	{
		SubscribeToEvents();
	}

	private void SubscribeToEvents()
	{
		UIEventTriggers component = GetComponent<UIEventTriggers>();
		component.OnPointerClickEvent.AddListener(OnPointerClick);
		component.OnPointerEnterEvent.AddListener(OnPointerEnter);
		component.OnPointerExitEvent.AddListener(OnPointerExit);
	}

	public void OnPointerClick()
	{
		Singleton<AudioManager>.Instance.PlaySFX(clickAudioClip);
	}

	public void OnPointerEnter()
	{
		Singleton<CurserManager>.Instance.SetCurser(CurserTypes.Hand);
		Singleton<AudioManager>.Instance.PlaySFX(hoverAudioClip);
	}

	public void OnPointerExit()
	{
		Singleton<CurserManager>.Instance.SetCurser(CurserTypes.Normal);
	}
}
